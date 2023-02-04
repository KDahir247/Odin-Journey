package physics

import "../mathematics"
import "../container"
import "core:math/linalg"

integrate :: proc(physics : ^container.Physics, position : ^container.Position, direction : f32, delta_time : f32) {

    // infinite mass
    if physics.inverse_mass <= 0{
        position.value = mathematics.Vec2{0,0}
    }

    acceleration := mathematics.Vec2{physics.acceleration.x * direction, physics.acceleration.y}

    physics.velocity += acceleration * delta_time
    physics.velocity *= linalg.pow(physics.damping, delta_time)

    position.value += physics.velocity * delta_time * physics.acceleration * delta_time * delta_time * 0.5
}

add_force :: proc(physics : ^container.Physics, force : mathematics.Vec2){
    physics.accumulated_force += force
}

// A = 1 / m * f
compute_acceleration :: proc(inverse_mass : f32, force : mathematics.Vec2) -> mathematics.Vec2{
    return inverse_mass * force
}

