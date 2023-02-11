package utility

import "core:encoding/json"
import "core:os"
import "core:hash"
import "core:strconv"
import "core:fmt"
import "core:intrinsics"
HEXADECIMAL_BASE :: 16

LDTK_CONTEXT :: struct(len : int){
    level : LDTK_LEVEL,
    ldtk_neighbours : [dynamic]LDTK_NEIGHBOUR,
    img : LDTK_LAYER_IMG(len),
    entities : [dynamic]LDTK_ENTITY,
}

// Simpified..
LDTK_LEVEL :: struct{
    background_color : [3]f32,
    identifier : string,
    uid : string,
    x : i64,
    y : i64,
    width : i64,
    height : i64,
}

LDTK_NEIGHBOUR :: struct{
    level_uid : string,
    direction : u8,
}

LDTK_ENTITY :: struct{
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


parse_level_simplified :: proc($path : string, $layer_count : int) -> LDTK_CONTEXT(layer_count){
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

    ldtk_context := LDTK_CONTEXT(layer_count){
        level = ldtk_level,
        ldtk_neighbours = ldtk_neighbour_collection,
        img = ldtk_level_img,
        entities = ldtk_entities_collection,
    }

    

    return ldtk_context
}


free_ldtk_context :: proc(a : ^LDTK_CONTEXT($E))
where E > 0
{ 
    delete(a.ldtk_neighbours)
    delete(a.entities)
}

// TODO: there is quite a bit of configuaration in ldtk that will alter the way to read data.
// eg. Export as png, saving level seperately.
parse_ldtk :: proc($path : string){

    // this will load by world not by level which is done by parse_level_simplified function.
    // world will contain a collection of level in the given world.
    // parse_ldtk function doesn't not support multiple world. Just a single world with multiple levels.
    // TODO: khal maybe make a function to support ldtk multiple world.. Maybe...


    data, _ := os.read_entire_file_from_filename(path)
    defer delete(data)

    ldtk_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)
    defer json.destroy_value(ldtk_json)

    ldtk_world := ldtk_json.(json.Object)

    ldtk_world_iid := ldtk_world["iid"].(json.String)

    ldtk_has_external_level := ldtk_world["externalLevels"].(json.Boolean)
    ldtk_simplified_export := ldtk_world["simplifiedExport"].(json.Boolean)

    ldtk_world_definitions := ldtk_world["defs"].(json.Object);

    ldtk_world_layer_definitions := ldtk_world_definitions["layers"].(json.Array)

    for layer_def in ldtk_world_layer_definitions{
        ldtk_layer_obj := layer_def.(json.Object)

        ldtk_layer_id := ldtk_layer_obj["identifier"].(json.String)
        ldtk_layer_type := ldtk_layer_obj["type"].(json.String)
        ldtk_layer_iid := ldtk_layer_obj["uid"].(json.Integer)

        ldtk_layer_opacity := ldtk_layer_obj["displayOpacity"].(json.Integer)

        ldtk_layer_grid_size := ldtk_layer_obj["gridSize"].(json.Integer)
        fmt.println()


    }

    // Once we got the definition then we can do..

    // if ldtk_has_external_level or if it is simplified then handle, since this parse function 
    // has really explicit json parsing.




    //TODO: we want to check if both simplified and exported level


    //toc, level, check json version, iid, def, background color, external level, 

}