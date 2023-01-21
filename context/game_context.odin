package game_context
import "core:log"
import "vendor:sdl2"
import sdl2_img "vendor:sdl2/image"

Context :: struct{
	window : ^sdl2.Window,
	renderer : ^sdl2.Renderer,
	textures : [dynamic]^sdl2.Texture,
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
		log.errorf("sdl image init reuturn %v", img_res)
	}

	// should I make it full screen by default? add  .FULLSCREEN to Flag
	ctx.window = sdl2.CreateWindow("game", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, 800, 500, sdl2.WindowFlags{ .SHOWN}) 
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
	for texture in ctx.textures {
		sdl2.RenderCopy(ctx.renderer, texture, nil, nil)
	}

	sdl2.RenderPresent(ctx.renderer)
}

@(cold)
cleanup :: proc(){
	ctx := cast(^Context) context.user_ptr

	sdl2.DestroyRenderer(ctx.renderer)
	sdl2.DestroyWindow(ctx.window)
	delete(ctx.textures)
	sdl2.Quit()

}

