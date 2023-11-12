package journey


import "core:math"
import "core:math/linalg"
import "core:simd"
import "core:fmt"
import "core:intrinsics"


//the rate at which two objects are getting closer to each other.
compute_seperation_speed :: proc(velocity : Velocity, collision_normal : [2]f32) ->f32{
    velocity_simd_1 := #simd[4]f32{velocity.x, velocity.y, 0, 0} 
    collision_normal :=#simd[4]f32{collision_normal.x, collision_normal.y, 0, 0} //compute_collision_normal(position_1, position_2)
    seperation_speed := simd.reduce_add_ordered(velocity_simd_1 * collision_normal)
    
    return seperation_speed
}

compute_linear_impulse :: proc(velocity: Velocity, inverse_mass : InverseMass, collision_normal : [2]f32, restitution : f32) -> Velocity{
    seperation_speed := compute_seperation_speed(velocity, collision_normal)

    if seperation_speed > 0{
        return velocity
    }

    new := -seperation_speed * clamp(restitution, 0, 1)

    delta := new - seperation_speed

    impulse  := delta / inverse_mass.val
    impulse_with_dir := impulse * collision_normal

    return Velocity{
        x = velocity.x + impulse_with_dir.x * inverse_mass.val,
        y = velocity.y + impulse_with_dir.y * inverse_mass.val,
        previous_x = velocity.x,
        previous_y = velocity.y,
    }

}

compute_contact_velocity :: proc(velocity: Velocity, acceleration : Acceleration, inverse_mass : InverseMass, collision_normal : [2]f32, restitution : f32, dt : f32) -> Velocity{

    seperating_velocity := (velocity.x * collision_normal.x) + (velocity.y * collision_normal.y)
    total_inv_mass := inverse_mass.val

    //seperating or stationary, so no impulse needed or Infinite mass impulse has no effect
    if seperating_velocity > 0 || total_inv_mass <= 0{
        return velocity
    }

    new_seperating_velocity := -seperating_velocity * restitution

    acc_caused_velocity := acceleration

    acc_caused_seperation_velocity :=  (acc_caused_velocity.x * collision_normal.x) + (acc_caused_velocity.y * collision_normal.y) * dt

    if acc_caused_seperation_velocity < 0{
        new_seperating_velocity += restitution * acc_caused_seperation_velocity

        if (new_seperating_velocity < 0){
            new_seperating_velocity = 0
        }
    }

    delta_velocity := new_seperating_velocity - seperating_velocity

    impulse := (delta_velocity / inverse_mass.val) * collision_normal

    new_velocity := velocity
    new_velocity.x += impulse.x * total_inv_mass
    new_velocity.y += impulse.y * total_inv_mass
    return new_velocity
}

compute_interpenetration :: proc(inverse_mass : InverseMass, penetration : f32, contact_normal : [2]f32) -> [2]f32{
    
    if (penetration <= 0) || inverse_mass.val <= 0{
        return [2]f32{}
    }

    penetration_resolution := (-penetration / inverse_mass.val) * contact_normal

    delta_position := penetration_resolution * inverse_mass.val

    return delta_position
}


compute_speed :: proc(velocity : Velocity) -> f32{
    arr := [2]f32{velocity.x, velocity.y}
    return linalg.length(arr)
}

compute_direction :: proc(velocity : Velocity) -> [2]f32{
    rcp_speed := 1.0 / compute_speed(velocity)
    return [2]f32{
        velocity.x * rcp_speed,
        velocity.y * rcp_speed,
    }
}

gravitational_force :: proc(mass : f32, gravitational_acceleration : f32 = GRAVITY) -> f32{
    return gravitational_acceleration * mass
}

quadratic_drag_force :: #force_inline proc(drag_coefficent : f32, velocity : Velocity) -> Force{
    quad_drag_x : simd.f32x4 = #simd[4]f32{drag_coefficent, velocity.x, velocity.x, -linalg.sign(velocity.x)}
    quad_drag_y : simd.f32x4 = #simd[4]f32{drag_coefficent, velocity.y, velocity.y, -linalg.sign(velocity.y)}

    drag_force := Force{
        x = simd.reduce_mul_ordered(quad_drag_x),
        y = simd.reduce_mul_ordered(quad_drag_y),
    }

    return drag_force
}

linear_drag_force :: proc(drag_coefficent : f32, velocity : Velocity) -> Force{

    return Force{
        x = drag_coefficent * -velocity.x,
        y = drag_coefficent * -velocity.y,
    }
}

