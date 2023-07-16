package main;
import "core:fmt"

import "core:thread"
import "core:sys/windows"
import "core:sync"
import "core:intrinsics"


import "vendor:stb/image"
import "vendor:sdl2"

//TODO: got to redo the ecs system it look like there alot of unessary work.. -.-'
import "ecs"
import "system"
import "common"

@(private)
@(init)
init_game :: proc(){
	common.CREATE_PROFILER("ProfilerData.spall")
}

//TODO: we need to find a way to get the ecs system without passing it as argument. for both fixed update and update.

@(optimization_mode="size")
fixed_update :: proc(fixed_time : f64, elapsed_time : f64, delta_time : f64){
	common.BEGIN_EVENT("Physics Update")


	common.END_EVENT()
}

@(optimization_mode="size")
update :: proc(elapsed_time : f64, delta_time : f64){

	common.BEGIN_EVENT("Update")

	
	// for  sprite in sprite_handles {

	// 	sprite_batch := ecs.get_component_unchecked(&shared_data.ecs, ecs.Entity(sprite.batch_handle), common.SpriteBatch)


	// 	animation_index += 1
		
	// 	animation_index = animation_index - llvm.floor_f32(animation_index * 0.14285714285714285714285714285714) * 7
	// 	sprite_batch.sprite_batch[sprite.sprite_handle].src_rect = hlsl.float4{39.0 * animation_index, 41.0 * 4, 39.0, 41.0}

	// }  

	common.END_EVENT()
}

@(optimization_mode="size")
on_animation :: proc(elapsed_time : f64, delta_time : f64){

}


@(optimization_mode="size")
create_render_queue :: proc(){


}


@(optimization_mode="size")
main ::  proc()  {
	display_setting : windows.DEVMODEW

	windows.EnumDisplaySettingsW(nil,windows.ENUM_CURRENT_SETTINGS, &display_setting)

	//TODO: khal. not sure if this is right. Want to get cpu frequency
 	eax,ebx,ecx,edx := intrinsics.x86_cpuid(0x80000002, 0x0)
	freq :=(eax + ebx) + (ecx + edx)

	rcp_freq := 1.0 / f64(freq)
	min_delta_time := 1.0 /  f64(display_setting.dmDisplayFrequency)

	previous :i64 = 0
	current : i64 = 0

	//TODO: remove this.
	running := true

	time_carryover : f64 = 0.0
    elapsed_time :f64= 0.0 
	fixed_time : f64 = 0.0
	accumulator : f64 = 0.0

	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo 
	
	ecs_context := ecs.init_ecs()
	context.user_ptr = &ecs_context

	render_thread : ^thread.Thread
	render_batch_buffer := new(common.RenderBatchBuffer)
	render_batch_buffer.mutex = sync.Mutex{}
	render_batch_buffer.barrier = sync.Barrier{}

	sync.barrier_init(&render_batch_buffer.barrier, 2)
	
	sdl2.InitSubSystem(sdl2.InitFlags{sdl2.InitFlag.EVENTS})

	sdl2_window := sdl2.CreateWindow(
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

	sdl2.GetWindowWMInfo(sdl2_window, &window_info)

	defer{	
        common.sprite_batch_free(&ecs_context)

		thread.destroy(render_thread)	

		ecs.deinit_ecs(&ecs_context)
		context.user_ptr = nil

		sdl2.DestroyWindow(sdl2_window)
		sdl2.QuitSubSystem(sdl2.InitFlags{sdl2.InitFlag.EVENTS})

		common.FREE_PROFILER()
	}

    player_entity := ecs.create_entity(&ecs_context)

	player_batcher_id := common.create_sprite_batcher(&ecs_context,"resource/sprite/padawan/pad.png", 0)

	player_batch, player_batch_shared:= ecs.get_components_2_unchecked(&ecs_context,ecs.Entity(player_batcher_id), common.SpriteBatch, common.SpriteBatchShared)

    ecs.add_component_unchecked(&ecs_context, player_entity, common.SpriteHandle{
        //player sprite parameters
        sprite_handle = common.sprite_batch_append(player_batch,common.SpriteInstanceData{
            transform = {
                1.0, 0.0, 0.0, 200.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            },
            hue_displacement = 1,
            src_rect = {0.0,0.0, f32(player_batch_shared.width), f32(player_batch_shared.height)},
        }),

        //Batch entity which has the player parameters
        batch_handle = player_batcher_id,
    })

	render_thread = thread.create(system.init_render_subsystem)

	render_thread.data = render_batch_buffer

	render_thread.user_args[0] = window_info.info.win.window

	thread.start(render_thread) 

    sync.barrier_wait(&render_batch_buffer.barrier)

	current = intrinsics.read_cycle_counter()

	for running{
		current = intrinsics.read_cycle_counter()
     
		delta_time := clamp(common.TIME_SCALE * (f64(current) - f64(previous)) * rcp_freq,min_delta_time, 0.333)
        
		previous = current

		for sdl2.PollEvent(&sdl2_event){
			running = sdl2_event.type != sdl2.EventType.QUIT

			// scan_code_index := u64(sdl2_event.key.keysym.scancode)
			// if sdl2_event.key.type != sdl2.EventType.TEXTINPUT && scan_code_index > 0 && scan_code_index <= 512{
			// 	input_encoded = scan_code_index << 4 | u64(sdl2_event.key.repeat << 2) | u64(sdl2_event.key.state)
			// }
		}

        elapsed_time += delta_time 
		accumulator += delta_time + time_carryover

		for accumulator >= common.SCALED_FIXED_DELTA_TIME {

			fixed_update(fixed_time,elapsed_time, delta_time)
	
			fixed_time += common.SCALED_FIXED_DELTA_TIME 
			accumulator -= common.SCALED_FIXED_DELTA_TIME
		}

		update(elapsed_time, delta_time)
		//TODO: khal we don't delta time to be scaled here.
		on_animation(elapsed_time, delta_time)

		time_carryover = accumulator


		//Spin lock. Don't want the main thread to get blocked, but don't want to call this every frame.....
		if sync.try_lock(&render_batch_buffer.mutex){
			common.BEGIN_EVENT("Retrieving Sprite batches")
			sprite_batch_shared := ecs.get_component_list(&ecs_context, common.SpriteBatchShared)
			sprite_batch := ecs.get_component_list(&ecs_context, common.SpriteBatch)
			common.END_EVENT()
	
			common.BEGIN_EVENT("Syncing Render data")

			render_batch_buffer.modified = true

			render_batch_buffer.shared = sprite_batch_shared
			render_batch_buffer.batches = sprite_batch

			render_thread.data = render_batch_buffer

			// Thread render_data will be updated. Later i want a better data structure to 
			// update individual entry of the data structure rather then the whole.
			//render_thread.data 

			sync.unlock(&render_batch_buffer.mutex)
			common.END_EVENT()

		}
		


	}

	sync.atomic_store_explicit(&render_thread.flags, {.Done},sync.Atomic_Memory_Order.Release)
}
