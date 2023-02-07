package utility

import "core:encoding/json"
import "core:os"
import "core:fmt"
import "../container"
import "vendor:sdl2"
import "vendor:sdl2/image"
import "core:strings"

parse_game_config :: proc($path : string) -> container.GameConfig  {
    enabled_game_flags := sdl2.InitFlags{} 
    enabled_img_flags := image.InitFlags{}
    enabled_window_flags := sdl2.WindowFlags{}
    enabled_render_flags := sdl2.RendererFlags{}
    clear_color := [4]u8{}
    
    data, _ := os.read_entire_file_from_filename(path)
    defer delete(data)

    anim_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)
    defer json.destroy_value(anim_json)

    root := anim_json.(json.Object)

    game_flags := root["game_flags"].(json.Array)
    image_flags := root["image_flags"].(json.Array)

    for flag in game_flags{
        init_game_flag := flag.(json.Integer)

        incl(&enabled_game_flags, sdl2.InitFlag(init_game_flag))
    }

    for flag in image_flags{
        init_img_flag := flag.(json.Integer)

        incl(&enabled_img_flags, image.InitFlag(init_img_flag))
    }

    window_config := root["window_config"].(json.Object)
    
    window_title := window_config["title"].(json.String)
    title := strings.clone_to_cstring(window_title)
    
    center_x := i32(window_config["x"].(json.Integer))
    center_y := i32(window_config["y"].(json.Integer))

    grid_width := i32(window_config["grid_width"].(json.Integer))
    grid_height := i32(window_config["grid_height"].(json.Integer))
    grid_cell := i32(window_config["grid_cell_size"].(json.Integer))

    window_flags := window_config["flags"].(json.Array)

    for flag in window_flags{
        init_window_flag := flag.(json.Integer)

        incl(&enabled_window_flags, sdl2.WindowFlag(init_window_flag))
    }

    render_config := root["render_config"].(json.Object)

    color := render_config["clear_color"].(json.Array)

    for i, index in color {
        col :=  u8(i.(json.Integer))
        clear_color[index] = col
    }

    render_flag := render_config["flags"].(json.Array)

    for flag in render_flag{
        init_render_flag := flag.(json.Integer)

        incl(&enabled_render_flags, sdl2.RendererFlag(init_render_flag))
    }

    return container.GameConfig{
        enabled_game_flags,
        enabled_img_flags,
        enabled_window_flags,
        enabled_render_flags,

        title,
        {center_x, center_y},
        {grid_width, grid_height, grid_cell},
        clear_color,

    }


}

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


//TODO: khal this will parse ldtk level file
parse_level :: proc($path : string){
    data, _ := os.read_entire_file_from_filename(path)
    defer delete(data)

    anim_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)
    defer json.destroy_value(anim_json)
}