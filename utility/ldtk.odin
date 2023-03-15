package utility

import "../mathematics"

import "core:encoding/json"
import "core:os"
import "core:strconv"
import "core:intrinsics"
import "core:strings"

HEXADECIMAL_BASE :: 16

// Simpified..
LDTK_LEVEL_SIMPLIFIED :: struct{
    identifier : string,
    uid : string,
    background_color : [3]f32,
    x : i64,
    y : i64,
    width : i64,
    height : i64,
}

LDTK_NEIGHBOUR_SIMPLIFIED :: struct{
    level_uid : string,
    direction : u8,
}

LDTK_LAYER_IMG :: struct(len : int){
    // bg, background, collision, wall shadow.
     layer_imgs : [len]string,
}   

LDTK_ENTITY_SIMPLIFIED :: struct{
    idenifier : string,
    uid : string,
    layer : string,
    x : i64,
    y : i64,
    width : i64,
    height : i64,
    //custom_fields : container,
}

LDTK_CONTEXT_SIMPLIFIED :: struct(len : int){
    level : LDTK_LEVEL_SIMPLIFIED,
    ldtk_neighbours : [dynamic]LDTK_NEIGHBOUR_SIMPLIFIED,
    img : LDTK_LAYER_IMG(len),
    entities : [dynamic]LDTK_ENTITY_SIMPLIFIED,
}

parse_ldtk_simplified :: proc($path : string, $layer_count : int) -> LDTK_CONTEXT_SIMPLIFIED(layer_count){
    ldtk_level :LDTK_LEVEL= {} 
    ldtk_level_img : LDTK_LAYER_IMG(layer_count) ={}
    ldtk_entities_collection := make([dynamic]LDTK_ENTITY)

    data, _ := os.read_entire_file_from_filename(path)
    defer delete(data)

    ldtk_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)
    defer json.destroy_value(ldtk_json)

    ldtk_level_root := ldtk_json.(json.Object)

    // Level
    ldtk_level.identifier = ldtk_level_root["identifier"].(json.String)
    ldtk_level.uid = ldtk_level_root["uniqueIdentifer"].(json.String)
    
    ldtk_level.x = ldtk_level_root["x"].(json.Integer)
    ldtk_level.y = ldtk_level_root["y"].(json.Integer)

    ldtk_level.width = ldtk_level_root["width"].(json.Integer)
    ldtk_level.height = ldtk_level_root["height"].(json.Integer)
    
    ldtk_background_color_str := ldtk_level_root["bgColor"].(json.String)
    color_code,err := strconv.parse_int(ldtk_background_color_str[1:], HEXADECIMAL_BASE)
    ldtk_level.background_color = hex_to_rgb(color_code, false)

    // Neighbour
    ldtk_neighbour_levels := ldtk_level_root["neighbourLevels"].(json.Array)
    ldtk_neighbour_collection := make_dynamic_array_len([dynamic]LDTK_NEIGHBOUR, len(ldtk_neighbour_levels))

    // Iterate over the neighbouring level
    for ldtk_neighbour, index in ldtk_neighbour_levels{
        ldtk_neighbour_obj := ldtk_neighbour.(json.Object)

        ldtk_neighbour_collection[index].level_uid = ldtk_neighbour_obj["levelIid"].(json.String)
        ldtk_neighbour_direction := ldtk_neighbour_obj["dir"].(json.String)
        
        compass_map := map[string]u8{
            "n" = 0,
            "e" = 1,
            "s" = 2,
            "w" = 3,
        }
        ldtk_neighbour_collection[index].direction = compass_map[ldtk_neighbour_direction]
    }

    // Layers
    layers :[layer_count]string= {}

    ldtk_level_layers := ldtk_level_root["layers"].(json.Array)
    
    // Iterate over the level images 
    for ldtk_layer, index in ldtk_level_layers{
        layers[index] = ldtk_layer.(json.String)
    }

    ldtk_level_img.layer_imgs = layers

    // Entity
    // How can we retrieve all entities
    entities_obj := ldtk_level_root["entities"].(json.Object)
   
    // Get the Entity Category
    for entity_tag, entity_category in entities_obj{
       entity_array := entity_category.(json.Array)

       // Iterate over the Entity/s array
       for entity in entity_array {
        entity_obj := entity.(json.Object)

        entity_id := entity_obj["id"].(json.String)
        entity_iid := entity_obj["iid"].(json.String)
        entity_layer := entity_obj["layer"].(json.String)

        entity_x := entity_obj["x"].(json.Integer)
        entity_y := entity_obj["y"].(json.Integer)
        entity_width := entity_obj["width"].(json.Integer)
        entity_height := entity_obj["height"].(json.Integer)

        entity := LDTK_ENTITY{
            idenifier = entity_id,
            uid = entity_iid,
            layer = entity_layer,
            x = entity_x,
            y = entity_y,
            width = entity_width,
            height = entity_height,
        }

        append(&ldtk_entities_collection, entity)

        //TODO: khal How will i get custom data there is not concrete type??
       }
    }

    ldtk_context := LDTK_CONTEXT_SIMPLIFIED(layer_count){
        level = ldtk_level,
        ldtk_neighbours = ldtk_neighbour_collection,
        img = ldtk_level_img,
        entities = ldtk_entities_collection,
    }

    return ldtk_context
}


