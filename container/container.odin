package game_container

import "../mathematics"
import "vendor:sdl2"
import "vendor:sdl2/image"
import "core:sync"
import "core:prof/spall"
import "vendor:directx/d3d11"

import "core:fmt"
//////////////////// Utility FN ////////////////////////
 

//Should be called when the ptr has been initalized.
@(deferred_in=_INTERNAL_AUTO_FREE)
AUTO_FREE :: #force_inline proc(ptr : rawptr)  {
}


@(private)
_INTERNAL_AUTO_FREE :: proc(ptr : rawptr) {
    unknown_ptr := cast(^d3d11.IUnknown)ptr
    if unknown_ptr != nil{
        unknown_ptr->Release()
        unknown_ptr = nil
    }
}


//TODO got to look at this lol....
CREATE_PROFILER :: proc(name : string){
    when #config(PROFILE,true){
        profiler_context = spall.context_create_with_sleep(name)
    }

    CREATE_PROFILER_BUFFER()
}


CREATE_PROFILER_BUFFER :: #force_inline proc(size : int = spall.BUFFER_DEFAULT_SIZE){
    when #config(PROFILE,true){
        profiler_backer := make([]u8, spall.BUFFER_DEFAULT_SIZE)
        profiler_buffer = spall.buffer_create(profiler_backer, u32(sync.current_thread_id()))
    }
}


FREE_PROFILER :: proc(){
    FREE_PROFILER_BUFFER()
    FREE_PROFILER_CONTEXT()
}

FREE_PROFILER_BUFFER :: #force_inline proc(){
    when #config(PROFILE,true){
		spall.buffer_destroy(&profiler_context, &profiler_buffer)
    }
}

FREE_PROFILER_CONTEXT :: #force_inline proc(){
    when #config(PROFILE,true){
		spall.context_destroy(&profiler_context)
    }
}

BEGIN_EVENT :: #force_inline proc(name : string){
    when #config(PROFILER, true){
        spall._buffer_begin(&profiler_context, &profiler_buffer, name)
    }
}

END_EVENT :: #force_inline proc(){
    when #config(PROFILER, true){
        spall._buffer_end(&profiler_context, &profiler_buffer)
    }
}

//////////////////// CORE DATA /////////////////////////
@(private) profiler_context : spall.Context
@(private) @(thread_local) profiler_buffer : spall.Buffer

GRID_DESC :: struct{
    GridWidth : i32,
    GridHeight : i32,
}

WINDOWS_DESC :: struct{
    GridDesc: GRID_DESC,
    Flags : sdl2.InitFlags,
    WinFlags : sdl2.WindowFlags,
}

SharedContext :: struct #align 64 {
    profiler : spall.Context,
	Systems : SystemInitFlags,
	Mutex : sync.Mutex,
	Cond : sync.Cond,
}
System :: enum u8{
	GameSystem,
	WindowSystem,
	DX11System,
}

SystemInitFlags :: bit_set[System; u32]
/////////////////////////////////////////////////////////

/////////////////// RENDERER DATA ///////////////////////
Vertex :: struct{
    Vertex : [2]f32,
    Uv : [2]f32,
}

SpriteDetail :: struct{
    Width : i32,
    Height : i32,
}

SpritePath :: struct{
    Path : string,
}

////////////////////////////////////////////////////////


/////////////////// GAME DATA /////////////////////////

Position :: struct{
    Value : [2]f32,
}

Rotation :: struct{
    Value : f32,
}

Scale :: struct {
    Value : [2]f32,
}



///////////////////////////////////////////////////////

//REMOVE BELOW
Physics :: struct{
    collider : mathematics.AABB,
    position : mathematics.Vec2,
    velocity : mathematics.Vec2,
    acceleration : mathematics.Vec2,
    accumulated_force : mathematics.Vec2,
    damping : f32, 
    inverse_mass : f32,
    friction : f32,
    restitution : f32,
    grounded : bool, //TODO: khal don't like this move to wanted to align it to power of twos
}

TileMap :: struct{
    texture : ^sdl2.Texture,
	dimension : mathematics.Vec2i,
}

GameConfig :: struct{
    img_flags : image.InitFlags,
    window_flags : sdl2.WindowFlags,
    render_flags : sdl2.RendererFlags,

    dimension : mathematics.Vec2i,
    center : mathematics.Vec2i,
    title : cstring,
    clear_color : int,
}


PhysicsContact :: struct{
    contacts : [2]Physics,
    contact_normal : mathematics.Vec2,
    penetration : f32,  
}

CoolDownTimer:: struct{
    cooldown_amount : u32,
    cooldown_duration : u32,
}

Player :: struct{
    //TODO: khal this structure doesn't hold. enemy can have cooldown timer and possibly objects
    cooldown : [2]CoolDownTimer, 
}

GameEntity :: struct{
    input_direction : int,
    render_direction : sdl2.RendererFlip,
}

DynamicResource :: struct{
 
    // time
    elapsed_time : u32,
    delta_time : f32,
    current_physics_time : f32,

}

Animator :: struct{
    current_animation : string,
    previous_frame : int,
    animation_time : f32,
    animation_speed : f32,
    clips : map[string]AnimationClip, 
}

AnimationClip :: struct{
    name : string, //TODO: khal we can remove this since we are using a map with a string as a key.
    dimension : mathematics.Vec2i, //width and height
    pos : int, // represent the vertical column of sprite sheet
    len : int, // represent the horizontal column of sprite sheet 
    loopable : bool, 
}


TextureAsset :: struct{
	texture : ^sdl2.Texture,
	dimension : mathematics.Vec2,
}