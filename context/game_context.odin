package game_context

import "../physics"
import  "../ecs"
import "../container"
import "../mathematics"
import "../editor"

import  "core:math/linalg"
import "core:fmt"
import "core:log"

import "vendor:sdl2"
import sdl2_img "vendor:sdl2/image"
import "core:c"

Context :: struct{
	window : ^sdl2.Window,
	renderer : ^sdl2.Renderer,
	world : ecs.Context,
	pixel_format : ^sdl2.PixelFormat,
	editor : editor.Context,
	clear_color : [4]u8,

	//TODO: khal find a way to remove the below variables.
	mouse_hover : bool,
	editor_e : bool,
	a : bool,
}

@(cold)
initialize_dynamic_resource :: proc() -> ecs.Entity 
{
	resource_entity := ecs.Entity{}

	if context.user_ptr != nil{
		ctx := cast(^Context) context.user_ptr
		resource_entity = ecs.create_entity(&ctx.world)

		ecs.add_component_unchecked(&ctx.world, resource_entity, container.DynamicResource{sdl2.GetTicks(),0,f32(sdl2.GetTicks())})
	}
	
	return resource_entity
}

@(cold)
init :: proc(game_cfg : container.GameConfig) -> Context{
	ctx := Context{}

	if err := sdl2.Init(game_cfg.game_flags); err != 0{
		log.error(sdl2.GetError())
	}

	img_res := sdl2_img.Init(game_cfg.img_flags)

	if img_res != game_cfg.img_flags{
		log.errorf("sdl image init return %v", img_res)
	}

	sdl2.ClearError()

	width := i32(game_cfg.grid.x * game_cfg.grid.z) + 1
	height := i32(game_cfg.grid.y * game_cfg.grid.z) + 1

	window_pos_x :c.int= sdl2.WINDOWPOS_CENTERED
	window_pos_y :c.int= sdl2.WINDOWPOS_CENTERED

	if game_cfg.center.x >= 0{
		window_pos_x = game_cfg.center.x
	}

	if game_cfg.center.y >= 0{
		window_pos_y = game_cfg.center.y
	}

	ctx.window = sdl2.CreateWindow(game_cfg.title, window_pos_x, window_pos_y, width,height, game_cfg.window_flags) 
	ctx.pixel_format = sdl2.GetWindowSurface(ctx.window).format
	
	ctx.renderer = sdl2.CreateRenderer(ctx.window,-1, game_cfg.render_flags)
	
	#no_bounds_check{
		if err := sdl2.SetRenderDrawColor(ctx.renderer, game_cfg.clear_color[0], game_cfg.clear_color[1], game_cfg.clear_color[2], game_cfg.clear_color[3]); err != 0 {
			log.error(sdl2.GetError())
		}
	}

	ctx.clear_color = game_cfg.clear_color

	cursor_pos := mathematics.Vec4i{
		(game_cfg.grid.x - 1) / 2 * game_cfg.grid.z,
		(game_cfg.grid.y - 1) / 2 * game_cfg.grid.z,
		game_cfg.grid.z,
		game_cfg.grid.z,
	}

	ctx.editor = editor.Context{
		cursor_pos,
		game_cfg.grid,
		{55,55,55,255},
		{55,55,55,255},
	}

	ctx.editor_e = true

	return ctx;
}

