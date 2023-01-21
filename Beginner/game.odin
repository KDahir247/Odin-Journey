package game;

import "core:fmt"
import "core:log"
import game "context"
import  "utility"

main :: proc() {
	core := new(game.Context)
	core^ = game.init().?

	context.user_ptr = core
	
	defer game.cleanup()
	defer free(core)

	//load 
	utility.load_texture("Resource/spritesheet.png")

	{
		running := true;
		
		for running{
			
			running = game.handle_event()
			game.on_fixed_update()
			game.on_update()
			game.on_render()
		}
	}
}
