package utility

import "../container"
import "../utility"

import "core:strconv"
import "core:encoding/json"
import "core:os"
import "core:strings"
import "core:math/linalg"
import "core:fmt"

import "vendor:sdl2"
import "vendor:sdl2/image"

@(private)
DEFAULT_BG_HEX :: 2960685

parse_game_config :: proc($path : string) -> container.GameConfig {
    enabled_img_flags : image.InitFlags //TODO: remove...
    enabled_window_flags : sdl2.WindowFlags
    enabled_render_flags : sdl2.RendererFlags

    //TODO: khal handle err. This is a logic err not a user err.
    data, os_err := os.read_entire_file_from_filename(path)
    anim_json, json_err := json.parse(data, json.DEFAULT_SPECIFICATION, true)

    defer delete(data)
    defer json.destroy_value(anim_json)

    root := anim_json.(json.Object)

    window_config := root["window_config"].(json.Object)
    
    window_title := window_config["title"].(json.String)
    title := strings.clone_to_cstring(window_title)
    
    center_x := int(window_config["x"].(json.Integer))
    center_y := int(window_config["y"].(json.Integer))

    grid_width := int(window_config["grid_width"].(json.Integer))
    grid_height := int(window_config["grid_height"].(json.Integer))
    grid_cell := int(window_config["grid_cell_size"].(json.Integer))

    render_config := root["render_config"].(json.Object)

    color_hex_string := render_config["clear_color"].(json.String)
    hex_int, valid_val :=  strconv.parse_int(color_hex_string[1:], HEXADECIMAL_BASE)

    valid_mask := int(valid_val)
    invert_valid_mask := valid_mask ~ 1

    result_bg_color := (hex_int * valid_mask) + (DEFAULT_BG_HEX * invert_valid_mask)
    
    image_flags := root["image_flags"].(json.Array)

    window_flags := window_config["flags"].(json.Array)
    render_flags := render_config["flags"].(json.Array)

    img_flag_len := len(image_flags) - 1
    window_flag_len := len(window_flags) - 1
    render_flag_len := len(render_flags) - 1

    length := linalg.max(render_flag_len,linalg.max_double(img_flag_len,window_flag_len))

    #no_bounds_check{
        for i in 0..<length{
            init_img_flag := image_flags[linalg.min(i, img_flag_len)].(json.Integer)
            
            init_window_flag := window_flags[linalg.min(i, window_flag_len)].(json.Integer)
            init_render_flag := render_flags[linalg.min(i, render_flag_len)].(json.Integer)

            //TODO: remove this.....
            incl(&enabled_img_flags, image.InitFlag(init_img_flag))
            incl(&enabled_window_flags, sdl2.WindowFlag(init_window_flag))
            incl(&enabled_render_flags, sdl2.RendererFlag(init_render_flag))
        }
    }

    width := grid_width * grid_cell
    height := grid_height * grid_cell

    return container.GameConfig{
        enabled_img_flags,
        enabled_window_flags,
        enabled_render_flags,
        {width + 1, height + 1},
        {center_x, center_y},
        title,
        result_bg_color,
    }
}