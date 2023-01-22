package game_context

import  "../ecs"

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
	ctx.renderer = sdl2.CreateRenderer(ctx.window,-1, sdl2.RendererFlags{.ACCELERATED, .PRESENTVSYNC})
	
	ctx.pixel_format = sdl2.GetWindowSurface(ctx.window).format
	
	sdl2.SetRenderDrawColor(ctx.renderer, 255, 255, 255, 255)

	return ctx;
}

handle_event ::proc() -> bool{

	sdl_event : sdl2.Event;

	running := true;
	// todo khal add the required event handling.
	for sdl2.PollEvent(&sdl_event){
		#partial switch sdl_event.type{
		case .QUIT:
			running = false;
		}
	}

	
	return running;
}

on_fixed_update :: proc(){
	//Physics
}

on_update :: proc(){
	// Logic
}

on_render :: proc(){
	ctx := cast(^Context) context.user_ptr
	
	sdl2.RenderClear(ctx.renderer)

	// Render Function goes here.

	for entity  in ctx.world.component_map[TextureAsset].entity_indices{

		texture_components :=  cast(^[dynamic]TextureAsset)ctx.world.component_map[TextureAsset].data;

		texture_asset := texture_components[entity]

		dst_rec := sdl2.Rect{0, 0, texture_asset.dimension.x, texture_asset.dimension.y}

		sdl2.RenderCopy(ctx.renderer, texture_asset.texture, nil, &dst_rec)
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

