package game_context

import "../physics"
import  "../ecs"
import "../container"
import "../mathematics"

import  "core:math/linalg"
import "core:log"

import "vendor:sdl2"
import "vendor:sdl2/image"
import "core:container/queue"

Context :: struct{
	window : ^sdl2.Window,
	renderer : ^sdl2.Renderer,
	world : ecs.Context,
	pixel_format : ^sdl2.PixelFormat,
	clear_color : [3]u8,
	// TODO: khal attach this GameEntity struct it will be used by npc, enemy and player.
	event_queue : queue.Queue(container.Action),
}

@(cold)
initialize_dynamic_resource :: proc()
{
	if context.user_ptr != nil{
		ctx := cast(^Context) context.user_ptr
		resource_entity := ecs.create_entity(&ctx.world)

		ecs.add_component_unchecked(&ctx.world, resource_entity, container.DynamicResource{sdl2.GetTicks(),0,f32(sdl2.GetTicks())})
	}
}

@(cold)
init :: proc(game_cfg : container.GameConfig) -> Context{
	ctx := Context{}

	// We only need the cstring for window title. Once created we can delete it to free memory.
	defer delete(game_cfg.title)

	if err := sdl2.Init(game_cfg.game_flags); err != 0{
		log.error(sdl2.GetError())
	}

	img_res := image.Init(game_cfg.img_flags)

	if img_res != game_cfg.img_flags{
		log.errorf("sdl image init return %v", img_res)
	}

	sdl2.ClearError()

	width := i32(game_cfg.grid.x * game_cfg.grid.z) 
	height := i32(game_cfg.grid.y * game_cfg.grid.z)
	
	width = width + 1
	height = height + 1

	pos_x_mask := i32(game_cfg.center.x >= 0)
	pos_y_mask := i32(game_cfg.center.y >= 0)

	window_pos_x :[2]int= {sdl2.WINDOWPOS_CENTERED, game_cfg.center.x}
	window_pos_y :[2]int= {sdl2.WINDOWPOS_CENTERED, game_cfg.center.y}

	#no_bounds_check{
			ctx.window = sdl2.CreateWindow(game_cfg.title, i32(window_pos_x[pos_x_mask]), i32(window_pos_y[pos_y_mask]), width,height, game_cfg.window_flags) 
	}

	ctx.pixel_format = sdl2.GetWindowSurface(ctx.window).format
	
	ctx.renderer = sdl2.CreateRenderer(ctx.window,-1, game_cfg.render_flags)
	
	if err := sdl2.SetRenderDrawColor(ctx.renderer, game_cfg.clear_color.r, game_cfg.clear_color.g, game_cfg.clear_color.b, 255); err != 0 {
		log.error(sdl2.GetError())
	}

	ctx.clear_color = game_cfg.clear_color

	queue.init(&ctx.event_queue)

	return ctx;
}

