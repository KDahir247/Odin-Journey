package journey

import "core:math/linalg"

//Goes infinitely from the origin to the direction in both side (+ direction, - direction)
Line :: struct{
    origin : [2]f32,
    direction : [2]f32,
}

//Goes infinitely from the origin to the direction
Ray :: struct{
    origin : [2]f32,
    direction : [2]f32,
}

//Goes from the origin to the origin + displacement (end point)
Segement :: struct{
    origin : [2]f32,
    direction : [2]f32, // should be normalized
    displacement : [2]f32, // direction & distance
}

AABB :: struct{
    origin : [2]f32,
    half : [2]f32,
}


cross_vector :: proc(v, v1 : [2]f32) -> f32{
    return (v.x * v1.y) - (v.y * v1.x)
}

normal_vector :: proc (v : [2]f32) -> [2]f32{
    return {-v.y, v.x}
}

normal_neg_vector :: proc(v : [2]f32) -> [2]f32{
    return {v.y, -v.x}
}

rotate_vector :: proc(v: [2]f32, angle_rad : f32) -> [2]f32  {
    sin := linalg.sin(angle_rad)
    cos := linalg.cos(angle_rad)


    return  {v.x * cos - v.y * sin, v.x * sin + v.y * cos}
}

angle_vector :: proc(v, v1 : [2]f32) -> f32{
    norm_v0 := linalg.normalize(v)
    norm_v1 := linalg.normalize(v1)

    dp := linalg.dot(norm_v0, norm_v1)
    return linalg.to_degrees(linalg.acos(dp))
}

project_vector :: proc(proj, onto : [2]f32) -> [2]f32{
    length_sqr := linalg.length2(onto)

    res := onto
    if length_sqr > 0{
        dp := linalg.dot(proj, onto)
        res = onto * (dp * length_sqr)
    }

    return res
}