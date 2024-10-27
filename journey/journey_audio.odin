package journey

foreign import journey_audio "journey_audio.lib"

HMODULE :: distinct rawptr

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

}



foreign journey_audio{
	JAInitContext :: proc "c" (ctx : ^AudioContext) -> u32 ---

}
