package physics

import "../mathematics"
import "../container"

import "core:math"

import "core:fmt"


//Update physics interal data.
integrate :: proc(physics : ^container.Physics, dt : f32){
    if physics.inverse_mass == 0{
        return
    }
    physics.position += physics.velocity * dt

    acc := physics.acceleration
    acc += (physics.inverse_mass * physics.accumulated_force)


    physics.velocity += acc * dt 
    physics.velocity *= math.pow(physics.damping, dt)

    physics.accumulated_force = 0
}

compute_length :: #force_inline proc "contextless"(velocity : mathematics.Vec2) -> f32{
    return math.sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
}


compute_direction :: #force_inline proc "contextless"(velocity : mathematics.Vec2) -> mathematics.Vec2{
    rcp_speed := 1.0 / compute_length(velocity)
    return velocity * rcp_speed
}

compute_seperation_velocity :: #force_inline proc(#no_alias physics, other : ^container.Physics, contact_normal : mathematics.Vec2) -> mathematics.Vec2{
    a := (physics.velocity - other.velocity)
    return (a.x * contact_normal.x) + (a.y * contact_normal.y)
}

compute_closing_velocity :: #force_inline proc(#no_alias physics, other : ^container.Physics, contact_normal : mathematics.Vec2) -> mathematics.Vec2{
    a := -(physics.velocity - other.velocity)
    return (a.x * contact_normal.x) + (a.y * contact_normal.y)
}

add_impulse :: #force_inline proc(physics : ^container.Physics, impulse_factor : f32, impulse_direction : mathematics.Vec2){
    mass := 1.0 / physics.inverse_mass
    impulse := impulse_direction * impulse_factor * mass

    physics.velocity += impulse * physics.inverse_mass
}

add_friction_force :: #force_inline proc(physics : ^container.Physics, friction_coefficient : f32){

    //N = m*g
    //if surface is inclined then the formula would be N = m * g *cos(theta)
    mass := 1.0 / physics.inverse_mass
    normal_force := mass * physics.acceleration.y
    friction := normal_force * friction_coefficient

    friction_force := -physics.velocity.x * friction
    add_force(physics, {friction_force, 0})
}

add_gravitation_force :: #force_inline proc(physics : ^container.Physics, gravity : mathematics.Vec2){
    
    if physics.inverse_mass == 0{
        return //Handle infinite mass and prevent dividing by zero.
    }
    
    physics_mass := 1.0 / physics.inverse_mass

    add_force(physics, gravity * physics_mass)
}

add_entity_spring :: #force_inline proc(#no_alias physics,other :^container.Physics ,rest_length : f32, spring_constraint : f32){
    force := physics.position - other.position
    
    magnitude := abs(compute_length(force) - rest_length)
    stiff_magnitude := -spring_constraint * magnitude
    
    force_direction := compute_direction(force) 

    add_force(physics,stiff_magnitude * force_direction)
}

add_bungee_spring :: #force_inline proc(#no_alias physics, other: ^container.Physics, rest_length : f32, spring_constraint : f32){
    force := physics.position - other.position

    force_length := compute_length(force)

    if (force_length <= rest_length){
        return
    }

    magnitude := (rest_length - force_length)
    stiff_magnitude := spring_constraint * magnitude

    force_direction := force / force_length

    add_force(physics,force_direction * -stiff_magnitude)
}

add_buoyancy_force :: #force_inline proc(physics : ^container.Physics, max_depth : f32, volume : f32, water_height : f32, liquid_density : f32){
    depth := physics.position.y

    if (depth >= water_height + max_depth){
        return
    }

    force :mathematics.Vec2 ={}

    if (depth <= water_height - max_depth){
        force.y = liquid_density * volume
        add_force(physics,force)
        return
    }

    force.y = liquid_density * volume * (depth - max_depth - water_height) / 2 * max_depth
    
    add_force(physics,force)
}

