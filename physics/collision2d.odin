package physics

import "../container"
import "../mathematics"

import "core:math/linalg"

overlapping :: #force_inline proc(min_a : f32, max_a : f32, min_b : f32, max_b : f32) -> bool{
    return min_b <= max_a && min_a <= max_b
}

rectangle_collision :: proc(rectangle_0 : container.Rectangle, rectangle_1 : container.Rectangle) -> bool{
    left_0 := rectangle_0.origin.x
    bottom_0 := rectangle_0.origin.y

    right_0 := rectangle_0.origin.x + rectangle_0.size.x
    top_0 := rectangle_0.origin.y + rectangle_0.size.y

    left_1 := rectangle_1.origin.x
    bottom_1 := rectangle_1.origin.y

    right_1 := rectangle_1.origin.x + rectangle_1.size.x
    top_1 := rectangle_1.origin.y + rectangle_1.size.y

    return overlapping(left_0, right_0, left_1, right_1) && overlapping(bottom_0, top_0, bottom_1, top_1)
}


rect_collision :: proc(rect_0 : mathematics.Vec4, rect_1 : mathematics.Vec4) -> bool{

    if ((rect_0.z + rect_0.w + rect_1.z + rect_1.w) == 0){
        return false
    }
    
    
    a := linalg.min(rect_0.x, rect_0.x + rect_0.z) < linalg.max(rect_1.x, rect_1.x + rect_1.z)
    b := linalg.min(rect_0.y, rect_0.y + rect_0.w) < linalg.max(rect_1.y, rect_1.y + rect_1.w)
    c := linalg.max(rect_0.x, rect_0.x + rect_0.z) > linalg.min(rect_1.x, rect_1.x + rect_1.z)
    d := linalg.max(rect_0.y, rect_0.y + rect_0.w) > linalg.min(rect_1.y, rect_1.y + rect_1.w)

    return a & b & c & d
}

circle_collision :: proc(circle_0 : container.Circle, circle_1 : container.Circle) -> bool{
    sum_radius_sqr := (circle_0.radius + circle_1.radius) * (circle_0.radius + circle_1.radius) 
    circle_center_distance := circle_0.center - circle_1.center

    return linalg.length2(circle_center_distance) <= sum_radius_sqr
}

point_collision :: proc(point_0 : mathematics.Vec2, point_1 : mathematics.Vec2) -> bool{
    return point_0 == point_1
}