package utility

import "core:encoding/json"
import "core:os"
import "core:hash"
import "core:strconv"
import "core:fmt"

HEXADECIMAL_BASE :: 16

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

LDTK_NEIGHBOUR_COLLECTION :: struct{
    neighbours : [dynamic]LDTK_NEIGHBOUR,
}

LDTK_NEIGHBOUR :: struct{
    identifier : string,
    direction : u8,
}

LDTK_ENTITY :: struct{
    idenifier : string,
    layer : string,
    x : int,
    y : int,
    width : int,
    height : int,
    //custom_fields : container,
}

LDTK_LAYER_IMG :: struct(len : int){
    // bg, background, collision, wall shadow.
     layer_imgs : [len]string,
}   


//TODO: khal this will parse ldtk level file
parse_level_simplified :: proc($path : string, $layer_count : int){
     ldtk_level :LDTK_LEVEL= {} 
     ldtk_level_img : LDTK_LAYER_IMG(layer_count) ={}

    data, _ := os.read_entire_file_from_filename(path)
    defer delete(data)

    anim_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)
    defer json.destroy_value(anim_json)

    ldtk_level_root := anim_json.(json.Object)

    ldtk_level.identifier = ldtk_level_root["identifier"].(json.String)
    ldtk_level.uid = ldtk_level_root["uniqueIdentifer"].(json.String)
    
    ldtk_level.x = ldtk_level_root["x"].(json.Integer)
    ldtk_level.y = ldtk_level_root["y"].(json.Integer)

    ldtk_level.width = ldtk_level_root["width"].(json.Integer)
    ldtk_level.height = ldtk_level_root["height"].(json.Integer)
    
    ldtk_background_color_str := ldtk_level_root["bgColor"].(json.String)
    color_code,err := strconv.parse_int(ldtk_background_color_str[1:], HEXADECIMAL_BASE)
    ldtk_level.background_color = hex_to_rgb(color_code, false)

    ldtk_neighour_levels := ldtk_level_root["neighbourLevels"].(json.Array)
    ldtk_neighour_collection := make_dynamic_array_len([dynamic]LDTK_NEIGHBOUR, len(ldtk_neighour_levels))

    for ldtk_neighbour, index in ldtk_neighour_levels{
        ldtk_neighbour_obj := ldtk_neighbour.(json.Object)

        ldtk_neighour_collection[index].identifier = ldtk_neighbour_obj["levelIid"].(json.String)
        ldtk_neighbour_direction := ldtk_neighbour_obj["dir"].(json.String)
        
        compass_map := map[string]u8{
            "n" = 0,
            "e" = 1,
            "s" = 2,
            "w" = 3,
        }
        ldtk_neighour_collection[index].direction = compass_map[ldtk_neighbour_direction]
    }

    fmt.println(ldtk_neighour_collection)

    layers :[layer_count]string= {}

    ldtk_level_layers := ldtk_level_root["layers"].(json.Array)
    
    for ldtk_layer, index in ldtk_level_layers{
        layers[index] = ldtk_layer.(json.String)
    }

    ldtk_level_img.layer_imgs = layers

    // Neighbours ?
    delete(ldtk_neighour_collection)

}

