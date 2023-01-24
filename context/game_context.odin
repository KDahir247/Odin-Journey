package game_context

import  "../ecs"
import "../container"
import "../math"

import "core:fmt"
import "core:log"

import "vendor:sdl2"
import sdl2_img "vendor:sdl2/image"
// Solution till i incorperate ecs 


Context :: struct{
	window : ^sdl2.Window,
	renderer : ^sdl2.Renderer,
	world : ecs.Context,
	pixel_format : ^sdl2.PixelFormat,
}

@(cold)
initialize_dynamic_resource :: proc() -> ecs.Entity  {
	resource_entity := ecs.Entity{}

	if context.user_ptr == nil{
		log.error("Context hasn't been initialized and set to the user pointer call init and assign user pointer")
	}else{
		ctx := cast(^Context) context.user_ptr
		resource_entity = ecs.create_entity(&ctx.world)

		ecs.add_component(&ctx.world, resource_entity, container.DynamicResource{sdl2.GetTicks(),0,0})
	}
	
	return resource_entity
}

@(cold)
init :: proc() -> Maybe(Context){
	ctx := Context{}

	if err := sdl2.Init(sdl2.InitFlags{ .VIDEO}); err != 0{
		log.error(sdl2.GetError())
	}

	img_init_flag := sdl2_img.INIT_PNG;
	img_res := sdl2_img.InitFlags(sdl2_img.Init(img_init_flag))

	if img_init_flag != img_res{
		log.errorf("sdl image init return %v", img_res)
	}

	sdl2.ClearError()

	ctx.window = sdl2.CreateWindow("game", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, 800, 500, sdl2.WindowFlags{ .SHOWN}) 
	ctx.renderer = sdl2.CreateRenderer(ctx.window,-1, sdl2.RendererFlags{.ACCELERATED, .PRESENTVSYNC, .TARGETTEXTURE})
	ctx.pixel_format = sdl2.GetWindowSurface(ctx.window).format
	
	if err := sdl2.SetRenderDrawColor(ctx.renderer, 255, 255, 255, 255); err != 0 {
		log.error(sdl2.GetError())
	}

	return ctx;
}

handle_event ::proc() -> bool{
	sdl_event : sdl2.Event;

	running := true;
	for sdl2.PollEvent(&sdl_event){
		if sdl_event.type == sdl2.EventType.QUIT{
			running = false;
		}
	}

	return running;
}

on_fixed_update :: proc(){
	ctx := cast(^Context) context.user_ptr
	resource_entity := cast(ecs.Entity)context.user_index
	resource, _:= ecs.get_component(&ctx.world, resource_entity, container.DynamicResource)
	
	current_time := sdl2.GetTicks()

	delta_time := cast(f32)(current_time - resource.elapsed_physic_time) * 0.001

	//Physics Loop

	ecs.set_component(&ctx.world, resource_entity,container.DynamicResource{resource.elapsed_time, delta_time, current_time} )
}

on_update :: proc(){
	ctx := cast(^Context) context.user_ptr

	keyboard_snapshot := sdl2.GetKeyboardState(nil)
	
	entites := ecs.get_entities_with_components(&ctx.world, {container.Position})

	for entity in entites{
		current_translation, _ := ecs.get_component(&ctx.world, entity, container.Position)

		#no_bounds_check{
			
			//todo khal : movement for player will be retrieve from a config file.
			left := cast(f32)(keyboard_snapshot[sdl2.Scancode.A] | keyboard_snapshot[sdl2.Scancode.LEFT]) * -1;
			down := cast(f32)(keyboard_snapshot[sdl2.Scancode.S] | keyboard_snapshot[sdl2.Scancode.DOWN]);
			right := cast(f32)(keyboard_snapshot[sdl2.Scancode.D] | keyboard_snapshot[sdl2.Scancode.RIGHT])
			up := cast(f32)(keyboard_snapshot[sdl2.Scancode.W] | keyboard_snapshot[sdl2.Scancode.UP]) * -1
		
			target_vertical := up + down
			target_horizontal := left + right

			desired_translation := container.Position{math.Vec2{current_translation.value.x + target_horizontal, current_translation.value.y + target_vertical}}
			ecs.set_component(&ctx.world, entity, desired_translation)
		}
	}

	// Logic
}

update_animation :: proc(){
	// Animation
}

on_late_update :: proc(){


	// Camera and other
}



on_render :: proc(){
	ctx := cast(^Context) context.user_ptr
	
	sdl2.RenderClear(ctx.renderer)

	texture_assets,e := ecs.get_component_list(&ctx.world, container.TextureAsset)

	tex_entities:= ecs.get_entities_with_components(&ctx.world, {container.TextureAsset})

	for entity in tex_entities{
		texture_component, _ := ecs.get_component(&ctx.world, entity, container.TextureAsset)

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

