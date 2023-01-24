package game_container

import "../math"
import "vendor:sdl2"

DynamicResource :: struct{
    // camera

    // time
    elapsed_time : u32,
    delta_time : f32,
    elapsed_physic_time : u32,
}

Animation :: struct{
    value : math.Vec4,
    //will have a [dynamic]math.Vec2i for the animation indices
}

Position :: struct{
    value : math.Vec2,
}

Rotation :: struct{
    value : f64,
}

Scale :: struct {
    value : math.Vec2,
}

TextureAsset :: struct{
	texture : ^sdl2.Texture,
	dimension : math.Vec2,
}