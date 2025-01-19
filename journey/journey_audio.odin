package journey

foreign import journey_audio "journey_audio.lib"

OpaqueHandle :: distinct rawptr

AudioStreamFlow :: enum{
  Render,
  Capture,
  All,
}

AudioStreamRole :: enum{
  Console,
  Multimedia,
  Communication,
}

AudioStreamCategory :: enum{
  Other,
  ForegroundOnlyMedia,
  BackgroundCapableMedia,
  Communication,
  Alerts,
  SoundEffects,
  GameEffects,
  GameMedia,
  GameChat,
  Speech,
  Movie,
  Media,
}

AudioFormat :: enum{
  PCM = 0x1,
  ADPCM = 0x2,
  Float = 0x3,
  Unknown = 0x4,
}

MemoryDescriptor :: struct{
  static_reserve : u32,
  static_commit : u32,
  ring_size : u32,
  _padding_ : u32,
}

DeviceDescriptor :: struct{
  flow : AudioStreamFlow,
  role : AudioStreamRole,
  category : AudioStreamCategory,
  periodicity : u32, //TODO:Khal simpler naming
}

//TODO:Khal implement me!
Device :: struct{
  client : rawptr,
  device : rawptr,

  streaming_handle : rawptr,
  rerouting_handle : rawptr,
  quit_handle : rawptr,

  max_buffer_capacity : u32,
  device_format : AudioFormat,
  channel_count : u32,
  bits_per_sample : u32,
  sample_per_second : u32,
  optimal_latency : u32,
}

RingBuffer :: struct{
buffer : rawptr,
size : u64,
write_index : u64,
read_index : u64,
}

Resource :: struct{
  ring : RingBuffer,
  alloc : rawptr,
  com : rawptr,
}

foreign journey_audio{
	JA_GetComAllocator :: proc "c"() -> rawptr ---
	JA_InitBackend :: proc "c" (mem_desc : ^MemoryDescriptor, resource : ^Resource) -> u32 ---
	JA_InitDevice :: proc "c" (device_desc : ^DeviceDescriptor, resource : ^Resource, device : ^Device) -> u32 ---
	JA_DeinitDevice :: proc "c" (device : ^Device) ---
}
