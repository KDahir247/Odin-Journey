package main
import "vendor:glfw"
import "vendor:OpenGL"
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

    red := f32(color_bits[0].(json.Float))
    green := f32(color_bits[1].(json.Float))
    blue := f32(color_bits[2].(json.Float))
    
    defer delete(color_bits)

    create_window("", i32(window_width), i32(window_height), [3]f32{red, green, blue})

}

create_window :: proc(title : cstring, width : i32= 1920, height : i32 = 1080, color : [3]f32){
    if !bool(glfw.Init()){
        return
    }

    window_handle := glfw.CreateWindow(width, height, title, nil, nil)

    defer glfw.Terminate()
    defer glfw.DestroyWindow(window_handle)

    if window_handle == nil{
        return
    }

    glfw.MakeContextCurrent(window_handle);

    OpenGL.load_up_to(4, 5, glfw.gl_set_proc_address)


    for !glfw.WindowShouldClose(window_handle){

        glfw.PollEvents()

        OpenGL.ClearColor(color[0], color[1], color[2], 1.0)
        OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT)

        glfw.SwapBuffers(window_handle)


    }

}

@(test)
main_test :: proc(v: ^testing.T){
    testing.expect_value(v, 4,4)

}
