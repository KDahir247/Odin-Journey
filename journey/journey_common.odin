package journey

import "core:prof/spall"

//////////////////// Utility FN ////////////////////////

CREATE_PROFILER :: #force_inline proc($name : string, buffer_size : int = spall.BUFFER_DEFAULT_SIZE,thread_id : u32 = 0, pid : u32 = 0){
    when #config(PROFILE,true){
        if created == false{
            created = true


            profiler_context = spall.context_create_with_sleep(name)
            profiler_backer := make([]u8, buffer_size)
            profiler_buffer = spall.buffer_create(profiler_backer,thread_id, pid)
        }
    }
}

CREATE_PROFILER_BUFFER :: #force_inline proc(tid : u32, pid :u32= 0){
    when #config(PROFILE,true){
        if created == false{
            created = true

            profiler_backer := make([]u8, spall.BUFFER_DEFAULT_SIZE)
            profiler_buffer = spall.buffer_create(profiler_backer, tid, pid)
        }
    }
}

FREE_PROFILER :: #force_inline proc(){
    when #config(PROFILE,true){
        if created == true{
            created = false

            defer delete(profiler_buffer.data)
            spall.buffer_destroy(&profiler_context, &profiler_buffer)
            spall.context_destroy(&profiler_context)
        }
    }
}

FREE_PROFILER_BUFFER :: #force_inline proc(){
    when #config(PROFILE,true){
        if created == true{
                        
        created = false

        defer delete(profiler_buffer.data)
		spall.buffer_destroy(&profiler_context, &profiler_buffer)
        }
    }
}

BEGIN_EVENT :: proc(name : string){
    when #config(PROFILER, true){
        if created{
            spall._buffer_begin(&profiler_context, &profiler_buffer, name)
        }
    }
}

END_EVENT :: proc(){
    when #config(PROFILER, true){
        if created{
            spall._buffer_end(&profiler_context, &profiler_buffer)
        }
    }
}
/////////////////////////////////////////////////////////

//////////////////// Utility DATA /////////////////////////


@(private) profiler_context : spall.Context
@(private) @(thread_local) profiler_buffer : spall.Buffer
@(private) @(thread_local) created : bool

/////////////////////////////////////////////////////////


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

DEFAULT_BATCH_SIZE : u32 : 1024

FIXED_DELTA_TIME : f32 : 0.01388888888888888888888888888889 // 1 / 72
SCALED_FIXED_DELTA_TIME : f32 : FIXED_DELTA_TIME * TIME_SCALE
TIME_SCALE : f32 :  1.0

DELTA_TIME_VSYNC_144 : f32 : 0.00694444444444444444444444444444

MAX_DELTA_TIME : f32: 0.3333 * TIME_SCALE

//temp
ResourceCache :: struct{
    render_buffer : ^RenderBatchBuffer,
}
///////////////////////////////////////////////////////

/////////////////// RENDERER DATA /////////////////////
MAX_SPRITE_BATCH :: 2048

INSTANCE_BYTE_WIDTH :: size_of(RenderInstanceData) << 11

SpriteIndex :: struct{
    position : [2]f32,
}

GlobalDynamicVSConstantBuffer :: struct #align (16){
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
    sprite_batch_groups : map[uint]SpriteBatchGroup,
}

Changed :: enum{
    ALL,
    TRANSFORM,
    ANIMATION,
}

SpriteBatchGroup :: struct{
    texture_param : TextureParam,
    instances : [dynamic]RenderInstanceData, //TODO:khal we would want 
}

RenderInstanceData :: struct #align (16){
    transform : matrix[4,4]f32,
    src_rect : Rect,
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
SpriteInstance :: struct{
    hash : uint,
    instance_index : uint,
}

Position :: struct{
    x : f32,
    y : f32,
}

Rotation :: struct{
    z : f32,
    __padding : f32,
}

Scale :: struct {
    x : f32,
    y : f32,
}

Animator :: struct{
    clips :[]Animation,
    animation_speed : f32,
    current_clip : int,
    previous_frame : int, 
    animation_time : f32,
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

///////////////////////////////////////////////////////

/////////////////// RESOURCE DATA /////////////////////////

KeyResource :: struct{
    dir : [4]int,
    repeated : u8,
    //padding
    _ : u8,
    _ : u8,
}


///////////////////////////////////////////////////////


// //REMOVE BELOW
// Physics :: struct{
//     collider : mathematics.AABB,
//     position : mathematics.Vec2,
//     velocity : mathematics.Vec2,
//     acceleration : mathematics.Vec2,
//     accumulated_force : mathematics.Vec2,
//     damping : f32, 
//     inverse_mass : f32,
//     friction : f32,
//     restitution : f32,
//     grounded : bool, //TODO: khal don't like this move to wanted to align it to power of twos
// }

// TileMap :: struct{
//     texture : ^sdl2.Texture,
// 	dimension : mathematics.Vec2i,
// }

// PhysicsContact :: struct{
//     contacts : [2]Physics,
//     contact_normal : mathematics.Vec2,
//     penetration : f32,  
// }


