package main

import "core:fmt"
import "core:sys/windows"
import "core:sync"
import "core:os"
import "core:encoding/json"
import "core:math"
import "core:slice"

import "../journey"

import "vendor:stb/image"
import "vendor:sdl2"

import bt "../thirdparty/obacktracing"

GameLoop :: struct{
	current_time : u32,
	previous_time : u32,

	maximum_frame_time : f32,

	delta_time : f32,
	elapsed_time : f32,

	accumulated_time : f32,
	
	carry_over_time : f32,

	fixed_deltatime : f32,
	elapsed_fixed_time : f32,
 
	terminate_next_iteration : bool,

	update_per_second : f32,
}

next_frame_window :: proc(game_loop : ^GameLoop) -> bool{
	game_loop.current_time = sdl2.GetTicks()

    game_loop.delta_time = clamp(f32(game_loop.current_time - game_loop.previous_time) * 0.001, 0, game_loop.maximum_frame_time)
    game_loop.elapsed_time += game_loop.delta_time

    game_loop.accumulated_time += (game_loop.delta_time + game_loop.carry_over_time)

    for game_loop.accumulated_time >= game_loop.fixed_deltatime{

		fixed_update(game_loop)
		physics_simulate(game_loop)

        game_loop.elapsed_fixed_time += game_loop.fixed_deltatime
        game_loop.accumulated_time -= game_loop.fixed_deltatime
		game_loop.carry_over_time = game_loop.accumulated_time
    }

	update(game_loop)
	on_animation(game_loop)
	late_update(game_loop)

	game_loop.previous_time = game_loop.current_time

    return !game_loop.terminate_next_iteration
}

start_looping_game :: proc(game_loop : ^GameLoop, event : ^sdl2.Event){
    for !game_loop.terminate_next_iteration{
        for sdl2.PollEvent(event){
            event_update(event)
            game_loop.terminate_next_iteration = event.type == sdl2.EventType.QUIT
        }

		next_frame_window(game_loop)
    }
}

// If refresh rate is zero it will adapt the refresh rate with the monitor refresh rate (uses win call)
// linux it a bit tricker it need Xrandr extension, so this only works for windows. 
init_game_loop_window :: proc($refresh_rate : f32 , $refresh_rate_multiplier : f32 , $max_frame_time :f32) -> GameLoop{
    target_refresh_rate := refresh_rate

    when refresh_rate == 0{
		when ODIN_OS == .Windows{
			display_setting : windows.DEVMODEW
			windows.EnumDisplaySettingsW(nil,windows.ENUM_CURRENT_SETTINGS, &display_setting)
			target_refresh_rate = f32(display_setting.dmDisplayFrequency)
		}else{
			//This will be fetched from game_config.json Fallback_RefreshRate
			target_refresh_rate = 60
		}
    }

    target_refresh_rate *= refresh_rate_multiplier
    fixed_deltatime := 1.0 / target_refresh_rate
    
    return GameLoop{
        delta_time = 0,
		previous_time = sdl2.GetTicks(),
        maximum_frame_time = max_frame_time,
        update_per_second = refresh_rate,
        fixed_deltatime = fixed_deltatime,
    }
}

//FNV-1a Hash
string_hash :: proc($path : string) -> uint{
	hash :uint=  0xcbf29ce484222325
	prime :uint= 0x100000001b3

	for char_rune in path{
		hash ~= cast(uint)(char_rune)
		hash *= prime
	}
	return hash
}

