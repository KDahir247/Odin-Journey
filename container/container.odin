package game_container

import "../math"
import "vendor:sdl2"


MovementController :: struct{
    vertical : i8,
    horizontal : i8,
}

Position :: struct{
    value : math.Vec2,
}

Rotation :: struct{
    // We will only have a rotation for the z axis
    value : f64,
}

Scale :: struct {
    value : math.Vec2,
}

TextureAsset :: struct{
	texture : ^sdl2.Texture,
	dimension : math.Vec2,
}