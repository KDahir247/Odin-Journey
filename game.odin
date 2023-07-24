package main;
import "core:fmt"
import "core:thread"
import "core:sys/windows"
import "core:sync"
import "core:intrinsics"
import "core:os"
import "core:math/linalg"

import "vendor:sdl2"

//TODO: got to redo the ecs system it look like there alot of unessary work.. -.-'
import "ecs"
import "system"
import "common"

import "core:encoding/json"

//TODO: we need to find a way to get the ecs system without passing it as argument. for both fixed update and update.
@(optimization_mode="size")
fixed_update :: proc(fixed_time : f64, elapsed_time : f64, delta_time : f64){
	common.BEGIN_EVENT("Physics Update")


	common.END_EVENT()
}

@(optimization_mode="size")
update :: proc(elapsed_time : f64, delta_time : f64){
	common.BEGIN_EVENT("Update")

	

	common.END_EVENT()
}

@(optimization_mode="size")
on_animation :: proc(elapsed_time : f64){
	ecs_context := cast(^ecs.Context)context.user_ptr
	
	animator_entities := ecs.get_entities_with_single_component_fast(ecs_context, common.Animator)

	for entity in animator_entities{
		common.BEGIN_EVENT("Animation Loop")

		//TODO: khal don't like all the get components here
		animator := ecs.get_component_unchecked(ecs_context, entity, common.Animator)
		sprite_handle := ecs.get_component_unchecked(ecs_context,entity, common.SpriteHandle)
		sprite_batch := ecs.get_component_unchecked(ecs_context, ecs.Entity(sprite_handle.batch_handle), common.SpriteBatch)

		current_clip := animator.clips[animator.current_clip]

		animation_delta_time := (elapsed_time - animator.animation_time) * 0.001

		frame_to_update := linalg.floor(animation_delta_time *animator.animation_speed)

		update_mask := frame_to_update > 0 ? 1.0 : 0.0

		next_frame := animator.previous_frame + int(frame_to_update)
		rcp_update_mask := 1 - update_mask

		animator.previous_frame = next_frame
		animator.previous_frame %= current_clip.len

		animator.animation_time = (elapsed_time * update_mask) + (animator.animation_time * rcp_update_mask)
		y :=current_clip.index * current_clip.height
		x := animator.previous_frame * current_clip.width

		sprite_batch.sprite_batch[sprite_handle.sprite_handle].src_rect = {
			f32(x), f32(y), f32(current_clip.width), f32(current_clip.height),
		}

		common.END_EVENT()
	}
}

@(optimization_mode="size")
main ::  proc()  {
	common.CREATE_PROFILER("ProfilerData.spall") //

	ecs_context := ecs.init_ecs()
	context.user_ptr = &ecs_context
	
	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo 

	display_setting : windows.DEVMODEW
	windows.EnumDisplaySettingsW(nil,windows.ENUM_CURRENT_SETTINGS, &display_setting)
	min_delta_time := common.TIME_SCALE /  f64(display_setting.dmDisplayFrequency)

	running := true

	//TODO: khal. not sure if this is right. Want to get cpu frequency
	eax,ebx,ecx,edx := intrinsics.x86_cpuid(0x80000002, 0x0)

	rcp_freq := common.TIME_SCALE / f64((eax + ebx) + (ecx + edx)) 

	current : f64 = 0
	previous :f64 = 0

	time_carryover : f64 = 0.0
    elapsed_time :f64= 0.0 
	fixed_time : f64 = 0.0
	accumulator : f64 = 0.0

	render_thread : ^thread.Thread

	barrier :=  &sync.Barrier{}
	sync.barrier_init(barrier, 2)

	window : ^sdl2.Window

	render_batch_buffer : common.RenderBatchBuffer
	
	sdl2.InitSubSystem(sdl2.InitFlags{sdl2.InitFlag.EVENTS})

	window = sdl2.CreateWindow(
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

	defer{	
        common.sprite_batch_free()

		thread.destroy(render_thread)	

		ecs.deinit_ecs(&ecs_context)
		context.user_ptr = nil

		sdl2.DestroyWindow(window)
		sdl2.Quit()

		common.FREE_PROFILER()
	}

	player_batcher_id := common.create_sprite_batcher("resource/sprite/padawan/pad.png", 0)

	player_batcher_id1 := common.create_sprite_batcher("resource/sprite/dark/Temple Guardian/attack 1 with VFX.png", 0)


	render_thread = thread.create(system.init_render_subsystem)
	
	render_thread.data = &render_batch_buffer
	render_thread.user_args[0] = window_info.info.win.window
	render_thread.user_args[1] = barrier

	thread.start(render_thread) 

	sync.barrier_wait(barrier)

	player_entity_1 := common.create_game_entity(player_batcher_id, {
		transform = {
			1.0, 0.0, 0.0, 200.0,
			0.0, 1.0, 0.0, 0.0,
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},
	})

	player_entity_2 := common.create_game_entity(player_batcher_id1, {
		transform = {
			1.0, 0.0, 0.0, 400.0,
			0.0, 1.0, 0.0, 0.0,
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},
	})
	data,_ := os.read_entire_file_from_filename("config/animation/player_anim.json")
	player_anim : common.Animator
	json.unmarshal(data, &player_anim)

	data1,_ := os.read_entire_file_from_filename("config/animation/single_anim.json")
	player_anim1 : common.Animator
	json.unmarshal(data1, &player_anim1)
	ecs.add_component_unchecked(&ecs_context, player_entity_1, player_anim)

	ecs.add_component_unchecked(&ecs_context, player_entity_2, player_anim1)

	//

	for running{
		current = f64(intrinsics.read_cycle_counter())
     
		delta_time := clamp((current - previous) * rcp_freq,min_delta_time, common.MAX_DELTA_TIME)
        
		previous = current

		for sdl2.PollEvent(&sdl2_event){
			running = sdl2_event.type != sdl2.EventType.QUIT
		}

		if !sync.atomic_load_explicit(&render_batch_buffer.changed_flag, sync.Atomic_Memory_Order.Consume){

			elapsed_time += delta_time 
			accumulator += delta_time + time_carryover
	
			for accumulator >= common.SCALED_FIXED_DELTA_TIME {
				fixed_update(fixed_time,elapsed_time, delta_time)
		
				fixed_time += common.SCALED_FIXED_DELTA_TIME 
				accumulator -= common.SCALED_FIXED_DELTA_TIME
			}
	
			update(elapsed_time, delta_time)
			on_animation(elapsed_time)
	
			time_carryover = accumulator
	
			common.BEGIN_EVENT("Syncing Render Data")
			
			{
				batch_shared := ecs_context.component_map[common.SpriteBatchShared].data
				batch := ecs_context.component_map[common.SpriteBatch].data
	
				changed := len(render_batch_buffer.batches) != batch.len || len(render_batch_buffer.shared) != batch_shared.len
	
				render_batch_buffer.shared = (cast(^[dynamic]common.SpriteBatchShared)batch_shared)[:]
				render_batch_buffer.batches = (cast(^[dynamic]common.SpriteBatch)batch)[:]
				
				render_thread.data = &render_batch_buffer
	
				sync.atomic_store_explicit(&render_batch_buffer.changed_flag, changed, sync.Atomic_Memory_Order.Relaxed)
			}

			common.END_EVENT()
		}

		free_all(context.temp_allocator)
	}

	sync.atomic_store_explicit(&render_thread.flags, {.Done},sync.Atomic_Memory_Order.Release)
}