handle_event ::proc() -> bool{
	ctx := cast(^Context)context.user_ptr

	player_entity := ecs.get_entities_with_components(&ctx.world, {container.GameEntity, container.Player}) // there should only be one playable player.
	game_component := ecs.get_component_unchecked(&ctx.world, player_entity[0], container.GameEntity)
	animation_component := ecs.get_component_unchecked(&ctx.world, player_entity[0], container.Animation_Tree)

	keyboard_snapshot := sdl2.GetKeyboardState(nil)
	sdl_event : sdl2.Event;

	current_time := sdl2.GetTicks()

	running := true;

	for sdl2.PollEvent(&sdl_event){
		running = sdl_event.type != sdl2.EventType.QUIT
	
		#partial switch sdl_event.type{
			case sdl2.EventType.MOUSEMOTION:
				ctx.editor.cursor_position = mathematics.Vec4i{
					(sdl_event.motion.x / ctx.editor.grid_dimension.z) * ctx.editor.grid_dimension.z,
					(sdl_event.motion.y / ctx.editor.grid_dimension.z) * ctx.editor.grid_dimension.z,
					ctx.editor.grid_dimension.z,
					ctx.editor.grid_dimension.z }
			case sdl2.EventType.WINDOWEVENT:
				if sdl_event.window.event  == sdl2.WindowEventID.ENTER{
					ctx.mouse_hover = true
				} else if sdl_event.window.event == sdl2.WindowEventID.LEAVE{
					ctx.mouse_hover = false
				}
		}
	}

	jumping := keyboard_snapshot[sdl2.Scancode.SPACE]
	left := keyboard_snapshot[sdl2.Scancode.A] | keyboard_snapshot[sdl2.Scancode.LEFT]
	right := keyboard_snapshot[sdl2.Scancode.D] | keyboard_snapshot[sdl2.Scancode.RIGHT]
	roll := keyboard_snapshot[sdl2.Scancode.C]

	editor_mode := keyboard_snapshot[sdl2.Scancode.ESCAPE]
	if editor_mode == 1 && ctx.a{
		ctx.editor_e = !ctx.editor_e
		ctx.a = false
	}else if editor_mode != 1{
		ctx.a = true
	}

	if game_component.actions <= {container.Action.Idle, container.Action.Walking} && jumping >= 1 && container.Action.Roll not_in game_component.actions {
		game_component.actions = {container.Action.Jumping}

	}else if game_component.actions <= {container.Action.Idle, container.Action.Walking}&& container.Action.Roll not_in game_component.actions {
		combined_left_right := int(left | right)

		game_component.animation_index = combined_left_right
		game_component.actions = {container.Action(linalg.abs(combined_left_right))}
		
		if combined_left_right != 0{
			game_component.direction = sdl2.RendererFlip(left > right)
		}
	}
	
	if roll >= 1 && container.Action.Idle not_in game_component.actions{
			//TODO: khal we need to add a timer to constraint have a cooldown.
		if game_component.animation_timer <= 0{
			animation_component.previous_frame = 0
			game_component.actions = {container.Action.Roll}
			game_component.animation_index = 4
			game_component.animation_timer = 200
		}
	}

	game_component.animation_timer = linalg.clamp(game_component.animation_timer -1,0, 200);

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
		direction_map := f32(game_component.direction) * -1.0
		direction_map += 0.5
		direction := direction_map * 2.0

		acceleration_direction := mathematics.Vec2{physics_component.acceleration.x * direction, physics_component.acceleration.y}
				
		grounded :f32= 0.0;

		// TODO: Khal we are doing a intersection check we need a ground check not a check on all side of the rect.
		// if velocity is zero then acceleration must also be zero, since acceleration is velocity with respect of time
		if sdl2.HasIntersection(&sdl2.Rect{i32(position_component.value.x), i32(position_component.value.y), 5, 100}, &sdl2.Rect{0,612,1000,36}){
			grounded = 1.0
			physics_component.velocity.y = 0
			physics_component.acceleration.y = 0
		}else{
			fall := int(physics_component.velocity.y > 0)
			jump := int(physics_component.velocity.y < 0)
			// TODO: khal magic number here...
			physics_component.acceleration.y = (3000 * f32(fall)) + (1000 * f32(jump))
		}
		if container.Action.Jumping in game_component.actions{
			// TODO: khal magic number here...
			physics.add_force(physics_component, mathematics.Vec2{0, -21000 * grounded})
		}

		result_acceleration := (acceleration_direction + physics_component.accumulated_force) * physics_component.inverse_mass

		physics_component.velocity += result_acceleration * resource.delta_time
		physics_component.velocity *= linalg.pow(physics_component.damping, resource.delta_time)


		if container.Action.Roll in game_component.actions{
			physics_component.velocity.x = physics_component.velocity.x * 1.05
		}

		// TODO : khal do this instead of check if idle in the update loop
		//physics_component.velocity.x := physics_component.velocity.x * input_direction

		physics_component.accumulated_force = mathematics.Vec2{0,0}
	}
}

on_update :: proc(){
	ctx := cast(^Context)context.user_ptr
	resource_entity := ecs.Entity(context.user_index)
	resource := ecs.get_component_unchecked(&ctx.world, resource_entity, container.DynamicResource)
	
	game_entities := ecs.get_entities_with_components(&ctx.world, {container.Position, container.GameEntity, container.Physics})
	
	for entity in game_entities{
		current_translation := ecs.get_component_unchecked(&ctx.world, entity, container.Position)
		game_entity := ecs.get_component_unchecked(&ctx.world, entity, container.GameEntity)
		physics_component := ecs.get_component_unchecked(&ctx.world, entity, container.Physics)
		
		if physics_component.velocity.y > 0{
			//fall
			game_entity.actions = {container.Action.Falling}
			game_entity.animation_index = 3
		}else if physics_component.velocity.y < 0{
			// jump
			game_entity.actions = {container.Action.Jumping}
			game_entity.animation_index = 2
		}else{
			if game_entity.actions & {container.Action.Idle, container.Action.Walking, container.Action.Roll} == {}{
				game_entity.actions = {container.Action.Idle}
				game_entity.animation_index = 0
			}
		}

		if container.Action.Idle in game_entity.actions{
			physics_component.velocity.x = 0
		}else{
			current_translation.value.x += physics_component.velocity.x * resource.delta_time + physics_component.acceleration.x * resource.delta_time * resource.delta_time * 0.5
		}

		current_translation.value.y += physics_component.velocity.y * resource.delta_time + physics_component.acceleration.y * resource.delta_time * resource.delta_time * 0.5
	}
}

