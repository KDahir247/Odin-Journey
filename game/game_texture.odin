package game

import "../ecs"
import "../mathematics"
import ctx "../context"
import "../container"

import "vendor:sdl2"
import "vendor:sdl2/image"

create_texture_entity :: proc(path : cstring) -> ecs.Entity{
	ctx := cast(^ctx.Context) context.user_ptr

    surface := image.Load(path)
    optimal_surface := sdl2.ConvertSurface(surface, ctx.pixel_format, 0)

    key := sdl2.MapRGB(optimal_surface.format, 0,0,0)
    sdl2.SetColorKey(optimal_surface, 1, key)

    texture_entity := ecs.create_entity(ctx.world)

    texture := sdl2.CreateTextureFromSurface(ctx.renderer, optimal_surface )
    dimension := mathematics.Vec2{f32(optimal_surface.w), f32(optimal_surface.h)}

    ecs.add_component(ctx.world, texture_entity, container.TextureAsset{texture, dimension})

    sdl2.FreeSurface(surface)

    return texture_entity
}

free_all_texture_entities :: proc(){
    ctx := cast(^ctx.Context) context.user_ptr

    tex_assets := ecs.get_component_list(ctx.world, container.TextureAsset)

    for tex in tex_assets{
        sdl2.DestroyTexture(tex.texture)
    }
}


