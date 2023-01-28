package utility

import "core:encoding/json"
import "core:os"
import "core:fmt"
import "../container"
parse_animation :: proc($path : string, animation_keys : []string) -> (string,[dynamic]container.AnimationConfig) {
    anim_configs := make([dynamic]container.AnimationConfig)
    
    data, _ := os.read_entire_file_from_filename(path)
    defer delete(data)

    anim_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)
    defer json.destroy_value(anim_json)

    root := anim_json.(json.Object)
    
    tex_path := root["path"].(json.String)
    
    for anim_key in animation_keys{
        anim_content := root[anim_key].(json.Object)

        anim_index := anim_content["index"].(json.Integer)
        animation_slice := anim_content["num_slice"].(json.Integer)
        animation_width := anim_content["width"].(json.Float)
        animation_height := anim_content["height"].(json.Float)

        append(&anim_configs, container.AnimationConfig{
            anim_index,
            animation_slice,
            animation_width,
            animation_height})
    }

    return tex_path, anim_configs
}