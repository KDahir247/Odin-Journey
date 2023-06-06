package game_context

import "../physics"
import "../ecs"
import "../container"
import "../system"
import "../utility"

import "core:math/linalg"
import "core:log"
import "core:intrinsics"
import "core:fmt"

import "vendor:sdl2"
import "vendor:sdl2/image"

Context :: struct {
	window:       ^sdl2.Window,
	renderer:     ^sdl2.Renderer,
	pixel_format: ^sdl2.PixelFormat,
	world:        ^ecs.Context,
}

@(cold)
initialize_dynamic_resource :: proc() {
	ctx := cast(^Context)context.user_ptr

	current_time := sdl2.GetTicks()
	resource_entity := ecs.create_entity(ctx.world)
	ecs.add_component_unchecked(
		ctx.world,
		resource_entity,
		container.DynamicResource{current_time, 0, f32(current_time)},
	)
}

@(cold)
init :: proc(game_cfg: container.GameConfig) -> Context {
	ctx := Context{}
	
	ecs_ctx := new(ecs.Context)
	ecs_world := ecs.init_ecs()
	ecs_ctx^ = ecs_world
	ctx.world = ecs_ctx


	if img_res := image.Init(game_cfg.img_flags); img_res != game_cfg.img_flags {
		log.errorf("sdl image init return %v", img_res)
	}

	sdl2.ClearError()

	pos_x_mask := i32(game_cfg.center.x >= 0)
	pos_y_mask := i32((game_cfg.center.y >= 0)) + 2

	window_pos: [4]int = {
		sdl2.WINDOWPOS_CENTERED,
		game_cfg.center.x,
		sdl2.WINDOWPOS_CENTERED,
		game_cfg.center.y,
	}

	#no_bounds_check {
		ctx.window = sdl2.CreateWindow(
			game_cfg.title,
			i32(window_pos[pos_x_mask]),
			i32(window_pos[pos_y_mask]),
			i32(game_cfg.dimension.x),
			i32(game_cfg.dimension.y),
			game_cfg.window_flags,
		)
	}

	delete(game_cfg.title)

	ctx.pixel_format = sdl2.GetWindowSurface(ctx.window).format

	ctx.renderer = sdl2.CreateRenderer(ctx.window, -1, game_cfg.render_flags)

	color := utility.hex_to_rgb(game_cfg.clear_color,false)

	if err := sdl2.SetRenderDrawColor(
		ctx.renderer,
		u8(color.r),
		u8(color.g),
		u8(color.b),
		255,
	); err != 0 {
		log.error(sdl2.GetError())
	}

	return ctx
}

handle_event :: proc() -> bool {
	@(static)
	ANIMATIONS := [2]string{"Idle", "Walk"}

	ctx := cast(^Context)context.user_ptr
	resource := ecs.get_component_unchecked(ctx.world, 0, container.DynamicResource)

	player_entity := ecs.Entity(context.user_index)

	player_component := ecs.get_component_unchecked(ctx.world, player_entity, container.Player)
	game_component := ecs.get_component_unchecked(ctx.world, player_entity, container.GameEntity)
	animator_component := ecs.get_component_unchecked(ctx.world, player_entity, container.Animator)

	keyboard_snapshot := sdl2.GetKeyboardState(nil)
	sdl_event: sdl2.Event

	running := true

	for sdl2.PollEvent(&sdl_event) {
		running = sdl_event.key.keysym.scancode != sdl2.Scancode.ESCAPE
	}

	#no_bounds_check {
		jumping := keyboard_snapshot[sdl2.Scancode.SPACE]
		left := keyboard_snapshot[sdl2.Scancode.A] | keyboard_snapshot[sdl2.Scancode.LEFT]

		right := keyboard_snapshot[sdl2.Scancode.D] | keyboard_snapshot[sdl2.Scancode.RIGHT]
		roll := keyboard_snapshot[sdl2.Scancode.C]

		if animator_component.current_animation == ANIMATIONS[0] || animator_component.current_animation == ANIMATIONS[1] {
			combined_left_right := int(left | right)
			game_component.input_direction = int(right) - int(left)
		
			set_animation_clip(animator_component, ANIMATIONS[combined_left_right], true, 13.0)

			if game_component.input_direction != 0 {
				game_component.render_direction = sdl2.RendererFlip(left > right)
			}
		}

		if roll >= 1{
			// //TODO: remove cooldown
			if resource.elapsed_time > player_component.cooldown[1].cooldown_duration {
				player_component.cooldown[1].cooldown_duration =
				resource.elapsed_time + player_component.cooldown[1].cooldown_amount

				set_animation_clip_and_reset(animator_component, "Roll", animator_component.current_animation != "Roll", 15.0)
			}
		}

		set_animation_clip(animator_component, "Jump",jumping >= 1, 15.0)

	}


	return running
}

