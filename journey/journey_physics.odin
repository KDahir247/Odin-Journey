package journey


import "core:math"
import "core:math/linalg"



CollisionHit :: struct{
    collider : AABB,
    contact_point : [2]f32, // the collision point.
    delta_displacement : [2]f32,//  vector to add move collided AABB back to non collided state.
    contact_normal : [2]f32,
    time : f32, //how far along the line the collision occurred (0,1)
}   

CollisionSweep :: struct{
    hit : CollisionHit,
    pos : [2]f32,
    time : f32,
}

//////////////////////////////// INTERSECTION FUNCTION /////////////////////////////////

line_line_intersection :: proc "contextless" (a : Line, b : Line) -> (a_intersection: [2]f32, b_intersection: [2]f32){
    intersection_point_a : [2]f32
    intersection_point_b : [2]f32

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
line_horizontal_intersection :: proc "contextless" (a : Line, y : f32) -> [2]f32{
    intersection_point : [2]f32

    displacement_vector :[2]f32 = {-a.origin.x, y - a.origin.y}

    colinear_mask := f32(i32(a.direction.y != 0)) // false (0) is colinear
    parallel_mask := f32(i32(displacement_vector.y == 0)) // false (0) is not parallel

    intersection_time := displacement_vector.y / a.direction.y
    intersection_point = ({a.origin.x + intersection_time *  a.direction.x, y} * colinear_mask) + (a.origin * parallel_mask)

    return intersection_point
}

// x represent the y axis for the vertical line
line_vetical_intersection :: proc "contextless" (a : Line, x : f32) -> [2]f32{
    intersection_point : [2]f32

    displacement_vector :[2]f32 = {x - a.origin.x,  -a.origin.y}

    colinear_mask := f32(i32(a.direction.x != 0)) // false (0) is colinear
    parallel_mask := f32(i32(displacement_vector.x == 0)) // false (0) is not parallel

    intersection_time := displacement_vector.x / a.direction.x

    intersection_point = ({x, a.origin.y + intersection_time * a.direction.y} * colinear_mask) + (a.origin * parallel_mask)

    //Note We can now use the point to aabb to get the collision hit since intersection_point is the point that collided in the aabb.


    return intersection_point
}

fast_aabb_aabb_intersection :: proc "contextless"(a : AABB, b : AABB) -> bool{

    x :=  abs(a.origin.x - b.origin.x) <= (a.half.x + b.half.x)
    y := abs(a.origin.y - b.origin.y) <= (a.half.y + b.half.y)
    
    return x && y

}

aabb_point_intersection :: proc "contextless"(a : AABB, b : [2]f32) -> CollisionHit {
    hit : CollisionHit

    displacement_vector := b - a.origin
    overlap := a.half - {abs(displacement_vector.x), abs(displacement_vector.y)}

    if overlap.x <= 0 || overlap.y <= 0{
        //TODO: khal add a collision flag so i know if it collider or not maybe it return a enum.
        return hit
    }

    hit.collider = a

    signed_displacement :[2]f32 = {math.sign(displacement_vector.x), math.sign(displacement_vector.y)} 

    collision_mask := i32(overlap.x < overlap.y)

    mask :[2]f32 = {f32(collision_mask), f32(1- collision_mask)}

    hit.delta_displacement = overlap * signed_displacement * mask
    hit.contact_normal = signed_displacement * mask
    hit.contact_point = ((a.origin + (a.half * signed_displacement)) * mask.x) + (b * mask.y)

    return hit
}

aabb_segement_intersection :: proc "contextless"(a : AABB, b : Segement, padding : [2]f32 = {0,0}) -> CollisionHit{
    hit : CollisionHit
    
    rcp_displacement := 1.0 / b.displacement
    rcp_signed_displacement : [2]f32 = {math.sign(rcp_displacement.x),math.sign(rcp_displacement.y)}

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

aabb_aabb_intersection :: proc "contextless"(a : AABB, b : AABB) -> CollisionHit{
    hit : CollisionHit

    //TODO:khal move this to ldtk collision. Note that the origin will change depending on the entity pivot point.
    // Right now it is the top left
    a_half := a.half * 0.5
    b_half := b.half * 0.5
    a_origin := a.origin + a_half
    b_origin := b.origin + b_half
    
    displacement_vector := b_origin - a_origin
    overlap := (b_half + a_half) - {abs(displacement_vector.x),abs(displacement_vector.y)}

    if (overlap.x <= 0 || overlap.y <= 0){
        return hit
    }

    signed_displacement :[2]f32 = {math.sign(displacement_vector.x), math.sign(displacement_vector.y)}

    hit.collider = a

    collision_mask := int(overlap.x < overlap.y)
    mask : [2]f32= {f32(collision_mask), f32(1 - collision_mask)} 

    hit.delta_displacement = overlap * signed_displacement * mask
    hit.contact_normal = signed_displacement * mask
    hit.contact_point = ((a_origin + (a_half * signed_displacement)) * mask.x) + (b_origin * mask.y)

    return hit
} 

////////////////////////////////////////////////////////////////////////////////////////


//////////////////////////////// SWEEP TEST ///////////////////////////////////////////

aabb_aabb_sweep :: proc (a : AABB, b : AABB, velocity : [2]f32) -> CollisionSweep{
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

    segment := Segement{b.origin,linalg.normalize(velocity),velocity}
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


// sweep_aabb :: proc(dyn_physic : ^common.Physics, static_col : [] common.Physics) -> (bool, CollisionSweep){
//     nearest : CollisionSweep
//     nearest.time = 1
//     res := false

//     nearest.pos = dyn_physic.collider.origin + dyn_physic.velocity
//     for i := 0; i < len(static_col); i += 1 {

//         if dyn_physic.collider != static_col[i].collider{
//             sweep := aabb_aabb_sweep(dyn_physic.collider, static_col[i].collider, dyn_physic.velocity)
//             if (sweep.time < nearest.time){
//                 nearest = sweep
//                 res = true
//             }  
//         } 
//     }

//     return res, nearest
// }



/////////////////////////////////////////////////////////////////////////////////////



///////////////////////////// Collision Normal & Reflection /////////////////////////

collision_reflection :: proc "contextless" (intersection_point : [2]f32, movement_vector : [2]f32, intersection_time : f32, collision_normal : [2]f32) -> [2]f32{
    dot_product := 2.0 * ((movement_vector.x * collision_normal.x) + (movement_vector.y * collision_normal.y))
    
    remaining_intersection_time := 1.0 - intersection_time
    reflection_vector :=  remaining_intersection_time * (movement_vector - dot_product * collision_normal)
    
    return intersection_point + reflection_vector
}


aabb_line_collision_normal ::  proc "contextless"(a : AABB, b : Line) -> (left_normal, right_normal : [2]f32){
    return {-b.direction.y, b.direction.x}, {b.direction.y, -b.direction.x}
}

aabb_horizontal_collision_normal :: proc "contextless"(a : AABB, y : f32) -> (left_normal, right_normal : [2]f32){
    return {0, 1}, {0, -1}
}

aabb_vertical_collision_normal ::proc "contextless" (a : AABB, x : f32) -> (left_normal,right_normal : [2]f32){
    return {1,0}, {-1, 0}
}

/////////////////////////////////////////////////////////////////////////////////////////



///////////////////////////// Physics Integration //////////////////////////////////////


//Update physics interal data.
// integrate :: proc(physics : ^common.Physics, dt : f32){
//     if physics.inverse_mass == 0{
//         return
//     }
//     physics.position += physics.velocity * dt

//     acc := physics.acceleration
//     acc += (physics.inverse_mass * physics.accumulated_force)

//     physics.velocity += acc * dt 
//     physics.velocity *= math.pow(physics.damping, dt)

//     physics.accumulated_force = 0
// }

// compute_length :: #force_inline proc "contextless"(velocity : mathematics.Vec2) -> f32{
//     return math.sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
// }


// compute_direction :: #force_inline proc "contextless"(velocity : mathematics.Vec2) -> mathematics.Vec2{
//     rcp_speed := 1.0 / compute_length(velocity)
//     return velocity * rcp_speed
// }

// compute_seperation_velocity :: #force_inline proc(#no_alias physics, other : ^common.Physics, contact_normal : mathematics.Vec2) -> mathematics.Vec2{
//     a := (physics.velocity - other.velocity)
//     return (a.x * contact_normal.x) + (a.y * contact_normal.y)
// }

// compute_closing_velocity :: #force_inline proc(#no_alias physics, other : ^common.Physics, contact_normal : mathematics.Vec2) -> mathematics.Vec2{
//     a := -(physics.velocity - other.velocity)
//     return (a.x * contact_normal.x) + (a.y * contact_normal.y)
// }

// add_impulse :: #force_inline proc(physics : ^common.Physics, impulse_factor : f32, impulse_direction : mathematics.Vec2){
//     mass := 1.0 / physics.inverse_mass
//     impulse := impulse_direction * impulse_factor * mass

//     physics.velocity += impulse * physics.inverse_mass
// }

// add_friction_force :: #force_inline proc(physics : ^common.Physics, friction_coefficient : f32){

//     //N = m*g
//     //if surface is inclined then the formula would be N = m * g *cos(theta)
//     mass := 1.0 / physics.inverse_mass
//     normal_force := mass * physics.acceleration.y
//     friction := normal_force * friction_coefficient

//     friction_force := -physics.velocity.x * friction
//     add_force(physics, {friction_force, 0})
// }

// add_gravitation_force :: #force_inline proc(physics : ^common.Physics, gravity : mathematics.Vec2){
    
//     if physics.inverse_mass == 0{
//         return //Handle infinite mass and prevent dividing by zero.
//     }
    
//     physics_mass := 1.0 / physics.inverse_mass

//     add_force(physics, gravity * physics_mass)
// }

// add_entity_spring :: #force_inline proc(#no_alias physics,other :^common.Physics ,rest_length : f32, spring_constraint : f32){
//     force := physics.position - other.position
    
//     magnitude := abs(compute_length(force) - rest_length)
//     stiff_magnitude := -spring_constraint * magnitude
    
//     force_direction := compute_direction(force) 

//     add_force(physics,stiff_magnitude * force_direction)
// }

// add_bungee_spring :: #force_inline proc(#no_alias physics, other: ^common.Physics, rest_length : f32, spring_constraint : f32){
//     force := physics.position - other.position

//     force_length := compute_length(force)

//     if (force_length <= rest_length){
//         return
//     }

//     magnitude := (rest_length - force_length)
//     stiff_magnitude := spring_constraint * magnitude

//     force_direction := force / force_length

//     add_force(physics,force_direction * -stiff_magnitude)
// }

// add_buoyancy_force :: #force_inline proc(physics : ^common.Physics, max_depth : f32, volume : f32, water_height : f32, liquid_density : f32){
//     depth := physics.position.y

//     if (depth >= water_height + max_depth){
//         return
//     }

//     force :mathematics.Vec2 ={}

//     if (depth <= water_height - max_depth){
//         force.y = liquid_density * volume
//         add_force(physics,force)
//         return
//     }

//     force.y = liquid_density * volume * (depth - max_depth - water_height) / 2 * max_depth
    
//     add_force(physics,force)
// }

// add_anchor_spring :: #force_inline proc(physics : ^common.Physics, anchor : mathematics.Vec2, rest_length : f32, spring_constrant : f32){
//     force := physics.position - anchor

//     magnitude := rest_length - compute_length(force)
//     stiff_magnitude := spring_constrant * magnitude

//     force_direction := compute_direction(force)

//     add_force(physics, stiff_magnitude * force_direction)
// }

// add_drag_force :: #force_inline proc(physics : ^common.Physics, velocity_drag_coef : f32, sqr_velocity_drag_coef : f32){
//     drag_coef := compute_length(physics.velocity)
    
//     res := (velocity_drag_coef * drag_coef) + (sqr_velocity_drag_coef * drag_coef * drag_coef)

//     force_norm := physics.velocity / drag_coef

//     add_force(physics,force_norm * -res)
// }

// add_force :: #force_inline proc(physics : ^common.Physics, force : mathematics.Vec2){
//     physics.accumulated_force += force
// }

// compute_interpenetration :: proc(#no_alias collider, collided : ^common.Physics, penetration : f32, contact_normal : mathematics.Vec2 = {0,1}){

//     total_inv_mass := collider.inverse_mass + collided.inverse_mass
    
//     if penetration <= 0 || total_inv_mass <= 0{
//         return
//     }

//     penetration_resolution := penetration / total_inv_mass * contact_normal

//     total_delta_pos_a := penetration_resolution * -collider.inverse_mass
//     total_delta_pos_b := penetration_resolution * collided.inverse_mass


//     collider.position += total_delta_pos_a
//     collided.position += total_delta_pos_b
// }


// compute_contact_velocity :: proc(#no_alias collider, collided : ^common.Physics, restitution : f32, contact_normal : mathematics.Vec2 = {0,1}, dt : f32){
//     displacement_velocity := collided.velocity - collider.velocity

//     seperating_velocity := (displacement_velocity.x * contact_normal.x) + (displacement_velocity.y * contact_normal.y)
//     total_inv_mass := collider.inverse_mass + collided.inverse_mass

//     //seperating or stationary, so no impulse needed or Infinite mass impulse has no effect
//     if seperating_velocity > 0 || total_inv_mass <= 0{
//         return
//     }

//     new_seperating_velocity := -seperating_velocity * restitution

//     acc_caused_velocity := collided.acceleration - collider.acceleration

//     acc_caused_seperation_velocity := (acc_caused_velocity.x * contact_normal.x) + (acc_caused_velocity.y * contact_normal.y) * dt

//     if acc_caused_seperation_velocity < 0{
//         new_seperating_velocity += restitution * acc_caused_seperation_velocity

//         if (new_seperating_velocity < 0){
//             new_seperating_velocity = 0
//         }
//     }

//     delta_velocity := new_seperating_velocity - seperating_velocity

//     impulse := (delta_velocity / total_inv_mass) * contact_normal

//     collider.velocity += impulse * -collider.inverse_mass
//     collided.velocity += impulse * collided.inverse_mass
// }
///////////////////////////////////////////////////////////////////////////


////////////////////////// Physics Solver /////////////////////////////////

// resolve_contacts :: proc(iteration : int, contacts : [dynamic]common.PhysicsContact, dt : f32){
//     iteration_used := 0
//     contact_num := len(contacts)
//     for iteration_used < iteration {
//         max :f32 = math.F32_MAX
//         max_index := contact_num
//         for i := 0; i < contact_num; i += 1 {
//             // calculate seperating velocity
//             contact := contacts[i].contacts
//             displacement_velocity := contact[0].velocity - contact[1].velocity
//             seperating_velocity := (displacement_velocity.x * contacts[i].contact_normal.x) + (displacement_velocity.y * contacts[i].contact_normal.y)

//             if(seperating_velocity < max && seperating_velocity < 0 || contacts[i].penetration > 0){
//                 max = seperating_velocity
//                 max_index = i
//             }

//         }

//         if max_index == contact_num{
//             break
//         }

//         contact := contacts[max_index].contacts
//         contact_normal := contacts[max_index].contact_normal
//         compute_contact_velocity(&contact.x, &contact.y, 0.0, contact_normal,dt)
//         compute_interpenetration(&contact.x, &contact.y, contacts[max_index].penetration,contact_normal)

//         iteration_used = iteration_used + 1
//     }
// }


/////////////////////////////////////////////////////////////////////

