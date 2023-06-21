package system

import "../container"
//import "../physics"
import "../ecs"
import "../mathematics"

// Currently we will support Dynamic with Static, We will support dynamic with dynamic in the future
// Update the collider position prior to calling this function.
collision_system :: proc(world : ^ecs.Context, dynamic_physics : []container.Physics, static_collider : []mathematics.AABB){
    // for physic in dynamic_physics {

    //     collided, sweep_result := physics.sweep_aabb(physic.collider, physic.velocity, static_collider)

    //     if collided{

            

    //         //We don't support rotation collsion yet.
           
    //         // there has been a collsion add it.
    //         // we want to make sure that the collision is only added once.
    //     }
    // }
}