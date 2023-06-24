package system

import "core:os"
import "core:fmt"
import "core:thread"
import "core:math/linalg/hlsl"

import "vendor:stb/image"
import "vendor:sdl2"


import "../ecs"
import "../common"


@(optimization_mode="size")
init_game_subsystem :: proc(current_thread : ^thread.Thread){
    shared_data := cast(^common.SharedContext)current_thread.data

    common.CREATE_PROFILER_BUFFER(current_thread.id)

    keyboard_snapshot := sdl2.GetKeyboardState(nil)

    common.BEGIN_EVENT("Player Batch Creation")

    player_entity := ecs.create_entity(&shared_data.ecs)
    player_entity_1 := ecs.create_entity(&shared_data.ecs) //TODO: remove for testing
    player_batch_entity := ecs.create_entity(&shared_data.ecs)


    player_batch  :=  ecs.add_component_unchecked(&shared_data.ecs, player_batch_entity, common.SpriteBatch{
        sprite_batch = make([dynamic]common.SpriteInstanceData),
        shader_cache = 0,
    })

    player_batch.texture = image.load("resource/sprite/padawan/pad.png", &player_batch.width, &player_batch.height, nil, 4)

    common.END_EVENT()

    defer{
        common.sprite_batch_free(player_batch)
        common.FREE_PROFILER_BUFFER()
    }

    common.BEGIN_EVENT("Player Entity Creation")

    ecs.add_component_unchecked(&shared_data.ecs, player_entity, common.SpriteHandle{
        //player sprite parameters
        sprite_handle = common.sprite_batch_append(player_batch,common.SpriteInstanceData{
            transform = {
                1.0, 0.0, 0.0, 200.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            },
            hue_displacement = 1,
            src_rect = {0.0,0.0, f32(player_batch.width), f32(player_batch.height)},
        }),

        //Batch entity which has the player parameters
        batch_handle = uint(player_batch_entity),
    })

    ecs.add_component_unchecked(&shared_data.ecs, player_entity_1, common.SpriteHandle{
        //player sprite parameters
        sprite_handle = common.sprite_batch_append(player_batch,common.SpriteInstanceData{
            transform = {
                1.0, 0.0, 0.0, 300.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            },
            hue_displacement = 1,
            src_rect = {0.0,0.0, f32(player_batch.width), f32(player_batch.height)},
        }),

        //Batch entity which has the player parameters
        batch_handle = uint(player_batch_entity),
    })
    
    common.END_EVENT()

    for (common.System.WindowSystem in shared_data.Systems){
        sprite_handles := ecs.get_component_list(&shared_data.ecs, common.SpriteHandle)

        //TODO: note khal the update loop time is not uniform
        for sprite in sprite_handles {
            common.BEGIN_EVENT("Simple ECS Upate")

            sprite_batch := ecs.get_component_unchecked(&shared_data.ecs, ecs.Entity(sprite.batch_handle), common.SpriteBatch)
            
            move_x_matrix : hlsl.float4x4 = {
                0.0, 0.0, 0.0, (f32(keyboard_snapshot[sdl2.Scancode.D]) - f32(keyboard_snapshot[sdl2.Scancode.A])) * 0.0001,
                0.0, 0.0, 0.0, 0.0,
                0.0, 0.0, 0.0, 0.0,
                0.0, 0.0, 0.0, 0.0,
            }

            sprite_batch.sprite_batch[sprite.sprite_handle].transform += move_x_matrix

            common.END_EVENT()
        }
    }
}