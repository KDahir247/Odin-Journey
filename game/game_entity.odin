package game

import "../ecs"
import "../mathematics"
import "../container"
import ctx "../context"

import "vendor:sdl2"

create_game_entity ::proc($path : cstring,anim_config : [$E]container.AnimationConfig, translation : [2]f32, rotation:f64, scale: [2]f32){

	ctx := cast(^ctx.Context) context.user_ptr

    game_entity := create_animation_texture_entity(path,anim_config)
    
    if context.user_index == int(game_entity) {
        ecs.add_component_unchecked(&ctx.world, game_entity, container.Player{{container.CoolDownTimer{3000, 0}, container.CoolDownTimer{3000, 0}} })
    }

    ecs.add_component_unchecked(&ctx.world, game_entity, container.Position{mathematics.Vec2{translation.x, translation.y}})
    ecs.add_component_unchecked(&ctx.world, game_entity, container.Rotation{rotation})
    ecs.add_component_unchecked(&ctx.world, game_entity, container.Scale{mathematics.Vec2{scale.x, scale.y}})

    ecs.add_component_unchecked(&ctx.world, game_entity, container.Physics{mathematics.Vec2{translation.x,translation.y}, mathematics.Vec2{0, 0},mathematics.Vec2{0, 9.81},mathematics.Vec2{0,0},0.999, 1, })

    ecs.add_component_unchecked(&ctx.world, game_entity, container.GameEntity{0,0,0, sdl2.RendererFlip.NONE})
}