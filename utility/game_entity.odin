package utility

import "../ecs"
import "../math"
import "../container"
import game "../context"

create_game_entity ::proc(path : string,translation : [2]f32, rotation:f64, scale: [2]f32) -> ecs.Entity{

	ctx := cast(^game.Context) context.user_ptr

    game_entity := load_texture(path)

    #no_bounds_check{    
        ecs.add_component(&ctx.world, game_entity, container.Position{ math.Vec2{translation[0], translation[1]}})
        ecs.add_component(&ctx.world,game_entity, container.Rotation{rotation})
        ecs.add_component(&ctx.world, game_entity, container.Scale{math.Vec2{scale[0], scale[1]}})
    }

    return game_entity;
}