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

	game_loop.delta_time = min(f32(game_loop.current_time - game_loop.previous_time) * 0.001, game_loop.maximum_frame_time)
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

create_game_entity :: proc($tex_path : string, $shader_cache : u32, $render_order : int, entity_desc : journey.EntityDescriptor) -> uint{
    world := cast(^journey.World)context.user_ptr

	//TODO:khal change when implemented resource in ecs side 
	unique_entity := uint(context.user_index)
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)
	//

	width :i32= 0
	height :i32= 0

	path_hash := journey.string_hash(tex_path)

	batch_group, valid := resource.render_buffer.render_batch_groups[path_hash]

	if valid{
		
		width = batch_group.texture_param.width
		height = batch_group.texture_param.height

	}else{
		texture_bytes := image.load(cstring(tex_path),&width,&height,nil,  4)

		tex_param : journey.TextureParam = journey.TextureParam{
			texture = texture_bytes,
			width = width,
			height = height,
			shader_cache = shader_cache,
		}

		resource.render_buffer.render_batch_groups[path_hash] = journey.RenderBatchGroup{
			texture_param = tex_param,
			instances = make([dynamic]journey.RenderInstanceData, 0 ,1 << 5),
		}
	}

	game_entity := journey.create_entity(world)

	position := journey.Position{
		x = entity_desc.position.x,
		y = entity_desc.position.y,
	}

	scale := journey.Scale{
		x = entity_desc.scale.x,
		y = entity_desc.scale.y,
	}

	rotation := journey.Rotation{
		z = entity_desc.rotation,
	}

	color := journey.Color{
		r = entity_desc.color.r,
		g = entity_desc.color.g,
		b = entity_desc.color.b,
		a = entity_desc.color.a,
	}

	//TODO:khal this will change later since sprite sheet will have a width and height of zero then it will
	// get changed in the game loop to the correct width and height depending on the animator. 
	// We need to set the default width and height rather then just set it to zero.
	rect_width := f32(width & -i32(entity_desc.sprite_texture_type))
	rect_height := f32(height & -i32(entity_desc.sprite_texture_type))

	rect := journey.Rect{
		x = 0,
		y = 0,
		width = rect_width,
		height = rect_height,
	}

	vertical_bit := i32(entity_desc.direction) & 1
	horizontal_bit := i32(entity_desc.direction) >> 1

	flip := journey.Flip{
		x = horizontal_bit,
		y = vertical_bit,
	}

	journey.add_soa_component(world, game_entity, position)
	journey.add_soa_component(world, game_entity, scale)
	journey.add_soa_component(world, game_entity, rotation)
	journey.add_soa_component(world, game_entity, color)
	journey.add_soa_component(world, game_entity, rect)
	journey.add_soa_component(world, game_entity, flip)
	
	sprite_batch := &resource.render_buffer.render_batch_groups[path_hash]

	append(&sprite_batch.instances, journey.RenderInstanceData{
		transform = {
			scale.x * math.cos(rotation.z) , -math.sin(rotation.z), 0.0, position.x,
			math.sign(rotation.z), scale.y * math.cos(rotation.z), 0.0, position.y,
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},
		src_rect = {
			rect.x,
			rect.y,
			rect.width,
			rect.height,
		},
		color = {color.r, color.g, color.b, color.a},
		flip_bit = {f32(flip.x), f32(flip.y)},
		order_index = render_order,
	})

	journey.add_soa_component(world, game_entity, journey.RenderInstance{
		hash = path_hash,
		instance_index = len(sprite_batch.instances) - 1,
	})

	sync.atomic_store_explicit(&resource.render_buffer.changed_flag, true, sync.Atomic_Memory_Order.Relaxed)

	return game_entity
}


