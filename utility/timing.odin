package utility

import "vendor:sdl2"

elapsed_frame_precise  :: proc() -> u64 {
    return sdl2.GetPerformanceCounter()
}

elapsed_frame ::proc() -> u32 {
    return sdl2.GetTicks()
}

cap_frame_rate_precise :: proc(elapsed_time_precise  : u64, target_fps : u64){
    current_time := sdl2.GetPerformanceCounter()

    target_ms :u64= 1000 / target_fps

    elapsed_ms := (current_time - elapsed_time_precise ) / sdl2.GetPerformanceFrequency() * 1000

    delay_factor := target_ms - elapsed_ms

    sdl2.Delay(cast(u32)delay_factor)
}

cap_frame_rate :: proc(elapsed_time : u32, target_fps : u32){
    current_time := sdl2.GetTicks()

    target_ms := 1000 / target_fps

    frame_duration :=  current_time - elapsed_time
    delay := target_ms - frame_duration

    cap_delay := current_time - elapsed_time < target_ms ? delay : 0
    
    sdl2.Delay(cap_delay)
}