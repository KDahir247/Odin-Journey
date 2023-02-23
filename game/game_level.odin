package game

import "../utility"
import "../ecs"
import ctx "../context"
import "../container"
import "../mathematics"

import "vendor:sdl2"
import "vendor:sdl2/image"

import "core:strings"
import "core:fmt"
//We will pass by pointer, since the size of LDTK_CONTEXT is quite big :P
create_game_level :: proc(ldtk_ctx : ^utility.LDTK_CONTEXT){
	ctx := cast(^ctx.Context) context.user_ptr

    for lv in ldtk_ctx.levels{
       

        for layer in lv.layer_instances{
            
            tile_path := ""
            tile_dimension := mathematics.Vec2{}

            layerdef := utility.LDTK_LAYER_DEFINITION{}
            tiledef := utility.LDTK_TILESET_DEFINITION{}

            for layer_def in ldtk_ctx.layer_def{
                if layer.layerdef_uid == layer_def.uid{
                    layerdef = layer_def
                }
            }

            for tile_def in ldtk_ctx.tileset_def{
                if layer.tiledef_uid == tile_def.uid{
                    tile_dimension = tile_def.dimension
                    tile_path = tile_def.tile_path
                    tiledef = tile_def
                }
            }

            c_path := strings.clone_to_cstring(tile_path)
            defer delete(c_path)

            tilemap_entity := ecs.create_entity(&ctx.world)
           
            tileset_texture := image.LoadTexture(ctx.renderer, c_path)
        
            tilemap_texture := sdl2.CreateTexture(ctx.renderer,
                ctx.pixel_format.format,
                sdl2.TextureAccess.TARGET,
                i32(lv.dimension.x),
                i32(lv.dimension.y),
            )

            sdl2.SetRenderTarget(ctx.renderer, tilemap_texture)
            for tile in layer.auto_layer_tiles{
                tileset_entity := ecs.create_entity(&ctx.world)
               
                coord_id := utility.get_layer_coord_id_at(mathematics.Vec2i{int(tile.pixel.x), int(tile.pixel.y)}, layer, layerdef)
                tile_grid_position := utility.get_tile_grid_position(coord_id, layer)
                tile_position := utility.get_tile_position(tile_grid_position,layerdef,layer)
                tile_texture_rect := utility.get_tile_texture_rect(int(tile.tile_id), tiledef)
                
                dst_rect := sdl2.Rect{
                    i32(tile_position.x),
                    i32(tile_position.y),
                    i32(layerdef.cell_size),
                    i32(layerdef.cell_size),
                }

                src_rect := sdl2.Rect{
                    i32(tile_texture_rect.x), //x
                    i32(tile_texture_rect.y), //y
                    i32(tile_texture_rect.z), //width
                    i32(tile_texture_rect.z), //height
                }

                flip_x := int(tile.render_flip) & 1
                flip_y := (int(tile.render_flip)>>1)&1

                flip := (flip_x == 1 ? 0x00000001 : 0x00000000) |
                 (flip_y == 1 ? 0x00000002 : 0x00000000)

                 //ecs.add_component(&ctx.world, tileset_entity, container.TileSet{src_rect,dst_rect,sdl2.RendererFlip(flip), tileset_texture})
                 sdl2.SetTextureBlendMode(tileset_texture, sdl2.BlendMode.NONE)

                 sdl2.RenderCopyEx(ctx.renderer,tileset_texture, &src_rect,&dst_rect,0,nil, sdl2.RendererFlip(flip))
                //add to tile collection for rendering or render..
            }
            sdl2.SetRenderTarget(ctx.renderer, nil)

            ecs.add_component(&ctx.world, tilemap_entity, container.TileMap{tilemap_texture, lv.orientation.xy})
        }
    }
}




free_game_level :: proc(){
	ctx := cast(^ctx.Context) context.user_ptr
    

    tile_sets,_ := ecs.get_component_list(&ctx.world, container.TileSet)

    tile_maps,_ := ecs.get_component_list(&ctx.world, container.TileMap)

    for tile in tile_sets{
        sdl2.DestroyTexture(tile.texture)
    }

    for tile_map in tile_maps{
        sdl2.DestroyTexture(tile_map.texture)
    }


}