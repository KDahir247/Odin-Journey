package utility

import "../ecs"
import "../mathematics"
import game "../context"
import "../container"

import "core:strings"

import "vendor:sdl2"
import sdl2_img "vendor:sdl2/image"



// load a single sprite
load_texture :: proc(path : string) -> ecs.Entity{

	ctx := cast(^game.Context) context.user_ptr

    path := strings.clone_to_cstring(path, context.temp_allocator)
    
    surface := sdl2_img.Load(path)
    optimal_surface := sdl2.ConvertSurface(surface, ctx.pixel_format, 0)

    key := sdl2.MapRGB(optimal_surface.format, 0,0,0)
    sdl2.SetColorKey(optimal_surface, 1, key)

    texture := sdl2.CreateTextureFromSurface(ctx.renderer, optimal_surface )

    dimension := mathematics.Vec2{ cast(f32)optimal_surface.w, cast(f32)optimal_surface.h}
    
    texture_entity := ecs.create_entity(&ctx.world)

    ecs.add_component(&ctx.world, texture_entity, container.TextureAsset{texture, dimension})
    
    sdl2.FreeSurface(surface)

    return texture_entity;
}

// load a sprite sheet
load_animated_texture :: proc(){

}