update_animation :: proc(){
	ctx := cast(^Context) context.user_ptr

	game_entites := ecs.get_entities_with_components(&ctx.world, {container.Animation_Tree, container.GameEntity})

	for entity in game_entites{
		game_entity := ecs.get_component_unchecked(&ctx.world,entity, container.GameEntity)
		animation_tree := ecs.get_component_unchecked(&ctx.world, entity, container.Animation_Tree)
		current_time := f32(sdl2.GetTicks())
		
		delta_time := (current_time - game_entity.animation_time) * 0.001
		frame_to_update := linalg.floor(delta_time * animation_tree.animation_fps)
	
		if(frame_to_update > 0){
			animation_tree.previous_frame += int(frame_to_update)
			animation_tree.previous_frame %= len(animation_tree.animations[game_entity.animation_index].value) 
			game_entity.animation_time = current_time
		}
	}

	//TODO: khal we want to confine this to the player only, enemy/npc will follow a different dodge animation.
	for entity in game_entites{
		game_entity := ecs.get_component_unchecked(&ctx.world,entity, container.GameEntity)
		animation_tree := ecs.get_component_unchecked(&ctx.world, entity, container.Animation_Tree)

		if game_entity.animation_index == 4{
			if animation_tree.previous_frame == len(animation_tree.animations[game_entity.animation_index].value) -1{
				game_entity.animation_index = 0
				game_entity.actions = {container.Action.Idle}
				animation_tree.previous_frame = 0
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
			ctx.clear_color.a,
		)

		if ctx.editor_e{
			sdl2.RenderClear(ctx.renderer)
	
			sdl2.SetRenderDrawColor(ctx.renderer,
				ctx.editor.line_clear_color.r,
				ctx.editor.line_clear_color.g,
				ctx.editor.line_clear_color.b,
				ctx.editor.line_clear_color.a,
			)
	
			for x :i32= 0; x < ctx.editor.grid_dimension.x * ctx.editor.grid_dimension.z ; x+=ctx.editor.grid_dimension.z {
				sdl2.RenderDrawLine(ctx.renderer,x,0,x, i32(ctx.editor.grid_dimension.y * ctx.editor.grid_dimension.z) + 1)
			}
	
			for y :i32=0 ; y < ctx.editor.grid_dimension.y * ctx.editor.grid_dimension.z ; y+=ctx.editor.grid_dimension.z {
				sdl2.RenderDrawLine(ctx.renderer,0, y,i32(ctx.editor.grid_dimension.x * ctx.editor.grid_dimension.z) + 1, y)
			}
	
			sdl2.SetRenderDrawColor(ctx.renderer,
				ctx.editor.cursor_clear_color.r,
				ctx.editor.cursor_clear_color.g,
				ctx.editor.cursor_clear_color.z,
				ctx.editor.cursor_clear_color.w,
			)
	
			if ctx.mouse_hover{
				//TODO: khal add blinking
					cursor_rect := sdl2.Rect{
						ctx.editor.cursor_position.x,
						ctx.editor.cursor_position.y,
						ctx.editor.cursor_position.z,
						ctx.editor.cursor_position.w,
					}
					
					sdl2.RenderFillRect(ctx.renderer, &cursor_rect)
				}
	
		}
	
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
	
			if animation_tree != nil && game_entity != nil{
				max_frame_len := len(animation_tree.animations[game_entity.animation_index].value) - 1
				capped_frame := linalg.clamp(animation_tree.previous_frame, 0, max_frame_len)
	
				src_res^ = animation_tree.animations[game_entity.animation_index].value[capped_frame]
			}else{
				src_res = nil
			}
	
			sdl2.RenderCopyExF(ctx.renderer, texture_component.texture,src_res, &dst_rec, angle, nil, game_entity.direction)
		}
	}


	sdl2.RenderPresent(ctx.renderer)

	// Rendering
}

@(cold)
cleanup :: proc(){
	ctx := cast(^Context) context.user_ptr

	sdl2.DestroyRenderer(ctx.renderer)
	sdl2.DestroyWindow(ctx.window)
	sdl2.Quit()

	ecs.deinit_ecs(&ctx.world)

}

