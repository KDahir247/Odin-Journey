package journey

foreign import journey_audio "journey_audio.lib"

HMODULE :: distinct rawptr

DitherParam :: struct{
	lcg_random : u32,
	lcg_multiplier : u32,
	lcg_increment : u32,
	lcg_modulo : u32,


	quantization_err : f32,
	boxcar_constant : f32,
}

AudioContext :: struct{

	CoInitialize : proc "stdcall" (),
	CoCreateInstance : proc "stdcall" (),
	CoUninitialize : proc "stdcall" (),
	CoMemAlloc : proc "stdcall" (),
	CoMemFree : proc "stdcall" (),
	CoMemRealloc : proc "stdcall" (),
	CoFreePropvariants : proc "stdcall" (),
	CoPropVariantClear : proc "stdcall" (),
	CoPropVariantCopy : proc "stdcall" (),

	ole32_module : HMODULE,

	AvSetMmThreadPriority : proc "stdcall" (),
	AvSetMmThreadCharacteristicW : proc "stdcall" (),
	AvQuerySystemResponsiveness : proc "stdcall" (),
	AvRevertMmThreadCharacteristics : proc "stdcall" (),

	avrt_module : HMODULE,

	dither_param : DitherParam,

}



foreign journey_audio{
	JAInitContext :: proc "c" (ctx : ^AudioContext, profile : u32) -> u32 ---

}
