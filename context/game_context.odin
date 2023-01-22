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

// Initializes 
@(cold)
init :: proc() -> Maybe(Context){
	ctx := Context{}

	//handle case where it fails...
	sdl_res := sdl2.Init(sdl2.InitFlags{ .VIDEO})

	// sdl image maybe?
	img_init_flag := sdl2_img.INIT_PNG;
	img_res := sdl2_img.InitFlags(sdl2_img.Init(img_init_flag))

	if img_init_flag != img_res{
		log.errorf("sdl image init return %v", img_res)
	}

	// should I make it full screen by default? add  .FULLSCREEN to Flag
	ctx.window = sdl2.CreateWindow("game", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, 800, 500, sdl2.WindowFlags{ .SHOWN}) 
	
	// limit framerate to whatever the video card since we are using PRESENTVSYNC flag.
	// fps cap is only necessary if you want a unformaity fps regardless of video card Hz 
	ctx.renderer = sdl2.CreateRenderer(ctx.window,-1, sdl2.RendererFlags{.ACCELERATED, .PRESENTVSYNC, .TARGETTEXTURE})

	ctx.pixel_format = sdl2.GetWindowSurface(ctx.window).format
	
	sdl2.SetRenderDrawColor(ctx.renderer, 255, 255, 255, 255)

	return ctx;
}

handle_event ::proc() -> bool{

	sdl_event : sdl2.Event;

	running := true;
	// todo khal add the required event handling.
	for sdl2.PollEvent(&sdl_event){
		if sdl_event.type == sdl2.EventType.QUIT{
			running = false;
		}

		keyboard_snapshot := sdl2.GetKeyboardState(nil)

	}

	
	return running;
}

on_fixed_update :: proc(){
	//Physics
}

on_update :: proc(){
	ctx := cast(^Context) context.user_ptr

	keyboard_snapshot := sdl2.GetKeyboardState(nil)
	
	entites := ecs.get_entities_with_components(&ctx.world, {container.Position})

	for entity in entites{

		//todo : khal no event handling here and solution look like a hacky way [-.-`]

		// We don't need to check since we are querying above
		current_translation, _ := ecs.get_component(&ctx.world, entity, container.Position)

		// remap negative input. rather then 0 or 1 we remap it to 0 or -1
		left := cast(f32)keyboard_snapshot[sdl2.Scancode.A] * -1;
		down := cast(f32)keyboard_snapshot[sdl2.Scancode.S];
	
		right := cast(f32)keyboard_snapshot[sdl2.Scancode.D]
		up := cast(f32)keyboard_snapshot[sdl2.Scancode.W] * -1
		
		target_vertical := up + down
		target_horizontal := left + right
		//keystate[SDLK_RETURN]

		desired_translation := container.Position{math.Vec2{current_translation.value.x + target_horizontal, current_translation.value.y + target_vertical}}
		ecs.set_component(&ctx.world, entity, desired_translation)


	}

	// Logic
}

on_render :: proc(){
	ctx := cast(^Context) context.user_ptr
	
	sdl2.RenderClear(ctx.renderer)

	// Render Function goes here.
	texture_assets,e := ecs.get_component_list(&ctx.world, container.TextureAsset)

	tex_entities:= ecs.get_entities_with_components(&ctx.world, {container.TextureAsset})

	for entity in tex_entities{
		texture_component, _ := ecs.get_component(&ctx.world, entity, container.TextureAsset)

		position := ecs.get_component(&ctx.world, entity, container.Position) or_else nil
		rotation := ecs.get_component(&ctx.world,entity, container.Rotation) or_else nil;

		x : f32= 0
		y : f32= 0

		angle : f64 = 0

		if position != nil{
			x = position.value.x
			y = position.value.y
		}


		if rotation != nil{
			angle = rotation.value 
		}



		dst_rec := sdl2.FRect{x, y, texture_component.dimension.x, texture_component.dimension.y}

		sdl2.RenderCopyExF(ctx.renderer, texture_component.texture,nil, &dst_rec,angle,nil, sdl2.RendererFlip.NONE)
	}

	for tex in texture_assets{
		
	}

	
	sdl2.RenderPresent(ctx.renderer)
}

@(cold)
cleanup :: proc(){
	ctx := cast(^Context) context.user_ptr

	sdl2.DestroyRenderer(ctx.renderer)
	sdl2.DestroyWindow(ctx.window)
	sdl2.Quit()

	ecs.deinit_ecs(&ctx.world)

}

