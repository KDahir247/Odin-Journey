package system


import "core:math/linalg/hlsl"
import "core:thread"
import "core:fmt"

import "vendor:stb/image"
import "vendor:sdl2"

import "../container"
import "../ecs"




@(optimization_mode="size")
init_game_subsystem :: proc(){
    shared_data := cast(^container.SharedContext)context.user_ptr

    input := sdl2.GetKeyboardState(nil)

    player_batch_entity := ecs.create_entity(&shared_data.ecs)
    player_entity := ecs.create_entity(&shared_data.ecs)

    player_batch  :=  ecs.add_component_unchecked(&shared_data.ecs, player_batch_entity, container.SpriteBatch{
        sprite_batch = make_dynamic_array_len([dynamic]container.SpriteInstanceData, 2048),
        shader_cache = 0,
    })

    player_batch.texture = image.load("resource/sprite/padawan/pad.png", &player_batch.width, &player_batch.height, nil, 4)
   

    defer{
        fmt.println("cleaning game thread")

        container.sprite_batch_free(player_batch)
    }


    ecs.add_component_unchecked(&shared_data.ecs, player_entity, container.SpriteHandle{
        //player sprite parameters
        sprite_handle = container.sprite_batch_append(player_batch,container.SpriteInstanceData{
            transform = container.IDENTITY,
            hue_displacement = 0,
            src_rect = {0.0,0.0, f32(player_batch.width), f32(player_batch.height)},
        }),

        //Batch entity which has the player parameters
        batch_handle = uint(player_batch_entity),
    })
    

    for (container.System.WindowSystem in shared_data.Systems){



    }
}