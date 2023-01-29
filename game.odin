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
	context.user_index = int(dynamic_index)

	defer game.cleanup()
	defer free(core)
	defer ecs.deinit_ecs(&cxt)

	running := true;
	
	tex_path, configs := utility.parse_animation("config/animation/player.json",{"Idle", "Walk"})
	defer delete(configs)
	
	utility.create_game_entity(tex_path,configs, {400,300}, 0, {0.1	,0.2})

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