create_game_entity :: proc($tex_path : string, $shader_cache : u32, $render_order : int, entity_desc : journey.EntityDescriptor) -> uint{
    world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)

	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)
	
	path_hash := string_hash(tex_path)

	if path_hash not_in resource.render_buffer.render_batch_groups{
		width :i32= 0
		height :i32= 0

		tex := image.load(cstring(tex_path),&width,&height,nil,  4)

		tex_param : journey.TextureParam = journey.TextureParam{
			texture = tex,
			width = width,
			height = height,
			shader_cache = shader_cache,
		}

		resource.render_buffer.render_batch_groups[path_hash] = journey.RenderBatchGroup{
			texture_param = tex_param,
			instances = make([dynamic]journey.RenderInstanceData),
		}
	}

	sprite_batch := &resource.render_buffer.render_batch_groups[path_hash]

	vertical_bit := u32(entity_desc.direction) & 1
	horizontal_bit := u32(entity_desc.direction) >> 1 

	append(&sprite_batch.instances, journey.RenderInstanceData{
		transform = {
			entity_desc.scale.x , 0.0, 0.0, entity_desc.position.x,
			0.0, entity_desc.scale.y, 0.0, entity_desc.position.y,
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},
		src_rect = {
			0.0,
			0.0,
			f32(sprite_batch.texture_param.width & -i32(entity_desc.sprite_texture_type)),
			f32(sprite_batch.texture_param.height & -i32(entity_desc.sprite_texture_type)),
		},
		color = entity_desc.color,
		flip_bit = {f32(horizontal_bit), f32(vertical_bit)},
		order_index = render_order,
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

event_update :: proc(event : ^sdl2.Event){

}

fixed_update :: proc(global : ^GameLoop){
    world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)

	player_movement_query := journey.query(world,journey.InverseMass, journey.AccumulatedForce, journey.GameController, 8)
	npc_movement_offset := player_movement_query.len

	all_accum_force_entites,all_accum_force,_ := journey.get_soa_component_with_id(world, journey.SOAType(journey.AccumulatedForce))
	
	npc_movement_forces := all_accum_force[npc_movement_offset:]
	npc_movement_entities := all_accum_force_entites[npc_movement_offset:]

	assert(len(npc_movement_entities) == len(npc_movement_forces), "Entites count doesn't equal to component count this is a logic error in ecs solution")

	jump_query := journey.query(world, journey.Velocity)

	for component_storage, index in journey.run(&player_movement_query){
		mutable_component_storage := component_storage

		player_input_x := component_storage.component_c[index].key_buffer[sdl2.Scancode.A] - component_storage.component_c[index].key_buffer[sdl2.Scancode.D]
		mutable_component_storage.component_b[index].x += f32(player_input_x) * 80000 * global.fixed_deltatime 
	}

	for npc_movement, index in npc_movement_forces{

	}

	//TODO: optimize
	for component_storage, index in journey.run(&jump_query){
		mutable_component_storage := component_storage

		acceleration := journey.get_soa_component(world, component_storage.entities[index], journey.Acceleration)
		mass := journey.get_soa_component(world, component_storage.entities[index], journey.InverseMass)

		if journey.has_soa_component(world, component_storage.entities[index], journey.GameController){
			game_controller := journey.get_soa_component(world,component_storage.entities[index], journey.GameController )

			if acceleration.y == 0{
				mass := 1.0 / mass.val
				impulse_direction := [2]f32{0, f32(-game_controller.key_buffer[sdl2.Scancode.SPACE])}
				impulse := impulse_direction * 500 * mass * global.fixed_deltatime
				
				mutable_component_storage.component_a[index].y += impulse.y
			}
		}
	}
}

physics_simulate :: proc(global : ^GameLoop){
    world := cast(^journey.World)context.user_ptr

	//TODO:khal this will change when i implement unique in ecs solution
	unique_entity := uint(context.user_index)
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)
	physics_collision_solver := journey.get_soa_component(world, unique_entity, journey.CollisionResolver)
	//

	free_all(context.temp_allocator)
	collision_hit_map := make_map(map[uint]journey.PhysicsContact,1 << 6, context.temp_allocator)

	collider_query := journey.query(world,journey.Velocity, journey.Collider, journey.InverseMass,journey.AccumulatedForce, 8)
	static_collider_offset := collider_query.len
	collider_entities, all_collider, collider_len := journey.get_soa_component_with_id(world, journey.SOAType(journey.Collider))
		
	assert(static_collider_offset < collider_len, "Static collider offset is greater then the total amount of colliders in the game. This is a logical bug")

	static_colliders := all_collider[static_collider_offset:]
	static_entites := collider_entities[static_collider_offset:]
	
	force_query := journey.query(world, journey.InverseMass, journey.AccumulatedForce, journey.Velocity, 8)
    velocity_integrate_query := journey.query(world, journey.Velocity, journey.Collider,journey.InverseMass,journey.AccumulatedForce, 8)
	acceleration_integrate_query := journey.query(world, journey.Acceleration)

	position_integrate_query := journey.query(world, journey.Velocity, journey.Collider, 8)

	/////////////////////////////// Collision Detection ///////////////////////////////
	for component_storage, dynamic_index in journey.run(&collider_query){
		mutable_component_storage := component_storage
	
		//Collision Storing
		for static_collider, static_index in static_colliders{
			collision_hit : journey.PhysicsContact
			
			total_extent := [2]f32{
				static_collider.extent_x + component_storage.component_b[dynamic_index].extent_x,
				static_collider.extent_y + component_storage.component_b[dynamic_index].extent_y,
			}


			//TODO: magic number to handle very small velocity we will consider using a normal AABB to AABB collision test and not a sweep test.
			if (abs(component_storage.component_a[dynamic_index].x) + abs(component_storage.component_a[dynamic_index].y)) <= 0.01{
				//AABB to AABB intersection

				dynamic_origin := [2]f32{
					component_storage.component_b[dynamic_index].center_x,
					component_storage.component_b[dynamic_index].center_y,
				}

				static_origin := [2]f32{
					static_collider.center_x,
					static_collider.center_y,
				}

				collider_displacement := dynamic_origin-static_origin
				overlap := total_extent - [2]f32{abs(collider_displacement.x), abs(collider_displacement.y)}
				sign_collider_displacement := [2]f32{math.sign(collider_displacement.x), math.sign(collider_displacement.y)}

				if math.ceil_f32(overlap.x) > 0 && math.ceil_f32(overlap.y) > 0{
					//TODO: khal optimize
					horizontal_collision_mask := int(overlap.x < overlap.y)
					collision_direction_mask := [2]f32{f32(horizontal_collision_mask), f32(1 - horizontal_collision_mask)}

					//normal
					collision_hit.collision_normal_x = sign_collider_displacement.x * collision_direction_mask.x
					collision_hit.collision_normal_y = sign_collider_displacement.y * collision_direction_mask.y

					//point
					//TODO: khal not yet implemented.

					//pentration
					penetration_x := (component_storage.component_b[dynamic_index].center_x + (-collision_hit.collision_normal_x * component_storage.component_b[dynamic_index].extent_x)) - (static_collider.center_x - (collision_hit.collision_normal_x * static_collider.extent_x))
					penetration_y := (component_storage.component_b[dynamic_index].center_y + (-collision_hit.collision_normal_y * component_storage.component_b[dynamic_index].extent_y)) - (static_collider.center_y +  (collision_hit.collision_normal_y * static_collider.extent_y))
					collision_hit.penetration = penetration_x * abs(collision_hit.collision_normal_x) + penetration_y * abs(collision_hit.collision_normal_y)

					//restitution
					//TODO: khal not yet implemented. This will be implemented when we get the ldtk parsing working.
					//collision_hit.restitution = journey.get_soa_component(world, collision_hit.collided, journey.Restitution).val
					collision_hit.restitution = 0.0

					//collided entity
					collision_hit.collider = component_storage.entities[dynamic_index]
					collision_hit.collided = static_entites[static_index]

					collision_hit_map[collision_hit.collider + collision_hit.collided] = collision_hit
				}
			}else{
				// Sweep contact (AABB SEGEMENT intersection)

				rcp_velocity := 1.0 / [2]f32{component_storage.component_a[dynamic_index].x, component_storage.component_a[dynamic_index].y}
				signed_velocity := [2]f32{math.sign(rcp_velocity.x), math.sign(rcp_velocity.y)}

				near_time_x := ((-signed_velocity.x * total_extent.x) + (-static_collider.center_x + component_storage.component_b[dynamic_index].center_x)) * rcp_velocity.x 
				near_time_y := ((-signed_velocity.y * total_extent.y) + (-static_collider.center_y + component_storage.component_b[dynamic_index].center_y)) * rcp_velocity.y

				far_time_x := ((signed_velocity.x * total_extent.x) + (-static_collider.center_x + component_storage.component_b[dynamic_index].center_x)) * rcp_velocity.x 
				far_time_y := ((signed_velocity.y * total_extent.y) + (-static_collider.center_y + component_storage.component_b[dynamic_index].center_y)) * rcp_velocity.y

				if near_time_x <= far_time_y && near_time_y <= far_time_x{

					near_time := near_time_x > near_time_y ? near_time_x : near_time_y
					far_time := far_time_x < far_time_y ? far_time_x : far_time_y

					if near_time < 1 && far_time > 0{

						inverted_time := 1.0 - clamp(near_time, 0, 1)

						dynamic_min := [2]f32{
							component_storage.component_b[dynamic_index].center_x - component_storage.component_b[dynamic_index].extent_x,
							component_storage.component_b[dynamic_index].center_y - component_storage.component_b[dynamic_index].extent_y,
						}

						dynamic_max := [2]f32{
							component_storage.component_b[dynamic_index].center_x + component_storage.component_b[dynamic_index].extent_x,
							component_storage.component_b[dynamic_index].center_y + component_storage.component_b[dynamic_index].extent_y,
						}

						static_min := [2]f32{
							static_collider.center_x - static_collider.extent_x,
							static_collider.center_y - static_collider.extent_y,
						}

						static_max := [2]f32{
							static_collider.center_x + static_collider.extent_x,
							static_collider.center_y + static_collider.extent_y,
						}

						overlap_x := min(dynamic_max[0], static_max[0]) - max(dynamic_min[0], static_min[0]) 
						overlap_y := min(dynamic_max[1], static_max[1]) - max(dynamic_min[1], static_min[1])

						collision_displacement := [2]f32{
							component_storage.component_b[dynamic_index].center_x - static_collider.center_x,
							component_storage.component_b[dynamic_index].center_y - static_collider.center_y,
						}

						horizontal_collision_mask := int(overlap_x < overlap_y)
						collision_direction_mask := [2]f32{f32(horizontal_collision_mask), f32(1 - horizontal_collision_mask)}

						//normal
						collision_hit.collision_normal_x = math.sign(collision_displacement.x) * collision_direction_mask.x
						collision_hit.collision_normal_y = math.sign(collision_displacement.y) * collision_direction_mask.y

						//point
						//TODO: khal not yet implemented.
				
						//penetration
						penetration_x := (component_storage.component_b[dynamic_index].center_x + (-collision_hit.collision_normal_x * component_storage.component_b[dynamic_index].extent_x)) - (static_collider.center_x - (collision_hit.collision_normal_x * static_collider.extent_x))
						penetration_y := (component_storage.component_b[dynamic_index].center_y + (-collision_hit.collision_normal_y * component_storage.component_b[dynamic_index].extent_y)) - (static_collider.center_y +  (collision_hit.collision_normal_y * static_collider.extent_y))
						collision_hit.penetration = penetration_x * abs(collision_hit.collision_normal_x) + penetration_y * abs(collision_hit.collision_normal_y)
						
						//restitution
						//TODO: khal not yet implemented. This will be implemented when we get the ldtk parsing working.
						//collision_hit.restitution = journey.get_soa_component(world, collision_hit.collided, journey.Restitution).val
						collision_hit.restitution = 0.0

						//collided entity
						collision_hit.collider = component_storage.entities[dynamic_index]
						collision_hit.collided = static_entites[static_index]

						collision_hit_map[collision_hit.collider + collision_hit.collided] = collision_hit
					}
				}
			}
		}
	}

	physic_contacts,_ := slice.map_values(collision_hit_map, context.temp_allocator)

	journey.set_soa_component(world, unique_entity, journey.PhysicsContacts{
		contacts = physic_contacts,
	})


	/////////////////////////////// Compute Force ///////////////////////////////
	for component_storage, index in journey.run(&force_query){
		mutable_component_storage := component_storage

		mass := component_storage.component_a[index].val != 0 ?  1.0 / component_storage.component_a[index].val : 0

		//Gravitation force & Drag force (air resistance)
		{
			mutable_component_storage.component_b[index].y += journey.gravitational_force(component_storage.component_a[index]) + journey.quadratic_drag_force(0.01,component_storage.component_c[index]).y 
		}

		// Friction force. We will only calculate horizontal friction force for the game.
		{
			mutable_component_storage.component_b[index].x += journey.friction_force(0.6, component_storage.component_a[index],component_storage.component_c[index]).x
		}
	}


	/////////////////////////////// Compute Velocity ///////////////////////////////
	for component_storage, index in journey.run(&velocity_integrate_query){
		// sprite := journey.get_soa_component(world, component_storage.entities[index], journey.RenderInstance)
		// sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]

		mutable_component_storage := component_storage

		//Velocity first, then Position
		//From Gaffer On Games (Semi-Implicit Euler)

		acceleration_step_x :f32= component_storage.component_c[index].val * component_storage.component_d[index].x
		acceleration_step_y :f32=  component_storage.component_c[index].val * component_storage.component_d[index].y

		mutable_component_storage.component_d[index] = {}

		mutable_component_storage.component_a[index].previous_x = component_storage.component_a[index].x
		mutable_component_storage.component_a[index].previous_y = component_storage.component_a[index].y

		mutable_component_storage.component_a[index].x += (acceleration_step_x * global.fixed_deltatime)
		mutable_component_storage.component_a[index].y += (acceleration_step_y * global.fixed_deltatime)
	}

	/////////////////////////////// Collision Resolution ///////////////////////////////
	iteration_used := 0
	for iteration_used < physics_collision_solver.collision_iteration{
		max :f32= math.F32_MAX
		max_index := len(physic_contacts)
		for i := 0; i < len(physic_contacts); i+=1{
			velocity := journey.get_soa_component(world, physic_contacts[i].collider, journey.Velocity)
			seperating_velocity :f32= (velocity.x *  physic_contacts[i].collision_normal_x) + (velocity.y * physic_contacts[i].collision_normal_y)

			if seperating_velocity < max && seperating_velocity < 0{
				max = seperating_velocity
				max_index = i
			}
		}

		if max_index == len(physic_contacts){
			break
		}

		contact := physic_contacts[max_index]

		velocity := journey.get_soa_component(world, contact.collider, journey.Velocity)
		inverse_mass := journey.get_soa_component(world, contact.collider, journey.InverseMass)

		acceleration := journey.Acceleration{
			x = (velocity.x - velocity.previous_x) / global.fixed_deltatime,
			y = (velocity.y - velocity.previous_y) / global.fixed_deltatime,
		}
		
		impulse := journey.compute_contact_velocity(velocity, acceleration, inverse_mass, [2]f32{contact.collision_normal_x, contact.collision_normal_y}, contact.restitution, global.fixed_deltatime)

		journey.set_soa_component(world, contact.collider, impulse)

		//TODO:khal we need to handle inital interpenetration.

		iteration_used += 1

		journey.set_soa_component(world, unique_entity, journey.CollisionResolver{
			used_iteration = iteration_used,
			collision_iteration = physics_collision_solver.collision_iteration,
		})
	}
	
	/////////////////////////////// Acceleration Integrate ///////////////////////////////
	for component_storage, index in journey.run(&acceleration_integrate_query){
		mutable_component_storage := component_storage

		velocity := journey.get_soa_component(world, component_storage.entities[index], journey.Velocity)

		mutable_component_storage.component_a[index].x = (velocity.x - velocity.previous_x) / global.fixed_deltatime
		mutable_component_storage.component_a[index].y =  (velocity.y - velocity.previous_y) / global.fixed_deltatime 
	}


	/////////////////////////////// Position Integrate ///////////////////////////////
	for component_storage, index in journey.run(&position_integrate_query){
		mutable_component_storage := component_storage

		sprite := journey.get_soa_component(world, component_storage.entities[index], journey.RenderInstance)
		sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]

		//Position update
		sprite_batch.instances[sprite.instance_index].transform[0,3] += (component_storage.component_a[index].x * global.fixed_deltatime) 
		sprite_batch.instances[sprite.instance_index].transform[1,3] += (component_storage.component_a[index].y * global.fixed_deltatime)


		//Collider Resizing and Re-Orientation
		{
			//TODO:khal we don't want to get the resource to modify the collider in the physics simulation
			sprite_rect := sprite_batch.instances[sprite.instance_index].src_rect

			mutable_component_storage.component_b[index].extent_x = sprite_rect[2]
			mutable_component_storage.component_b[index].extent_y = sprite_rect[3]
	
			mutable_component_storage.component_b[index].center_x = sprite_batch.instances[sprite.instance_index].transform[0,3]
			mutable_component_storage.component_b[index].center_y = sprite_batch.instances[sprite.instance_index].transform[1,3]
		}
	}
}

