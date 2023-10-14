package journey

import "core:prof/spall"


//////////////////// COMMAN MATH ///////////////////////
  
IDENTITY : matrix[4,4]f32 :  {
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
}


//////////////////// COMMON PATH ///////////////////////
CACHED_SHARED_PATH :[1]string = {
    "resource/shader/sprite_instancing.hlsl",
} 

DEFAULT_SPRITE_PATH :: "resource/sprite/*.png"

DEFAULT_SHADER_PATH :: "resource/shader/*.hlsl"

DEFAULT_LEVEL_PATH :: "resource/level/*.ldtk"

//Quality 1, Size = 4
DEFAULT_AUDIO_PATH_WAV :: "reosurce/audio/*.wav"

//Quality 2, Size = 3
DEFAULT_AUDIO_PATH_FLAC :: "resource/audio/*.flac"

//Quality 3, Size = 2
DEFAULT_AUDIO_PATH_OGG :: "resource/audio/*.ogg"

//Quality 4, Size = 1
DEFAULT_AUDIO_PATH_MP3 :: "resource/aduio/*.mp3"

//////////////////// COMMON VARIABLES //////////////////

TIME_SCALE : f32 :  1.0
MAX_DELTA_TIME : f32: (1.0 / 60.0) * TIME_SCALE

GRAVITY :: 9.81
///////////////////////////////////////////////////////

/////////////////// RENDERER DATA /////////////////////
INSTANCE_BYTE_WIDTH :: size_of(RenderInstanceData) << 11

ResourceCache :: struct{
    render_buffer : ^RenderBatchBuffer,
}

SpriteIndex :: struct{
    position : [2]f32,
}

GlobalDynamicVSConstantBuffer :: struct #align (16){
    projection_matrix : matrix[4,4]f32,
    view_matrix : matrix[4,4]f32,

    viewport_x : f32,
    viewport_y : f32,
    viewport_width : f32,
    viewport_height : f32,
}

GlobalDynamicPSConstantBuffer :: struct #align (16){
    time : f32,
    delta_time : f32,
}

RenderBatchBuffer :: struct #align (64){
    changed_flag : bool,
    render_batch_groups : map[uint]RenderBatchGroup,
}

RenderBatchGroup :: struct{
    texture_param : TextureParam,
    instances : [dynamic]RenderInstanceData, 
}

RenderInstanceData :: struct #align (16){
    transform : matrix[4,4]f32,
    src_rect : Rect,
    color : [4]f32,
    //-1 is true, 1 is false
    flip_bit : [2]f32,
    pivot_point : [2]f32,
    order_index : int,
    //TODO: khal add another 4 f32 and align to 16
}

/////////////

TextureParam :: struct{
    texture : rawptr,
    width : i32,
    height : i32,
    shader_cache : u32,
}
////////////////////////////////////////////////////////


/////////////////// GAME DATA /////////////////////////
RenderInstance :: struct{
    hash : uint,
    instance_index : uint,
}

Position :: struct{
    x : f32,
    y : f32,
}

Rotation :: struct{
    z : f32,
}

Scale :: struct {
    x : f32,
    y : f32,
}

Animator :: struct{
    clips :[]Animation,
    animation_speed : f32,
    current_clip : int,
    animation_duration_sec : f32,
}

Animation :: struct{
    width : int, // (the sprite width for the animation clip)
    height : int, // (the sprite height for the animation clip)
    index : int, // (the row the animation strip is in)
    len : int, // (how much column the animation has aka. the number of clips)
    // carry_over : int, // (if the animation continues over from the index to the next index what index is it carried over to and how much column does it take up. 0 mean no carry over 1 mean the it will take 1 column from the next row, etc...)
    // offset_slice : int, // (how much column should be be skipped in the sprite sheet)
    // animation_speed : int, // (the speed of the animation 1.0x mean normal, 2.0x mean 2 times etc...)
    // loop : int, // (looping animation clip. 1 is looping, 0 mean doesn't loop)
}

Velocity :: struct{
    x : f32,
    y : f32,
}

Acceleration :: struct{
    x : f32,
    y : f32,
}

//Mass val is represent as the inverse mass
Mass :: struct{
    val : f32, 
}

AccumulatedForce :: struct{
    x : f32,
    y : f32,
}

Friction :: struct{
    val : f32,
}

Restitution :: struct{
    val : f32,
}

///////////////////////////////////////////////////////

/////////////////// RESOURCE DATA /////////////////////////

GameController :: struct{
    key_buffer : []f32,
    dead : f32,
    sensitvity : f32,
    gravity : f32,
    rcp_max_threshold : f32,
}

///////////////////////////////////////////////////////

// PhysicsContact :: struct{
//     contacts : [2]Physics,
//     contact_normal : mathematics.Vec2,
//     penetration : f32,  
// }


