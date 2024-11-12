package journey

import "core:mem"
import "core:mem/virtual"

import "vendor:miniaudio"

//TODO: Khal In the future we will deprecate this and move to raw wasapi implementation. Currently I want to quickly prototype and understand a bit of DSP and audio before doing the WASAPI implementation.


data_callback :: proc "c"(device : ^miniaudio.device, output_buffer, input_buffer : rawptr, frame_count : u32){
	decoder := (^miniaudio.decoder)(device.pUserData)
	
	miniaudio.decoder_read_pcm_frames(decoder, output_buffer, u64(frame_count), nil)


}


//


InitPlayback :: proc(arena : ^virtual.Arena){






}


//arena allocator
InitDevice :: proc(arena : ^virtual.Arena){
	decoder :=  new(miniaudio.decoder)
	
	res := miniaudio.decoder_init_file("resource/audio/Dragon_level.mp3", nil, decoder)

	target_backend : []miniaudio.backend  = []miniaudio.backend{miniaudio.backend.wasapi}
	
	ctx : miniaudio.context_type

	device, _ := virtual.new(arena, miniaudio.device)

	config := miniaudio.device_config_init(miniaudio.device_type.playback)
	config.playback.format = miniaudio.format.unknown
	config.playback.channels = 0
	config.sampleRate = 0
	config.dataCallback = data_callback
	config.pUserData = decoder

	//Note:Khal maybe we want to override some of the context config (allocation, threadsize). Context in miniaudio sit above device. There is only 1 context of to many device
	ctx_config := miniaudio.context_config_init()
	miniaudio.device_init_ex(raw_data(target_backend), 1, &ctx_config, &config, device)


	miniaudio.device_start(device)
	
}