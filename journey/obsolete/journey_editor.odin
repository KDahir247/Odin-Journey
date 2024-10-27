package journey
import "vendor:microui"

//1280, 720
HEADER_SCALE_FACTOR :: 30
ASSET_SCALE_FACTOR :: SCREEN_RESOLUTION.x - (SCREEN_RESOLUTION.x - 250)
DEFAULT_EDITOR_STYLE :: microui.Style{
    font = nil, size = { 68, 10 },
	padding = 5, spacing = 4, indent = 24,
	title_height = 24, footer_height = 20,
	scrollbar_size = 12, thumb_size = 8,
	colors = DEFAULT_COLORMAP,
}

DEFAULT_COLORMAP :: [microui.Color_Type]microui.Color{
    .TEXT         = {255, 255, 255, 255},
    .BORDER       = {25,  25,  25,  255},
    .WINDOW_BG    = {45,  45,  45,  255},
    .TITLE_BG     = {21,  21,  21,  255},
    .TITLE_TEXT   = {240, 240, 240, 255},
    .PANEL_BG     = {33, 36, 41, 255 },
    .BUTTON       = {75,  75,  75,  255},
    .BUTTON_HOVER = {95,  95,  95,  255},
    .BUTTON_FOCUS = {115, 115, 115, 255},
    .BASE         = {30,  30,  30,  255},
    .BASE_HOVER   = {35,  35,  35,  255},
    .BASE_FOCUS   = {40,  40,  40,  255},
    .SCROLL_BASE  = {43,  43,  43,  255},
    .SCROLL_THUMB = {30,  30,  30,  255},
}

HEADER_COLORMAP :: [microui.Color_Type]microui.Color{
    .TEXT         = {255, 255, 255, 255},
    .BORDER       = {33, 36, 41, 255},
    .WINDOW_BG    = {33, 36, 41, 255},
    .TITLE_BG     = {33, 36, 41, 255},
    .TITLE_TEXT   = {255, 255, 255, 255},
    .PANEL_BG     = {33, 36, 41, 255 },
    .BUTTON       = {33, 36, 41, 255},
    .BUTTON_HOVER = {33, 36, 41, 255},
    .BUTTON_FOCUS = {30, 30, 30, 255},
    .BASE         = {30,  30,  30,  255},
    .BASE_HOVER   = {33, 36, 41, 255},
    .BASE_FOCUS   = {33, 36, 41, 255},
    .SCROLL_BASE  = {33, 36, 41, 255},
    .SCROLL_THUMB = {33, 36, 41, 255},
}

ASSET_COLORMAP :: [microui.Color_Type]microui.Color{
    .TEXT         = {255, 255, 255, 255},
    .BORDER       = {33, 36, 41, 255},
    .WINDOW_BG    = {33, 36, 41, 255},
    .TITLE_BG     = {33, 36, 41, 255},
    .TITLE_TEXT   = {255, 255, 255, 255},
    .PANEL_BG     = {45,46,51, 255},
    .BUTTON       = {45, 46, 51, 255},
    .BUTTON_HOVER = {35, 35, 35, 255},
    .BUTTON_FOCUS = {35, 35, 35, 255},
    .BASE         = {30,  30,  30,  255},
    .BASE_HOVER   = {33, 36, 41, 255},
    .BASE_FOCUS   = {33, 36, 41, 255},
    .SCROLL_BASE  = {33, 36, 41, 255},
    .SCROLL_THUMB = {33, 36, 41, 255},
}

INSPECTOR_COLORMAP :: [microui.Color_Type]microui.Color{
    .TEXT         = {255, 255, 255, 255},
    .BORDER       = {33, 36, 41, 255},
    .WINDOW_BG    = {33, 36, 41, 255},
    .TITLE_BG     = {33, 36, 41, 255},
    .TITLE_TEXT   = {255, 255, 255, 255},
    .PANEL_BG     = {45,46,51, 255},
    .BUTTON       = {33, 36, 41, 255},
    .BUTTON_HOVER = {33, 36, 41, 255},
    .BUTTON_FOCUS = {30, 30, 30, 255},
    .BASE         = {30,  30,  30,  255},
    .BASE_HOVER   = {33, 36, 41, 255},
    .BASE_FOCUS   = {33, 36, 41, 255},
    .SCROLL_BASE  = {33, 36, 41, 255},
    .SCROLL_THUMB = {33, 36, 41, 255},
}

MAXIMUM_EDITOR_VERTICES :: 24000

GameEditor :: struct{
    ctx : ^microui.Context,
    buffer : []VertexData,
    buf_len : u32,
}


// editor_init :: proc(screen_resolution : ) -> GameEditor{
    
// }


push_editor_quad :: proc(editor : ^GameEditor, destination_rect : microui.Rect, source_rect : microui.Rect, color : microui.Color){
    
    HALF_SCREEN_RES_X : i32: SCREEN_RESOLUTION.x >> 1
    HALF_SCREEN_RES_Y : i32: SCREEN_RESOLUTION.y >> 1

    RCP_NORM_COLOR : f32 : 1.0 / 255.0
    RCP_NORM_U : f32 : 1.0 / microui.DEFAULT_ATLAS_WIDTH
    RCP_NORM_V : f32 : 1.0 / microui.DEFAULT_ATLAS_HEIGHT

    left_vertex := f32(destination_rect.x - HALF_SCREEN_RES_X)
    right_vertex := f32(destination_rect.x + destination_rect.w - HALF_SCREEN_RES_X)
    
    bottom_vertex := f32(destination_rect.y - HALF_SCREEN_RES_Y)
    top_vertex := f32(destination_rect.y + destination_rect.h - HALF_SCREEN_RES_Y)
}

editor_poll :: proc(){

}



editor_update :: proc(editor : ^GameEditor){
    @static header_option := microui.Options{.NO_CLOSE, .NO_TITLE, .NO_RESIZE}
    microui.begin(editor.ctx)

    //create the header window.
    editor.ctx.style.colors = HEADER_COLORMAP

    if microui.window(editor.ctx, "__Header__", {0,0,SCREEN_RESOLUTION.x, HEADER_SCALE_FACTOR}, header_option){
        microui.layout_row(editor.ctx, {120, 64, 64, 64 ,64, HEADER_SCALE_FACTOR - 6})

        r := microui.layout_next(editor.ctx)
        microui.draw_box(editor.ctx, r, microui.Color{255,255,255,255})

        if .SUBMIT in microui.button(editor.ctx, "File"){
            //Popup UI
        }

        if .SUBMIT in microui.button(editor.ctx, "Edit"){
            //Popup UI
        }

        if .SUBMIT in microui.button(editor.ctx, "Theme"){
            //Popup UI
        }

        if .SUBMIT in microui.button(editor.ctx, "About"){
            //Popup UI
        }

        // microui.begin_panel()

        // microui.draw_box()
        // microui.draw_icon()
    }

    editor.ctx.style.colors =  DEFAULT_COLORMAP

    microui.end(editor.ctx)


    command : ^microui.Command

    for microui.next_command(editor.ctx, &command){
        source_rect : microui.Rect = microui.default_atlas[microui.DEFAULT_ATLAS_WHITE]
        destination_rect : microui.Rect
        color : microui.Color

        if text_command, valid := command.variant.(^microui.Command_Text); valid{

        }else if rect_command, valid := command.variant.(^microui.Command_Rect); valid{
            destination_rect = rect_command.rect
            color = rect_command.color

            
        }



            //push quad


    }
}






//(left, right middle)
//mouse move,
//mouse down,
//mouse up,

//input scroll,

//(shift, ctrl, alt, backspace, return)
//key down
//key up


//input text