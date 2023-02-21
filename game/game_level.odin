package game

import "../utility"
import "../ecs"
import ctx "../context"
import "../container"

import "core:fmt"
//We will pass by pointer, since the size of LDTK_CONTEXT is quite big :P
create_game_level :: proc(ldtk_ctx : ^utility.LDTK_CONTEXT){
	ctx := cast(^ctx.Context) context.user_ptr

    //TODO: my thought...
    //Create a level entity each level will have an array rect
    //and one sdl2 texture of the full img.

    for tile in ldtk_ctx^.tileset_def{
        
       
        // we need to create all the entity with tile first...
    }

 
    for lv in ldtk_ctx.levels{

        for layer in lv.layer_instances{



        }
    }
}