package system


import "core:fmt"

import "vendor:stb/image"
import "vendor:sdl2"

import "../container"
import "../ecs"


@(optimization_mode="size")
init_game_subsystem :: proc(){
    container.CREATE_PROFILER_BUFFER()

    shared_data := cast(^container.SharedContext)context.user_ptr

    input := sdl2.GetKeyboardState(nil)

    container.BEGIN_EVENT("Player Batch Creation")

    player_batch_entity := ecs.create_entity(&shared_data.ecs)
    player_entity := ecs.create_entity(&shared_data.ecs)
    player_entity_1 := ecs.create_entity(&shared_data.ecs) //TODO: remove for testing


    player_batch  :=  ecs.add_component_unchecked(&shared_data.ecs, player_batch_entity, container.SpriteBatch{
        sprite_batch = make([dynamic]container.SpriteInstanceData),
        shader_cache = 0,
    })

    player_batch.texture = image.load("resource/sprite/padawan/pad.png", &player_batch.width, &player_batch.height, nil, 4)
   
    container.END_EVENT()

    defer{

        container.FREE_PROFILER_BUFFER()
        
        fmt.println("cleaning game thread")

        container.sprite_batch_free(player_batch)
    }

    container.BEGIN_EVENT("Player Entity Creation")

    ecs.add_component_unchecked(&shared_data.ecs, player_entity, container.SpriteHandle{
        //player sprite parameters
        sprite_handle = container.sprite_batch_append(player_batch,container.SpriteInstanceData{
            transform = container.IDENTITY,
            hue_displacement = 1,
            src_rect = {0.0,0.0, f32(player_batch.width), f32(player_batch.height)},
        }),

        //Batch entity which has the player parameters
        batch_handle = uint(player_batch_entity),
    })

    ecs.add_component_unchecked(&shared_data.ecs, player_entity_1, container.SpriteHandle{
        //player sprite parameters
        sprite_handle = container.sprite_batch_append(player_batch,container.SpriteInstanceData{
            transform = {
                1.0, 0.0, 0.0, 0.0,
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
    
    container.END_EVENT()


    for (container.System.WindowSystem in shared_data.Systems){
        


    }
}