update :: proc(global : ^GameLoop){
	world := cast(^journey.World)context.user_ptr
	
	unique_entity := uint(context.user_index)
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)

	sprite_flip_query := journey.query(world, journey.GameController)
	animation_query := journey.query(world, journey.Animator)

	for component_storage, index in journey.run(&sprite_flip_query){

		sprite := journey.get_soa_component(world,component_storage.entities[index], journey.RenderInstance)
		sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]

		left_input := component_storage.component_a[index].key_buffer[sdl2.SCANCODE_A]
		right_input := component_storage.component_a[index].key_buffer[sdl2.SCANCODE_D]

		if bool(left_input ~ right_input){
			sprite_batch.instances[sprite.instance_index].flip_bit[0] = f32(1 - right_input)
			sprite_batch.instances[sprite.instance_index].flip_bit[0] = f32(left_input)
		}
	}

	for component_storage, index in journey.run(&animation_query){
		mutable_component_storage := component_storage

		if journey.has_soa_component(world, component_storage.entities[index], journey.Velocity){
			velocity := journey.get_soa_component(world, component_storage.entities[index], journey.Velocity)

			if velocity.y > 0{
				mutable_component_storage.component_a[index].current_clip = 4
			}else if velocity.y < 0{
				mutable_component_storage.component_a[index].current_clip = 3
			}else if velocity.previous_y == 0 {
				mutable_component_storage.component_a[index].current_clip = int(abs(velocity.x) >= 0.5) 
			}
		}
	}
}