free_ldtk_simplfied_context :: proc(ctx : ^LDTK_CONTEXT_SIMPLIFIED($E))
where E > 0
{ 
    delete(ctx.ldtk_neighbours)
    delete(ctx.entities)
}

//-------------------------------------------------------------------------------

LDTK_LEVELS ::struct{
    levels : [dynamic]LDTK_LEVEL,
}

// LDTK_LAYER_DEFINITION :: struct{
//     parallax_factor : mathematics.Vec3,
//     pixel_offset : mathematics.Vec2,
//     auto_layer : Maybe(LDTK_LAYER_AUTO_LAYER),

//     uid : f64,
//     cell_size : f64,
//     opacity : f64,

//     int_grid : [dynamic]LDTK_INT_GRID_VALUE,
// }

// //TODO: khal this isn't used..
// LDTK_LAYER_AUTO_LAYER :: struct{
//     autoSourceLayerDefUid : f64,
//     tilesetDefUid : f64,
// }

// // Don't need the img
// LDTK_ENTITY_DEFINITION :: struct{   
//     //color : mathematics.Vec3,
//     // Width, Height
//     dimension : mathematics.Vec2,
//     pivot : mathematics.Vec2,
//     uid : f64,
// }


// LDTK_INT_GRID_VALUE :: struct{
//     identifier : string,
//     color : mathematics.Vec3,
//     value : f64,
// }

LDTK_LEVEL :: struct{
    orientation : mathematics.Vec3i,
    dimension : mathematics.Vec2i,
    background_color : mathematics.Vec3,

    uid : i64,

    layer_instances : [dynamic]LDTK_LAYER_INSTANCE,
}

LDTK_TILESET_DEFINITION :: struct{
    dimension : mathematics.Vec2i,
    grid_dimension : mathematics.Vec2i,
    grid_size : i64,
    spacing : i64,
    padding : i64,
    uid : i64,
}

LDTK_ENTITY_INSTANCE :: struct{
    dimension : mathematics.Vec2i,
    pixel : mathematics.Vec2i,
    def_uid : i64,
}

LDTK_AUTO_LAYER_TILE :: struct{
    src : mathematics.Vec2i,
    pixel : mathematics.Vec2i,
    tile_id : i64,
    render_flip : i64,
}

LDTK_LAYER_INSTANCE :: struct{
    tile_definition : LDTK_TILESET_DEFINITION,
    
    offset : mathematics.Vec2i,
    grid_dimension : mathematics.Vec2i,
    level_id : i64,

    cell_size : i64,
    texture_path : cstring,
    opacity : i64,
    //  __type, levelId, gridTiles

    int_grid_csv : [dynamic]int,
    entity_instances : [dynamic]LDTK_ENTITY_INSTANCE,
    auto_layer_tiles : [dynamic]LDTK_AUTO_LAYER_TILE,
}


