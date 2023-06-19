package system


import "core:fmt"

import "vendor:miniaudio"

import "../container"

//Will require addition parameters.
@(optimization_mode="size")
init_audio_subsystem :: proc(){
    container.CREATE_PROFILER_BUFFER()

    shared_data := cast(^container.SharedContext)context.user_ptr

    container.BEGIN_EVENT("AUDIO Engine construction")

    //TODO: khal we will perferably use the low level implementation rather then the high level.
    sound_engine : miniaudio.engine
    sound_config : miniaudio.engine_config = miniaudio.engine_config_init()
	miniaudio.engine_init(&sound_config, &sound_engine)

    container.END_EVENT()


    //TEST
	miniaudio.engine_play_sound(&sound_engine, "resource/audio/Dragon_level.mp3", nil)


    defer{

        container.FREE_PROFILER_BUFFER()

        miniaudio.engine_uninit(&sound_engine)

        fmt.println("cleaning audio thread")
    }


    for (container.System.WindowSystem in shared_data.Systems){



    }
}