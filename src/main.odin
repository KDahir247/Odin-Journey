package main

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

 loop_fn :: #type proc(game_loop : ^GameLoop)
 event_fn :: #type proc(game_loop : ^GameLoop, event : ^sdl2.Event)
 
 QUERY_PERF_FREQUENCY :: 1000000
 RCP_QUERY_PERF_FREQUENCY :: 1.0 / QUERY_PERF_FREQUENCY

 GameLoop :: struct{
    data : rawptr,
    
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
init_game_loop_window :: proc(shared_data : rawptr, refresh_rate : f32 = 0 , refresh_rate_multiplier : f32 = 0.5, max_frame_time :f32= journey.MAX_DELTA_TIME) -> GameLoop{
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
        data = shared_data,
        last_delta_time = 0,

        maximum_frame_time = max_frame_time,
        update_per_second = refresh_rate,
        fixed_timestep = fixed_time_step,

        previous_time = previous_time,
        current_time = current_time,
    }
}

 //Remove below.

create_game_entity :: proc(batch_handle : uint, instance_data : journey.SpriteInstanceData) -> uint{
    world := cast(^journey.World)context.user_ptr
    game_entity := journey.create_entity(world)

	//TODO:khal remove this.....
    target_batch := journey.get_soa_component(world,batch_handle, journey.SpriteBatch)

    append(&target_batch.sprite_batch, instance_data)

	journey.set_soa_component(world, batch_handle, target_batch)

	journey.add_soa_component(world, game_entity, journey.SpriteHandle{
        sprite_handle = uint(len(target_batch.sprite_batch) - 1),
        batch_handle = batch_handle,
    })

	////////

    return game_entity
}

create_sprite_batcher :: proc($tex_path : cstring, $shader_cache : u32) -> uint{
    world := cast(^journey.World)context.user_ptr
    
    sprite_batch_entity := journey.create_entity(world)

	identifier_index := journey.get_soa_component_len(world, journey.SpriteBatchShared)

	width :i32= 0
	height :i32= 0
	tex := image.load(tex_path,&width,&height,nil,  4)

	journey.add_soa_component(world, sprite_batch_entity, journey.SpriteBatchShared{
		identifier = identifier_index,
		texture = tex,
		width = width, 
		height = height,
		shader_cache = shader_cache,
	})
	
	journey.add_soa_component(world, sprite_batch_entity,journey.SpriteBatch{
		sprite_batch =  make_dynamic_array_len_cap([dynamic]journey.SpriteInstanceData,0, journey.DEFAULT_BATCH_SIZE),
    })

    return uint(sprite_batch_entity)
}

sprite_batch_free :: proc(){
    world := cast(^journey.World)context.user_ptr
    
	batcher_entity := journey.get_id_soa_components(world, journey.SpriteBatch)

    for entity in batcher_entity{

		batcher := journey.get_soa_component(world,entity, journey.SpriteBatch)
		shared := journey.get_soa_component(world, entity, journey.SpriteBatchShared)

		image.image_free(shared.texture)
        shared.texture = nil

		delete(batcher.sprite_batch)
    }
}
//

//////////////////////////////////////////////////////////////////////

event_update :: proc(game_loop : ^GameLoop, event : ^sdl2.Event){
	
}

fixed_update :: proc(game_loop : ^GameLoop){
    world := cast(^journey.World)context.user_ptr
	
	sprites := journey.get_id_soa_components(world, journey.SpriteHandle)

	
	for sprite in sprites{
		journey.BEGIN_EVENT("Physics Update")

		
		journey.END_EVENT()
	}
}

update :: proc(game_loop : ^GameLoop){
	journey.BEGIN_EVENT("Update")

	render_batch_buffer := cast(^journey.RenderBatchBuffer)game_loop.data
    world := cast(^journey.World)context.user_ptr

	//TODO:khal optimize this only store when changed.
	if !sync.atomic_load_explicit(&render_batch_buffer.changed_flag, sync.Atomic_Memory_Order.Consume){
		{
			batch_shared,_ := journey.get_soa_components(world,journey.SOAType(journey.SpriteBatchShared))
			batch,_:= journey.get_soa_components(world, journey.SOAType(journey.SpriteBatch))

			changed := len(render_batch_buffer.batches) != len(batch) || len(render_batch_buffer.shared) != len(batch_shared)

			if changed{
				render_batch_buffer.shared = batch_shared
				render_batch_buffer.batches = batch
				
				sync.atomic_store_explicit(&render_batch_buffer.changed_flag, true, sync.Atomic_Memory_Order.Relaxed)
			}
		}

	}

	journey.END_EVENT()
}

on_animation :: proc(game_loop : ^GameLoop){
    world := cast(^journey.World)context.user_ptr

	animator_entities := journey.get_id_soa_components(world, journey.Animator)

	for entity in animator_entities{
		journey.BEGIN_EVENT("Animation Loop")

		//TODO: khal don't like all the get components here
		animator := journey.get_soa_component(world, entity, journey.Animator)
		handle := journey.get_soa_component(world, entity, journey.SpriteHandle)
		batch := journey.get_soa_component(world, handle.batch_handle, journey.SpriteBatch)

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

		batch.sprite_batch[handle.sprite_handle].src_rect = {
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

	render_batch_buffer : journey.RenderBatchBuffer

	game_loop := init_game_loop_window(&render_batch_buffer)

	world := journey.init_world()
	context.user_ptr = world

    journey.register(world, journey.Animator)
    journey.register(world, journey.SpriteBatchShared)
    journey.register(world, journey.SpriteBatch)
	journey.register(world, journey.SpriteHandle)

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

	render_thread := journey.run_renderer(journey.RenderBackend.DX11,window_info.info.win.window, &render_batch_buffer)

	defer{	
		journey.stop_renderer(render_thread)

        sprite_batch_free() //TODO:khal remove

		journey.deinit_world(world)
		context.user_ptr = nil

		sdl2.DestroyWindow(window)
		sdl2.Quit()

		journey.FREE_PROFILER()
	}
	////////////////////////////////////////////////////////////////////

	///////////////////////// Game Start ///////////////////////////////

	player_batcher_id := create_sprite_batcher("resource/sprite/padawan/pad.png", 0)

	player_batcher_id1 := create_sprite_batcher("resource/sprite/dark/Temple Guardian/attack 1 with VFX.png", 0)

	player_entity_1 := create_game_entity(player_batcher_id, {
		transform = {
			1.0, 0.0, 0.0, 200.0,
			0.0, 1.0, 0.0, 0.0,
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},
	})

	player_entity_2 := create_game_entity(player_batcher_id1, {
		transform = {
			1.0, 0.0, 0.0, 400.0,
			0.0, 1.0, 0.0, 0.0,
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},
	})

	//TODO:khal proof of implementation flesh it out.
	data,_ := os.read_entire_file_from_filename("resource/animation/player_anim.json")
	player_anim : journey.Animator
	json.unmarshal(data, &player_anim)

	data1,_ := os.read_entire_file_from_filename("resource/animation/single_anim.json")
	player_anim1 : journey.Animator
	json.unmarshal(data1, &player_anim1)
	
	journey.add_soa_component(world, player_entity_1, player_anim)
	journey.add_soa_component(world, player_entity_2, player_anim1)

	///////////////////////////////////////////////////////////////////

	///////////////////////// Game Loop ///////////////////////////////
	start_looping_game(&game_loop,&sdl2_event, event_update, GameFnDescriptor{
		update = update,
		fixed_update = fixed_update,
		on_animation = on_animation,
	})

	///////////////////////// Game Loop ///////////////////////////////
}
