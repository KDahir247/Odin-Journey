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

		ecs.add_component_unchecked(&ctx.world, resource_entity, container.DynamicResource{sdl2.GetTicks(),0,0,0})
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
	
	if err := sdl2.SetRenderDrawColor(ctx.renderer, 255, 255, 255, 255); err != 0 {
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

	//Physics Loop

	ecs.set_component_unchecked(&ctx.world, resource_entity,container.DynamicResource{resource.elapsed_time, delta_time, current_time,resource.animation_time } )
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
			down := f32(keyboard_snapshot[sdl2.Scancode.S] | keyboard_snapshot[sdl2.Scancode.DOWN]);
			right := f32(keyboard_snapshot[sdl2.Scancode.D] | keyboard_snapshot[sdl2.Scancode.RIGHT])
			up := f32(keyboard_snapshot[sdl2.Scancode.W] | keyboard_snapshot[sdl2.Scancode.UP]) * -1
		
			target_vertical := up + down + current_translation.value.y
			target_horizontal := left + right + current_translation.value.x

			desired_translation := container.Position{mathematics.Vec2{target_horizontal, target_vertical}}
			ecs.set_component_unchecked(&ctx.world, entity, desired_translation)
		}
	}

	// Logic
}

update_animation :: proc(){
	ctx := cast(^Context) context.user_ptr
	resource_entity := ecs.Entity(context.user_index)
	dynamic_resource := ecs.get_component_unchecked(&ctx.world, resource_entity, container.DynamicResource)

	animation_entities := ecs.get_entities_with_components(&ctx.world, {container.Animation})

	for entity in animation_entities{
		
		animation := ecs.get_component_unchecked(&ctx.world, entity, container.Animation)

		current_time := f32(sdl2.GetTicks())
		
		delta_time := (current_time - dynamic_resource.animation_time) * 0.001

		//TODO: khal the 60 is a magic number remove magic number
		frame_to_update := math.floor(delta_time / (1 / 60))
		
		if(frame_to_update > 0){
			animation.previous_frame += cast(u32)frame_to_update
			//TODO: khal animation sprite size is hardcoded.
			animation.previous_frame %= 5
			dynamic_resource.animation_time = current_time
		}
}

	// Animation
}

on_late_update :: proc(){


	// Camera and other
}


on_render :: proc(){
	ctx := cast(^Context) context.user_ptr
	
	sdl2.RenderClear(ctx.renderer)

	tex_entities:= ecs.get_entities_with_components(&ctx.world, {container.TextureAsset})

	for entity in tex_entities{
		texture_component := ecs.get_component_unchecked(&ctx.world, entity, container.TextureAsset)

		position := ecs.get_component(&ctx.world, entity, container.Position) or_else nil
		rotation := ecs.get_component(&ctx.world,entity, container.Rotation) or_else nil
		scale := ecs.get_component(&ctx.world, entity, container.Scale) or_else nil

		x : f32= 0
		y : f32= 0

		angle : f64 = 0

		scale_x : f32= 1
		scale_y : f32= 1

		if position != nil{
			x = position.value.x
			y = position.value.y
		}


		if rotation != nil{
			angle = rotation.value 
		}

		if scale != nil{
			scale_x = scale.value.x
			scale_y = scale.value.y
		}

		target_dimension_x := texture_component.dimension.x * scale_x
		target_dimension_y := texture_component.dimension.y * scale_y

		dst_rec := sdl2.FRect{x, y, target_dimension_x, target_dimension_y}

		sdl2.RenderCopyExF(ctx.renderer, texture_component.texture,nil, &dst_rec,angle,nil, sdl2.RendererFlip.NONE)
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

