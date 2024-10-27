package journey

import "core:simd"
import  "core:sync"


//Remember constant variable (float) are stored in static memory, while constant integer are 
//included as part of the instruction code. 

//////////////////// COMMAN MATH ///////////////////////
  
// IDENTITY : matrix[4,4]f32 :  {
//     1.0, 0.0, 0.0, 0.0,
//     0.0, 1.0, 0.0, 0.0,
//     0.0, 0.0, 1.0, 0.0,
//     0.0, 0.0, 0.0, 1.0,
// }

//////////////////// COMMON PATH ///////////////////////
//CONFIG_BYTES :: #load("../resource/game_config.json")

default_cursor := []u16{114, 101, 115, 111, 117, 114, 99, 101, 47, 100, 101, 102, 97, 117, 108, 116, 46, 99, 117, 114, 0}
DEFAULT_SHADER :: "resource/shader/common.hlsl"

// DEFAULT_SPRITE_PATH :: "resource/sprite/*.png"

// DEFAULT_SHADER_PATH :: "resource/shader/*.hlsl"

// //Quality 1, Size = 4
// DEFAULT_AUDIO_PATH_WAV :: "reosurce/audio/*.wav"
// //Quality 2, Size = 3
// DEFAULT_AUDIO_PATH_FLAC :: "resource/audio/*.flac"
// //Quality 3, Size = 2
// DEFAULT_AUDIO_PATH_OGG :: "resource/audio/*.ogg"
// //Quality 4, Size = 1
// DEFAULT_AUDIO_PATH_MP3 :: "resource/aduio/*.mp3"

//////////////////// COMMON VARIABLES //////////////////

SCREEN_RESOLUTION : [2]i32: #config(ScreenResolution, [2]i32{1280, 720})
WINDOW_STYLE_BORDERLESS : b32 : #config(WindowStyle, true)

CollisionCount :: 64

BATCH_SIZE :: 64

TIME_SCALE : f32 :  1.0
MAX_DELTA_TIME : f32: (1.0 / 60.0) * TIME_SCALE

GRAVITY :: 9.81
///////////////////////////////////////////////////////

/////////////////// RENDERER DATA /////////////////////
//INSTANCE_BYTE_WIDTH :: size_of(InstanceRenderData) << 14

SortMode :: enum i32{
    Texture, 
    BackToFront, // lhs_depth > rhs_depth
    FrontToBack, // lhs_depth < rhs_depth
}

INDICES_PER_SPRITE :: 6
VERTICES_PER_SPRITE :: 4
BATCH_LIMIT :: 20000//1024

GlobalDynamicVSConstantBuffer :: struct #align (16){
    projection_matrix : matrix[4,4]f32,
    view_matrix : matrix[4,4]f32,
}


RenderDescriptor :: struct{
    render_handle : rawptr,
    cond : ^sync.Cond,
}

GlobalVSConstantBuffer :: struct #align (16){
    viewport_x : f32,
    viewport_y : f32,
    viewport_width : f32,
    viewport_height : f32,
}

GlobalDynamicPSConstantBuffer :: struct #align (16){
    time : f32,
    delta_time : f32,
    sin_time : f32,
    cos_time : f32,
}

SpriteBatch :: struct{
    vertex_buffer : []VertexData,
    texture_param : TextureParam,
}

VertexData :: struct{
    color : [4]f32,
    position : [2]f32,
    uv : [2]f32,

}
/////////////

TextureParam :: struct{
    texture : rawptr,
    width : i64,
    height : i64,
    shader_cache : u64,
}
////////////////////////////////////////////////////////


/////////////////// GAME DATA /////////////////////////
// Animator :: struct{
//     animator_string_hash : u32, //fnv32a constant once created.
//     clip_string_hash : u32,  //fnv32a dynamically change to play next animation.
//     rect_size : f32, 
//     animation_speed : f32,
//     animation_duration : f32,
// }

// SliceDirection :: enum i32{
//     Horizontal = 0, 
//     Vertical = 1, 
// }

// AnimationClip :: struct{
//     half_bounds : []f32, //Stored as [(x, y), (x, y), (x, y), ....]
//     name_hash : u32,
//     len : f32,
//     index : f32,
//     direction : SliceDirection,
// }

CollisionResolver :: struct{
    collision_iteration : int,
    used_iteration : int,
}

// We are using sse rather then avx due to the amount of workload stress avx will put on the cpu.
// We want a nice balance on maximizing workload and reducing cpu stress (excess heat on cpu).
// We are also using multiple threads with sse, so this should be more than sufficent.

Parallax :: struct{

}

Position :: struct{
    x : #simd[4]f32,
    y : #simd[4]f32,
}

Scale :: struct{
    w : #simd[4]f32,
    h : #simd[4]f32,
}

Rotation :: struct{
    z : #simd[4]f32,
}

Render :: struct{
    indices : [4]i32,
}
//

// ONE 4k PAGE

//uv is x,y , x+w,y, x,y+h, x+w,y+h
//position follow the same.
//collider will use rect where center is (x + w) / 2 and half extent is w / 2 
Rect :: struct{
    x : #simd[4]f32,
    y : #simd[4]f32,
    w : #simd[4]f32,
    h : #simd[4]f32,
}

//make to 64
Visual :: struct {
    r : #simd[4]f32,
    g : #simd[4]f32,
    b : #simd[4]f32,
}

//ONE 4k PAGE

//TODO: should this be integer types instead, since we do not want decimals in the animation at all.
// Also reduce the number of parameter in this struct...
// Should we seperate this to a Animator and a SRC Rect?
Animator :: struct {
    animation_step : #simd[4]f32,
    frame_index : #simd[4]f32,

    clip_row : #simd[4]f32,
    clip_column : #simd[4]f32,
}

PhysicMaterial :: struct{
    restitution : #simd[4]f32,
    friction : #simd[4]f32,
}

//TODO: re-order this struct
Physic :: struct{
    drag : #simd[4]f32, 
    inverse_mass : #simd[4]f32,
    
    velocity_x : #simd[4]f32,
    velocity_y : #simd[4]f32,
}

//accumulated force
Force :: struct{
    x : #simd[4]f32,
    y : #simd[4]f32,
}

//Only update the render buffer once and not every frame, since modification is very rare/never.
RenderData :: struct{
    total_instances : int,
    hash : int,
}

// Game :: struct{    

//     world : ^World,
//     key_buffer : []i8,

//     //render_batch : map[int]RenderBatchGroup,//rename
// }

///////////////////////////////////////////////////////

/////////////////// RESOURCE DATA /////////////////////

Camera :: struct{
    look_at_x : f32,
    look_at_y : f32,
}

///////////////////////////////////////////////////////

