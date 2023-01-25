package utility

import "../ecs"
import "../mathematics"
import "../container"
import game "../context"

// This will have texture and collider other common componenent animation,
create_static_entity :: proc(path : string) -> ecs.Entity{
    ctx := cast(^game.Context) context.user_ptr

    game_entity := load_texture(path)

    return game_entity
}


// Create a dynamic entity.
// param:
// path is the file path to load the sprite from.
// translation is the position the sprite will be in
// rotation is the rotation around the z axis for the sprite (Degree)
// scale is factor to scale the sprite by
// animation contains the following;
// rows of sprites in the sprite sheet
// column of sprites in the sprite sheet
// the width apart each sprite
// the height apart each sprite
create_game_entity ::proc(path : string,translation : [2]f32, rotation:f64, scale: [2]f32 , animation : [4]f32) -> ecs.Entity{

	ctx := cast(^game.Context) context.user_ptr

    game_entity := load_texture(path)

    #no_bounds_check{    
        ecs.add_component(&ctx.world, game_entity, container.Position{ mathematics.Vec2{translation[0], translation[1]}})
        ecs.add_component(&ctx.world,game_entity, container.Rotation{rotation})
        ecs.add_component(&ctx.world, game_entity, container.Scale{mathematics.Vec2{scale[0], scale[1]}})
        
        ecs.add_component(&ctx.world, game_entity, container.Animation{mathematics.Vec4{animation[0], animation[1], animation[2], animation[3]}, 0})

    }

    return game_entity
}