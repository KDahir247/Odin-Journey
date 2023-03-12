package physics

import "../mathematics"
import "../container"

import "core:math"
import "core:math/linalg"

CollisionHit :: struct{
    collider : mathematics.AABB,
    contact_point : mathematics.Vec2, // the collision point.
    delta_displacement : mathematics.Vec2,//  vector to add move collided AABB back to non collided state.
    contact_normal : mathematics.Vec2,
    time : f32, //how far along the line the collision occurred (0,1)
}   

CollisionSweep :: struct{
    hit : CollisionHit,
    pos : mathematics.Vec2,
    time : f32,
}

@(private)
enlarge_aabb_point :: proc "contextless"(r : mathematics.AABB, p : mathematics.Vec2) -> mathematics.AABB{
    enlarged : mathematics.AABB

    enlarged.origin = mathematics.Vec2{min(r.origin.x, p.x), min(r.origin.y, p.y)}
    enlarged.half = mathematics.Vec2{max(r.origin.x + r.half.x + r.half.x, p.x), max(r.origin.y + r.half.y + r.half.y, p.y)}
    enlarged.half = (enlarged.half - enlarged.origin)

    return enlarged
}

@(private)
enlarge_aabb :: proc "contextless"(r : mathematics.AABB, extender : mathematics.AABB) -> mathematics.AABB{
    max_corner := extender.origin + extender.half + extender.half

    enlarged := enlarge_aabb_point(r, max_corner)
    return enlarge_aabb_point(enlarged, extender.origin)
}

aabb_hull:: proc (a : [dynamic]mathematics.AABB) -> mathematics.AABB{
    aabb_hull : mathematics.AABB

    for index in 0..<len(a){
        aabb_hull = enlarge_aabb(aabb_hull, a[index])
    }

    aabb_hull.half = aabb_hull.half / 2
    return aabb_hull

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

    collision_mask := i32(overlap.x < overlap.y)

    mask :mathematics.Vec2 = {f32(collision_mask), f32(1- collision_mask)}

    hit.delta_displacement = overlap * signed_displacement * mask
    hit.contact_normal = signed_displacement * mask
    hit.contact_point = ((a.origin + (a.half * signed_displacement)) * mask.x) + (b * mask.y)

    return hit
}

aabb_segement_intersection :: proc "contextless"(a : mathematics.AABB, b : mathematics.Segement, padding : mathematics.Vec2 = {0,0}) -> CollisionHit{
    hit : CollisionHit
    
    rcp_displacement := 1.0 / b.displacement
    rcp_signed_displacement : mathematics.Vec2 = {math.sign(rcp_displacement.x),math.sign(rcp_displacement.y)}

    near_time := (a.origin - rcp_signed_displacement * (a.half + padding) - b.origin) * rcp_displacement
    far_time := (a.origin + rcp_signed_displacement * (a.half + padding) - b.origin) * rcp_displacement

    if (near_time.x > far_time.y || near_time.y > far_time.x){
        return hit
    }

    max_near_time := max(near_time.x, near_time.y)
    min_far_time := min(far_time.x, far_time.y)

    if (max_near_time >= 1 || min_far_time <= 0){
        return hit
    }

    hit.collider = a
    hit.time = clamp(max_near_time, 0, 1)

    horizontal_mask := int(near_time.x > near_time.y)
    vertical_mask := f32(1.0 - horizontal_mask)

    hit.contact_normal = -rcp_signed_displacement * {f32(horizontal_mask), vertical_mask}

    hit.delta_displacement = (1.0 - hit.time) * -b.displacement
    hit.contact_point = b.origin + b.displacement * hit.time

    return hit
}

aabb_aabb_intersection :: proc "contextless"(a : mathematics.AABB, b : mathematics.AABB) -> CollisionHit{
    hit : CollisionHit

    displacement_vector := b.origin - a.origin
    overlap := (b.half + a.half) - {abs(displacement_vector.x),abs(displacement_vector.y)}

    if (overlap.x <= 0 || overlap.y <= 0){
        return hit
    }

    signed_displacement :mathematics.Vec2 = {math.sign(displacement_vector.x), math.sign(displacement_vector.y)}

    hit.collider = a

    collision_mask := int(overlap.x < overlap.y)
    mask : mathematics.Vec2= {f32(collision_mask), f32(1 - collision_mask)} 

    hit.delta_displacement = overlap * signed_displacement * mask
    hit.contact_normal = signed_displacement * mask
    hit.contact_point = ((a.origin + (a.half * signed_displacement)) * mask.x) + (b.origin * mask.y)

    return hit
} 


aabb_aabb_sweep :: proc (a : mathematics.AABB, b : mathematics.AABB, velocity : mathematics.Vec2) -> CollisionSweep{
    sweep : CollisionSweep

    if (velocity.x == 0 && velocity.y == 0){
        sweep.pos = b.origin
        sweep.hit = aabb_aabb_intersection(a,b)
        
        if sweep.hit.collider == a{
            sweep.hit.time = 0
        }else{
            sweep.time = 1
        }

        return sweep
    }

    segment := mathematics.Segement{b.origin,linalg.normalize(velocity),velocity}
    sweep.hit = aabb_segement_intersection(a, segment, b.half)

    if sweep.hit.collider == a{
        sweep.time = clamp(sweep.hit.time - math.F32_EPSILON, 0, 1)
        sweep.pos = b.origin + velocity * sweep.time
        sweep.hit.contact_point = linalg.clamp(sweep.hit.contact_point + segment.direction * b.half, a.origin - a.half, a.origin + a.half)
    }else{
        sweep.pos = b.origin + velocity
        sweep.time = 1
    }

    return sweep
}

sweep_aabb :: proc(dyn_physic : ^container.Physics, static_col : [] container.Physics) -> (bool, CollisionSweep){
    nearest : CollisionSweep
    nearest.time = 1
    res := false
    nearest.pos = dyn_physic.collider.origin + dyn_physic.velocity
    for i := 0; i < len(static_col); i += 1 {
        if dyn_physic.collider != static_col[i].collider{
            sweep := aabb_aabb_sweep(dyn_physic.collider, static_col[i].collider, dyn_physic.velocity)
            if (sweep.time < nearest.time){
                nearest = sweep
                res = true
            }  
        } 
    }

    return res, nearest
}