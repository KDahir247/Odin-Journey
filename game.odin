package main;

import ctx "context"
import "game"
import  "utility"
import "ecs"

when ODIN_DEBUG{
	import "core:fmt"
	import "core:mem"
}

MS_CAP :: 17

main :: proc() {
	//memory leak tracking.
	when ODIN_DEBUG {
		track : mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator =mem.tracking_allocator(&track)
	}
	game_config := utility.parse_game_config("config/game_config.json")
	levels := utility.parse_levels_ldtk("level/basic.ldtk")

	core := new(ctx.Context)
	core^ = ctx.init(game_config)

	context.user_ptr = core
	context.user_index = 1

	ctx.initialize_dynamic_resource()

	// Player must be loaded first..
	configs := utility.parse_animation("config/animation/player.json",[8]string{"Idle", "Walk", "Jump", "Fall", "Roll", "Teleport_Start", "Teleport_End", "Attack"})
	game.create_game_entity("resource/padawan/pad.png",configs, {450,100}, 0, {0.1,0.2})

	game.create_game_level(&levels)
	
	running := true;
	{
		for running{
			elapsed := utility.elapsed_frame_precise();

			running = ctx.handle_event()
			ctx.on_fixed_update()
			ctx.on_update()
			ctx.update_animation()
			ctx.on_late_update()
			ctx.on_render()

			utility.cap_frame_rate_precise(elapsed, MS_CAP)
			free_all(context.temp_allocator)
		}
	}

	game.free_all_animation_entities()
	game.free_game_level()
	utility.free_ldtk_levels(&levels)

	ctx.cleanup()
	context.user_ptr = nil
	free(core)
	
	when ODIN_DEBUG{
		// For debugging purpose (bad free, leak, etc...)
		for bad in track.bad_free_array{
			fmt.printf("%v bad \n\n", bad.location)
		}
		
		for _,leak in track.allocation_map{
			fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
		}

		mem.tracking_allocator_clear(&track)
		mem.tracking_allocator_destroy(&track)
	}
}
