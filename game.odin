package main 

import "core:thread"

game_update :: proc(thread : ^thread.Thread){
	//Though idea
		/*
			Solution for Stutter: Optimize logic in game loop to maximize fps. Don't cap fps to arbitrary size, but the monitor fps.
								  When capping the fps don't trust sleeping the thread since the timing will be wrong, but rather sleep the thread for the majority  of the time
								  then do a spin wait for the small bit of time slice that should be capped.
								  If the FPS drops we can do interpolation to blend out the stutter.


			Solution for Juddering : have the game loop fps divisble by the monitor refresh rate. Ideally we want a 1:1 mapping eg. if the monitor refresh rate is 144hz then we want a 144 game loop fps and clamp it to it.
									 If that isn't possible make a 2:1 mapping where the game loop fps is 72 fps while the monitor is 144hz

			Vsync will be disabled. We will allow the user to use enable other synchronization such as Enhanced Sync, Adaptive VSync, FreeSync, and GSync.
			but if the user wants to enable vsync then it will be allowed.
		*/

		//FPS to Ms ==  (1 / FPS) * 1000 

		//Handle Screen judder (FPS should be cleanly divisable by the Montior Hertz)
		//So we need to handle if the game has a long delay for example if the game is running at a 72 cap fps, but there is a delay
		//which make the fps 60, we might delay the fps to make it divisble by the monitor.


		//Handle Screen stutter ()



}