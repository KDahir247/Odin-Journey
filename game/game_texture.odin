package game

import "../ecs"
import "../mathematics"
import ctx "../context"
import "../container"

import "core:strings"

import "vendor:sdl2"
import "vendor:sdl2/image"

create_animation_texture_entity :: proc($path : string, anim_configs : [$E]container.AnimationConfig) -> ecs.Entity{
	ctx := cast(^ctx.Context) context.user_ptr
    texture_entity := ecs.create_entity(&ctx.world)

    animations := make_dynamic_array_len([dynamic]container.Animation,E)

    cpath := strings.clone_to_cstring(path)
    defer delete(cpath)

    surface := image.Load(cpath)
    optimal_surface := sdl2.ConvertSurface(surface, ctx.pixel_format, 0)

    key := sdl2.MapRGB(optimal_surface.format, 0,0,0)
    sdl2.SetColorKey(optimal_surface, 1, key)

    texture := sdl2.CreateTextureFromSurface(ctx.renderer, optimal_surface )

    dimension := mathematics.Vec2{ cast(f32)optimal_surface.w, cast(f32)optimal_surface.h}

    ecs.add_component(&ctx.world, texture_entity, container.TextureAsset{texture, dimension})

    sdl2.FreeSurface(surface)

    #no_bounds_check{
        for current_animation_index in 0..<E{
            current_animation_config := anim_configs[current_animation_index]
            for current_slice_index in 0..<current_animation_config.slices{
                
                x := current_slice_index * current_animation_config.width
                y := current_animation_config.index * current_animation_config.height

                anim_rect := sdl2.Rect{x, y, current_animation_config.width, current_animation_config.height }
                
                animations[current_animation_index].animation_speed = current_animation_config.animation_speed
                append(&animations[current_animation_index].value, anim_rect)
            }
        }
    }

    ecs.add_component(&ctx.world, texture_entity, container.Animation_Tree{0,  animations})

    return texture_entity;
}

free_all_animation_entities :: proc(){
    ctx := cast(^ctx.Context) context.user_ptr

    animation_trees,_ := ecs.get_component_list(&ctx.world, container.Animation_Tree)
    tex_assets, _ := ecs.get_component_list(&ctx.world, container.TextureAsset)

    for tree in animation_trees{
        for animation in tree.animations{
            delete(animation.value)
        }

        delete(tree.animations)
    }

    for tex in tex_assets{
        sdl2.DestroyTexture(tex.texture)
    }
}


