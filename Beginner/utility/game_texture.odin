package utility

import "vendor:sdl2"
import "core:strings"
import sdl2_img "vendor:sdl2/image"
import game "../context"

// load a single sprite
load_texture :: proc(path : string){

	ctx := cast(^game.Context) context.user_ptr

    path := strings.clone_to_cstring(path, context.temp_allocator)
    surface := sdl2_img.Load(path)

    optimal_surface := sdl2.ConvertSurface(surface, ctx.pixel_format, 0)

    texture := sdl2.CreateTextureFromSurface(ctx.renderer, optimal_surface )

    //store it some where
    append(&ctx.textures, texture)

    sdl2.FreeSurface(surface)
}

// load a sprite sheet
load_animated_texture :: proc(){

}