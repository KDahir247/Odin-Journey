package main

import "core:fmt"
import "core:thread"
import "core:sys/windows"
import "core:sync"
import "core:os"
import "core:math/linalg"

import "vendor:sdl2"
import "../journey"
import "core:encoding/json"
import "vendor:stb/image"

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

    delta_time := min((game_loop.current_time - game_loop.previous_time) * RCP_QUERY_PERF_FREQUENCY, game_loop.maximum_frame_time)
    
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
	if path_hash not_in resource.render_buffer.render_batch_groups{
		width :i32= 0
		height :i32= 0
		tex := image.load("resource/sprite/padawan/pad.png",&width,&height,nil,  4)

		tex_param : journey.TextureParam = journey.TextureParam{
			texture = tex,
			width = width,
			height = height,
			shader_cache = 0,
		}

		resource.render_buffer.render_batch_groups[path_hash] = journey.RenderBatchGroup{
			texture_param = tex_param,
			instances = make([dynamic]journey.RenderInstanceData),
		}
	}

	sprite_batch := &resource.render_buffer.render_batch_groups[path_hash]

	append(&sprite_batch.instances, journey.RenderInstanceData{
		transform = {
			1.0, 0.0, 0.0, position[0],
			0.0, 1.0, 0.0, position[1],
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},

		src_rect = {
			0.0,
			0.0,
			f32(sprite_batch.texture_param.width),
			f32(sprite_batch.texture_param.height),
		},
	})

	game_entity := journey.create_entity(world)

	journey.add_soa_component(world, game_entity, journey.RenderInstance{
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
	journey.BEGIN_EVENT("Fixed Update")

    world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)

    velocity_integrate_query := journey.query(world, journey.Velocity, journey.Damping, journey.Acceleration, 8)
	acceleration_integrate_query := journey.query(world, journey.Mass, journey.AccumulatedForce,journey.Acceleration, 8)
	gravity_query := journey.query(world, journey.Mass, journey.AccumulatedForce, 8)


	//TODO:khal something seem off, but it works. good working progress :P
	for component_storage, index in journey.run(&gravity_query){
		mutable_component_storage := component_storage

		//Assuming that the inverse mass is not zero if so then we have a divide by zero exception.
		mass := 1.0 /mutable_component_storage.component_a[index].val
		
		force := journey.GRAVITY * mass

		mutable_component_storage.component_b[index].y += force
	}

	//Simple Physics Integrate	
	for component_storage, index in journey.run(&acceleration_integrate_query){
		mutable_component_storage := component_storage

		acceleration_step_x := component_storage.component_a[index].val * component_storage.component_b[index].x
		acceleration_step_y := component_storage.component_a[index].val * component_storage.component_b[index].y

		mutable_component_storage.component_c[index].x = acceleration_step_x
		mutable_component_storage.component_c[index].y = acceleration_step_y 

		mutable_component_storage.component_b[index] = {}
	}

	for component_storage, index in journey.run(&velocity_integrate_query){
		sprite := journey.get_soa_component(world, component_storage.entities[index], journey.RenderInstance)
		sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]

		mutable_component_storage := component_storage

		last_velocity_x := component_storage.component_a[index].x * game_loop.last_delta_time
		last_velocity_y := component_storage.component_a[index].y * game_loop.last_delta_time

		sprite_batch.instances[sprite.instance_index].transform[0,3] += last_velocity_x 
		sprite_batch.instances[sprite.instance_index].transform[1,3] += last_velocity_y

		mutable_component_storage.component_a[index].x += (component_storage.component_c[index].x * game_loop.last_delta_time)
		mutable_component_storage.component_a[index].y += (component_storage.component_c[index].y * game_loop.last_delta_time)
		
		mutable_component_storage.component_a[index].x *= linalg.pow(component_storage.component_b[index].val, game_loop.last_delta_time)
		mutable_component_storage.component_a[index].y *= linalg.pow(component_storage.component_b[index].val, game_loop.last_delta_time)
	}
	//

	//Physic Solver




	//

	journey.END_EVENT()

}

update :: proc(game_loop : ^GameLoop){
	journey.BEGIN_EVENT("Update")



	journey.END_EVENT()
}

on_animation :: proc(game_loop : ^GameLoop){
	journey.BEGIN_EVENT("Animation Loop")

    world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)

	// Cache texture and shader and render data to send to render thread
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)

	anim_sprite_query := journey.query(world, journey.Animator)

	for component_storage, index in journey.run(&anim_sprite_query){
		
		sprite := journey.get_soa_component(world, component_storage.entities[index], journey.RenderInstance)
		animator := component_storage.component_a[index]

		current_clip := animator.clips[animator.current_clip]

		animation_delta_time := (game_loop.elapsed_time - animator.animation_time) 
		frame_to_update := linalg.floor(animation_delta_time * animator.animation_speed)
		next_frame := animator.previous_frame + int(frame_to_update)

		animator.previous_frame = next_frame
		animator.previous_frame %= current_clip.len

		update_mask :f32= max(frame_to_update, 0)
		rcp_update_mask := 1 - update_mask

		animator.animation_time = (game_loop.elapsed_time * update_mask) + (animator.animation_time * rcp_update_mask)
		
		y :=current_clip.index * current_clip.height
		x := animator.previous_frame * current_clip.width
		
		sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]
		sprite_batch.instances[sprite.instance_index].src_rect = {
			f32(x), f32(y), f32(current_clip.width), f32(current_clip.height),
		} 
	}

	journey.END_EVENT()
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

	resource.render_buffer.render_batch_groups = make(map[uint]journey.RenderBatchGroup)

	game_loop := init_game_loop_window()

	world := journey.init_world()
	context.user_ptr = world

	//TODO: khal this will change when resource is implement in journey_ecs
	context.user_index = int(journey.create_entity(world))
	journey.register(world, journey.ResourceCache)
	journey.add_soa_component(world, uint(context.user_index), resource)
	//

    journey.register(world, journey.Animator)

	journey.register(world, journey.Velocity)
	journey.register(world, journey.Acceleration)
	journey.register(world, journey.Damping)
	journey.register(world, journey.Mass)
	journey.register(world, journey.AccumulatedForce)
	journey.register(world, journey.Friction)
	journey.register(world, journey.Restitution)
	

	journey.register(world, journey.RenderInstance)

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

	player_entity_1 := create_game_entity("resource/sprite/padawan/pad.png", 0, {200,.10})
	player_entity_2 := create_game_entity("resource/sprite/padawan/pad.png", 0, {300,.20})

	//TODO:khal proof of implementation flesh it out.
	data,_ := os.read_entire_file_from_filename("resource/animation/player_anim.json")
	player_anim : journey.Animator
	json.unmarshal(data, &player_anim)

	journey.add_soa_component(world, player_entity_1, player_anim)
	journey.add_soa_component(world, player_entity_2, player_anim)

	journey.add_soa_component(world, player_entity_1, journey.Velocity{0, 0})
	journey.add_soa_component(world, player_entity_1, journey.Damping{0.99})
	journey.add_soa_component(world,player_entity_1, journey.Acceleration{})
	journey.add_soa_component(world, player_entity_1, journey.AccumulatedForce{})
	journey.add_soa_component(world, player_entity_1, journey.Mass{1})

	///////////////////////////////////////////////////////////////////

	///////////////////////// Game Loop ///////////////////////////////
	start_looping_game(&game_loop,&sdl2_event, event_update, GameFnDescriptor{
		update = update,
		fixed_update = fixed_update,
		on_animation = on_animation,
	})
	///////////////////////// Game Loop ///////////////////////////////
}