parse_levels_ldtk :: proc($path : string) -> LDTK_LEVELS{

    ldtk_cxt := LDTK_LEVELS{}

    ldtk_level_collection := make([dynamic]LDTK_LEVEL)
    
    data, _ := os.read_entire_file_from_filename(path)
    defer delete(data)

    ldtk_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)
    defer json.destroy_value(ldtk_json)

    ldtk_world := ldtk_json.(json.Object)
    
    ldtk_world_definitions := ldtk_world["defs"].(json.Object);

    ldtk_world_tileset_definitions := ldtk_world_definitions["tilesets"].(json.Array)

    ldtk_levels := ldtk_world["levels"].(json.Array)

    for ldtk_level in ldtk_levels{
        layer_instance_collection := make([dynamic]LDTK_LAYER_INSTANCE)

        ldtk_lv := LDTK_LEVEL{}

        ldtk_level_obj := ldtk_level.(json.Object)

        //TODO: khal full implemetation isn't completed. 
        //__bgPos(only for background img), bgRelPath

        ldtk_lv.uid = ldtk_level_obj["uid"].(json.Integer)

        ldtk_level_bg_color_str := ldtk_level_obj["__bgColor"].(json.String)
        color_code,_ := strconv.parse_int(ldtk_level_bg_color_str[1:], HEXADECIMAL_BASE)
        ldtk_level_background_color := hex_to_rgb(color_code, false)

        ldtk_lv.background_color = mathematics.Vec3{
            ldtk_level_background_color.r,
            ldtk_level_background_color.g,
            ldtk_level_background_color.b,
        }

        ldtk_lv.orientation = mathematics.Vec3i{
            int(ldtk_level_obj["worldX"].(json.Integer)),
            int(ldtk_level_obj["worldY"].(json.Integer)),
            int(ldtk_level_obj["worldDepth"].(json.Integer)),
        }

        ldtk_lv.dimension = mathematics.Vec2i{
            int(ldtk_level_obj["pxWid"].(json.Integer)),
            int(ldtk_level_obj["pxHei"].(json.Integer)),
        }

        ldtk_level_layer_instances := ldtk_level_obj["layerInstances"].(json.Array)

        for ldtk_level_layer_instance in ldtk_level_layer_instances{
            int_grid_csv_collection := make([dynamic]int)
            auto_layer_tiles_collection := make([dynamic]LDTK_AUTO_LAYER_TILE)
            entity_instance_collection := make([dynamic]LDTK_ENTITY_INSTANCE)
    
            //TODO: khal full implemetation isn't completed. 
            //  __type, levelId, gridTiles
            ldtk_level_layer := LDTK_LAYER_INSTANCE{}

            ldtk_level_layer_obj := ldtk_level_layer_instance.(json.Object)

            if ldtk_level_layer_obj["visible"].(json.Boolean){
                ldtk_level_layer.level_id = ldtk_level_layer_obj["levelId"].(json.Integer)
                tile_def_uid := ldtk_level_layer_obj["__tilesetDefUid"].(json.Integer) or_else 0

                ldtk_level_layer.cell_size = ldtk_level_layer_obj["__gridSize"].(json.Integer)
                ldtk_level_layer.opacity = ldtk_level_layer_obj["__opacity"].(json.Integer)
                ldtk_level_layer.texture_path = strings.clone_to_cstring(ldtk_level_layer_obj["__tilesetRelPath"].(json.String) or_else "")

                ldtk_level_layer.offset = mathematics.Vec2i{
                    int(ldtk_level_layer_obj["__pxTotalOffsetX"].(json.Integer)),
                    int(ldtk_level_layer_obj["__pxTotalOffsetY"].(json.Integer)),
                }

                ldtk_level_layer.grid_dimension = mathematics.Vec2i{
                    int(ldtk_level_layer_obj["__cWid"].(json.Integer)),
                    int(ldtk_level_layer_obj["__cHei"].(json.Integer)),
                }

                ldtk_level_layer_int_grid_csv := ldtk_level_layer_obj["intGridCsv"].(json.Array)

                for val in ldtk_level_layer_int_grid_csv{
                    int_val := int(val.(json.Integer))

                    append(&int_grid_csv_collection, int_val)
                }

                ldtk_level_auto_layer_tiles :=  ldtk_level_layer_obj["autoLayerTiles"].(json.Array)

                for ldtk_level_auto_tile in ldtk_level_auto_layer_tiles{
                    auto_layer_tile := LDTK_AUTO_LAYER_TILE{}

                    ldtk_level_auto_tile_obj := ldtk_level_auto_tile.(json.Object)

                    ldtk_level_auto_tile_px := ldtk_level_auto_tile_obj["px"].(json.Array)

                    #no_bounds_check{
                        auto_layer_tile.pixel = mathematics.Vec2i{
                            int(ldtk_level_auto_tile_px[0].(json.Integer)),
                            int(ldtk_level_auto_tile_px[1].(json.Integer)),
                        }
                    }

                    ldtk_level_auto_tile_src := ldtk_level_auto_tile_obj["src"].(json.Array)

                    #no_bounds_check{
                        auto_layer_tile.src = mathematics.Vec2i{
                            int(ldtk_level_auto_tile_src[0].(json.Integer)),
                            int(ldtk_level_auto_tile_src[1].(json.Integer)),
                        }
                    }

                    render_flip := ldtk_level_auto_tile_obj["f"].(json.Integer)
                    render_flip_x := render_flip & 1
                    render_fip_y := (render_flip>>1)&1

                    auto_layer_tile.render_flip = (render_flip_x == 1 ? 0x00000001 : 0x00000000) |
                    (render_fip_y == 1 ? 0x00000002 : 0x00000000)

                    auto_layer_tile.tile_id = ldtk_level_auto_tile_obj["t"].(json.Integer)

                    append(&auto_layer_tiles_collection, auto_layer_tile)
                }

                ldtk_level_entity_instances := ldtk_level_layer_obj["entityInstances"].(json.Array)

                for ldtk_level_entity in ldtk_level_entity_instances{
                    level_entity := LDTK_ENTITY_INSTANCE{}

                    ldtk_level_entity_obj := ldtk_level_entity.(json.Object)

                    level_entity.dimension = mathematics.Vec2i{
                        int(ldtk_level_entity_obj["width"].(json.Integer)),
                        int(ldtk_level_entity_obj["height"].(json.Integer)),
                    }

                    level_entity.def_uid = ldtk_level_entity_obj["defUid"].(json.Integer)

                    ldtk_level_entity_pos := ldtk_level_entity_obj["px"].(json.Array)

                    #no_bounds_check{
                        level_entity.pixel = mathematics.Vec2i{
                            int(ldtk_level_entity_pos[0].(json.Integer)),
                            int(ldtk_level_entity_pos[1].(json.Integer)),
                        }
                    }

                    append(&entity_instance_collection, level_entity)
                }
            
            ldtk_level_layer.auto_layer_tiles = auto_layer_tiles_collection
            ldtk_level_layer.entity_instances = entity_instance_collection
            ldtk_level_layer.int_grid_csv = int_grid_csv_collection

            
            for tile_def in ldtk_world_tileset_definitions{
                ldtk_tile_obj := tile_def.(json.Object)

                if tile_def_uid == ldtk_tile_obj["uid"].(json.Integer){

                    ldtk_level_layer.tile_definition.uid = ldtk_tile_obj["uid"].(json.Integer)

                    ldtk_level_layer.tile_definition.grid_dimension = mathematics.Vec2i{
                        int(ldtk_tile_obj["__cWid"].(json.Integer)),
                        int(ldtk_tile_obj["__cHei"].(json.Integer)),
                    }
            
                    ldtk_level_layer.tile_definition.dimension = mathematics.Vec2i{
                        int(ldtk_tile_obj["pxWid"].(json.Integer)),
                        int(ldtk_tile_obj["pxHei"].(json.Integer)),
                    }
            
                    ldtk_level_layer.tile_definition.grid_size = ldtk_tile_obj["tileGridSize"].(json.Integer)
            
                    ldtk_level_layer.tile_definition.spacing = ldtk_tile_obj["spacing"].(json.Integer)
                    ldtk_level_layer.tile_definition.padding = ldtk_tile_obj["padding"].(json.Integer)
                }
            }
        
            append(&layer_instance_collection, ldtk_level_layer)
            }
        }

        ldtk_lv.layer_instances = layer_instance_collection

        append(&ldtk_level_collection, ldtk_lv)
    }

    ldtk_cxt.levels = ldtk_level_collection

    return ldtk_cxt
}

