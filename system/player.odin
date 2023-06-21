package system

import "../container"
import "../physics"
import "../mathematics"

import "core:math/linalg"

move_player :: #force_inline proc(player_physics : ^container.Physics, direction : mathematics.Vec2, movement_speed : mathematics.Vec2){
    normalized_direction_safe := linalg.vector_normalize0(direction)

    physics.add_force(player_physics, normalized_direction_safe * movement_speed)
}

handle_player_collision :: proc(player_physics : ^container.Physics, static_collider : []container.Physics,dt : f32){
    //TODO: pivot support 
    player_physics.collider.origin = player_physics.position + player_physics.collider.half 

    player_physics.grounded = false
    
    for col in static_collider{
       hit := physics.aabb_aabb_intersection(player_physics.collider, col.collider)

        penetration := (hit.delta_displacement.x * hit.contact_normal.x) + (hit.delta_displacement.y * hit.contact_normal.y) - 0.001

		physics.compute_contact_velocity(player_physics,&container.Physics{}, 0.0, hit.contact_normal, dt)
		physics.compute_interpenetration(player_physics,&container.Physics{},penetration,hit.contact_normal)

        if hit.contact_normal == {0, 1}{
            player_physics.grounded = true
        }
    }
    // collided, sweep_result := physics.sweep_aabb(player_physics, static_collider)

    // if collided{
    //     penetration := sweep_result.hit.delta_displacement.y - 0.001

	// 	physics.compute_contact_velocity(&container.Physics{},player_physics, 0.0, {0,-1}, dt)
	// 	physics.compute_interpenetration(&container.Physics{},player_physics,penetration,{0, -1})
    // }

}