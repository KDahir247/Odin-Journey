package game_container

import "../mathematics"
import "vendor:sdl2"

Action :: enum{
    Idle,
    Walking,
    Falling,
    Jumping,
    Attacking,
    Dead,
}


Physics :: struct{
    velocity : mathematics.Vec2,
    acceleration : mathematics.Vec2,
    damping : mathematics.Vec2, // drag
    accumulated_force : mathematics.Vec2,
    inverse_mass : f32,
}

// Component to distingush playe
Player :: struct{
    _unused : u8,
}

GameEntity :: struct{
    animation_index : int,
    animation_time : f32,
    animation_timer : u32,
    direction : sdl2.RendererFlip,
    actions : bit_set[Action],
}

AnimationConfig :: struct{
    index : i64,
    slices : i64,
    width : f64,
    height : f64,
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
    animation_fps : f32,
    animations : [dynamic]Animation,
}

Animation :: struct{
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