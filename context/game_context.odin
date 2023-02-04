package game_context

import "../physics"
import  "../ecs"
import "../container"
import "../mathematics"

import  "core:math/linalg"
import "core:fmt"
import "core:log"

import "vendor:sdl2"
import sdl2_img "vendor:sdl2/image"


Context :: struct{
	window : ^sdl2.Window,
	renderer : ^sdl2.Renderer,
	world : ecs.Context,
	pixel_format : ^sdl2.PixelFormat,
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
init :: proc() -> Context{
	ctx := Context{}

	if err := sdl2.Init(sdl2.InitFlags{ .VIDEO}); err != 0{
		log.error(sdl2.GetError())
	}

	img_res := sdl2_img.Init(sdl2_img.INIT_PNG)

	if img_res != sdl2_img.INIT_PNG{
		log.errorf("sdl image init return %v", img_res)
	}

	sdl2.ClearError()

	ctx.window = sdl2.CreateWindow("game", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, 800, 500, sdl2.WindowFlags{ .SHOWN}) 
	ctx.pixel_format = sdl2.GetWindowSurface(ctx.window).format
	
	ctx.renderer = sdl2.CreateRenderer(ctx.window,-1, sdl2.RendererFlags{.ACCELERATED, .PRESENTVSYNC, .TARGETTEXTURE})
	
	if err := sdl2.SetRenderDrawColor(ctx.renderer, 45, 45, 45, 45); err != 0 {
		log.error(sdl2.GetError())
	}

	return ctx;
}

handle_event ::proc() -> bool{
	ctx := cast(^Context)context.user_ptr

	player_entity := ecs.get_entities_with_components(&ctx.world, {container.GameEntity, container.Player}) // there should only be one playable player.
	game_component := ecs.get_component_unchecked(&ctx.world, player_entity[0], container.GameEntity)

	keyboard_snapshot := sdl2.GetKeyboardState(nil)
	sdl_event : sdl2.Event;

	current_time := sdl2.GetTicks()

	running := true;

	for sdl2.PollEvent(&sdl_event){
		running = sdl_event.type != sdl2.EventType.QUIT
	
		if sdl_event.type == sdl2.EventType.MOUSEBUTTONDOWN{
			game_component.actions = {container.Action.Attacking}
			
			if current_time - game_component.animation_timer < 300{
				fmt.println("combo attack")

			}else{
				fmt.println("attack")
			}

			game_component.animation_timer = sdl2.GetTicks();

			//game_param.animation_index = 3
			// atack
		}
	}

	jumping := keyboard_snapshot[sdl2.Scancode.SPACE]

	if jumping == 1 && (container.Action.Idle in game_component.actions || container.Action.Walking in game_component.actions){
		
		game_component.actions = {container.Action.Jumping}

	}else if game_component.actions == {container.Action.Idle} || game_component.actions == {container.Action.Walking}{
		
		left := keyboard_snapshot[sdl2.Scancode.A] | keyboard_snapshot[sdl2.Scancode.LEFT]
		right := keyboard_snapshot[sdl2.Scancode.D] | keyboard_snapshot[sdl2.Scancode.RIGHT]
		
		combined_left_right := int(left | right)

		game_component.animation_index = combined_left_right

		game_component.actions =  {container.Action(linalg.abs(combined_left_right))}
		
		if combined_left_right != 0{
			game_component.direction = sdl2.RendererFlip(left > right)
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

	delta_time := (resource.current_physics_time - previous_physics_time) * 0.001
	resource.delta_time = delta_time

	physics_entities := ecs.get_entities_with_components(&ctx.world, {container.GameEntity, container.Physics, container.Position})

	for entity in physics_entities{

		physics_component := ecs.get_component_unchecked(&ctx.world, entity, container.Physics)
		game_component := ecs.get_component_unchecked(&ctx.world, entity, container.GameEntity)
		position_component := ecs.get_component_unchecked(&ctx.world, entity, container.Position)

		// remap -1 (left) to 1 (right) depending on the direction
		direction_map := f32(game_component.direction) * -1.0
		direction_map += 0.5
		direction := direction_map * 2.0

		acceleration_direction := mathematics.Vec2{physics_component.acceleration.x * direction, physics_component.acceleration.y}
				
		grounded := false;

		// TODO: Khal we are doing a intersection check we need a ground check not a check on all side of the rect.
		// if velocity is zero then acceleration must also be zero, since acceleration is velocity with respect of time
		if sdl2.HasIntersection(&sdl2.Rect{i32(position_component.value.x), i32(position_component.value.y), 5, 200}, &sdl2.Rect{0,630,1000,200}){
			grounded = true
			physics_component.velocity.y = 0
			physics_component.acceleration.y = 0
		}else{
			// TODO: Khal don't like this -.-
			physics_component.acceleration.y = 1000
		}

		//TODO : Khal working progress on jump hack solution.... need to be fleshed out correctly, but works :P
		if container.Action.Jumping in game_component.actions && grounded{
			physics.add_force(physics_component, mathematics.Vec2{0, -23000})
		}

		result_acceleration := (acceleration_direction + physics_component.accumulated_force) * physics_component.inverse_mass

		physics_component.velocity += result_acceleration * delta_time
		physics_component.velocity *= linalg.pow(physics_component.damping, delta_time)

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
			if container.Action.Idle not_in game_entity.actions && container.Action.Walking not_in game_entity.actions{
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
	// Animation
}

on_late_update :: proc(){


	// Camera and other
}


on_render :: proc(){
	ctx := cast(^Context)context.user_ptr
	sdl2.RenderClear(ctx.renderer)

	texture_entities:= ecs.get_entities_with_components(&ctx.world, {container.TextureAsset, container.Position, container.Rotation, container.Scale})

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

		if animation_tree != nil || game_entity != nil{
			max_frame_len := len(animation_tree.animations[game_entity.animation_index].value) - 1
			capped_frame := linalg.clamp(animation_tree.previous_frame, 0, max_frame_len)

			src_res^ = animation_tree.animations[game_entity.animation_index].value[capped_frame]
		}else{
			src_res = nil
		}

		sdl2.RenderCopyExF(ctx.renderer, texture_component.texture,src_res, &dst_rec, angle, nil, game_entity.direction)
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

