package system

import "vendor:sdl2"
import "vendor:botan/keccak"

import "core:thread"
import "core:fmt"

import "../container"
import "../ecs"

init_game_subsystem :: proc(){
    shared_data := cast(^container.SharedContext)context.user_ptr

    input := sdl2.GetKeyboardState(nil)


    //Parse LDTK
    // Parse entity (Player Spawn)
    // Create the LDTK level and add to ecs.

    //Create the Player.
    player := ecs.create_entity(&shared_data.ecs)
    //TODO: not done.
    ecs.add_component_unchecked(&shared_data.ecs, player, container.SpriteCache{"resource/padawan/pad.png"})
    ecs.add_component_unchecked(&shared_data.ecs,player, container.ShaderCache{"sprite_instancing"})
    

    


    defer{
        fmt.println("cleaning game thread")
    }


    for (container.System.WindowSystem in shared_data.Systems){



    }
}