get_tile_texture_pos :: #force_inline proc(tile_id : int, tile : LDTK_TILESET_DEFINITION) -> mathematics.Vec2i{
    
    grid_width := tile.dimension.x / int(tile.grid_size)
    
    grid_tile := mathematics.Vec2i{
        tile_id % grid_width,
        tile_id / grid_width,
    }

    grid_spacing := int(tile.grid_size + tile.spacing)

    return grid_tile * grid_spacing + int(tile.padding)
} 

get_tile_position :: #force_inline proc(grid_pos : mathematics.Vec2i #any_int cell_size : int, offset : mathematics.Vec2i) -> mathematics.Vec2i{
    return grid_pos * cell_size + offset
}

get_tile_grid_position :: #force_inline proc(coord_id : int, grid_width : int) -> mathematics.Vec2i{
    y := coord_id / grid_width
    x := coord_id % grid_width

    return mathematics.Vec2i{x,y}
}

get_tile_world_position :: #force_inline proc(grid_pos : mathematics.Vec2i, layer_grid_dimension : mathematics.Vec2i, #any_int layer_cell_size : int, #any_int layer_offset : int,) -> mathematics.Vec2i{
    pos := get_tile_position(grid_pos,layer_cell_size, layer_offset)

    orientation := layer_grid_dimension * layer_cell_size

    return pos + orientation
}

get_tile_texture_rect :: #force_inline proc(#any_int tile_id : int, tile : LDTK_TILESET_DEFINITION) -> mathematics.Vec4i{
    tile_texture_pos := get_tile_texture_pos(tile_id, tile)

    return mathematics.Vec4i{
        tile_texture_pos.x,
        tile_texture_pos.y,
        int(tile.grid_size),
        int(tile.grid_size),
    }
}

get_tile_vertices :: proc(){
    //TODO: khal implement this.
}

get_layer_coord_id_at :: #force_inline proc(pos : mathematics.Vec2i, grid_width : int, #any_int cell_size : int) -> int{
    return (pos.x + pos.y * grid_width) / cell_size
}

free_ldtk_levels :: proc(ldtk_lv : ^LDTK_LEVELS){

    for level in ldtk_lv.levels{

        for layer in level.layer_instances{
            delete(layer.int_grid_csv)
            delete(layer.auto_layer_tiles)
            delete(layer.entity_instances)

        }
        delete(level.layer_instances)
    }
    delete(ldtk_lv.levels)
}
