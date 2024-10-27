package journey

import "core:sys/windows"

SECONDS :: 0x1
MILLISECOND :: 0x3E8
MICROSECOND :: 0xF4240
NANOSECOND :: 0x3B9ACA00

Win32GetTimeStamp :: proc() -> i64{
	timestamp : windows.LARGE_INTEGER
	windows.QueryPerformanceCounter(&timestamp)
	return i64(timestamp)
}

Win32ElapsedTime :: proc(previous_counter : i64, $unit : i64) -> i64 {
	timestamp_frequency : windows.LARGE_INTEGER 
	windows.QueryPerformanceFrequency(&timestamp_frequency)

	current_counter := Win32GetTimeStamp()

	return ((current_counter - previous_counter) * unit) / i64(timestamp_frequency)
}

@(optimization_mode="favor_size")
Win32FrequencyNS :: #force_inline proc() -> i64{
	timestamp_frequency : windows.LARGE_INTEGER
	windows.QueryPerformanceFrequency(&timestamp_frequency)
	return i64(1_000_000_000 / timestamp_frequency)
}


Win32FrequencyMS :: #force_inline proc() -> i64{
	timestamp_frequency : windows.LARGE_INTEGER
	windows.QueryPerformanceFrequency(&timestamp_frequency)
	return i64(1_000_000 / timestamp_frequency)
}

