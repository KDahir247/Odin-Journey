package system

import "core:fmt"
import "core:thread"

//import "vendor:microui"

import "../common"

@(optimization_mode="size")
init_ui_subsystem :: proc(current_thread : ^thread.Thread){
    shared_data := cast(^common.SharedContext)current_thread.data

    common.CREATE_PROFILER_BUFFER(current_thread.id)


    defer{

        //fmt.println("cleaning game thread")

        common.FREE_PROFILER_BUFFER()
    }


    for (common.System.WindowSystem in shared_data.Systems){
        thread.yield() //temp


    }
}