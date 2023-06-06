package mathematics

//Goes infinitely from the origin to the direction in both side (+ direction, - direction)
Line :: struct{
    origin : Vec2,
    direction : Vec2,
}

//Goes infinitely from the origin to the direction
Ray :: struct{
    origin : Vec2,
    direction : Vec2,
}

//Goes from the origin to the origin + displacement (end point)
Segement :: struct{
    origin : Vec2,
    direction : Vec2, // should be normalized
    displacement : Vec2, // direction & distance
}

AABB :: struct{
    origin : Vec2,
    half : Vec2,
}