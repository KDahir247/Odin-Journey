package main;
import "core:fmt"

import "core:mem"
import "core:thread"
import "core:sys/windows"
import "core:sync"
import "vendor:stb/image"
import "core:intrinsics"
import "core:math"
import "core:math/linalg/hlsl"
import "core:sys/llvm"
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
fixed_update :: proc(elapsed_time : f64, delta_time : f64){
    fixed_timestep :f64= 0.02 
    fixed_delta_time :f64= 0.02 
    fixed_time :f64= 0.0

	for elapsed_time > (fixed_time + fixed_timestep) {

		//Fixed Update Logic


		fixed_time += fixed_delta_time 
	}


}

@(optimization_mode="size")
update :: proc(elapsed_time : f64, delta_time : f64){

	// for  sprite in sprite_handles {

	// 	sprite_batch := ecs.get_component_unchecked(&shared_data.ecs, ecs.Entity(sprite.batch_handle), common.SpriteBatch)


	// 	animation_index += 1
		
	// 	animation_index = animation_index - llvm.floor_f32(animation_index * 0.14285714285714285714285714285714) * 7
	// 	sprite_batch.sprite_batch[sprite.sprite_handle].src_rect = hlsl.float4{39.0 * animation_index, 41.0 * 4, 39.0, 41.0}

	// }  
}

@(optimization_mode="size")
on_animation :: proc(elapsed_time : f64, delta_time : f64){

}


@(optimization_mode="size")
create_render_queue :: proc(){


}


@(optimization_mode="size")
main ::  proc()  {


	//TODO: remove this.
	running := true

    previous_tick : i64 = 0
	current_tick : i64 = 0

	maximum_delta_time : f64= 0.333
    time :f64= 0.0 
   
    time_scale : f64 = 1.0
    delta_time_vsync : f64 = 1.0 / 144 //Hardcoded going to change this 

	input_encoded : u64


	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo 
	
	ecs_context := ecs.init_ecs()
	//context.user_ptr = &ecs_context

	render_thread : ^thread.Thread
	render_batch_buffer : common.RenderBatchBuffer
	render_batch_buffer.mutex = sync.Mutex{}

	///////////////////// TODO remove look at below ///////////////////// 
	shared_data,_ := mem.new_aligned(common.SharedContext, 64)

	//There might only be a barrier to sync up initialization (we don't want to queue up input while the renderer isn't intialized this will create a quick movement in the start and slow down to the correct speed)
	//Where should i move this to?
	shared_data.barrier = &sync.Barrier{}

	// TODO this will not be shared rather the render will have the compact version of the ecs data. Just the component and entity.
	// It up to the main loop to lock and syncronize if the data is update.
	// We will have a atomic dirty bit to signify to the renderer that it should update it internal interpetation of the data or we can do a push/pop mechanic 
	///////////////////////////////////////////////////////////////////

	sync.barrier_init(shared_data.barrier, 2)
	
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

		sdl2.DestroyWindow(sdl2_window)
		sdl2.QuitSubSystem(sdl2.InitFlags{sdl2.InitFlag.EVENTS})

		free(shared_data)

		common.FREE_PROFILER()
	}


    player_entity := ecs.create_entity(&ecs_context)
    player_entity_1 := ecs.create_entity(&ecs_context) //TODO: remove for testing

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

    ecs.add_component_unchecked(&ecs_context, player_entity_1, common.SpriteHandle{
        //player sprite parameters
        sprite_handle = common.sprite_batch_append(player_batch,common.SpriteInstanceData{
            transform = {
                1.0, 0.0, 0.0, 300.0,
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
    

	sprite_handles := ecs.get_component_list(&ecs_context, common.SpriteHandle)

	render_thread = thread.create(system.init_render_subsystem)

	//TODO remove
	shared_data.ecs = ecs_context
	render_thread.data = shared_data

	//

	render_thread.user_args[0] = windows.HWND(window_info.info.win.window)

	thread.start(render_thread) 

    sync.barrier_wait(shared_data.barrier)

	for running{

		previous_tick = current_tick
        current_tick = intrinsics.read_cycle_counter()
       
        delta_time :=  min(
			time_scale * f64(current_tick - previous_tick) * 1e6  * delta_time_vsync, //delta_time_vsync //time_scale *f64(current_tick - previous_tick) * 1000.0  * rcp_freq
			maximum_delta_time, 
		)

        time += delta_time 

		for sdl2.PollEvent(&sdl2_event){
			running = sdl2_event.type != sdl2.EventType.QUIT

			scan_code_index := u64(sdl2_event.key.keysym.scancode)
			if sdl2_event.key.type != sdl2.EventType.TEXTINPUT && scan_code_index > 0 && scan_code_index <= 512{
				input_encoded = 0
				input_encoded = scan_code_index << 4 | u64(sdl2_event.key.repeat << 2) | u64(sdl2_event.key.state)
			}
		}

		fixed_update(time, delta_time)
		update(time, delta_time)
		on_animation(time, delta_time)

		//Send to thread.. function.
		// The Sprite batch will always be clear prior to setting
		//This will batch position, rotation, scale, src_rect, hue_disp, z_depth and send thread
		//create_render_queue()

		
		//Spin lock. Don't want the main thread to get blocked.
		// if sync.try_lock(&render_batch_buffer.mutex){

		// 	sprite_batch_shared := ecs.get_component_list(&ecs_context, common.SpriteBatchShared)
		// 	sprite_batch := ecs.get_component_list(&ecs_context, common.SpriteBatch)

		// 	render_batch_buffer.shared = sprite_batch_shared
		// 	render_batch_buffer.batches = sprite_batch

		// 	// Thread render_data will be updated. Later i want a better data structure to 
		// 	// update individual entry of the data structure rather then the whole.
		// 	//render_thread.data 



			
		// 	sync.unlock(&render_batch_buffer.mutex)
		// }
   
	}

	sync.atomic_store_explicit(&render_thread.flags, {.Done},sync.Atomic_Memory_Order.Release)
}