handle_event ::proc() -> bool{
	ctx := cast(^Context)context.user_ptr

	player_entity := ecs.get_entities_with_components(&ctx.world, {container.GameEntity, container.Player}) // there should only be one playable player.
	
	player_component := ecs.get_component_unchecked(&ctx.world, player_entity[0], container.Player)
	game_component := ecs.get_component_unchecked(&ctx.world, player_entity[0], container.GameEntity)
	animation_component := ecs.get_component_unchecked(&ctx.world, player_entity[0], container.Animation_Tree)

	keyboard_snapshot := sdl2.GetKeyboardState(nil)
	sdl_event : sdl2.Event;

	running := true;

	for sdl2.PollEvent(&sdl_event){
		running = sdl_event.type != sdl2.EventType.QUIT
	
		#partial switch sdl_event.type{
			case sdl2.EventType.MOUSEBUTTONDOWN:
				if ctx.event_queue.len <= 0 || queue.peek_back(&ctx.event_queue)^ == container.Action.Attacking{
					animation_component.previous_frame = 5 * int(ctx.event_queue.len)
					queue.push(&ctx.event_queue, container.Action.Attacking)
					game_component.animation_index = 7
				}
		}
	}

	jumping := keyboard_snapshot[sdl2.Scancode.SPACE]
	left := keyboard_snapshot[sdl2.Scancode.A] | keyboard_snapshot[sdl2.Scancode.LEFT]
	right := keyboard_snapshot[sdl2.Scancode.D] | keyboard_snapshot[sdl2.Scancode.RIGHT]
	roll := keyboard_snapshot[sdl2.Scancode.C]

	if ctx.event_queue.len <= 0{
		combined_left_right := int(left | right)
		game_component.animation_index = combined_left_right
		game_component.input_direction = combined_left_right
		
		if combined_left_right != 0{
			game_component.render_direction = sdl2.RendererFlip(left > right)
		}
		
		if jumping >= 1{
			queue.push(&ctx.event_queue, container.Action.Jumping)
		}
		
		//TODO: khal we need a better way for cooldown....
		if roll >= 1 && game_component.input_direction != 0{
			if sdl2.GetTicks() > player_component.cooldown[0].cooldown_duration{
				player_component.cooldown[0].cooldown_duration = sdl2.GetTicks() + player_component.cooldown[0].cooldown_amount

				animation_component.previous_frame = 0
				queue.push(&ctx.event_queue, container.Action.Roll)
				game_component.animation_index = 4
				
			}
		}else if roll >= 1{
			if sdl2.GetTicks() > player_component.cooldown[1].cooldown_duration{
				player_component.cooldown[1].cooldown_duration = sdl2.GetTicks() + player_component.cooldown[1].cooldown_amount
				animation_component.previous_frame = 0
				queue.push(&ctx.event_queue, container.Action.Teleport)
				
				game_component.animation_index = 5
			}
		}
	}

	return running;
}

on_fixed_update :: proc(){
	ctx := cast(^Context)context.user_ptr
	
	resource_entity := ecs.Entity(context.user_index)
	resource := ecs.get_component_unchecked(&ctx.world, resource_entity, container.DynamicResource)
	
	previous_physics_time := resource.current_physics_time
	resource.current_physics_time = f32(sdl2.GetTicks())

	resource.delta_time = (resource.current_physics_time - previous_physics_time) * 0.001

	physics_entities := ecs.get_entities_with_components(&ctx.world, {container.GameEntity, container.Physics, container.Position})

	for entity in physics_entities{
		physics_component := ecs.get_component_unchecked(&ctx.world, entity, container.Physics)
		game_component := ecs.get_component_unchecked(&ctx.world, entity, container.GameEntity)
		position_component := ecs.get_component_unchecked(&ctx.world, entity, container.Position)

		// TODO: can we clean this...
		direction_map := f32(game_component.render_direction) * -1.0
		direction_map += 0.5
		direction := direction_map * 2.0

		acceleration_direction := mathematics.Vec2{physics_component.acceleration.x * direction, physics_component.acceleration.y}
				
		grounded :f32= 0.0;

		// TODO: khal TEMP SOLUTION
		if sdl2.HasIntersection(&sdl2.Rect{i32(position_component.value.x), i32(position_component.value.y), 5, 100}, &sdl2.Rect{0,612,2000,36}){
			grounded = 1.0
			physics_component.velocity.y = 0
			physics_component.acceleration.y = 0
		}else{
			fall := int(physics_component.velocity.y > 0)
			jump := int(physics_component.velocity.y < 0)
			// TODO: khal magic number here...
			physics_component.acceleration.y = (3000 * f32(fall)) + (1000 * f32(jump))
		}

		if ctx.event_queue.len > 0 {
			if queue.peek_back(&ctx.event_queue)^ == container.Action.Jumping{
				physics.add_force(physics_component, mathematics.Vec2{0, -21000 * grounded})
			}else if queue.peek_back(&ctx.event_queue)^ == container.Action.Roll{
				physics_component.velocity.x = physics_component.velocity.x * 1.05 
			}
		}

		result_acceleration := (acceleration_direction + physics_component.accumulated_force) * physics_component.inverse_mass

		physics_component.velocity += result_acceleration * resource.delta_time
		physics_component.velocity *= linalg.pow(physics_component.damping, resource.delta_time)

		physics_component.velocity.x = physics_component.velocity.x * f32(linalg.abs(game_component.input_direction))

		temp_velocity := physics_component.velocity
		temp_acceleration := physics_component.acceleration

		if ctx.event_queue.len > 0 {
			if queue.peek_back(&ctx.event_queue)^ == container.Action.Attacking{
				temp_velocity.x = 0
				temp_acceleration.x = 0
			}
		}

		position_component.value += temp_velocity * resource.delta_time 

		physics_component.accumulated_force = mathematics.Vec2{0,0}
	}
}

