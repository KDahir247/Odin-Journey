package main;

import "vendor:sdl2"

import "container"
import "core:thread"
import "core:sync"
import "system"

import "core:prof/spall"


import "core:fmt"


@(init)
init_prof_buffer :: proc(){
	container.CREATE_PROFILER("ProfilerData.spall")
}


@(optimization_mode="size")
init_sdl2_win :: #force_inline  proc(window_descriptor : ^container.WINDOWS_DESC) -> ^sdl2.Window {
	

	sdl2.InitSubSystem(window_descriptor.Flags)

	sdl_window := sdl2.CreateWindow(
		"MyGame",
		sdl2.WINDOWPOS_CENTERED, 
		sdl2.WINDOWPOS_CENTERED,
		window_descriptor.GridDesc.GridWidth,
		window_descriptor.GridDesc.GridHeight,
		window_descriptor.WinFlags,
	)

	return sdl_window
}


main :: proc() {
	running := true

	sdl2_event : sdl2.Event
	sdl2_window : ^sdl2.Window

	
	window_info : ^sdl2.SysWMinfo = new(sdl2.SysWMinfo)
	shared_data : ^container.SharedContext = new(container.SharedContext)

	window_descriptor := container.WINDOWS_DESC{
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

	defer{
		
		free(shared_data)
		free(window_info)

		sdl2.DestroyWindow(sdl2_window)
		sdl2_window = nil

		sdl2.QuitSubSystem(window_descriptor.Flags)

		container.FREE_PROFILER()
	}

	container.BEGIN_EVENT("SDL Initialization")

	sdl2_window = init_sdl2_win(&window_descriptor)
	sdl2.GetWindowWMInfo(sdl2_window, window_info)
	
	container.END_EVENT()


	container.BEGIN_EVENT("Shared Data and Thread Creation")
	
	shared_data.Systems = container.SystemInitFlags{
		.DX11System,
		.GameSystem,
		.WindowSystem,
	}

	shared_data.Mutex = sync.Mutex{}
	shared_data.Cond = sync.Cond{}
	// This will store the process id (PID) we might change this later.
	context.user_index = 0
	context.user_ptr = shared_data

	//TODO: got to look at profiler x.x
	game_thread := thread.create_and_start(system.init_game_subsystem, context)
	render_thread := thread.create_and_start_with_data(window_info,system.init_render_subsystem, context)

	container.END_EVENT()

	for running{
		for sdl2.PollEvent(&sdl2_event){
			running = sdl2_event.type != sdl2.EventType.QUIT
		}
	}

	excl(&shared_data.Systems, container.System.WindowSystem)


	thread.join_multiple(game_thread, render_thread)

	

	
}
