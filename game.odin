package game;

import "core:fmt"
import "core:log"

import "ecs"

import game "context"
import  "utility"

import "vendor:sdl2"

FPS_CAP :: 60


// Clean up tomorrow
main :: proc() {
	core := new(game.Context)
	core^ = game.init()
	context.user_ptr = core

	cxt := ecs.init_ecs()

	dynamic_index := game.initialize_dynamic_resource()
	context.user_index = cast(int)dynamic_index

	defer game.cleanup()
	defer free(core)
	defer ecs.deinit_ecs(&cxt)

	running := true;

	utility.create_game_entity("resource/lidia.png", {400,300}, 0, {0.8,0.8}, {0,0,0,0})
	utility.load_texture("resource/Arkanos_0.png")


	// Load Title Screen (maybe a cool splash) first add menu and for loop till the press the play button
	// to prevent the logic code below from happening

	{
		for running{
			elapsed := utility.elapsed_frame_precise();

			running = game.handle_event()

			game.on_fixed_update()
			game.on_update()
			// todo calculate animation time...
			game.update_animation() // delta time
			game.on_late_update()
			
			game.on_render()

			utility.cap_frame_rate_precise(elapsed, 60)
		}
	}
}
