package system

import "core:fmt"

//import "vendor:microui"

import "../container"


@(optimization_mode="size")
init_ui_subsystem :: proc(){
    shared_data := cast(^container.SharedContext)context.user_ptr



    defer{
        fmt.println("cleaning ui thread")
    }


    for (container.System.WindowSystem in shared_data.Systems){



    }
}