physics_body :: proc(body_entity : uint, $inverse_mass : f32, $restitution : f32, half_extent_x : f32 = 0, half_extent_y : f32 = 0){
    world := cast(^journey.World)context.user_ptr

	collider := journey.Collider{half_extent_x = half_extent_x, half_extent_y = half_extent_y}

	when inverse_mass > 0{
		journey.add_soa_component(world, body_entity, journey.Velocity{0, 0,0,0})
		journey.add_soa_component(world,body_entity, journey.Acceleration{0,0})
		journey.add_soa_component(world, body_entity, journey.AccumulatedForce{})
		journey.add_soa_component(world, body_entity, journey.InverseMass{0.1})
	}else{
		position := journey.get_soa_component(world,  body_entity, journey.Position)
		scale := journey.get_soa_component(world,body_entity, journey.Scale)

		collider.center_x = position.x
		collider.center_y = position.y

		collider.half_extent_x *= scale.x
		collider.half_extent_y *= scale.y
	}

	journey.add_soa_component(world, body_entity, collider)
	journey.add_soa_component(world, body_entity, journey.Restitution{val = restitution})
}

//////////////////////////////////////////////////////////////////////

event_update :: proc(event : ^sdl2.Event){

}

fixed_update :: proc(global : ^GameLoop){
    world := cast(^journey.World)context.user_ptr

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
	restitution_blend := journey.get_soa_component(world, unique_entity, journey.RestitutionBlend)
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

	position_integrate_query := journey.query(world, journey.Velocity, journey.Collider, journey.Position, 8)
	collider_reorientation_query := journey.query(world, journey.Velocity, journey.Collider, journey.Position, journey.Scale, 8)

	/////////////////////////////// Collision Detection ///////////////////////////////
	for component_storage, dynamic_index in journey.run(&collider_query){
		collider_restitution := journey.get_soa_component(world, component_storage.entities[dynamic_index], journey.Restitution)

		for static_collider, static_index in static_colliders{
			collided_restitution := journey.get_soa_component(world, static_entites[static_index], journey.Restitution)

			restitution_blend_lookup := [4]f32{
				max(collided_restitution.val,collider_restitution.val), // max restitution
				min(collided_restitution.val,collider_restitution.val), // min restitution
				(collided_restitution.val + collider_restitution.val) * 0.5, // average restitution
				collided_restitution.val * collider_restitution.val, // multiply restitution
			}

			collision_hit : journey.PhysicsContact

			total_extent := [2]f32{
				static_collider.half_extent_x + component_storage.component_b[dynamic_index].half_extent_x,
				static_collider.half_extent_y + component_storage.component_b[dynamic_index].half_extent_y,
			}

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

				if overlap.x > 0 && overlap.y > 0{
					//TODO: khal optimize
					horizontal_collision_mask := int(overlap.x < overlap.y)

					collision_direction_mask := [2]f32{f32(horizontal_collision_mask), f32(1 - horizontal_collision_mask)}

					collision_hit.collision_normal_x = sign_collider_displacement.x * collision_direction_mask.x
					collision_hit.collision_normal_y = sign_collider_displacement.y * collision_direction_mask.y

					extent_offset_x := static_collider.half_extent_x * sign_collider_displacement.x
					extent_offset_y :=  static_collider.half_extent_y * sign_collider_displacement.y

					static_collision_point_x := static_collider.center_x + extent_offset_x
					static_collision_point_y := static_collider.center_y + extent_offset_y

					collision_hit.collision_point_x = (static_collision_point_x * collision_direction_mask.x) + (component_storage.component_b[dynamic_index].center_x * collision_direction_mask.y)
					collision_hit.collision_point_y = (static_collision_point_y * collision_direction_mask.y)  + (component_storage.component_b[dynamic_index].center_y * collision_direction_mask.x)

					penetration_x := (component_storage.component_b[dynamic_index].center_x + (-collision_hit.collision_normal_x * component_storage.component_b[dynamic_index].half_extent_x)) - (static_collider.center_x - (collision_hit.collision_normal_x * static_collider.half_extent_x))
					penetration_y := (component_storage.component_b[dynamic_index].center_y + (-collision_hit.collision_normal_y * component_storage.component_b[dynamic_index].half_extent_y)) - (static_collider.center_y +  (collision_hit.collision_normal_y * static_collider.half_extent_y))
					collision_hit.penetration = penetration_x * abs(collision_hit.collision_normal_x) + penetration_y * abs(collision_hit.collision_normal_y)

					collision_hit.restitution = restitution_blend_lookup[restitution_blend.val]

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

						time := clamp(near_time, 0, 1)

						dynamic_min := [2]f32{
							component_storage.component_b[dynamic_index].center_x - component_storage.component_b[dynamic_index].half_extent_x,
							component_storage.component_b[dynamic_index].center_y - component_storage.component_b[dynamic_index].half_extent_y,
						}

						dynamic_max := [2]f32{
							component_storage.component_b[dynamic_index].center_x + component_storage.component_b[dynamic_index].half_extent_x,
							component_storage.component_b[dynamic_index].center_y + component_storage.component_b[dynamic_index].half_extent_y,
						}

						static_min := [2]f32{
							static_collider.center_x - static_collider.half_extent_x,
							static_collider.center_y - static_collider.half_extent_y,
						}

						static_max := [2]f32{
							static_collider.center_x + static_collider.half_extent_x,
							static_collider.center_y + static_collider.half_extent_y,
						}

						overlap_x := min(dynamic_max[0], static_max[0]) - max(dynamic_min[0], static_min[0])
						overlap_y := min(dynamic_max[1], static_max[1]) - max(dynamic_min[1], static_min[1])

						collision_displacement := [2]f32{
							component_storage.component_b[dynamic_index].center_x - static_collider.center_x,
							component_storage.component_b[dynamic_index].center_y - static_collider.center_y,
						}

						horizontal_collision_mask := int(overlap_x < overlap_y)
						collision_direction_mask := [2]f32{f32(horizontal_collision_mask), f32(1 - horizontal_collision_mask)}

						collision_hit.collision_normal_x = math.sign(collision_displacement.x) * collision_direction_mask.x
						collision_hit.collision_normal_y = math.sign(collision_displacement.y) * collision_direction_mask.y

						displacement_x := (1 - time) * -component_storage.component_a[dynamic_index].x
						displacement_y := (1 - time) * -component_storage.component_a[dynamic_index].y

						collision_hit.collision_point_x = component_storage.component_b[dynamic_index].center_x + displacement_x * time
						collision_hit.collision_point_y = component_storage.component_b[dynamic_index].center_y + displacement_y * time

						penetration_x := (component_storage.component_b[dynamic_index].center_x + (-collision_hit.collision_normal_x * component_storage.component_b[dynamic_index].half_extent_x)) - (static_collider.center_x - (collision_hit.collision_normal_x * static_collider.half_extent_x))
						penetration_y := (component_storage.component_b[dynamic_index].center_y + (-collision_hit.collision_normal_y * component_storage.component_b[dynamic_index].half_extent_y)) - (static_collider.center_y +  (collision_hit.collision_normal_y * static_collider.half_extent_y))
						collision_hit.penetration = (penetration_x * abs(collision_hit.collision_normal_x)) + (penetration_y * abs(collision_hit.collision_normal_y))

						collision_hit.restitution = restitution_blend_lookup[restitution_blend.val]

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
			mutable_component_storage.component_b[index].y += journey.gravitational_force(mass) + journey.quadratic_drag_force(0.01,component_storage.component_c[index]).y
		}

		// Friction force. We will only calculate horizontal friction force for the game.
		{
			mutable_component_storage.component_b[index].x += journey.friction_force(0.6,mass,component_storage.component_c[index]).x
		}
	}


	/////////////////////////////// Compute Velocity ///////////////////////////////
	for component_storage, index in journey.run(&velocity_integrate_query){
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
	collision_iteration := len(physic_contacts) << 1
	for iteration_used < collision_iteration{
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

		mutable_component_storage.component_c[index].x += (component_storage.component_a[index].x * global.fixed_deltatime)
		mutable_component_storage.component_c[index].y += (component_storage.component_a[index].y * global.fixed_deltatime)
	}

	for component_storage, index in journey.run(&collider_reorientation_query){
		mutable_component_storage := component_storage
		
		sprite_rect := journey.get_soa_component(world, component_storage.entities[index], journey.Rect)

		mutable_component_storage.component_b[index].half_extent_x =  sprite_rect.width * 0.5 * component_storage.component_d[index].x
		mutable_component_storage.component_b[index].half_extent_y = sprite_rect.height * 0.5 * component_storage.component_d[index].y

		mutable_component_storage.component_b[index].center_x = component_storage.component_c[index].x
		mutable_component_storage.component_b[index].center_y = component_storage.component_c[index].y
	}
}

update :: proc(global : ^GameLoop){
	world := cast(^journey.World)context.user_ptr

	sprite_flip_query := journey.query(world, journey.GameController)
	animation_query := journey.query(world, journey.Animator)

	for component_storage, index in journey.run(&sprite_flip_query){

		left_input := component_storage.component_a[index].key_buffer[sdl2.SCANCODE_A]
		right_input := component_storage.component_a[index].key_buffer[sdl2.SCANCODE_D]

		if bool(left_input ~ right_input){
			facing := 1 - right_input
			facing = left_input

			journey.set_soa_component(world, component_storage.entities[index], journey.Flip{
				x = i32(facing),
			})
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

	anim_sprite_query := journey.query(world, journey.Animator, journey.Rect, 8)

	for component_storage, index in journey.run(&anim_sprite_query){
		mutable_component_storage := component_storage

		animator := component_storage.component_a[index]

		current_clip := animator.clips[animator.current_clip]

		normalized_time := global.elapsed_time / animator.animation_duration_sec

		y :=current_clip.index * current_clip.height
		x := (int(normalized_time) % current_clip.len) * current_clip.width

		mutable_component_storage.component_b[index] = {
			f32(x), f32(y), f32(current_clip.width), f32(current_clip.height),
		}
	}
}

late_update :: proc(global : ^GameLoop){
	//This is where updating the camera goes
	world := cast(^journey.World)context.user_ptr

	unique_entity := uint(context.user_index)
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)

	//TODO:khal render Sync Point. We will optimize the loops later.
	position_scale_query := journey.query(world, journey.Position, journey.Scale, journey.RenderInstance, 16)
	rotation_flip_query := journey.query(world, journey.Rotation, journey.Flip, journey.RenderInstance, 16)
	rect := journey.query(world,journey.Animator, journey.Rect, journey.RenderInstance, 16)
	
	for component_storage, index in journey.run(&rotation_flip_query){
		sprite_hash := component_storage.component_c[index].hash
		sprite_instance_index := component_storage.component_c[index].instance_index
		sprite_batch := resource.render_buffer.render_batch_groups[sprite_hash]

		cos_rotation := math.cos(component_storage.component_a[index].z)
		sin_rotation := math.sin(component_storage.component_a[index].z)

		sprite_batch.instances[sprite_instance_index].transform[0,0] = cos_rotation
		sprite_batch.instances[sprite_instance_index].transform[1,1] = cos_rotation
		sprite_batch.instances[sprite_instance_index].transform[0,1] = -sin_rotation
		sprite_batch.instances[sprite_instance_index].transform[1,0] = sin_rotation

		sprite_batch.instances[sprite_instance_index].flip_bit = {
			f32(component_storage.component_b[index].x),
			1,//f32(component_storage.component_a[index].y),
		}
	}

	for component_storage, index in journey.run(&position_scale_query){
		sprite_hash := component_storage.component_c[index].hash
		sprite_instance_index := component_storage.component_c[index].instance_index
		
		sprite_batch := resource.render_buffer.render_batch_groups[sprite_hash]


		
		sprite_batch.instances[sprite_instance_index].transform[0,3] = component_storage.component_a[index].x
		sprite_batch.instances[sprite_instance_index].transform[1,3] = component_storage.component_a[index].y

		sprite_batch.instances[sprite_instance_index].transform[0,0] *= component_storage.component_b[index].x
		sprite_batch.instances[sprite_instance_index].transform[1,1] *= component_storage.component_b[index].y

	}



	for component_storage, index in journey.run(&rect){
		sprite_hash := component_storage.component_c[index].hash
		sprite_instance_index := component_storage.component_c[index].instance_index
		sprite_batch := resource.render_buffer.render_batch_groups[sprite_hash]

		sprite_batch.instances[sprite_instance_index].src_rect = {
			component_storage.component_b[index].x,
			component_storage.component_b[index].y,
			component_storage.component_b[index].width,
			component_storage.component_b[index].height,
		}
	}
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

	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo

	resource : journey.ResourceCache 

	when ODIN_DEBUG{
		bt.tracking_allocator_init(&bt_track, 16, context.allocator)
		bt.tracking_allocator_destroy(&bt_track)
		context.allocator = bt.tracking_allocator(&bt_track)
	}

	////////////////////// Game Initialize /////////////////////////
	game_loop := init_game_loop_window(0, 1, journey.MAX_DELTA_TIME)

	world := journey.init_world()
	context.user_ptr = world

	{
		journey.register(world, journey.Collider)
		journey.register(world, journey.Velocity)
		journey.register(world, journey.Acceleration)
		journey.register(world, journey.InverseMass)
		journey.register(world, journey.AccumulatedForce)
		//frictions are not used yet.
		journey.register(world, journey.StaticFriction)
		journey.register(world, journey.DynamicFriction)
		journey.register(world, journey.Restitution)
		journey.register(world, journey.RestitutionBlend)
		journey.register(world, journey.PhysicsContacts)
	}

	{
		journey.register(world, journey.RenderInstance)
		journey.register(world, journey.ResourceCache)
		journey.register(world, journey.Animator)
		journey.register(world, journey.GameController)
		journey.register(world, journey.Position)
		journey.register(world, journey.Scale)
		journey.register(world, journey.Rotation)
		journey.register(world, journey.Color)
		journey.register(world, journey.Rect)
		journey.register(world, journey.Flip)
	}


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
			//sdl2.WindowFlag.BORDERLESS,
		},
	)

	sdl2.GetWindowWMInfo(window, &window_info)
	
	//TODO: khal this will change when resource is implement in journey_ecs
	// Then the playable entity id will be stored in contect.user_index
	resource = journey.ResourceCache{
		render_buffer = new(journey.RenderBatchBuffer),
	}

	resource.render_buffer.render_batch_groups = make(map[uint]journey.RenderBatchGroup)

	context.user_index = int(journey.create_entity(world))
	journey.add_soa_component(world, uint(context.user_index), resource)
	journey.add_soa_component(world, uint(context.user_index), journey.PhysicsContacts{})
	journey.add_soa_component(world, uint(context.user_index), journey.RestitutionBlend{val = journey.RBlend.Average})
	//

	////////////////////////////////////////////////////////////////////

	///////////////////////// Game Start ///////////////////////////////

	main_player := create_game_entity("resource/sprite/padawan/pad.png", 0,4,journey.EntityDescriptor{
		position = {0,0},
		scale = {1,1},
		color = {0,0,0,0},
		sprite_texture_type = journey.TextureType.SpriteSheet,
		direction = journey.Direction.Left_Top,
	})

	journey.add_soa_component(world, main_player, journey.GameController{
		key_buffer = transmute([]i8)sdl2.GetKeyboardStateAsSlice(),
	})

	ground := create_game_entity("resource/sprite/test-block.png", 0,2, journey.EntityDescriptor{
		position = {0,250},
		scale = {1,1},
		color = {0,0,0,0},

		sprite_texture_type = journey.TextureType.Individual,
		direction = journey.Direction.Left_Top,
	})

	//TODO:khal proof of implementation flesh it out.
	data,_ := os.read_entire_file_from_filename("resource/animation/player_anim.json")
	player_anim : journey.Animator
	json.unmarshal(data, &player_anim)
	delete(data)
	journey.add_soa_component(world, main_player, player_anim)
	//

	physics_body(main_player, 0.1, 0)
	physics_body(ground,0, 0, 8, 8)

	///////////////////////////////////////////////////////////////////

	render_thread := journey.create_renderer(journey.RenderBackend.DX11, window_info.info.win.window, resource.render_buffer, context.allocator)

	///////////////////////// Game Loop ///////////////////////////////
	start_looping_game(&game_loop,&sdl2_event)
	///////////////////////////////////////////////////////////////////

	//////////////////////// DeInitialize ////////////////////////////
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
		bt.tracking_allocator_print_results(&bt_track)
		bt.tracking_allocator_destroy(&bt_track)
	}

	///////////////////////////////////////////////////////////////////
}
