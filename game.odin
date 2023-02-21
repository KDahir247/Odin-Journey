package main;

when ODIN_DEBUG{
	import "core:fmt"
	import "core:mem"
}

import "ecs"

import ctx "context"
import "game"
import  "utility"

MS_CAP :: 17

// entity index 0 will be the resource entity.
// context.user_index is the player entity. To allow change in player in game.
// eg. starting as a evil bad guy in the level, but as the story progress you might want.
// to switch perspective to another character and play that character...
main :: proc() {
	//memory leak tracking.
	when ODIN_DEBUG {
		track : mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator =mem.tracking_allocator(&track)
	}

	game_config := utility.parse_game_config("config/game_config.json")

	core := new(ctx.Context)
	core^ = ctx.init(game_config)

	context.user_ptr = core
	// The second entity created is the player. (0 is for resource, 1 is for player)
	// this value will change when player is playing to switch between character in the story.
	// so order matter in the code layout.
	context.user_index = 1

	cxt := ecs.init_ecs()

	ctx.initialize_dynamic_resource()
	running := true;

	level: utility.LDTK_CONTEXT= utility.parse_level("level/basic.ldtk")
	configs := utility.parse_animation("config/animation/player.json",[8]string{"Idle", "Walk", "Jump", "Fall", "Roll", "Teleport_Start", "Teleport_End", "Attack"})
	
	game.create_game_entity("resource/padawan/pad.png",configs, {400,500}, 0, {0.1,0.2})
	game.create_game_level(&level)
	
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
		}
	}

	game.free_all_animation_entities()
	utility.free_level(&level)

	ctx.cleanup()
	context.user_ptr = nil
	free(core)
	
	ecs.deinit_ecs(&cxt)


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