add_anchor_spring :: #force_inline proc(physics : ^container.Physics, anchor : mathematics.Vec2, rest_length : f32, spring_constrant : f32){
    force := physics.position - anchor

    magnitude := rest_length - compute_length(force)
    stiff_magnitude := spring_constrant * magnitude

    force_direction := compute_direction(force)

    add_force(physics, stiff_magnitude * force_direction)
}

add_drag_force :: #force_inline proc(physics : ^container.Physics, velocity_drag_coef : f32, sqr_velocity_drag_coef : f32){
    drag_coef := compute_length(physics.velocity)
    
    res := (velocity_drag_coef * drag_coef) + (sqr_velocity_drag_coef * drag_coef * drag_coef)

    force_norm := physics.velocity / drag_coef

    add_force(physics,force_norm * -res)
}

add_force :: #force_inline proc(physics : ^container.Physics, force : mathematics.Vec2){
    physics.accumulated_force += force
}

compute_interpenetration :: proc(#no_alias collider, collided : ^container.Physics, penetration : f32, contact_normal : mathematics.Vec2 = {0,1}){

    total_inv_mass := collider.inverse_mass + collided.inverse_mass
    
    if penetration <= 0 || total_inv_mass <= 0{
        return
    }

    penetration_resolution := penetration / total_inv_mass * contact_normal

    total_delta_pos_a := penetration_resolution * -collider.inverse_mass
    total_delta_pos_b := penetration_resolution * collided.inverse_mass


    collider.position += total_delta_pos_a
    collided.position += total_delta_pos_b
}


compute_contact_velocity :: proc(#no_alias collider, collided : ^container.Physics, restitution : f32, contact_normal : mathematics.Vec2 = {0,1}, dt : f32){
    displacement_velocity := collided.velocity - collider.velocity

    seperating_velocity := (displacement_velocity.x * contact_normal.x) + (displacement_velocity.y * contact_normal.y)
    total_inv_mass := collider.inverse_mass + collided.inverse_mass

    //seperating or stationary, so no impulse needed or Infinite mass impulse has no effect
    if seperating_velocity > 0 || total_inv_mass <= 0{
        return
    }

    new_seperating_velocity := -seperating_velocity * restitution

    acc_caused_velocity := collided.acceleration - collider.acceleration

    acc_caused_seperation_velocity := (acc_caused_velocity.x * contact_normal.x) + (acc_caused_velocity.y * contact_normal.y) * dt

    if acc_caused_seperation_velocity < 0{
        new_seperating_velocity += restitution * acc_caused_seperation_velocity

        if (new_seperating_velocity < 0){
            new_seperating_velocity = 0
        }
    }

    delta_velocity := new_seperating_velocity - seperating_velocity

    impulse := (delta_velocity / total_inv_mass) * contact_normal

    collider.velocity += impulse * -collider.inverse_mass
    collided.velocity += impulse * collided.inverse_mass
}

resolve_contacts :: proc(iteration : int, contacts : [dynamic]container.PhysicsContact, dt : f32){
    iteration_used := 0
    contact_num := len(contacts)
    for iteration_used < iteration {
        max :f32 = math.F32_MAX
        max_index := contact_num
        for i := 0; i < contact_num; i += 1 {
            // calculate seperating velocity
            contact := contacts[i].contacts
            displacement_velocity := contact[0].velocity - contact[1].velocity
            seperating_velocity := (displacement_velocity.x * contacts[i].contact_normal.x) + (displacement_velocity.y * contacts[i].contact_normal.y)

            if(seperating_velocity < max && seperating_velocity < 0 || contacts[i].penetration > 0){
                max = seperating_velocity
                max_index = i
            }

        }

        if max_index == contact_num{
            break
        }

        contact := contacts[max_index].contacts
        contact_normal := contacts[max_index].contact_normal
        compute_contact_velocity(&contact.x, &contact.y, 0.0, contact_normal,dt)
        compute_interpenetration(&contact.x, &contact.y, contacts[max_index].penetration,contact_normal)

        iteration_used = iteration_used + 1
    }
}