package journey

foreign import journey_audio "journey_audio.lib"

HMODULE :: distinct rawptr


MemoryDescriptor :: struct{
  static_reserve : u64,
  static_commit : u64,
  ring_size : u64,
  _padding_ : u64,
}

RingBuffer :: struct{
buffer : rawptr,
size : u64,
write_index : u64,
read_index : u64,
}


Resource :: struct{
  alloc : rawptr,
  ring : RingBuffer,
}


foreign journey_audio{
	JA_InitBackend :: proc "c" (mem_desc : ^MemoryDescriptor, resource : ^Resource) -> u32 ---
	//JAInitContext :: proc "c" (ctx : ^AudioContext, profile : u32) -> u32 ---

}
