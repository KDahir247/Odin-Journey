package main

import "core:slice"
import "core:fmt"
import "core:thread"
import "core:sys/windows"
import "core:sync"
import "core:intrinsics"
import "core:os"
import "core:math/linalg"

import "vendor:sdl2"
import "../journey"
import "core:encoding/json"
import "vendor:stb/image"
import "vendor:stb/rect_pack"

loop_fn :: #type proc(game_loop : ^GameLoop)
event_fn :: #type proc(game_loop : ^GameLoop, event : ^sdl2.Event)

QUERY_PERF_FREQUENCY :: 1000000
RCP_QUERY_PERF_FREQUENCY :: 1.0 / QUERY_PERF_FREQUENCY

GameLoop :: struct{
   last_delta_time : f32,
   elapsed_time : f32,
   elapsed_fixed_time : f32,

   maximum_frame_time : f32,
   update_per_second : f32,
   fixed_timestep : f32,

   accumulated_time : f32,
   carry_over_time : f32,

   previous_time : f32,
   current_time : f32,

   terminate_next_iteration : bool,
}

GameFnDescriptor :: struct{
    update : loop_fn,
    fixed_update : loop_fn,
    on_animation : loop_fn,
    //late_update : loop_fn,
}

next_frame_window :: proc(game_loop : ^GameLoop, game_descriptor : GameFnDescriptor) -> bool{
    
    large_time : windows.LARGE_INTEGER

    if game_loop.terminate_next_iteration{
        return false
    }

    windows.QueryPerformanceCounter(&large_time)
    game_loop.current_time = f32(large_time)

    delta_time := min((game_loop.current_time - game_loop.previous_time) / 1000000, game_loop.maximum_frame_time)
    
    game_loop.last_delta_time = delta_time
    game_loop.elapsed_time += delta_time
    game_loop.accumulated_time += delta_time + game_loop.carry_over_time

    for game_loop.accumulated_time >= game_loop.fixed_timestep{
        game_descriptor.fixed_update(game_loop)

        game_loop.elapsed_fixed_time += game_loop.fixed_timestep
        game_loop.accumulated_time -= game_loop.fixed_timestep
    }

    game_descriptor.update(game_loop)
    game_descriptor.on_animation(game_loop)

    game_loop.carry_over_time = game_loop.accumulated_time

    game_loop.previous_time = game_loop.current_time

    return !game_loop.terminate_next_iteration
}

start_looping_game :: proc(game_loop : ^GameLoop, event : ^sdl2.Event,event_fn : event_fn, game_descriptor : GameFnDescriptor){
    for next_frame_window(game_loop, game_descriptor){
        for sdl2.PollEvent(event){
            event_fn(game_loop, event)
            game_loop.terminate_next_iteration = event.type == sdl2.EventType.QUIT
        }
    }
}

// If refresh rate is zero it will adapt the refresh rate with the monitor refresh rate (uses win call)
// linux it a bit tricker it need Xrandr extension, so this only works for windows. 
init_game_loop_window :: proc(refresh_rate : f32 = 0 , refresh_rate_multiplier : f32 = 0.5, max_frame_time :f32= journey.MAX_DELTA_TIME) -> GameLoop{
    large_time : windows.LARGE_INTEGER

    refresh_rate := refresh_rate

    if refresh_rate == 0{
        display_setting : windows.DEVMODEW
        windows.EnumDisplaySettingsW(nil,windows.ENUM_CURRENT_SETTINGS, &display_setting)
        refresh_rate = f32(display_setting.dmDisplayFrequency)
    }

    refresh_rate *= refresh_rate_multiplier
    fixed_time_step := 1.0 / refresh_rate
    
    windows.QueryPerformanceCounter(&large_time)

    current_time := f32(large_time) 
    previous_time := f32(large_time)

    return GameLoop{
        last_delta_time = 0,

        maximum_frame_time = max_frame_time,
        update_per_second = refresh_rate,
        fixed_timestep = fixed_time_step,

        previous_time = previous_time,
        current_time = current_time,
    }
}

//FNV-1a Hash
string_hash :: proc(path : string) -> uint{
	hash :uint=  0xcbf29ce484222325
	prime :uint= 0x100000001b3

	for char_rune in path{
		hash ~= cast(uint)(char_rune)
		hash *= prime
	}
	return hash

}

create_game_entity :: proc($tex_path : string, $shader_cache : u32, position : [2]f32) -> uint{
    world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)

	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)
	
	path_hash := string_hash(tex_path)
	if path_hash not_in resource.render_buffer.sprite_batch_groups{
		width :i32= 0
		height :i32= 0
		tex := image.load("resource/sprite/padawan/pad.png",&width,&height,nil,  4)

		tex_param : journey.TextureParam = journey.TextureParam{
			texture = tex,
			width = width,
			height = height,
			shader_cache = 0,
		}

		resource.render_buffer.sprite_batch_groups[path_hash] = journey.SpriteBatchGroup{
			texture_param = tex_param,
			instances = make([dynamic]journey.RenderInstanceData),
		}
	}

	sprite_batch := &resource.render_buffer.sprite_batch_groups[path_hash]

	append(&sprite_batch.instances, journey.RenderInstanceData{
		transform = {
			1.0, 0.0, 0.0, position[0],
			0.0, 1.0, 0.0, position[1],
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},
		//First Frame in animation.
		src_rect = {
			0.0,
			0.0,
			f32(sprite_batch.texture_param.width),
			f32(sprite_batch.texture_param.height),
		},
	})

	game_entity := journey.create_entity(world)

	journey.add_soa_component(world, game_entity, journey.SpriteInstance{
		hash = path_hash,
		instance_index = len(sprite_batch.instances) - 1,
	})

	sync.atomic_store_explicit(&resource.render_buffer.changed_flag, true, sync.Atomic_Memory_Order.Relaxed)

	return game_entity
}

