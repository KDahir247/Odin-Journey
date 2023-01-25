package game_container

import "../mathematics"
import "vendor:sdl2"

DynamicResource :: struct{
    // camera

    // time
    elapsed_time : u32,
    delta_time : f32,
    elapsed_physic_time : f32,
    animation_time : f32,

}

Animation :: struct{
    value : mathematics.Vec4,
    previous_frame : u32,
    //will have a [dynamic]math.Vec2i for the animation indices
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