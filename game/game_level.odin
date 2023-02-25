package game

import "../utility"
import "../ecs"
import ctx "../context"
import "../container"

import "vendor:sdl2"
import "vendor:sdl2/image"


create_game_level :: proc(ldtk_ctx : ^utility.LDTK_LEVELS){
	ctx := cast(^ctx.Context) context.user_ptr

    for lv in ldtk_ctx.levels{
        for layer in lv.layer_instances{

            opacity_factor := u8(255 * layer.opacity)

            defer delete(layer.texture_path)

            tilemap_entity := ecs.create_entity(&ctx.world)
            tileset_texture := image.LoadTexture(ctx.renderer, layer.texture_path)
        
            tilemap_texture := sdl2.CreateTexture(ctx.renderer,
                ctx.pixel_format.format,
                sdl2.TextureAccess.TARGET,
                i32(lv.dimension.x),
                i32(lv.dimension.y),
            )
            sdl2.SetRenderTarget(ctx.renderer, tilemap_texture)
            for tile in layer.auto_layer_tiles{
               
                coord_id := utility.get_layer_coord_id_at(tile.pixel, layer.grid_dimension.x, layer.cell_size)
                tile_grid_position := utility.get_tile_grid_position(coord_id, layer.grid_dimension.x)
                tile_position := utility.get_tile_position(tile_grid_position,layer.cell_size, layer.offset)
                tile_texture_rect := utility.get_tile_texture_rect(tile.tile_id, layer.tile_definition)
                
                dst_rect := sdl2.Rect{
                    i32(tile_position.x),
                    i32(tile_position.y),
                    i32(layer.cell_size),
                    i32(layer.cell_size),
                }

                src_rect := sdl2.Rect{
                    i32(tile_texture_rect.x), //x
                    i32(tile_texture_rect.y), //y
                    i32(tile_texture_rect.z), //width
                    i32(tile_texture_rect.z), //height
                }

                flip_x := tile.render_flip & 1
                flip_y := (tile.render_flip>>1)&1

                flip := (flip_x == 1 ? 0x00000001 : 0x00000000) |
                 (flip_y == 1 ? 0x00000002 : 0x00000000)

                 sdl2.SetTextureBlendMode(tileset_texture, sdl2.BlendMode.NONE)

                 sdl2.SetTextureAlphaMod(tileset_texture, opacity_factor)

                 sdl2.RenderCopyEx(ctx.renderer,tileset_texture, &src_rect,&dst_rect,0,nil, sdl2.RendererFlip(flip))
            }

            sdl2.SetRenderTarget(ctx.renderer, nil)

            sdl2.DestroyTexture(tileset_texture)

            ecs.add_component(&ctx.world, tilemap_entity, container.TileMap{tilemap_texture, lv.orientation.xy})
        }
    }
}


free_game_level :: proc(){
	ctx := cast(^ctx.Context) context.user_ptr
    
    tile_maps,_ := ecs.get_component_list(&ctx.world, container.TileMap)

    for tile_map in tile_maps{
        sdl2.DestroyTexture(tile_map.texture)
    }
}