package game

import "../ecs"
import "../mathematics"
import "../container"
import ctx "../context"

import "vendor:sdl2"

create_game_entity ::proc($path : cstring, animator : uint, translation : [2]f32, rotation:f64, scale: [2]f32, player : bool) -> int{

	ctx := cast(^ctx.Context) context.user_ptr

    game_entity := create_texture_entity(path)
    
    // if context.user_index == int(game_entity) {
    //     ecs.add_component_unchecked(&ctx.world, game_entity, container.Player{{container.CoolDownTimer{3000, 0}, container.CoolDownTimer{3000, 0}} })
    // }

    if player{
        ecs.add_component_unchecked(&ctx.world, game_entity, container.Player{{container.CoolDownTimer{3000, 0}, container.CoolDownTimer{3000, 0}} })
    }

    ecs.add_component_unchecked(&ctx.world, game_entity, container.Position{mathematics.Vec2{translation.x, translation.y}})
    ecs.add_component_unchecked(&ctx.world, game_entity, container.Rotation{rotation})
    ecs.add_component_unchecked(&ctx.world, game_entity, container.Scale{mathematics.Vec2{scale.x, scale.y}})

    collider_component := mathematics.AABB{{translation.x, translation.y}, {39,41}}

    physics_component := container.Physics{collider_component,mathematics.Vec2{translation.x,translation.y}, mathematics.Vec2{0, 0},mathematics.Vec2{0, 9.81},mathematics.Vec2{0,0},0.999, 1, 0.65,0}

    ecs.add_component_unchecked(&ctx.world, game_entity, physics_component)

    ecs.add_component_unchecked(&ctx.world, game_entity, container.GameEntity{0, sdl2.RendererFlip.NONE})
    
    animator_component := ecs.get_component_unchecked(&ctx.world, ecs.Entity(animator), container.Animator)
    
    ecs.add_component_unchecked(&ctx.world, game_entity,container.Animator{
        animator_component.current_animation,
        animator_component.previous_frame,
        animator_component.animation_time,
        animator_component.animation_speed,
        animator_component.clips,
    })


    return int(game_entity)
}