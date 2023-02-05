package game_container

import "../mathematics"
import "vendor:sdl2"
import "vendor:sdl2/image"

GameConfig :: struct{
    game_flags : sdl2.InitFlags,
    img_flags : image.InitFlags,
    window_flags : sdl2.WindowFlags,
    render_flags : sdl2.RendererFlags,

    title : cstring,
    center : mathematics.Vec2i,
    grid : mathematics.Vec3i,
    clear_color : [4]u8,
}

OrientedRectangle :: struct{
    center : mathematics.Vec2,
    half_extent : mathematics.Vec2,
    rotation_degree : f32,
}

Rectangle :: struct{
    origin : mathematics.Vec2,
    size : mathematics.Vec2,
}

Circle :: struct{
    center : mathematics.Vec2,
    radius : f32,
}

LineSegment :: struct{
    start_point : mathematics.Vec2,
    end_point : mathematics.Vec2,
}

Line :: struct{
    base : mathematics.Vec2,
    direction : mathematics.Vec2, // should be normalized this is direction
}

Physics :: struct{
    velocity : mathematics.Vec2,
    acceleration : mathematics.Vec2,
    damping : mathematics.Vec2, // drag
    accumulated_force : mathematics.Vec2,
    inverse_mass : f32,
}

Player :: struct{
    _unused : u8,
}

Action :: enum u8{
    Idle = 0,
    Walking = 1,
    Falling = 2,
    Jumping = 3,
    Roll,
    Attacking,
    Dead,
}

GameEntity :: struct{
    animation_index : int,
    animation_time : f32,
    animation_timer : i32,
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