package utility

import "core:encoding/json"
import "core:os"
import "core:strconv"
import "core:intrinsics"

import "../mathematics"
HEXADECIMAL_BASE :: 16

LDTK_CONTEXT_SIMPLIFIED :: struct(len : int){
    level : LDTK_LEVEL_SIMPLIFIED,
    ldtk_neighbours : [dynamic]LDTK_NEIGHBOUR_SIMPLIFIED,
    img : LDTK_LAYER_IMG(len),
    entities : [dynamic]LDTK_ENTITY_SIMPLIFIED,
}

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

LDTK_LAYER_IMG :: struct(len : int){
    // bg, background, collision, wall shadow.
     layer_imgs : [len]string,
}   

load_level :: proc{parse_ldtk_simplified, parse_ldtk}
free_level :: proc{free_ldtk_simplfied_context, free_ldtk_context}

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

LDTK_CONTEXT :: struct{
    iid : string,
    layer_def : [dynamic]LDTK_LAYER_DEFINITION,
    entity_def : [dynamic]LDTK_ENTITY_DEFINITION,
    tileset_def : [dynamic]LDTK_TILESET_DEFINITION,
    levels : [dynamic]LDTK_LEVEL,
}

LDTK_LAYER_DEFINITION :: struct{
    identifier : string,
    type : string,
    parallax_factor : mathematics.Vec3,
    pixel_offset : mathematics.Vec2,
    uid : f64,
    grid_size : f64,
    opacity : f64,

    auto_layer : Maybe(LDTK_LAYER_AUTO_LAYER),
    //value as key and identfier as value
    int_grid : map[f64]string,
}

//TODO: khal this isn't used..
LDTK_LAYER_AUTO_LAYER :: struct{
    autoSourceLayerDefUid : f64,
    tilesetDefUid : f64,
}

// Don't need the img
LDTK_ENTITY_DEFINITION :: struct{   
    identifier : string,
    //color : mathematics.Vec3,
    // Width, Height
    dimension : mathematics.Vec2,
    pivot : mathematics.Vec2,
    uid : f64,
}

LDTK_TILESET_DEFINITION :: struct{
    identifier : string,
    tile_path : string,
    dimension : mathematics.Vec2,
    grid_size : f64,
    spacing : f64,
    padding : f64,
    uid : f64,
}

LDTK_LEVEL :: struct{
    identifier : string,
    iid : string,
    
    orientation : mathematics.Vec3,

    dimension : mathematics.Vec2,
    background_color : mathematics.Vec3,

    uid : f64,

    layer_instances : [dynamic]LDTK_LAYER_INSTANCE,
}

LDTK_LAYER_INSTANCE :: struct{
    id : string,
    offset : mathematics.Vec2,
    level_id : f64,
    layerdef_uid : f64,

    entity_instances : [dynamic]LDTK_ENTITY_INSTANCE,
    auto_layer_tiles : [dynamic]LDTK_AUTO_LAYER_TILE,
    int_grid_csv : [dynamic]int,
}

LDTK_ENTITY_INSTANCE :: struct{
    iid : string,
    dimension : mathematics.Vec2,
    pixel : mathematics.Vec2,
    def_uid : f64,
}

LDTK_AUTO_LAYER_TILE :: struct{
    src : mathematics.Vec2,
    pixel : mathematics.Vec2,
    tile_id : f64,
    render_flip : f64,
}


