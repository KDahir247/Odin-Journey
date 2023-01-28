package game_container

import "../mathematics"
import "vendor:sdl2"

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
    elapsed_physic_time : f32,
    animation_time : f32,
    
    animation_index : int,

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