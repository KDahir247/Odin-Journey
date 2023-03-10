package game_container

import "../mathematics"
import "vendor:sdl2"
import "vendor:sdl2/image"

Physics :: struct{
    collider : mathematics.AABB,
    position : mathematics.Vec2,
    velocity : mathematics.Vec2,
    acceleration : mathematics.Vec2,
    accumulated_force : mathematics.Vec2,
    damping : f32, 
    inverse_mass : f32,
    friction : f32,
    restitution : f32,
}

TileMap :: struct{
    texture : ^sdl2.Texture,
	dimension : mathematics.Vec2i,
}

GameConfig :: struct{
    game_flags : sdl2.InitFlags,
    img_flags : image.InitFlags,
    window_flags : sdl2.WindowFlags,
    render_flags : sdl2.RendererFlags,

    title : cstring,
    center : mathematics.Vec2i,
    grid : mathematics.Vec3i,
    clear_color : [3]u8,
}

PhysicsContact :: struct{
    contacts : [2]Physics,
    contact_normal : mathematics.Vec2,
    penetration : f32,  
}



CoolDownTimer:: struct{
    cooldown_amount : u32,
    cooldown_duration : u32,
}

Player :: struct{
    //TODO: khal this structure doesn't hold. enemy can have cooldown timer and possibly objects
    cooldown : [2]CoolDownTimer, 
}

Action :: enum i32{
    Idle = 0,
    Walking = 1,
    Falling = 2,
    Jumping = 3,
    Roll,
    Teleport,
    TeleportDown,
    Attacking,
    Dead,
}

GameEntity :: struct{
    animation_index : int,
    input_direction : int,

    animation_time : f32,
    render_direction : sdl2.RendererFlip,
}

AnimationConfig :: struct{
    index : i32,
    slices : i32,
    width : i32,
    height : i32,
    animation_speed : f32,
}

DynamicResource :: struct{
    // camera

    // time
    elapsed_time : u32,
    delta_time : f32,
    current_physics_time : f32,

}

Animation_Tree :: struct{
    previous_frame : int,
    //Idle Walk etc....
    animations : [dynamic]Animation,
}

Animation :: struct{
    // The rect cycle maybe have animation speed for each animation....
    animation_speed : f32,
    value : [dynamic]sdl2.Rect,
}

Position :: struct{
    value : mathematics.Vec2,
}

Rotation :: struct{
    value : f64,
}

Scale :: struct {
    value : mathematics.Vec2,
}


TextureAsset :: struct{
	texture : ^sdl2.Texture,
	dimension : mathematics.Vec2,
}