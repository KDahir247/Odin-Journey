package journey

// Sprite batches and Sprite
//  May also hold tilemapping?.


//TODO: khal this is legacy code need re-work below.

// create_game_entity ::proc($path : cstring, animator : uint, translation : [2]f32, rotation:f64, scale: [2]f32, player : bool) -> int{

// 	ctx := cast(^ctx.Context) context.user_ptr

//     game_entity := create_texture_entity(path)
    
//     if player{
//         ecs.add_component_unchecked(ctx.world, game_entity, container.Player{{container.CoolDownTimer{3000, 0}, container.CoolDownTimer{3000, 0}} })
//     }

//     ecs.add_component_unchecked(ctx.world, game_entity, container.Position{mathematics.Vec2{translation.x, translation.y}})
//     ecs.add_component_unchecked(ctx.world, game_entity, container.Rotation{rotation})
//     ecs.add_component_unchecked(ctx.world, game_entity, container.Scale{mathematics.Vec2{scale.x, scale.y}})

//     collider_component := mathematics.AABB{{translation.x , translation.y}, { 20,27  }}

//     physics_component := container.Physics{collider_component,mathematics.Vec2{translation.x,translation.y}, mathematics.Vec2{0, 0},mathematics.Vec2{0, 9.81},mathematics.Vec2{0,0},0.999, 1, 0.65, 0, false}

//     ecs.add_component_unchecked(ctx.world, game_entity, physics_component)

//     ecs.add_component_unchecked(ctx.world, game_entity, container.GameEntity{0, sdl2.RendererFlip.NONE})
    
//     animator_component := ecs.get_component_unchecked(ctx.world, ecs.Entity(animator), container.Animator)
    
//     ecs.add_component_unchecked(ctx.world, game_entity,container.Animator{
//         animator_component.current_animation,
//         animator_component.previous_frame,
//         animator_component.animation_time,
//         animator_component.animation_speed,
//         animator_component.clips,
//     })

//     ecs.destroy_entity(ctx.world, ecs.Entity(animator))

//     return int(game_entity)
// }


// move_player :: #force_inline proc(player_physics : ^common.Physics, direction : mathematics.Vec2, movement_speed : mathematics.Vec2){
//     normalized_direction_safe := linalg.vector_normalize0(direction)

//     physics.add_force(player_physics, normalized_direction_safe * movement_speed)
// }

// handle_player_collision :: proc(player_physics : ^common.Physics, static_collider : []common.Physics,dt : f32){
//     //TODO: pivot support 
//     player_physics.collider.origin = player_physics.position + player_physics.collider.half 

//     player_physics.grounded = false
    
//     for col in static_collider{
//        hit := physics.aabb_aabb_intersection(player_physics.collider, col.collider)

//         penetration := (hit.delta_displacement.x * hit.contact_normal.x) + (hit.delta_displacement.y * hit.contact_normal.y) - 0.001

// 		physics.compute_contact_velocity(player_physics,&common.Physics{}, 0.0, hit.contact_normal, dt)
// 		physics.compute_interpenetration(player_physics,&common.Physics{},penetration,hit.contact_normal)

//         if hit.contact_normal == {0, 1}{
//             player_physics.grounded = true
//         }
//     }
//     // collided, sweep_result := physics.sweep_aabb(player_physics, static_collider)

//     // if collided{
//     //     penetration := sweep_result.hit.delta_displacement.y - 0.001

// 	// 	physics.compute_contact_velocity(&common.Physics{},player_physics, 0.0, {0,-1}, dt)
// 	// 	physics.compute_interpenetration(&common.Physics{},player_physics,penetration,{0, -1})
//     // }

// }