on_animation :: proc(global : ^GameLoop){

    world := cast(^journey.World)context.user_ptr
	
	unique_entity := uint(context.user_index)
	// Cache texture and shader and render data to send to render thread
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)

	anim_sprite_query := journey.query(world, journey.Animator)

	for component_storage, index in journey.run(&anim_sprite_query){
		mutable_component_storage := component_storage

		sprite := journey.get_soa_component(world, component_storage.entities[index], journey.RenderInstance)
		sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]
		
		animator := component_storage.component_a[index]

		current_clip := animator.clips[animator.current_clip]

		normalized_time := global.elapsed_time / animator.animation_duration_sec

		y :=current_clip.index * current_clip.height
		x := (int(normalized_time) % current_clip.len) * current_clip.width
		
		sprite_batch.instances[sprite.instance_index].src_rect = {
			f32(x), f32(y), f32(current_clip.width), f32(current_clip.height),
		} 
	}
}

late_update :: proc(global : ^GameLoop){
	//This is where updating the camera goes
	world := cast(^journey.World)context.user_ptr
	
	unique_entity := uint(context.user_index)

	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)

	player_entities := journey.get_id_soa_components(world,journey.GameController)

	assert(len(player_entities) == 1, "There is no game controller or more then one game controller on a entity")

	sprite := journey.get_soa_component(world, player_entities[0], journey.RenderInstance)
	sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]

	transform := sprite_batch.instances[sprite.instance_index].transform

	resource.render_buffer.camera = journey.Camera{
		look_at_x = transform[0,3],
		look_at_y = transform[1,3],
	}

}

