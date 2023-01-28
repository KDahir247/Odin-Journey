package utility

import "../ecs"
import "../mathematics"
import game "../context"
import "../container"

import "core:strings"
import "core:fmt"

import "vendor:sdl2"
import sdl2_img "vendor:sdl2/image"

ANIM_FPS :: 15
load_animation_texture :: proc(path : string,anim_configs : [dynamic]container.AnimationConfig) -> ecs.Entity{

	ctx := cast(^game.Context) context.user_ptr
    texture_entity := ecs.create_entity(&ctx.world)

    animations := make([dynamic]container.Animation, len(anim_configs))

    path := strings.clone_to_cstring(path, context.temp_allocator)
    
    surface := sdl2_img.Load(path)
    optimal_surface := sdl2.ConvertSurface(surface, ctx.pixel_format, 0)

    key := sdl2.MapRGB(optimal_surface.format, 0,0,0)
    sdl2.SetColorKey(optimal_surface, 1, key)

    texture := sdl2.CreateTextureFromSurface(ctx.renderer, optimal_surface )

    dimension := mathematics.Vec2{ cast(f32)optimal_surface.w, cast(f32)optimal_surface.h}

    ecs.add_component(&ctx.world, texture_entity, container.TextureAsset{texture, dimension})

    sdl2.FreeSurface(surface)

    for config, anim_config_index in anim_configs{
        for current_slice_index in 0..<config.slices {
            anim_rect := sdl2.Rect{i32(current_slice_index) * i32(config.width), i32(config.index) * i32(config.height), i32(config.width), i32(config.height) }
            append_elem(&animations[anim_config_index].value, anim_rect)
        }
    }

    ecs.add_component(&ctx.world, texture_entity, container.Animation_Tree{0, ANIM_FPS, animations})

    return texture_entity;
}