package mathematics

import "core:math/linalg"

Vec2 :: distinct [2]f32
Vec3 :: distinct [3]f32
Vec4 :: distinct [4]f32

Vec2i :: distinct [2]int
Vec3i :: distinct [3]int
Vec4i :: distinct [4]int

cross_vector :: proc(v, v1 : Vec2) -> f32{
    return (v.x * v1.y) - (v.y * v1.x)
}

normal_vector :: proc (v : Vec2) -> Vec2{
    return {-v.y, v.x}
}

normal_neg_vector :: proc(v : Vec2) -> Vec2{
    return {v.y, -v.x}
}

rotate_vector :: proc(v: Vec2, angle_rad : f32) -> Vec2  {
    sin := linalg.sin(angle_rad)
    cos := linalg.cos(angle_rad)

    result := Vec2{v.x * cos - v.y * sin, v.x * sin + v.y * cos}

    return result
}

angle_vector :: proc(v, v1 : Vec2) -> f32{
    norm_v0 := linalg.normalize(v)
    norm_v1 := linalg.normalize(v1)

    dp := linalg.dot(norm_v0, norm_v1)
    return linalg.to_degrees(linalg.acos(dp))
}

project_vector :: proc(proj, onto : Vec2) -> Vec2{
    length_sqr := linalg.length2(onto)

    res := onto
    if length_sqr > 0{
        dp := linalg.dot(proj, onto)
        res = onto * (dp * length_sqr)
    }

    return res
}