on_update :: proc(){
	ctx := cast(^Context)context.user_ptr

	game_entities := ecs.get_entities_with_components(&ctx.world, {container.Position, container.GameEntity, container.Physics, container.Animation_Tree})
	
	for entity in game_entities{
		current_translation := ecs.get_component_unchecked(&ctx.world, entity, container.Position)
		game_entity := ecs.get_component_unchecked(&ctx.world, entity, container.GameEntity)
		physics_component := ecs.get_component_unchecked(&ctx.world, entity, container.Physics)

		if physics_component.velocity.y > 0{
			queue.pop_back_safe(&ctx.event_queue)
			queue.push_back(&ctx.event_queue, container.Action.Falling)
			game_entity.animation_index = 3
		}else if physics_component.velocity.y < 0{
			game_entity.animation_index = 2
		}else{
			if ctx.event_queue.len > 0 && (queue.peek_back(&ctx.event_queue)^ == container.Action.Falling || queue.peek_back(&ctx.event_queue)^ == container.Action.Jumping){
				queue.clear(&ctx.event_queue)
				game_entity.animation_index = 0
			}
		}


		if game_entity.animation_index == 6 && queue.peek_back(&ctx.event_queue)^ == container.Action.TeleportDown{
			direction_map := f32(game_entity.render_direction) * -1.0
			direction_map += 0.5
			direction := direction_map * 2.0		

			current_translation.value.x += (200 * direction)
			queue.pop_back(&ctx.event_queue)
		}
	}
}

update_animation :: proc(){
	ctx := cast(^Context) context.user_ptr

	game_entites := ecs.get_entities_with_components(&ctx.world, {container.Animation_Tree, container.GameEntity})

	for entity in game_entites{
		game_entity := ecs.get_component_unchecked(&ctx.world,entity, container.GameEntity)
		animation_tree := ecs.get_component_unchecked(&ctx.world, entity, container.Animation_Tree)
		current_time := f32(sdl2.GetTicks())
		
		current_animation := animation_tree.animations[game_entity.animation_index]

		delta_time := (current_time - game_entity.animation_time) * 0.001
		frame_to_update := linalg.floor(delta_time * current_animation.animation_speed)

		if(frame_to_update > 0){
			animation_tree.previous_frame += int(frame_to_update)
			animation_tree.previous_frame %= len(current_animation.value) 
			game_entity.animation_time = current_time
		}
	}

	//TODO: khal we want to confine this to the player only, enemy/npc will follow a different dodge animation.
	// Should make this a map for string. It will be more readable this way..
	for entity in game_entites{
		game_entity := ecs.get_component_unchecked(&ctx.world,entity, container.GameEntity)
		animation_tree := ecs.get_component_unchecked(&ctx.world, entity, container.Animation_Tree)

		if game_entity.animation_index == 4{
			if animation_tree.previous_frame == len(animation_tree.animations[game_entity.animation_index].value) -1{
				game_entity.animation_index = 0
				queue.pop_back(&ctx.event_queue)
				animation_tree.previous_frame = 0
			}
		}

		if game_entity.animation_index == 5{
			if animation_tree.previous_frame == len(animation_tree.animations[game_entity.animation_index].value) -1{
				animation_tree.previous_frame = 0
				queue.pop_back(&ctx.event_queue)
				queue.push(&ctx.event_queue, container.Action.TeleportDown)
				game_entity.animation_index = 6
			}
		}

		if game_entity.animation_index == 6{
			if animation_tree.previous_frame == len(animation_tree.animations[game_entity.animation_index].value) -1{
				game_entity.animation_index = 0
				animation_tree.previous_frame = 0
			}
		}

		if game_entity.animation_index == 7{
			if animation_tree.previous_frame == len(animation_tree.animations[game_entity.animation_index].value) - (12 / int(ctx.event_queue.len)){
				game_entity.animation_index = 0
				animation_tree.previous_frame = 0
				queue.pop_back(&ctx.event_queue)

				// if queue len is 3 then we did the full combo and reset back to idle...
			}
		}
	}

	// Animation
}