main ::  proc()  {
	
	bt_track : bt.Tracking_Allocator

	when ODIN_DEBUG{
		bt.tracking_allocator_init(&bt_track, 16, context.allocator)
		bt.tracking_allocator_destroy(&bt_track)
		context.allocator = bt.tracking_allocator(&bt_track)
	}

	////////////////////// Game Initialize /////////////////////////

	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo 

	//temp solution

	resource : journey.ResourceCache = journey.ResourceCache{
		render_buffer = new(journey.RenderBatchBuffer),
	}
	resource.render_buffer.render_batch_groups = make(map[uint]journey.RenderBatchGroup)

	game_loop := init_game_loop_window(0, 1, journey.MAX_DELTA_TIME)

	world := journey.init_world()
	journey.init_physic_world(world)
	context.user_ptr = world

	journey.register(world, journey.RenderInstance)
	journey.register(world, journey.Animator)
	journey.register(world, journey.GameController)
	journey.register(world, journey.ResourceCache)

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

	render_thread := journey.create_renderer(journey.RenderBackend.DX11,window_info.info.win.window, resource.render_buffer, context.allocator)

	//TODO: khal this will change when resource is implement in journey_ecs
	// Then the playable entity id will be stored in contect.user_index
	context.user_index = int(journey.create_entity(world))

	journey.add_soa_component(world, uint(context.user_index), resource)
	//

	defer{	
		journey.stop_renderer(render_thread)

		journey.deinit_world(world)
		context.user_ptr = nil

		{
			for _, group in resource.render_buffer.render_batch_groups{
				delete(group.instances)
			}

			delete(resource.render_buffer.render_batch_groups)
			free(resource.render_buffer)
		}

		sdl2.DestroyWindow(window)
		sdl2.Quit()

		when ODIN_DEBUG{
			// bt.tracking_allocator_print_results(&bt_track)
			// bt.tracking_allocator_destroy(&bt_track)
		}
	}
	////////////////////////////////////////////////////////////////////

	///////////////////////// Game Start ///////////////////////////////

	player_entity_1 := create_game_entity("resource/sprite/padawan/pad.png", 0,4,journey.EntityDescriptor{
		position = {0,0},
		scale = {2,2},
		color = {0,0,0,0},

		sprite_texture_type = journey.TextureType.SpriteSheet,
		direction = journey.Direction.Left_Top,
	})

	player_entity_2 := create_game_entity("resource/sprite/padawan/pad.png", 0,2, journey.EntityDescriptor{
		position = {0,250},
		scale = {2,2},
		color = {0,0,0,0},

		sprite_texture_type = journey.TextureType.SpriteSheet,
		direction = journey.Direction.Left_Top,
	})

	player_entity_3 := create_game_entity("resource/sprite/padawan/pad.png", 0,2, journey.EntityDescriptor{
		position = {200,230},
		scale = {2,2},
		color = {0,0,0,0},

		sprite_texture_type = journey.TextureType.SpriteSheet,
		direction = journey.Direction.Left_Top,
	})

	//TODO:khal proof of implementation flesh it out.
	data,_ := os.read_entire_file_from_filename("resource/animation/player_anim.json")
	defer delete(data)
	player_anim : journey.Animator
	json.unmarshal(data, &player_anim)

	journey.add_soa_component(world, player_entity_1, player_anim)
	journey.add_soa_component(world, player_entity_2, player_anim)
	journey.add_soa_component(world, player_entity_3, player_anim)

	journey.add_soa_component(world, player_entity_1, journey.GameController{
		key_buffer = transmute([]i8)sdl2.GetKeyboardStateAsSlice(),
	})

	journey.add_soa_component(world, player_entity_1, journey.Collider{})
	journey.add_soa_component(world, player_entity_1, journey.Velocity{0, 1,0,0})
	journey.add_soa_component(world,player_entity_1, journey.Acceleration{0,0})
	journey.add_soa_component(world, player_entity_1, journey.AccumulatedForce{})
	journey.add_soa_component(world, player_entity_1, journey.InverseMass{0.1})


	journey.add_soa_component(world, player_entity_2, journey.Collider{center_x = -500, center_y = 240, extent_x = 2000, extent_y = 10})
	journey.add_soa_component(world, player_entity_3, journey.Collider{center_x = 200, center_y = 200, extent_x = 30, extent_y = 50})

	///////////////////////////////////////////////////////////////////

	///////////////////////// Game Loop ///////////////////////////////
	start_looping_game(&game_loop,&sdl2_event)
	///////////////////////// Game Loop ///////////////////////////////
}
