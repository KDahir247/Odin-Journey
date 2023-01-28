package game_context

import  "../ecs"
import "../container"
import "../mathematics"

import  "core:math"
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

		ecs.add_component_unchecked(&ctx.world, resource_entity, container.DynamicResource{sdl2.GetTicks(),0,0,0, 0})
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
	sdl_event : sdl2.Event;

	running := true;

	for sdl2.PollEvent(&sdl_event){
		running = sdl_event.type != sdl2.EventType.QUIT;
	}

	return running;
}

on_fixed_update :: proc(){
	ctx := cast(^Context)context.user_ptr
	
	resource_entity := ecs.Entity(context.user_index)
	resource := ecs.get_component_unchecked(&ctx.world, resource_entity, container.DynamicResource)
	
	current_time := f32(sdl2.GetTicks())

	delta_time := current_time - resource.elapsed_physic_time * 0.001

	//Physics Loop Here

	ecs.set_component_unchecked(&ctx.world, resource_entity,container.DynamicResource{resource.elapsed_time, delta_time, current_time,resource.animation_time, resource.animation_index } )
}

on_update :: proc(){
	ctx := cast(^Context)context.user_ptr

	keyboard_snapshot := sdl2.GetKeyboardState(nil)
	
	entites := ecs.get_entities_with_components(&ctx.world, {container.Position})

	for entity in entites{
		current_translation := ecs.get_component_unchecked(&ctx.world, entity, container.Position)

		#no_bounds_check{
			//TODO: khal : movement for player will be retrieve from a config file. don't like this solution
			left := f32(keyboard_snapshot[sdl2.Scancode.A] | keyboard_snapshot[sdl2.Scancode.LEFT]) * -1;
			//down := f32(keyboard_snapshot[sdl2.Scancode.S] | keyboard_snapshot[sdl2.Scancode.DOWN]);
			right := f32(keyboard_snapshot[sdl2.Scancode.D] | keyboard_snapshot[sdl2.Scancode.RIGHT])
		
			// target_vertical := up + down + current_translation.value.y
			target_horizontal := left + right + current_translation.value.x

			desired_translation := container.Position{mathematics.Vec2{target_horizontal, current_translation.value.y}}
			ecs.set_component_unchecked(&ctx.world, entity, desired_translation)
		}
	}

	// Logic
}

update_animation :: proc(){
	ctx := cast(^Context) context.user_ptr
	resource_entity := ecs.Entity(context.user_index)
	resource := ecs.get_component_unchecked(&ctx.world, resource_entity, container.DynamicResource)

	animation_tree_entites := ecs.get_entities_with_components(&ctx.world, {container.Animation_Tree})

	for tree_entity in animation_tree_entites{
		animation_tree := ecs.get_component_unchecked(&ctx.world, tree_entity, container.Animation_Tree)
		current_time := f32(sdl2.GetTicks())
		
		delta_time := (current_time - resource.animation_time) * 0.001
		frame_to_update := math.floor(delta_time * animation_tree.animation_fps)
	
		if(frame_to_update > 0){
			animation_tree.previous_frame += int(frame_to_update)
			animation_tree.previous_frame %= len(animation_tree.animations[resource.animation_index].value) // this is correct
			resource.animation_time = current_time
		}
	}

	// Animation
}

on_late_update :: proc(){


	// Camera and other
}


on_render :: proc(){
	ctx := cast(^Context)context.user_ptr
	resource_entity := ecs.Entity(context.user_index)
	resource := ecs.get_component_unchecked(&ctx.world, resource_entity, container.DynamicResource)

	sdl2.RenderClear(ctx.renderer)

	texture_entities:= ecs.get_entities_with_components(&ctx.world, {container.TextureAsset})

	for texture_entity in texture_entities{
		texture_component := ecs.get_component_unchecked(&ctx.world, texture_entity, container.TextureAsset)

		animation_tree := ecs.get_component(&ctx.world, texture_entity, container.Animation_Tree) or_else nil
		position := ecs.get_component(&ctx.world, texture_entity, container.Position) or_else nil
		rotation := ecs.get_component(&ctx.world,texture_entity, container.Rotation) or_else nil
		scale := ecs.get_component(&ctx.world, texture_entity, container.Scale) or_else nil

		position_x : f32= 0
		position_y : f32= 0

		angle : f64 = 0

		scale_x : f32= 1
		scale_y : f32= 1

		if position != nil{
			position_x = position.value.x
			position_y = position.value.y
		}


		if rotation != nil{
			angle = rotation.value 
		}

		if scale != nil{
			scale_x = scale.value.x
			scale_y = scale.value.y
		}

		desired_scale_x := texture_component.dimension.x * scale_x
		desired_scale_y := texture_component.dimension.y * scale_y

		dst_rec := sdl2.FRect{position_x, position_y, desired_scale_x, desired_scale_y}
		
		src_res := new(sdl2.Rect)

		if animation_tree != nil{
			src_res^ = animation_tree.animations[resource.animation_index].value[animation_tree.previous_frame]
		}else{
			src_res = nil
		}

		sdl2.RenderCopyExF(ctx.renderer, texture_component.texture,src_res, &dst_rec,angle,nil, sdl2.RendererFlip.NONE)
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

