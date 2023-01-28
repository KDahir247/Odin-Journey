package utility

import "../ecs"
import "../mathematics"
import "../container"
import game "../context"
import "vendor:sdl2"


create_game_entity ::proc(path : string,anim_config : [dynamic]container.AnimationConfig, translation : [2]f32, rotation:f64, scale: [2]f32) -> ecs.Entity{

	ctx := cast(^game.Context) context.user_ptr

    game_entity := load_animation_texture(path,anim_config)

    // we need uniform scale
    //texture_asset := ecs.get_component_unchecked(&ctx.world, game_entity, container.TextureAsset)

    #no_bounds_check{    
        ecs.add_component(&ctx.world, game_entity, container.Position{ mathematics.Vec2{translation[0], translation[1]}})
        ecs.add_component(&ctx.world,game_entity, container.Rotation{rotation})
        ecs.add_component(&ctx.world, game_entity, container.Scale{mathematics.Vec2{scale[0], scale[1]}})
    }

    return game_entity
}