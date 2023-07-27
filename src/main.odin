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
import "../ecs"
import "../journey"
 import "core:encoding/json"
 import "vendor:stb/image"


//TODO: khal move create game entity and sprite batch to journey_entity.
@(optimization_mode="size")
create_game_entity :: proc(batch_handle : uint, instance_data : journey.SpriteInstanceData) -> ecs.Entity{
    ecs_context := cast(^ecs.Context)context.user_ptr
    target_batch := ecs.get_component_unchecked(ecs_context, ecs.Entity(batch_handle), journey.SpriteBatch)

    game_sprite_handle := sprite_batch_append(target_batch, instance_data)

    game_entity := ecs.create_entity(ecs_context)

    ecs.add_component_unchecked(ecs_context, game_entity, journey.SpriteHandle{
        sprite_handle = game_sprite_handle,
        batch_handle = batch_handle,
    })

    return game_entity
}

@(optimization_mode="size")
create_sprite_batcher :: proc($tex_path : cstring, $shader_cache : u32) -> uint{
    ecs_context := cast(^ecs.Context)context.user_ptr
    
    identifier_idx := u32(len(ecs_context.component_map[journey.SpriteBatchShared].entity_indices))

    sprite_batch_entity := ecs.create_entity(ecs_context)

    ecs.add_component_unchecked(ecs_context,sprite_batch_entity, journey.SpriteBatch{
        sprite_batch = make_dynamic_array_len_cap([dynamic]journey.SpriteInstanceData,0, journey.DEFAULT_BATCH_SIZE),
    })
    shared := ecs.add_component_unchecked(ecs_context, sprite_batch_entity, journey.SpriteBatchShared{
        identifier = identifier_idx,
    })

    shared.texture = image.load(tex_path,&shared.width,&shared.height,nil,  4)
    shared.shader_cache = shader_cache
    
    return uint(sprite_batch_entity)
}

@(optimization_mode="size")
sprite_batch_append :: proc(sprite_batch : ^journey.SpriteBatch, data : journey.SpriteInstanceData) -> uint{
    assert(len(sprite_batch.sprite_batch) < journey.MAX_SPRITE_BATCH, "The sprite batcher has reach it maximum batch and is trying to append a batch maximum 2048")
    append(&sprite_batch.sprite_batch, data)
    return uint(len(sprite_batch.sprite_batch) - 1)
}

@(optimization_mode="speed")
sprite_batch_set :: #force_inline proc(sprite_batch : ^journey.SpriteBatch, handle : int, data : journey.SpriteInstanceData){
    #no_bounds_check{
        sprite_batch.sprite_batch[handle] = data
    }
}

@(optimization_mode="speed")
sprite_batch_free :: proc(){
    ecs_context := cast(^ecs.Context)context.user_ptr
    
    batcher_entity := ecs.get_entities_with_single_component_fast(ecs_context, journey.SpriteBatch)

    for entity in batcher_entity{
        batcher, shared := ecs.get_components_2_unchecked(ecs_context, entity, journey.SpriteBatch, journey.SpriteBatchShared)

		image.image_free(shared.texture)
        shared.texture = nil

        delete(batcher.sprite_batch)

        ecs.remove_component(ecs_context, entity, journey.SpriteBatch)
        ecs.remove_component(ecs_context, entity, journey.SpriteBatchShared)
    }
}

//////////////////////////////////////////////////////////////////////



//TODO: we need to find a way to get the ecs system without passing it as argument. for both fixed update and update.
@(optimization_mode="size")
fixed_update :: proc(fixed_time : f64, elapsed_time : f64, delta_time : f64){
	ecs_context := cast(^ecs.Context)context.user_ptr
	
	resource := ecs.get_component_unchecked(ecs_context, ecs.Entity(context.user_index), journey.GameResource)
	sprites := ecs.get_component_list(ecs_context, journey.SpriteHandle)
	
	for sprite in sprites{
		journey.BEGIN_EVENT("Physics Update")

		sprite_batch := ecs.get_component_unchecked(ecs_context, ecs.Entity(sprite.batch_handle), journey.SpriteBatch)

		sprite_batch.sprite_batch[sprite.sprite_handle].transform += {
			0.0, 0.0, 0.0, f32(resource.key.dir[3]) * 0.009 * f32(delta_time) + f32(resource.key.dir[0]) * 0.009 * f32(delta_time),
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0,
		}
		
		journey.END_EVENT()
	}
}

@(optimization_mode="size")
update :: proc(elapsed_time : f64, delta_time : f64){
	journey.BEGIN_EVENT("Update")

	journey.END_EVENT()
}

