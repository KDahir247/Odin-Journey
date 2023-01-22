package game_context

import "../math"
import "vendor:sdl2"

TextureAsset :: struct{
	texture : ^sdl2.Texture,
	dimension : math.Vec2i,
}