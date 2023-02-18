package utility

import "core:math/linalg"

import "vendor:sdl2"

elapsed_frame_precise  :: proc() -> u64 {
    return sdl2.GetPerformanceCounter()
}

elapsed_frame ::proc() -> u32 {
    return sdl2.GetTicks()
}

//target ms can be calculated by 1000 / target_fps
cap_frame_rate_precise :: proc(elapsed_time_precise  : u64, $target_ms : u64){
    current_time := sdl2.GetPerformanceCounter()
    
    elapsed_ms := (current_time - elapsed_time_precise) / sdl2.GetPerformanceFrequency() * 1000

    delay_factor := target_ms - elapsed_ms

    sdl2.Delay(u32(delay_factor))
}

//target ms can be calculated by 1000 / target_fps
cap_frame_rate :: proc(elapsed_time : u32, $target_ms : u32){
    current_time := sdl2.GetTicks()

    frame_duration :=  current_time - elapsed_time
    sign_val := linalg.sign(current_time - elapsed_time)
    remap_intermediate := sign_val + 1
    delay := target_ms - frame_duration

    remapper := remap_intermediate * 0.5
    cap_delay := delay * u32(remapper)
    
    sdl2.Delay(cap_delay)
}