friction_force :: proc(friction_coefficient : f32, mass : f32, velocity : Velocity, gravitational_acceleration : f32 = GRAVITY, incident_angle_rad : f32 = 0) ->Force{
    friction_array := #simd[4]f32{mass, gravitational_acceleration, math.cos(incident_angle_rad), friction_coefficient}
    friction := simd.reduce_mul_ordered(friction_array)
    
    friction_force := Force{
        x = -velocity.x * friction,
        y = -velocity.y * friction,
    }

    return friction_force

}

// //////////////////////////////// INTERSECTION FUNCTION /////////////////////////////////


aabb_segement_intersection :: proc (dynamic_collider : Collider, delta : Velocity, static_collider : Collider) -> CollisionHit{
    hit : CollisionHit
    hit.time = 1

    scale_delta_x := 1.0 / delta.x
    scale_delta_y := 1.0 / delta.y
    
    signed_delta_x := linalg.sign(scale_delta_x)
    signed_delta_y := linalg.sign(scale_delta_y)

    total_half_extent_x := dynamic_collider.half_extent_x + static_collider.half_extent_x
    total_half_extent_y := dynamic_collider.half_extent_y + static_collider.half_extent_y

    near_time_x := (dynamic_collider.center_x - signed_delta_x * total_half_extent_x - static_collider.center_x) * scale_delta_x
    near_time_y := (dynamic_collider.center_y - signed_delta_y * total_half_extent_y - static_collider.center_y) * scale_delta_y

    far_time_x := (dynamic_collider.center_x + signed_delta_x * total_half_extent_x - static_collider.center_x) * scale_delta_x
    far_time_y := (dynamic_collider.center_y + signed_delta_y * total_half_extent_y - static_collider.center_y) * scale_delta_y

    if near_time_x > far_time_y || near_time_y > far_time_x{
        return hit
    }

    near_time := near_time_x > near_time_y ? near_time_x : near_time_y
    far_time := far_time_x < far_time_y ? far_time_x : far_time_y 

    if near_time >= 1 || far_time <= 0{
        return hit
    }

    hit.time = clamp(near_time, 0, 1)

    // dynamic_collider_min := [2]f32{dynamic_collider.center_x - dynamic_collider.half_extent_x, dynamic_collider.center_y - dynamic_collider.half_extent_y}
    // dynamic_collider_max := [2]f32{dynamic_collider.center_x + dynamic_collider.half_extent_x, dynamic_collider.center_y + dynamic_collider.half_extent_y}
    // static_collider_min :=  [2]f32{static_collider.center_x - static_collider.half_extent_x, static_collider.center_y - static_collider.half_extent_y}
    // static_collider_max := [2]f32{static_collider.center_x + static_collider.half_extent_x, static_collider.center_y + static_collider.half_extent_y}

    overlap_x := min(dynamic_collider.center_x + dynamic_collider.half_extent_x, static_collider.center_x + static_collider.half_extent_x) - max(dynamic_collider.center_x - dynamic_collider.half_extent_x, static_collider.center_x - static_collider.half_extent_x)
    overlap_y := min(dynamic_collider.center_y + dynamic_collider.half_extent_y, static_collider.center_y + static_collider.half_extent_y) - max(dynamic_collider.center_y - dynamic_collider.half_extent_y, static_collider.center_y - static_collider.half_extent_y)

    aabb_displacement := [2]f32{dynamic_collider.center_x, dynamic_collider.center_y} - [2]f32{static_collider.center_x, static_collider.center_y}
    
    horizontal_mask := int(overlap_x < overlap_y)
    contact_normal_mask : [2]f32= {f32(horizontal_mask), f32(1 - horizontal_mask)} 
    hit.contact_normal = linalg.sign(aabb_displacement) * contact_normal_mask

    //TODO: khal this doesn't seem to work.
    hit.delta_displacement.x = hit.time * -delta.x * hit.contact_normal.x
    hit.delta_displacement.y = hit.time * -delta.y * hit.contact_normal.y

    hit.contact_point.x = static_collider.center_x + delta.x * hit.time
    hit.contact_point.y = static_collider.center_y + delta.y * hit.time

    return hit
}

