package system


import "core:thread"

import "vendor:miniaudio"

import "../common"

//Will require addition parameters.
@(optimization_mode="size")
init_audio_subsystem :: proc(current_thread : ^thread.Thread){

    common.CREATE_PROFILER_BUFFER(u32(current_thread.id))

    common.BEGIN_EVENT("Audio Engine construction")

    //TODO: khal we will perferably use the low level implementation rather then the high level.
    sound_engine : miniaudio.engine
    sound_config : miniaudio.engine_config = miniaudio.engine_config_init()

    //TODO: khal pf
	miniaudio.engine_init(&sound_config, &sound_engine)

    common.END_EVENT()


    //TODO: khal TEST remove


    defer{
        miniaudio.engine_uninit(&sound_engine)


        common.FREE_PROFILER_BUFFER()
    }



	miniaudio.engine_play_sound(&sound_engine, "resource/audio/Dragon_level.mp3", nil)

    // for (common.System.WindowSystem in shared_data.Systems){
    //     thread.yield() // temp

        
    // }
}