package main;

import "vendor:sdl2"

import "container"
import "core:thread"
import "core:sync"
import "system"

import "core:prof/spall"


import "core:fmt"
import "core:time"

import "ecs"

@(init)
init_prof_buffer :: proc(){
	container.CREATE_PROFILER("ProfilerData.spall")
}

main :: proc() {

	running := true

	sdl2_event : sdl2.Event
	
	shared_data : ^container.SharedContext = new(container.SharedContext)

	WINDOW_DESCRIPTOR :: container.WINDOWS_DESC{
		GridDesc = {
			1045, // 29 * 36 + 1 (WIDTH + CELL SIZE + OFFSET)
			613, // 17 * 36 + 1 (HEIGHT + CELL SIZE + OFFSET)
		},
		WinFlags = sdl2.WindowFlags{
			sdl2.WindowFlag.SHOWN,
			sdl2.WindowFlag.RESIZABLE,
			sdl2.WindowFlag.ALLOW_HIGHDPI,
			//sdl2.WindowFlag.FULLSCREEN,
		},
		Flags = sdl2.InitFlags{
			sdl2.InitFlag.EVENTS,
		},
	}

	container.BEGIN_EVENT("SDL Initialization")

	window_info : ^sdl2.SysWMinfo = new(sdl2.SysWMinfo)
	sdl2.InitSubSystem(WINDOW_DESCRIPTOR.Flags)

	sdl2_window := sdl2.CreateWindow(
		"MyGame",
		sdl2.WINDOWPOS_CENTERED, 
		sdl2.WINDOWPOS_CENTERED,
		WINDOW_DESCRIPTOR.GridDesc.GridWidth,
		WINDOW_DESCRIPTOR.GridDesc.GridHeight,
		WINDOW_DESCRIPTOR.WinFlags,
	)

	sdl2.GetWindowWMInfo(sdl2_window, window_info)
	
	defer{
		
		free(shared_data)
		free(window_info)

		sdl2.DestroyWindow(sdl2_window)
		sdl2_window = nil

		sdl2.QuitSubSystem(WINDOW_DESCRIPTOR.Flags)

		container.FREE_PROFILER()
	}

	container.END_EVENT()


	container.BEGIN_EVENT("Shared Data and Thread Creation")
	
	shared_data.Systems = container.SystemInitFlags{
		.DX11System,
		.GameSystem,
		.WindowSystem,
	}

	shared_data.Mutex = {}
	shared_data.Cond = {}
	shared_data.ecs = ecs.init_ecs()
	
	context.user_ptr = shared_data

	thread.run(system.init_game_subsystem, context)
	thread.run_with_data(window_info,system.init_render_subsystem, context)

	start_time := time.tick_now()._nsec

	container.END_EVENT()

	for running{

		shared_data.time = (time.tick_now()._nsec - start_time) / 1000_000

		for sdl2.PollEvent(&sdl2_event){
			running = sdl2_event.type != sdl2.EventType.QUIT
		}
	}

	excl(&shared_data.Systems, container.System.WindowSystem)
	ecs.deinit_ecs(&shared_data.ecs)

}
