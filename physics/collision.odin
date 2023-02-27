package physics

import "../mathematics"

import "core:testing"
import "core:fmt"
import "core:math"

CollisionHit :: struct{
    collider : mathematics.AABB,
    contact_point : mathematics.Vec2, // the collision point.
    delta_displacement : mathematics.Vec2,//  vector to add move collided AABB back to non collided state.
    contact_normal : mathematics.Vec2,
    time : f32, //how far along the line the collision occurred (0,1)
}   


line_line_intersection :: proc "contextless" (a : mathematics.Line, b : mathematics.Line) -> (a_intersection: mathematics.Vec2, b_intersection: mathematics.Vec2){
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
line_horizontal_intersection :: proc "contextless" (a : mathematics.Line, y : f32) -> mathematics.Vec2{
    intersection_point : mathematics.Vec2

    displacement_vector :mathematics.Vec2 = {-a.origin.x, y - a.origin.y}

    colinear_mask := f32(i32(a.direction.y != 0)) // false (0) is colinear
    parallel_mask := f32(i32(displacement_vector.y == 0)) // false (0) is not parallel

    intersection_time := displacement_vector.y / a.direction.y
    intersection_point = ({a.origin.x + intersection_time *  a.direction.x, y} * colinear_mask) + (a.origin * parallel_mask)

    return intersection_point
}

// x represent the y axis for the vertical line
line_vetical_intersection :: proc "contextless" (a : mathematics.Line, x : f32) -> mathematics.Vec2{
    intersection_point : mathematics.Vec2

    displacement_vector :mathematics.Vec2 = {x - a.origin.x,  -a.origin.y}

    colinear_mask := f32(i32(a.direction.x != 0)) // false (0) is colinear
    parallel_mask := f32(i32(displacement_vector.x == 0)) // false (0) is not parallel

    intersection_time := displacement_vector.x / a.direction.x

    intersection_point = ({x, a.origin.y + intersection_time * a.direction.y} * colinear_mask) + (a.origin * parallel_mask)

    //Note We can now use the point to aabb to get the collision hit since intersection_point is the point that collided in the aabb.


    return intersection_point
}

collision_reflection :: proc "contextless" (intersection_point : mathematics.Vec2, movement_vector : mathematics.Vec2, intersection_time : f32, collision_normal : mathematics.Vec2) -> mathematics.Vec2{
    dot_product := 2.0 * ((movement_vector.x * collision_normal.x) + (movement_vector.y * collision_normal.y))
    
    remaining_intersection_time := 1.0 - intersection_time
    reflection_vector :=  remaining_intersection_time * (movement_vector - dot_product * collision_normal)
    
    return intersection_point + reflection_vector
}

//Collision normal

aabb_line_collision_normal ::  proc "contextless"(a : mathematics.AABB, b : mathematics.Line) -> (left_normal, right_normal : mathematics.Vec2){
    return {-b.direction.y, b.direction.x}, {b.direction.y, -b.direction.x}
}

aabb_horizontal_collision_normal :: proc "contextless"(a : mathematics.AABB, y : f32) -> (left_normal, right_normal : mathematics.Vec2){
    return {0, 1}, {0, -1}
}

aabb_vertical_collision_normal ::proc "contextless" (a : mathematics.AABB, x : f32) -> (left_normal,right_normal : mathematics.Vec2){
    return {1,0}, {-1, 0}
}



fast_aabb_aabb_intersection :: proc "contextless"(a : mathematics.AABB, b : mathematics.AABB) -> bool{

    x :=  abs(a.origin.x - b.origin.x) <= (a.half.x + b.half.x)
    y := abs(a.origin.y - b.origin.y) <= (a.half.y + b.half.y)
    
    return x && y

}

aabb_point_intersection :: proc "contextless"(a : mathematics.AABB, b : mathematics.Vec2) -> CollisionHit {
    hit : CollisionHit

    displacement_vector := b - a.origin
    overlap := a.half - {abs(displacement_vector.x), abs(displacement_vector.y)}

    if overlap.x <= 0 || overlap.y <= 0{
        //TODO: khal add a collision flag so i know if it collider or not maybe it return a enum.
        return hit
    }

    hit.collider = a

    signed_displacement :mathematics.Vec2 = {math.sign(displacement_vector.x), math.sign(displacement_vector.y)} 

    vertical_mask := i32(overlap.x < overlap.y)
    horizontal_mask := f32(1 - vertical_mask)

    mask :mathematics.Vec2 = {f32(vertical_mask), horizontal_mask}

    hit.delta_displacement = overlap * signed_displacement * mask
    hit.contact_normal = signed_displacement * mask
    hit.contact_point = {(a.origin.x + (a.half.x * signed_displacement.x) * mask.x) + (b.x * mask.y), (a.origin.y + (a.half.y * signed_displacement.y) * mask.x) + (b.y * mask.y) }

    return hit
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