package journey

import "core:thread"
import "core:sync"
import "core:sys/windows"
import "core:time"
import "core:mem/virtual"

import "core:fmt"

GameEntryPoint :: proc(current_thread : ^thread.Thread){
	static_virtual_arena: virtual.Arena
	err := virtual.arena_init_static(&static_virtual_arena, 4096 * 256)

	//set up audio
	//InitDevice(&static_virtual_arena)

	SLEEP_BIAS_NS :: 100 
	FIXED_DELTATIME_NS ::16_666_666

	display_info : windows.DEVMODEW
	windows.EnumDisplaySettingsW(nil, windows.ENUM_CURRENT_SETTINGS, &display_info)

	timestamp_frequency : windows.LARGE_INTEGER
	windows.QueryPerformanceFrequency(&timestamp_frequency)

	windows.timeBeginPeriod(1)

	target_nanosecond_for_frame := i64(1_000_000_000 / f64(display_info.dmDisplayFrequency))
	
	previous_counter := Win32GetTimeStamp()
	
	accumulated_time_ns : i64 

	on_startup : b32 = true
	
	//data race on user_index
	for (current_thread.user_index >= 1){

		current_counter := Win32GetTimeStamp()

		elapsed_nanosecond_for_frame := Win32ElapsedTime(previous_counter, NANOSECOND)
		
		if on_startup{
			//splashscreen
			//cutscene
			
			on_startup = false
		}else{
			accumulated_time_ns += elapsed_nanosecond_for_frame

			//in the fixed update are we going to store the previous and current to interpolate it? How about teleporting, or when a entity get destroy are we going to have a generational index?
			//We will probably do iterpolation using the most recent and the second most recent.
			for accumulated_time_ns >= FIXED_DELTATIME_NS{
				//physic loop here.

				accumulated_time_ns -= FIXED_DELTATIME_NS
			}
			//update, animation, audio here
		}		

		//We should wait on the render thread swap chain rather, since FPS is GPU and HZ is monitor????
		if elapsed_nanosecond_for_frame < target_nanosecond_for_frame{

			sleep_duration_ns :=  time.Duration(target_nanosecond_for_frame - elapsed_nanosecond_for_frame)
			
			if (sleep_duration_ns > SLEEP_BIAS_NS){
				//is this the right measurement.
				time.accurate_sleep(sleep_duration_ns)
			}
		}

		previous_counter = current_counter
	}

	windows.timeEndPeriod(1)
}