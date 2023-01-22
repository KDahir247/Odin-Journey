package game;

import "core:fmt"
import "core:log"

import "ecs"

import game "context"
import  "utility"

main :: proc() {
	core := new(game.Context)

	core^ = game.init().?
	cxt := ecs.init_ecs();

	context.user_ptr = core

	defer game.cleanup()
	defer free(core)
	defer ecs.deinit_ecs(&cxt)


	running := true;

	//load 
	utility.load_texture("resource/spritesheet.png")

	{
		for running{
			elapsed := utility.elapsed_frame();

			running = game.handle_event()
			game.on_fixed_update()
			game.on_update()
			game.on_render()

			utility.cap_frame_rate(elapsed, 60)
		}
	}
}
