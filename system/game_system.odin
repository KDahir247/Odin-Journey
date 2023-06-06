package system

import "vendor:sdl2"

import "core:thread"
import "core:fmt"

import "../container"

init_game_subsystem :: proc(game_thread : ^thread.Thread){
    shared_data := cast(^container.SharedContext)context.user_ptr

    input := sdl2.GetKeyboardState(nil)


    //Create the Player.
    


    defer{
        fmt.println("cleaning game thread")
    }


    for (container.System.WindowSystem in shared_data.Systems){



    }
}