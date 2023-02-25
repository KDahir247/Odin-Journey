package utility

import "vendor:sdl2"

elapsed_frame_precise  :: proc() -> u64 {
    return sdl2.GetPerformanceCounter()
}


//target ms can be calculated by 1000 / target_fps
cap_frame_rate_precise :: proc(elapsed_time_precise  : u64, $target_ms : u64){
    current_time := sdl2.GetPerformanceCounter()
    
    elapsed_ms := (current_time - elapsed_time_precise) / sdl2.GetPerformanceFrequency() * 1000

    delay_factor := target_ms - elapsed_ms

    sdl2.Delay(u32(delay_factor))
}