@(optimization_mode="size")
on_animation :: proc(elapsed_time : f64){
	ecs_context := cast(^ecs.Context)context.user_ptr

	animator_entities := ecs.get_entities_with_single_component_fast(ecs_context, journey.Animator)

	for entity in animator_entities{
		journey.BEGIN_EVENT("Animation Loop")

		//TODO: khal don't like all the get components here
		animator := ecs.get_component_unchecked(ecs_context, entity, journey.Animator)
		handle := ecs.get_component_unchecked(ecs_context,entity, journey.SpriteHandle)
		batch := ecs.get_component_unchecked(ecs_context, ecs.Entity(handle.batch_handle), journey.SpriteBatch)

		current_clip := animator.clips[animator.current_clip]

		animation_delta_time := (elapsed_time - animator.animation_time) * 0.001

		frame_to_update := linalg.floor(animation_delta_time * animator.animation_speed)

		update_mask := frame_to_update > 0 ? 1.0 : 0.0

		next_frame := animator.previous_frame + int(frame_to_update)
		rcp_update_mask := 1 - update_mask

		animator.previous_frame = next_frame
		animator.previous_frame %= current_clip.len

		animator.animation_time = (elapsed_time * update_mask) + (animator.animation_time * rcp_update_mask)
		y :=current_clip.index * current_clip.height
		x := animator.previous_frame * current_clip.width

		batch.sprite_batch[handle.sprite_handle].src_rect = {
			f32(x), f32(y), f32(current_clip.width), f32(current_clip.height),
		}

		journey.END_EVENT()
	}
}

@(optimization_mode="size")
main ::  proc()  {
	journey.CREATE_PROFILER("profiling/ProfilerData.spall")

	ecs_context := ecs.init_ecs()
	context.user_ptr = &ecs_context
	
	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo 

	display_setting : windows.DEVMODEW
	windows.EnumDisplaySettingsW(nil,windows.ENUM_CURRENT_SETTINGS, &display_setting)
	min_delta_time := journey.TIME_SCALE /  f64(display_setting.dmDisplayFrequency)

	running := true

	//TODO: khal. not sure if this is right. Want to get cpu frequency
	eax,ebx,ecx,edx := intrinsics.x86_cpuid(0x80000002, 0x0)

	rcp_freq := journey.TIME_SCALE / f64((eax + ebx) + (ecx + edx)) 

	current : f64 = 0
	previous :f64 = 0

	time_carryover : f64 = 0.0
    elapsed_time :f64= 0.0 
	fixed_time : f64 = 0.0
	accumulator : f64 = 0.0

	window : ^sdl2.Window

	render_batch_buffer : journey.RenderBatchBuffer
	
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
        sprite_batch_free()

		ecs.deinit_ecs(&ecs_context)
		context.user_ptr = nil

		sdl2.DestroyWindow(window)
		sdl2.Quit()

		journey.FREE_PROFILER()
	}

	render_thread := journey.run_renderer(journey.RenderBackend.DX11,window_info.info.win.window, &render_batch_buffer)

	//TODO: don't like this.
	resource_entity := ecs.create_entity(&ecs_context)
	context.user_index = int(resource_entity)
	resource_component := ecs.add_component_unchecked(&ecs_context, resource_entity, journey.GameResource{})

	//
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
	
	ecs.add_component_unchecked(&ecs_context, player_entity_1, player_anim)
	ecs.add_component_unchecked(&ecs_context, player_entity_2, player_anim1)

	//

	for running{
		current = f64(intrinsics.read_cycle_counter())
     
		delta_time := clamp((current - previous) * rcp_freq,min_delta_time, journey.MAX_DELTA_TIME)
        
		previous = current

		//TODO: don't like this.
		for sdl2.PollEvent(&sdl2_event){
			#partial switch sdl2_event.key.keysym.scancode {
			case sdl2.Scancode.A, sdl2.Scancode.LEFT:
				{
					resource_component.key.dir[0] = -int(sdl2_event.key.state)

				}
			case sdl2.Scancode.D,sdl2.Scancode.RIGHT: // default
				{
					resource_component.key.dir[3] = int(sdl2_event.key.state)

				}
			case sdl2.Scancode.W, sdl2.Scancode.UP:
				{
					resource_component.key.dir[1] = int(sdl2_event.key.state)

				}
			case sdl2.Scancode.S, sdl2.Scancode.DOWN:
				{
					resource_component.key.dir[2] = -int(sdl2_event.key.state)

				}
			}

			running = sdl2_event.type != sdl2.EventType.QUIT
		}

		if !sync.atomic_load_explicit(&render_batch_buffer.changed_flag, sync.Atomic_Memory_Order.Consume){

			elapsed_time += delta_time 
			accumulator += delta_time + time_carryover
	
			for accumulator >= journey.SCALED_FIXED_DELTA_TIME {
				fixed_update(fixed_time,elapsed_time, delta_time)
		
				fixed_time += journey.SCALED_FIXED_DELTA_TIME 
				accumulator -= journey.SCALED_FIXED_DELTA_TIME
			}
	
			update(elapsed_time, delta_time)
			on_animation(elapsed_time)
	
			time_carryover = accumulator
	
			journey.BEGIN_EVENT("Syncing Render Data")
			
			{
				batch_shared := ecs_context.component_map[journey.SpriteBatchShared].data
				batch := ecs_context.component_map[journey.SpriteBatch].data
	
				changed := len(render_batch_buffer.batches) != batch.len || len(render_batch_buffer.shared) != batch_shared.len
	
				if changed{
					render_batch_buffer.shared = (cast(^[dynamic]journey.SpriteBatchShared)batch_shared)[:]
					render_batch_buffer.batches = (cast(^[dynamic]journey.SpriteBatch)batch)[:]
					
					//render_thread.data = &render_batch_buffer
		
					sync.atomic_store_explicit(&render_batch_buffer.changed_flag, true, sync.Atomic_Memory_Order.Relaxed)
				}
			}

			journey.END_EVENT()
		}

		free_all(context.temp_allocator)
	}
	journey.stop_renderer(render_thread)
}
