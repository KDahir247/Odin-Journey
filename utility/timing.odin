package utility

import "vendor:sdl2"


elapsed_frame ::proc() -> u32 {
    return sdl2.GetTicks()
}

cap_frame_rate :: proc(elapsed_time : u32, target_fps : u32){

    current_time := sdl2.GetTicks()

    ms := 1000 / target_fps

    frame_duration :=  current_time - elapsed_time
    delay := ms - frame_duration

    cap_delay := current_time - elapsed_time < ms ? delay : 0
    
    sdl2.Delay(cap_delay)
}