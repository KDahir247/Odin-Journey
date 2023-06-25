package main;

import "core:thread"
import "core:sys/windows"
import "core:fmt"
import "core:mem"
import "core:sync"

import "vendor:sdl2"

import "ecs"
import "system"
import "common"

@(private)

@(init)
init_game :: proc(){
	///////////////// PROFILER ///////////////////////////
	common.CREATE_PROFILER("ProfilerData.spall")

	//////////////////// SDL2 ///////////////////////////
}

@(optimization_mode="size")
main :: proc() {
	window := new(common.Window)

	barrier := &sync.Barrier{}

	game_thread : ^thread.Thread
	audio_thread : ^thread.Thread
	ui_thread : ^thread.Thread
	render_thread : ^thread.Thread

	start_tick : windows.LARGE_INTEGER
	current_tick : windows.LARGE_INTEGER

	freq : windows.LARGE_INTEGER
	windows.QueryPerformanceFrequency(&freq)
	rcp_freq := 1.0 / f64(freq)

	running := true
	shared_data : common.SharedContext 
	

	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo 
	
	common.BEGIN_EVENT("Retrieving Window Info")

	sdl2.InitSubSystem(sdl2.InitFlags{sdl2.InitFlag.EVENTS})

    //TODO: khal pf
	sdl2_window := sdl2.CreateWindow(
		"MyGame",
		sdl2.WINDOWPOS_CENTERED, 
		sdl2.WINDOWPOS_CENTERED,
		1045, // 29 * 36 + 1 (WIDTH + CELL SIZE + OFFSET)
		613, // 17 * 36 + 1 (HEIGHT + CELL SIZE + OFFSET)
		sdl2.WindowFlags{
			sdl2.WindowFlag.SHOWN,
			sdl2.WindowFlag.RESIZABLE,
			sdl2.WindowFlag.ALLOW_HIGHDPI,
		},
	)

	sdl2.GetWindowWMInfo(sdl2_window, &window_info)

	window_handle := windows.HWND(window_info.info.win.window)

	window.handle = window_handle
	window.width = 1045
	window.height = 613

	defer{	
		excl(&shared_data.Systems, common.System.WindowSystem)
		excl(&shared_data.Systems, common.System.DX11System)
		excl(&shared_data.Systems, common.System.GameSystem)

		thread.destroy(game_thread)
		thread.destroy(render_thread)	
		thread.destroy(audio_thread)
		thread.destroy(ui_thread)

		ecs.deinit_ecs(&shared_data.ecs)

		free(window)

		sdl2.DestroyWindow(sdl2_window)
		sdl2.QuitSubSystem(sdl2.InitFlags{sdl2.InitFlag.EVENTS})

		common.FREE_PROFILER()
	}

	common.END_EVENT()

	common.BEGIN_EVENT("Constructing ECS Context")

	ecs_context := ecs.init_ecs()

	common.END_EVENT()

	common.BEGIN_EVENT("Shared Data and Thread Creation")
	
	sync.barrier_init(barrier, 2)

	DEFAULT_SYS :: common.SystemInitFlags{
		.DX11System,
		.GameSystem,
		.WindowSystem,
		//.UISystem,
		//.AudioSystem,
	}

	shared_data.Systems = DEFAULT_SYS

	shared_data.barrier = barrier
	shared_data.Mutex = {}
	shared_data.Cond = {}
	shared_data.ecs = ecs_context
	
	game_thread = thread.create(system.init_game_subsystem, thread.Thread_Priority.High)
	audio_thread = thread.create(system.init_audio_subsystem)
	ui_thread = thread.create(system.init_ui_subsystem)
	render_thread = thread.create(system.init_render_subsystem)

	game_thread.data = &shared_data
	audio_thread.data = &shared_data
	ui_thread.data = &shared_data
	render_thread.data = &shared_data
	render_thread.user_args[0] = window


	thread.start(game_thread)
	thread.start(render_thread) //defer render thread.
	thread.start(audio_thread)
	thread.start(ui_thread)

	common.END_EVENT()

	common.BEGIN_EVENT("Game loop")

	windows.QueryPerformanceCounter(&start_tick)

	for running{
		windows.QueryPerformanceCounter(&current_tick)
		//TODO: khal each thread will have thier own time. This doesn't make sense...
		shared_data.time = f64(current_tick - start_tick) * rcp_freq

		//TODO: khal we want to get delta time up and running 

		for sdl2.PollEvent(&sdl2_event){
			running = sdl2_event.type != sdl2.EventType.QUIT
		}


		//TODO: khal possible place editor here when implemented
	}

	common.END_EVENT()




}