on_fixed_update :: proc() {
	ctx := cast(^Context)context.user_ptr
	resource := ecs.get_component_unchecked(ctx.world, 0, container.DynamicResource)

	player_entity := ecs.Entity(context.user_index)

	player_game_component := ecs.get_component_unchecked(
		ctx.world,
		player_entity,
		container.GameEntity,
	)

	player_physics_component := ecs.get_component_unchecked(
		ctx.world,
		player_entity,
		container.Physics,
	)

	player_animator_component := ecs.get_component_unchecked(
		ctx.world,
		player_entity,
		container.Animator,
	)

	physics_components := ecs.get_component_list(ctx.world, container.Physics)

	previous_physics_time := resource.current_physics_time
	resource.current_physics_time = f32(sdl2.GetTicks())
	resource.delta_time = (resource.current_physics_time - previous_physics_time) * 0.001

	//-----------Player----------------
	system.move_player(
		player_physics_component,
		{f32(player_game_component.input_direction), 0},
		{250, 0},
	)

	if player_physics_component.grounded && player_animator_component.current_animation == "Jump" {
		physics.add_impulse(player_physics_component, -80, {0, 1})
	} else if player_animator_component.current_animation == "Roll" {
		physics.add_force(
			player_physics_component,
			{f32(player_game_component.input_direction * 400), 0},
		)
	}

	if player_physics_component.velocity.y > 0 {
		physics.add_gravitation_force(player_physics_component, {0, 300})
	} else if player_physics_component.velocity.y < 0 {
		physics.add_gravitation_force(player_physics_component, {0, 100})
	}

	for i in 0 ..< len(physics_components) {
		physics.add_friction_force(&physics_components[i], 0.65)

		physics.integrate(&physics_components[i], resource.delta_time)
	}

	system.handle_player_collision(
		player_physics_component,
		physics_components,
		resource.delta_time,
	)
}

on_update :: proc() {
	ctx := cast(^Context)context.user_ptr
	resource := ecs.get_component_unchecked(ctx.world, 0, container.DynamicResource)

	resource.elapsed_time = sdl2.GetTicks()

	game_entities := ecs.get_entities_with_components(
		ctx.world,
		{container.Position, container.GameEntity, container.Physics, container.Animator},
	)

	for entity in game_entities {
		animator_component := ecs.get_component_unchecked(ctx.world, entity, container.Animator)
		position_component := ecs.get_component_unchecked(ctx.world, entity, container.Position)
		physics_component := ecs.get_component_unchecked(ctx.world, entity, container.Physics)
		
		position_component.value = physics_component.position 
		
		set_animation_clip(animator_component, "Fall",physics_component.velocity.y > 0, 15)
		set_animation_clip(animator_component, "Idle", animation_clip_finished(animator_component) && physics_component.velocity.y == 0 , 15)
	}
}

update_animation :: proc() {
	ctx := cast(^Context)context.user_ptr
	resource := ecs.get_component_unchecked(ctx.world, 0, container.DynamicResource)

	current_time := f32(resource.elapsed_time)

	game_entites := ecs.get_entities_with_components(
		ctx.world,
		{container.Animator, container.GameEntity},
	)

	for entity in game_entites {
		animator_component := ecs.get_component_unchecked(ctx.world, entity, container.Animator)

		current_clip := animator_component.clips[animator_component.current_animation]

		delta_time := (current_time - animator_component.animation_time) * 0.001
		frame_to_update := linalg.floor(delta_time * animator_component.animation_speed)
	
		if (frame_to_update > 0 && !animation_clip_finished(animator_component)) {
			animator_component.previous_frame += int(frame_to_update)
			animator_component.previous_frame %= current_clip.len
			animator_component.animation_time = current_time
		}
	}
}

on_late_update :: proc() {


	// Camera and other
}


on_render :: proc() {
	ctx := cast(^Context)context.user_ptr

	texture_entities := ecs.get_entities_with_components(
		ctx.world,
		{container.TextureAsset, container.Position, container.Rotation, container.Scale},
	)
	tileset_entities := ecs.get_entities_with_components(ctx.world, {container.TileMap})

	sdl2.RenderClear(ctx.renderer)

	for tile_entity in tileset_entities {
		tileset_component := ecs.get_component_unchecked(
			ctx.world,
			tile_entity,
			container.TileMap,
		)

		sdl2.RenderCopy(ctx.renderer, tileset_component.texture, nil, nil)
	}

	#no_bounds_check {

		for texture_entity in texture_entities {

			texture_component := ecs.get_component_unchecked(
				ctx.world,
				texture_entity,
				container.TextureAsset,
			)

			game_entity :=
				ecs.get_component(ctx.world, texture_entity, container.GameEntity) or_else nil
			animator :=
				ecs.get_component(ctx.world, texture_entity, container.Animator) or_else nil

			position := ecs.get_component_unchecked(ctx.world, texture_entity, container.Position)
			rotation := ecs.get_component_unchecked(ctx.world, texture_entity, container.Rotation)
			scale := ecs.get_component_unchecked(ctx.world, texture_entity, container.Scale)

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

			if animator != nil && game_entity != nil {
				current_animation := animator.clips[animator.current_animation]

				max_frame_len := current_animation.len - 1
				capped_frame := linalg.clamp(animator.previous_frame, 0, max_frame_len)

				x := capped_frame * current_animation.dimension.x
				y := current_animation.pos * current_animation.dimension.y

				width := current_animation.dimension.x
				height := current_animation.dimension.y

				src_res^ = sdl2.Rect{i32(x), i32(y), i32(width), i32(height)}

			} else {
				src_res = nil
			}

			sdl2.RenderCopyExF(
				ctx.renderer,
				texture_component.texture,
				src_res,
				&dst_rec,
				angle,
				nil,
				game_entity.render_direction,
			)
		}
	}

	sdl2.RenderPresent(ctx.renderer)
}

@(cold)
cleanup :: proc() {
	ctx := cast(^Context)context.user_ptr

	sdl2.DestroyRenderer(ctx.renderer)
	sdl2.DestroyWindow(ctx.window)
	sdl2.Quit()

	ecs.deinit_ecs(ctx.world)
	free(ctx.world)

}