aabb_aabb_intersection :: proc (a,b : Collider) -> CollisionHit{
    hit : CollisionHit = CollisionHit{
        time = 1,
    }

    a_half := [2]f32{a.half_extent_x, a.half_extent_y}
    b_half := [2]f32{b.half_extent_x, b.half_extent_y} 
    a_origin := [2]f32{a.center_x, a.center_y} + a_half
    b_origin := [2]f32{b.center_x, b.center_y} + b_half
    
    displacement_vector := b_origin - a_origin
    overlap := (b_half + a_half) - {abs(displacement_vector.x),abs(displacement_vector.y)}

    if (linalg.ceil(overlap).x <= 0 || linalg.ceil(overlap).y <= 0){
        return hit
    }

    signed_displacement :[2]f32 = {math.sign(displacement_vector.x), math.sign(displacement_vector.y)}

    hit.collider = a

    collision_mask := int(overlap.x < overlap.y)
    mask : [2]f32= {f32(collision_mask), f32(1 - collision_mask)} 

    hit.delta_displacement = overlap * signed_displacement * mask
    hit.contact_normal = signed_displacement * mask
    hit.contact_point = ((a_origin + (a_half * signed_displacement)) * mask.x) + (b_origin * mask.y)


    hit.time = 0

    return hit
} 

// ////////////////////////////////////////////////////////////////////////////////////////


// //////////////////////////////// SWEEP TEST ///////////////////////////////////////////
aabb_aabb_sweep :: proc (dynamic_collider : Collider, velocity : Velocity, static_collider : Collider) -> CollisionSweep{
    sweep : CollisionSweep
    sweep.time = 1
    if (velocity.x == 0 && velocity.y == 0){
        sweep.pos.x = static_collider.center_x
        sweep.pos.y = static_collider.center_y

        sweep.hit = aabb_aabb_intersection(dynamic_collider,static_collider)
        return sweep
    }

    sweep.hit = aabb_segement_intersection(dynamic_collider, velocity, static_collider)

    if sweep.hit.time < 1{
        sweep.hit.collider = static_collider
        sweep.time = clamp(sweep.hit.time - math.F32_EPSILON, 0, 1)
        sweep.pos.x = static_collider.center_x + velocity.x * sweep.time
        sweep.pos.y = static_collider.center_y + velocity.y * sweep.time

        direction := linalg.normalize([2]f32{velocity.x, velocity.y})
        
        sweep.hit.contact_point = linalg.clamp(sweep.hit.contact_point + direction * [2]f32{static_collider.half_extent_x, static_collider.half_extent_y}, [2]f32{dynamic_collider.center_x, dynamic_collider.center_y} - [2]f32{dynamic_collider.half_extent_x , dynamic_collider.half_extent_y}, [2]f32{dynamic_collider.center_x, dynamic_collider.center_y} + [2]f32{dynamic_collider.half_extent_x, dynamic_collider.half_extent_y})
    }

    return sweep
}


sweep_aabb :: proc(dyn_collider : Collider, velocity : Velocity, static_collider : #soa[]Collider) -> (bool, CollisionSweep){
    nearest : CollisionSweep
    nearest.time = 1
    res := false

    nearest.pos.x = dyn_collider.center_x + velocity.x
    nearest.pos.y = dyn_collider.center_y + velocity.y

    for i := 0; i < len(static_collider); i += 1 {
        if dyn_collider != static_collider[i]{
            sweep := aabb_aabb_sweep(dyn_collider, velocity, static_collider[i])
            if (sweep.time < nearest.time){
                nearest = sweep
                res = true
                sweep.hit.collider = static_collider[i]
            }  
        } 
    }

    return res, nearest
}
/////////////////////////////////////////////////////////////////////////////////////



//TODO:khal Remove everything below
///////////////////////////// Collision Normal & Reflection /////////////////////////

collision_reflection :: proc "contextless" (intersection_point : [2]f32, movement_vector : [2]f32, intersection_time : f32, collision_normal : [2]f32) -> [2]f32{
    dot_product := 2.0 * ((movement_vector.x * collision_normal.x) + (movement_vector.y * collision_normal.y))
    
    remaining_intersection_time := 1.0 - intersection_time
    reflection_vector :=  remaining_intersection_time * (movement_vector - dot_product * collision_normal)
    
    return intersection_point + reflection_vector
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



// add_impulse :: #force_inline proc(physics : ^common.Physics, impulse_factor : f32, impulse_direction : mathematics.Vec2){
//     mass := 1.0 / physics.inverse_mass
//     impulse := impulse_direction * impulse_factor * mass

//     physics.velocity += impulse * physics.inverse_mass
// }

// add_friction_force :: #force_inline proc(physics : ^common.Physics, friction_coefficient : f32){

//     //N = m*g
//     //if surface is inclined then the formula would be N = m * g *cos(theta)
//     mass := 1.0 / physics.inverse_mass
//     normal_force := mass * gravity
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


