package utility

import "../ecs"
import "../mathematics"
import "../container"
import game "../context"
import "vendor:sdl2"

GRAVITY_SCALE :: 9.81

create_game_entity ::proc(path : string,anim_config : [dynamic]container.AnimationConfig, translation : [2]f32, rotation:f64, scale: [2]f32, is_player : bool) -> ecs.Entity{

	ctx := cast(^game.Context) context.user_ptr

    game_entity := load_animation_texture(path,anim_config)

    #no_bounds_check{    
        ecs.add_component(&ctx.world, game_entity, container.Physics{mathematics.Vec2{0, 0},mathematics.Vec2{250, 1000},mathematics.Vec2{0.1, 1},mathematics.Vec2{0,0}, 1})
        if is_player{
            ecs.add_component_unchecked(&ctx.world, game_entity, container.Player{0})
        }
        ecs.add_component_unchecked(&ctx.world, game_entity, container.GameEntity{0,0,0,sdl2.RendererFlip.NONE,{container.Action.Idle}})
        ecs.add_component_unchecked(&ctx.world, game_entity, container.Position{ mathematics.Vec2{translation[0], translation[1]}})
        ecs.add_component_unchecked(&ctx.world, game_entity, container.Rotation{rotation})
        ecs.add_component_unchecked(&ctx.world, game_entity, container.Scale{mathematics.Vec2{scale[0], scale[1]}})
    }

    return game_entity
}