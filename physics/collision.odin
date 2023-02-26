package physics

import "../mathematics"

import "core:testing"
import "core:fmt"

line_line_intersection :: proc(a : mathematics.Line, b : mathematics.Line) -> (a_intersection: mathematics.Vec2, b_intersection: mathematics.Vec2){
    intersection_point_a : mathematics.Vec2
    intersection_point_b : mathematics.Vec2

    displacement_vector := b.origin - a.origin

    cross_product_direction := (b.direction.x * a.direction.y) - (b.direction.y * a.direction.x)
    cross_product_displacement := (displacement_vector.x * a.direction.y) - (displacement_vector.y * a.direction.x)

    colinear_mask := f32(i32(cross_product_direction != 0)) // false (0) is colinear
    parallel_mask := f32(i32(cross_product_displacement == 0)) // false (0) is not parallel

    cross_product_direction_rcp := 1.0 / cross_product_direction

    intersection_time_a := ((b.direction.x * displacement_vector.y) - (b.direction.y * displacement_vector.x)) * cross_product_direction_rcp
    intersection_time_b := ((a.direction.x * displacement_vector.y) - (a.direction.y * displacement_vector.x)) * cross_product_direction_rcp

    time_direction_a := intersection_time_a * a.direction
    time_direction_b := intersection_time_b * b.direction

    intersection_point_a = ({a.origin.x + time_direction_a.x, a.origin.y + time_direction_a.y} * colinear_mask) + (a.origin * parallel_mask)
    intersection_point_b = ({b.origin.x + time_direction_b.x, b.origin.y + time_direction_b.y} * colinear_mask) + (b.origin * parallel_mask)
  
    return intersection_point_a, intersection_point_b
}

// y represent the y axis for the horizontal line
line_horizontal_intersection :: proc(a : mathematics.Line, y : f32) -> mathematics.Vec2{
    intersection_point : mathematics.Vec2

    displacement_vector :mathematics.Vec2 = {-a.origin.x, y - a.origin.y}

    colinear_mask := f32(i32(a.direction.y != 0)) // false (0) is colinear
    parallel_mask := f32(i32(displacement_vector.y == 0)) // false (0) is not parallel

    intersection_time := displacement_vector.y / a.direction.y
    intersection_point = ({a.origin.x + intersection_time *  a.direction.x, y} * colinear_mask) + (a.origin * parallel_mask)

    return intersection_point
}

// x represent the y axis for the vertical line
line_vetical_intersection :: proc(a : mathematics.Line, x : f32) -> mathematics.Vec2{
    intersection_point : mathematics.Vec2

    displacement_vector :mathematics.Vec2 = {x - a.origin.x,  -a.origin.y}

    colinear_mask := f32(i32(a.direction.x != 0)) // false (0) is colinear
    parallel_mask := f32(i32(displacement_vector.x == 0)) // false (0) is not parallel

    intersection_time := displacement_vector.x / a.direction.x

    intersection_point = ({x, a.origin.y + intersection_time * a.direction.y} * colinear_mask) + (a.origin * parallel_mask)

    return intersection_point
}

collision_reflection :: proc(intersection_point : mathematics.Vec2, movement_vector : mathematics.Vec2, intersection_time : f32, collision_normal : mathematics.Vec2) -> mathematics.Vec2{
    dot_product := 2.0 * ((movement_vector.x * collision_normal.x) + (movement_vector.y * collision_normal.y))
    
    remaining_intersection_time := 1.0 - intersection_time
    reflection_vector :=  remaining_intersection_time * (movement_vector - dot_product * collision_normal)
    
    return intersection_point + reflection_vector
}

@(test)
line_line_intersection_test ::proc(t : ^testing.T){

    a := mathematics.Line{{-4.5,3.5}, {1.5, 2}}
    b := mathematics.Line{{3,2}, {5,3}}
    a_result, b_result := line_line_intersection(a,b)
    fmt.println("%v %v",a_result, b_result)
}

@(test)
line_horizontal_intersection_test :: proc(t : ^testing.T){
    a := mathematics.Line{{-4.5,3.5}, {1.5, 2}}
    b :f32= 4.0

    res := line_horizontal_intersection(a, b)
    fmt.println("%v", res)
}