// TODO: there is quite a bit of configuaration in ldtk that will alter the way to read data.
// eg. Export as png, saving level seperately.
parse_ldtk :: proc($path : string) -> LDTK_CONTEXT{

    // this will load by world not by level which is done by parse_level_simplified function.
    // world will contain a collection of level in the given world.
    // parse_ldtk function doesn't not support multiple world. Just a single world with multiple levels.
    // TODO: khal maybe make a function to support ldtk multiple world.. Maybe...
    ldtk_context := LDTK_CONTEXT{}

    ldtk_layer_def_collection := make([dynamic]LDTK_LAYER_DEFINITION)
    ldtk_entity_def_collection := make([dynamic]LDTK_ENTITY_DEFINITION)
    ldtk_tileset_def_collection := make([dynamic]LDTK_TILESET_DEFINITION)

    ldtk_level_collection := make([dynamic]LDTK_LEVEL)
 
    data, _ := os.read_entire_file_from_filename(path)
    defer delete(data)

    ldtk_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, false)
    defer json.destroy_value(ldtk_json)


    ldtk_world := ldtk_json.(json.Object)

    ldtk_context.iid = ldtk_world["iid"].(json.String)

    //ldtk_has_external_level := ldtk_world["externalLevels"].(json.Boolean)
    //ldtk_simplified_export := ldtk_world["simplifiedExport"].(json.Boolean)

    ldtk_world_definitions := ldtk_world["defs"].(json.Object);

    ldtk_world_layer_definitions := ldtk_world_definitions["layers"].(json.Array)

    for ldtk_layer_def in ldtk_world_layer_definitions{
        ldtk_layer_definition := LDTK_LAYER_DEFINITION{}
        ldtk_int_grid_values := make(map[f64]string)

        ldtk_layer_obj := ldtk_layer_def.(json.Object)

        ldtk_layer_definition.identifier = ldtk_layer_obj["identifier"].(json.String)
        ldtk_layer_definition.type = ldtk_layer_obj["type"].(json.String)
        ldtk_layer_definition.uid = ldtk_layer_obj["uid"].(json.Float)

        ldtk_layer_definition.opacity = ldtk_layer_obj["displayOpacity"].(json.Float)

        ldtk_layer_definition.grid_size = ldtk_layer_obj["gridSize"].(json.Float)
        
        ldtk_layer_parallax_scaling := i64(ldtk_layer_obj["parallaxScaling"].(json.Boolean))

        ldtk_layer_definition.parallax_factor = mathematics.Vec3{
            f32(ldtk_layer_obj["parallaxFactorX"].(json.Float)),
            f32(ldtk_layer_obj["parallaxFactorY"].(json.Float)),
            f32(ldtk_layer_parallax_scaling),
        }

        ldtk_layer_definition.pixel_offset = mathematics.Vec2{
            f32(ldtk_layer_obj["pxOffsetX"].(json.Float)),
            f32(ldtk_layer_obj["pxOffsetY"].(json.Float)),
        }

        ldtk_layer_type := ldtk_layer_obj["type"].(json.String)

        
        //TODO: khal add this to the struct... (later)
        if ldtk_layer_type == "AutoLayer"{
            auto_layer := LDTK_LAYER_AUTO_LAYER{}

            auto_layer.autoSourceLayerDefUid = ldtk_layer_obj["autoSourceLayerDefUid"].(json.Float)
            auto_layer.tilesetDefUid = ldtk_layer_obj["tilesetDefUid"].(json.Float)
            ldtk_layer_definition.auto_layer = auto_layer
        }

        ldtk_layer_intgrid_values := ldtk_layer_obj["intGridValues"].(json.Array)

        for ldtk_grid_value in ldtk_layer_intgrid_values{
            ldtk_layer_grid_value_obj := ldtk_grid_value.(json.Object)

            ldtk_grid_value := ldtk_layer_grid_value_obj["value"].(json.Float)
            ldtk_grid_identfier := ldtk_layer_grid_value_obj["identifier"].(json.String) or_else ""

            ldtk_int_grid_values[ldtk_grid_value] = ldtk_grid_identfier
        }

        ldtk_layer_definition.int_grid = ldtk_int_grid_values

        append(&ldtk_layer_def_collection, ldtk_layer_definition)
    }
    // --------------------------------------------------------------------------------

    ldtk_world_entities_definitions := ldtk_world_definitions["entities"].(json.Array)

    for ldtk_entity_def in ldtk_world_entities_definitions{
        ldtk_entity_definition := LDTK_ENTITY_DEFINITION{}

        ldtk_entity_obj := ldtk_entity_def.(json.Object)

        ldtk_entity_definition.identifier = ldtk_entity_obj["identifier"].(json.String)
        ldtk_entity_definition.uid = ldtk_entity_obj["uid"].(json.Float)

        ldtk_entity_definition.dimension = mathematics.Vec2{
            f32(ldtk_entity_obj["width"].(json.Float)),
            f32(ldtk_entity_obj["height"].(json.Float)),
        }

        ldtk_entity_definition.pivot = mathematics.Vec2{
            f32(ldtk_entity_obj["pivotX"].(json.Float)),
            f32(ldtk_entity_obj["pivotY"].(json.Float)),
        }

        append(&ldtk_entity_def_collection, ldtk_entity_definition)
    }
    // --------------------------------------------------------------------------------

    ldtk_world_tileset_definitions := ldtk_world_definitions["tilesets"].(json.Array)

    for ldtk_tile_def in ldtk_world_tileset_definitions{
        ldtk_tileset_definition := LDTK_TILESET_DEFINITION{}

        ldtk_tile_obj := ldtk_tile_def.(json.Object)
    
        ldtk_tileset_definition.identifier = ldtk_tile_obj["identifier"].(json.String)
        ldtk_tileset_definition.uid = ldtk_tile_obj["uid"].(json.Float)

        ldtk_tileset_definition.tile_path = ldtk_tile_obj["realPath"].(json.String) or_else "nil"

        ldtk_tileset_definition.dimension = mathematics.Vec2{
            f32(ldtk_tile_obj["pxWid"].(json.Float)),
            f32(ldtk_tile_obj["pxHei"].(json.Float)),
        }

        ldtk_tileset_definition.grid_size = ldtk_tile_obj["tileGridSize"].(json.Float)

        ldtk_tileset_definition.spacing = ldtk_tile_obj["spacing"].(json.Float)
        ldtk_tileset_definition.padding = ldtk_tile_obj["padding"].(json.Float)
        //enum support tileset..

        append(&ldtk_tileset_def_collection, ldtk_tileset_definition)
    }
    // --------------------------------------------------------------------------------
    
    ldtk_levels := ldtk_world["levels"].(json.Array)

    for ldtk_level in ldtk_levels{
        layer_instance_collection := make([dynamic]LDTK_LAYER_INSTANCE)

        ldtk_lv := LDTK_LEVEL{}

        ldtk_level_obj := ldtk_level.(json.Object)

        ldtk_lv.identifier = ldtk_level_obj["identifier"].(json.String)
        ldtk_lv.iid = ldtk_level_obj["iid"].(json.String)
        ldtk_lv.uid = ldtk_level_obj["uid"].(json.Float)

        ldtk_level_bg_color_str := ldtk_level_obj["__bgColor"].(json.String)
        color_code,_ := strconv.parse_int(ldtk_level_bg_color_str[1:], HEXADECIMAL_BASE)
        ldtk_level_background_color := hex_to_rgb(color_code, false)

        ldtk_lv.background_color = mathematics.Vec3{
            ldtk_level_background_color.r,
            ldtk_level_background_color.g,
            ldtk_level_background_color.b,
        }

        ldtk_lv.orientation = mathematics.Vec3{
            f32(ldtk_level_obj["worldX"].(json.Float)),
            f32(ldtk_level_obj["worldY"].(json.Float)),
            f32(ldtk_level_obj["worldDepth"].(json.Float)),
        }

        ldtk_lv.dimension = mathematics.Vec2{
            f32(ldtk_level_obj["pxWid"].(json.Float)),
            f32(ldtk_level_obj["pxHei"].(json.Float)),
        }

        //back ground img support??

        ldtk_level_layer_instances := ldtk_level_obj["layerInstances"].(json.Array)

        for ldtk_level_layer_instance in ldtk_level_layer_instances{
            int_grid_csv_collection := make([dynamic]int)
            auto_layer_tiles_collection := make([dynamic]LDTK_AUTO_LAYER_TILE)
            entity_instance_collection := make([dynamic]LDTK_ENTITY_INSTANCE)
    
            ldtk_level_layer := LDTK_LAYER_INSTANCE{}

            ldtk_level_layer_obj := ldtk_level_layer_instance.(json.Object)

            if ldtk_level_layer_obj["visible"].(json.Boolean){
                ldtk_level_layer.id = ldtk_level_layer_obj["iid"].(json.String)
                ldtk_level_layer.level_id = ldtk_level_layer_obj["levelId"].(json.Float)
                ldtk_level_layer.layerdef_uid = ldtk_level_layer_obj["layerDefUid"].(json.Float)

                ldtk_level_layer.offset = mathematics.Vec2{
                    f32(ldtk_level_layer_obj["pxOffsetX"].(json.Float)),
                    f32(ldtk_level_layer_obj["pxOffsetY"].(json.Float)),
                }

                ldtk_level_layer_int_grid_csv := ldtk_level_layer_obj["intGridCsv"].(json.Array)

                for val in ldtk_level_layer_int_grid_csv{
                    int_val := int(val.(json.Float))

                    append(&int_grid_csv_collection, int_val)
                }

                ldtk_level_auto_layer_tiles :=  ldtk_level_layer_obj["autoLayerTiles"].(json.Array)

                for ldtk_level_auto_tile in ldtk_level_auto_layer_tiles{
                    auto_layer_tile := LDTK_AUTO_LAYER_TILE{}

                    ldtk_level_auto_tile_obj := ldtk_level_auto_tile.(json.Object)

                    //This is the positon of the tile in the level
                    ldtk_level_auto_tile_px := ldtk_level_auto_tile_obj["px"].(json.Array)

                    #no_bounds_check{
                        auto_layer_tile.pixel = mathematics.Vec2{
                            f32(ldtk_level_auto_tile_px[0].(json.Float)),
                            f32(ldtk_level_auto_tile_px[1].(json.Float)),
                        }
                    }

                    //this is the rect src for retrieving the correct sprite for the tile sheet.
                    ldtk_level_auto_tile_src := ldtk_level_auto_tile_obj["src"].(json.Array)

                    #no_bounds_check{
                        auto_layer_tile.src = mathematics.Vec2{
                            f32(ldtk_level_auto_tile_src[0].(json.Float)),
                            f32(ldtk_level_auto_tile_src[1].(json.Float)),
                        }
                    }

                    // flip bit
                    auto_layer_tile.render_flip = ldtk_level_auto_tile_obj["f"].(json.Float)

                    auto_layer_tile.tile_id = ldtk_level_auto_tile_obj["t"].(json.Float)

                    append(&auto_layer_tiles_collection, auto_layer_tile)
                }

                ldtk_level_entity_instances := ldtk_level_layer_obj["entityInstances"].(json.Array)

                for ldtk_level_entity in ldtk_level_entity_instances{
                    level_entity := LDTK_ENTITY_INSTANCE{}

                    ldtk_level_entity_obj := ldtk_level_entity.(json.Object)

                    level_entity.iid = ldtk_level_entity_obj["iid"].(json.String)
                    level_entity.dimension = mathematics.Vec2{
                        f32(ldtk_level_entity_obj["width"].(json.Float)),
                        f32(ldtk_level_entity_obj["height"].(json.Float)),
                    }

                    level_entity.def_uid = ldtk_level_entity_obj["defUid"].(json.Float)

                    ldtk_level_entity_pos := ldtk_level_entity_obj["px"].(json.Array)

                    #no_bounds_check{
                        level_entity.pixel = mathematics.Vec2{
                            f32(ldtk_level_entity_pos[0].(json.Float)),
                            f32(ldtk_level_entity_pos[1].(json.Float)),
                        }
                    }

                    append(&entity_instance_collection, level_entity)
                }
            }


            ldtk_level_layer.auto_layer_tiles = auto_layer_tiles_collection
            ldtk_level_layer.entity_instances = entity_instance_collection
            ldtk_level_layer.int_grid_csv = int_grid_csv_collection

            append(&layer_instance_collection, ldtk_level_layer)
        }

        ldtk_lv.layer_instances = layer_instance_collection

        append(&ldtk_level_collection, ldtk_lv)
    }

    ldtk_context.layer_def = ldtk_layer_def_collection
    ldtk_context.entity_def = ldtk_entity_def_collection
    ldtk_context.tileset_def = ldtk_tileset_def_collection
    ldtk_context.levels = ldtk_level_collection

    return ldtk_context
}

free_ldtk_context :: proc(ctx : ^LDTK_CONTEXT){
    delete(ctx.entity_def)
    delete(ctx.tileset_def)

    for layer_def in ctx.layer_def{
        delete(layer_def.int_grid)
    }

    delete(ctx.layer_def)

    for lv in ctx.levels{
        for inst in lv.layer_instances{
            delete(inst.auto_layer_tiles)
            delete(inst.entity_instances)
            delete(inst.int_grid_csv)
        }

        delete(lv.layer_instances)
    }

    delete(ctx.levels)
}