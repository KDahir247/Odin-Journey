package utility

import "../container"
import "../utility"

import "core:strconv"
import "core:encoding/json"
import "core:os"
import "core:strings"

import "vendor:sdl2"
import "vendor:sdl2/image"


parse_game_config :: proc($path : string) -> container.GameConfig  {
    enabled_game_flags : sdl2.InitFlags
    enabled_img_flags : image.InitFlags
    enabled_window_flags : sdl2.WindowFlags
    enabled_render_flags : sdl2.RendererFlags

    data, _ := os.read_entire_file_from_filename(path)
    anim_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)
    
    defer delete(data)
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
    
    center_x := int(window_config["x"].(json.Integer))
    center_y := int(window_config["y"].(json.Integer))

    grid_width := int(window_config["grid_width"].(json.Integer))
    grid_height := int(window_config["grid_height"].(json.Integer))
    grid_cell := int(window_config["grid_cell_size"].(json.Integer))

    window_flags := window_config["flags"].(json.Array)

    for flag in window_flags{
        init_window_flag := flag.(json.Integer)

        incl(&enabled_window_flags, sdl2.WindowFlag(init_window_flag))
    }

    render_config := root["render_config"].(json.Object)

    color_hex_string := render_config["clear_color"].(json.String)
    hex_int,valid_val :=  strconv.parse_int(color_hex_string[1:], HEXADECIMAL_BASE)
    
    color := [3]f32{45, 45, 45}

    if valid_val{
        color = utility.hex_to_rgb(hex_int,false)
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
        {
            u8(color.r),
            u8(color.g),
            u8(color.b),
        },
    }
}

parse_animation :: proc($path : string, animation_keys : [$E]string) -> [E]container.AnimationConfig{
    anim_configs : [E]container.AnimationConfig
    
    data, _ := os.read_entire_file_from_filename(path)
    anim_json, _ := json.parse(data, json.DEFAULT_SPECIFICATION, true)

    defer delete(data)
    defer json.destroy_value(anim_json)

    root := anim_json.(json.Object)
    
    #no_bounds_check{
        for index in 0..<E{
            current_key := animation_keys[index]
            anim_content := root[current_key].(json.Object)
    
            anim_index := anim_content["index"].(json.Integer)
            animation_slice := anim_content["num_slice"].(json.Integer)

            animation_width := anim_content["width"].(json.Float)
            animation_height := anim_content["height"].(json.Float)

            animation_fps := anim_content["fps"].(json.Float)
    
            anim_configs[index] = container.AnimationConfig{
                i32(anim_index),
                i32(animation_slice),
                i32(animation_width),
                i32(animation_height),
                f32(animation_fps),
            }
    
        }
    }

    return anim_configs
}