on_late_update :: proc(){


	// Camera and other
}


on_render :: proc(){
	ctx := cast(^Context)context.user_ptr
	sdl2.RenderClear(ctx.renderer)

	texture_entities:= ecs.get_entities_with_components(&ctx.world, {container.TextureAsset, container.Position, container.Rotation, container.Scale})
	
	#no_bounds_check{

		sdl2.SetRenderDrawColor(ctx.renderer,
			ctx.clear_color.r,
			ctx.clear_color.g,
			ctx.clear_color.b,
			255,
		)
	
		for texture_entity in texture_entities{
			texture_component := ecs.get_component_unchecked(&ctx.world, texture_entity, container.TextureAsset)
	
			game_entity := ecs.get_component(&ctx.world, texture_entity, container.GameEntity) or_else nil
			animation_tree := ecs.get_component(&ctx.world, texture_entity, container.Animation_Tree) or_else nil
	
			position := ecs.get_component_unchecked(&ctx.world, texture_entity, container.Position)
			rotation := ecs.get_component_unchecked(&ctx.world,texture_entity, container.Rotation)
			scale := ecs.get_component_unchecked(&ctx.world, texture_entity, container.Scale)
	
			position_x := position.value.x
			position_y := position.value.y
	
			angle := rotation.value 
	
			scale_x := scale.value.x
			scale_y := scale.value.y
	
			desired_scale_x := texture_component.dimension.x * scale_x
			desired_scale_y := texture_component.dimension.y * scale_y
	
			dst_rec := sdl2.FRect{position_x, position_y, desired_scale_x, desired_scale_y}
			
			src_res := new(sdl2.Rect)
			defer free(src_res)
	
			if animation_tree != nil && game_entity != nil{
				max_frame_len := len(animation_tree.animations[game_entity.animation_index].value) - 1
				capped_frame := linalg.clamp(animation_tree.previous_frame, 0, max_frame_len)
	
				src_res^ = animation_tree.animations[game_entity.animation_index].value[capped_frame]
			}else{
				src_res = nil
			}
			
			sdl2.RenderCopyExF(ctx.renderer, texture_component.texture,src_res, &dst_rec, angle, nil, game_entity.render_direction)
		}
	}


	sdl2.RenderPresent(ctx.renderer)

	// Rendering
}

@(cold)
cleanup :: proc(){
	ctx := cast(^Context) context.user_ptr

	queue.clear(&ctx.event_queue)
	queue.destroy(&ctx.event_queue)
	
	sdl2.DestroyRenderer(ctx.renderer)
	sdl2.DestroyWindow(ctx.window)
	sdl2.Quit()

	ecs.deinit_ecs(&ctx.world)

}