//////////////////////////////////////////////////////////////////////

event_update :: proc(game_loop : ^GameLoop, event : ^sdl2.Event){
	
}

fixed_update :: proc(game_loop : ^GameLoop){
    world := cast(^journey.World)context.user_ptr
	
}

update :: proc(game_loop : ^GameLoop){
	journey.BEGIN_EVENT("Update")



	journey.END_EVENT()
}

on_animation :: proc(game_loop : ^GameLoop){
    world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)

	// Cache texture and shader and render data to send to render thread
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)

	anim_sprite_query := journey.query(world, journey.Animator, journey.SpriteInstance, 4)

	for component_storage, index in journey.run(&anim_sprite_query){
		journey.BEGIN_EVENT("Animation Loop")

		sprite := component_storage.component_b[index]
		animator := component_storage.component_a[index]

		current_clip := animator.clips[animator.current_clip]

		animation_delta_time := (game_loop.elapsed_time - animator.animation_time) 

		frame_to_update := linalg.floor(animation_delta_time * animator.animation_speed)

		update_mask :f32= max(frame_to_update, 0)

		next_frame := animator.previous_frame + int(frame_to_update)
		rcp_update_mask := 1 - update_mask

		animator.previous_frame = next_frame

		animator.previous_frame %= current_clip.len

		animator.animation_time = (game_loop.elapsed_time * update_mask) + (animator.animation_time * rcp_update_mask)
		y :=current_clip.index * current_clip.height
		x := animator.previous_frame * current_clip.width
		sprite_batch := resource.render_buffer.sprite_batch_groups[sprite.hash]
		sprite_batch.instances[sprite.instance_index].src_rect = {
			f32(x), f32(y), f32(current_clip.width), f32(current_clip.height),

		} 
		
		journey.END_EVENT()
	}
}

main ::  proc()  {

	////////////////////// Game Initialize /////////////////////////
	journey.CREATE_PROFILER("profiling/ProfilerData.spall")

	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo 

	//temp solution
	resource : journey.ResourceCache = journey.ResourceCache{
		render_buffer = new(journey.RenderBatchBuffer),
	}

	resource.render_buffer.sprite_batch_groups = make(map[uint]journey.SpriteBatchGroup)

	game_loop := init_game_loop_window()

	world := journey.init_world()
	context.user_ptr = world

	//TODO: khal this will change when resource is implement in journey_ecs
	//Unique entity which will have the unique components.
	context.user_index = int(journey.create_entity(world))
	journey.register(world, journey.ResourceCache)
	journey.add_soa_component(world, uint(context.user_index), resource)
	//

    journey.register(world, journey.Animator)
	journey.register(world, journey.SpriteInstance)

	sdl2.InitSubSystem(sdl2.InitFlags{sdl2.InitFlag.EVENTS})

	window := sdl2.CreateWindow(
		"MyGame",
		sdl2.WINDOWPOS_CENTERED, 
		sdl2.WINDOWPOS_CENTERED,
		1045, // 29 * 36 + 1 (WIDTH + CELL SIZE + OFFSET)
		613, // 17 * 36 + 1 (HEIGHT + CELL SIZE + OFFSET)
		sdl2.WindowFlags{
			sdl2.WindowFlag.SHOWN,
			sdl2.WindowFlag.RESIZABLE,
			sdl2.WindowFlag.ALLOW_HIGHDPI,
		},
	)

	sdl2.GetWindowWMInfo(window, &window_info)

	render_thread := journey.create_renderer(journey.RenderBackend.DX11,window_info.info.win.window, resource.render_buffer)

	defer{	
		journey.stop_renderer(render_thread)

		journey.deinit_world(world)
		context.user_ptr = nil

		free(resource.render_buffer)

		sdl2.DestroyWindow(window)
		sdl2.Quit()

		journey.FREE_PROFILER()
	}
	////////////////////////////////////////////////////////////////////

	///////////////////////// Game Start ///////////////////////////////

	player_entity_1 := create_game_entity("resource/sprite/padawan/pad.png", 0, {200,.0})
	player_entity_2 := create_game_entity("resource/sprite/padawan/pad.png", 0, {300,.0})

	//TODO:khal proof of implementation flesh it out.
	data,_ := os.read_entire_file_from_filename("resource/animation/player_anim.json")
	player_anim : journey.Animator
	json.unmarshal(data, &player_anim)

	journey.add_soa_component(world, player_entity_1, player_anim)
	journey.add_soa_component(world, player_entity_2, player_anim)

	///////////////////////////////////////////////////////////////////

	///////////////////////// Game Loop ///////////////////////////////
	start_looping_game(&game_loop,&sdl2_event, event_update, GameFnDescriptor{
		update = update,
		fixed_update = fixed_update,
		on_animation = on_animation,
	})

	///////////////////////// Game Loop ///////////////////////////////
}
