package main

import "vendor:stb"
import "vendor:glfw"
import "core:testing"
import "core:encoding/json"
import "core:os"
import "core:sys/info"
import "core:fmt"

main :: proc() {
    empty_buff :: []byte{}
    nil_val :: json.Value{}

    data := os.read_entire_file_from_filename("window_setting.json") or_else empty_buff
    defer delete(data)
    
    json_data := json.parse(data) or_else nil_val

    defer json.destroy_value(json_data)

    window_obj := json_data.(json.Object)

    // we can then get the window details 
    window_width :f64= window_obj["window_width"].(json.Float)
    window_height :f64 = window_obj["window_height"].(json.Float)
    window_title : string = window_obj["window_title"].(json.String)

    renderer_setting_obj := window_obj["renderer_setting"].(json.Object)

    // minor, major
    versions := renderer_setting_obj["version"].(json.Array)
    color_bits := renderer_setting_obj["color_bit"].(json.Array)

    

    fmt.println(color_bits)
}


@(test)
main_test :: proc(v: ^testing.T){
    testing.expect_value(v, 4,4)

}
