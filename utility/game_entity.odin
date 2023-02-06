package utility

import "../ecs"
import "../mathematics"
import "../container"
import game "../context"
import "vendor:sdl2"

create_game_entity ::proc(path : string,anim_config : [dynamic]container.AnimationConfig, translation : [2]f32, rotation:f64, scale: [2]f32, is_player : bool) -> ecs.Entity{

	ctx := cast(^game.Context) context.user_ptr

    game_entity := load_animation_texture(path,anim_config)

    #no_bounds_check{    
        ecs.add_component(&ctx.world, game_entity, container.Physics{mathematics.Vec2{0, 0},mathematics.Vec2{250, 1000},mathematics.Vec2{0.1, 1},mathematics.Vec2{0,0}, 1})
        
        if is_player{
            ecs.add_component_unchecked(&ctx.world, game_entity, container.Player{{container.CoolDownTimer{3000, 0}, container.CoolDownTimer{3000, 0}} })
        }

        ecs.add_component_unchecked(&ctx.world, game_entity, container.GameEntity{0,0,0, sdl2.RendererFlip.NONE})
        ecs.add_component_unchecked(&ctx.world, game_entity, container.Position{ mathematics.Vec2{translation.x, translation.y}})
        ecs.add_component_unchecked(&ctx.world, game_entity, container.Rotation{rotation})
        ecs.add_component_unchecked(&ctx.world, game_entity, container.Scale{mathematics.Vec2{scale.x, scale.y}})
    }

    return game_entity
}