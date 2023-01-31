package physics

import "../mathematics"

// Newton-Euler integration method, which is a
// linear approximation to the correct integral. may be inaccurate, but it is sufficient.
integrate :: proc(velocity : [3]f32, acceleration : [3]f32, drag : f32, delta_time : f32) -> [3]f32{
    //TODO: Khal finish implementation.
    return {0,0,0}
}


// A = 1 / m * f
compute_acceleration :: proc(inverse_mass : f32, force : mathematics.Vec2) -> mathematics.Vec2{
    return inverse_mass * force
}