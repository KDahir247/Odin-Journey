package common

import "vendor:directx/d3d_compiler"
import "vendor:directx/d3d11"
import "vendor:stb/image"

import "core:sys/windows"
import "core:sync"
import "core:prof/spall"
import "core:math/linalg/hlsl"

when ODIN_DEBUG{
    import "core:fmt"
}

import "../ecs"

//////////////////// COMMAN MATH ///////////////////////

IDENTITY : hlsl.float4x4 :  {
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

FIXED_DELTA_TIME : f64 : 0.01388888888888888888888888888889 // 1 / 72
SCALED_FIXED_DELTA_TIME : f64 : FIXED_DELTA_TIME * TIME_SCALE
TIME_SCALE : f64 :  1.0

DELTA_TIME_VSYNC_144 : f64 : 0.00694444444444444444444444444444

MAX_DELTA_TIME : f64 : 0.3333 * TIME_SCALE

//////////////////// Utility FN ////////////////////////

@(deferred_in=DX_END)
@(optimization_mode="speed")
DX_CALL ::  proc(hr : d3d11.HRESULT, auto_free_ptr : rawptr, panic_on_fail := false, loc := #caller_location)  {
    when ODIN_DEBUG{

        // Eat a bit of memory x.x
        //TODO: khal we need to free this..
        // @(static) HR_ERR_MAP : map[int]string 
        // HR_ERR_MAP = {
        //     0x887C0002 =  "DX11 ERROR CODE : D3D11_ERROR_FILE_NOT_FOUND\nDESCRIPTION : The file was not found",
        //     0x887C0001 = "DX11 ERROR CODE : D3D11_ERROR_TOO_MANY_UNIQUE_STATE_OBJECTS\nDESCRIPTION : There are too many unique instances of a particular type of state object",
        //     0x887C0003 = "DX11 ERROR CODE : D3D11_ERROR_TOO_MANY_UNIQUE_VIEW_OBJECTS\nDESCRIPTION : There are too many unique instances of a particular type of view object", 
        //     0x887C0004 = "DX11 ERROR CODE : D3D11_ERROR_DEFERRED_CONTEXT_MAP_WITHOUT_INITIAL_DISCARD\nDESCRIPTION : The first call to ID3D11DeviceContext::Map after either ID3D11Device::CreateDeferredContext or ID3D11DeviceContext::FinishCommandList per Resource was not D3D11_MAP_WRITE_DISCARD", 
        //     0x80004005 = "DX11 ERROR CODE : E_FAIL\nDESCRIPTION : Attempted to create a device with the debug layer enabled and the layer is not installed",
        //     0x80070057 = "DX11 ERROR CODE : E_INVALIDARG\nnDESCRIPTION : An invalid parameter was passed to the returning function",
        //     0x8007000E = "DX11 ERROR CODE : E_OUTOFMEMORY\nDESCRIPTION : Direct3D could not allocate sufficient memory to complete the call",
        //     0x80004001 = "DX11 ERROR CODE : E_NOTIMPL\nDESCRIPTION : The method call isn't implemented with the passed parameter combination", 
        //     0x1 = "DX11 ERROR CODE : S_FALSE\nDESCRIPTION : Alternate success value, indicating a successful but nonstandard completion (the precise meaning depends on context)", 
        //     0x887A002B = "DX11 ERROR CODE : DXGI_ERROR_ACCESS_DENIED\nDESCRIPTION : You tried to use a resource to which you did not have the required access privileges. This error is most typically caused when you write to a shared resource with read-only access",
        //     0x887A0026 = "DX11 ERROR CODE : DXGI_ERROR_ACCESS_LOST\nDESCRIPTION : The desktop duplication interface is invalid. The desktop duplication interface typically becomes invalid when a different type of image is displayed on the desktop",
        //     0x887A0036 = "DX11 ERROR CODE : DXGI_ERROR_ALREADY_EXISTS\nDESCRIPTION : The desired element already exists. This is returned by DXGIDeclareAdapterRemovalSupport if it is not the first time that the function is called",
        //     0x887A002A = "DX11 ERROR CODE : DXGI_ERROR_CANNOT_PROTECT_CONTENT\nDESCRIPTION : DXGI can't provide content protection on the swap chain. This error is typically caused by an older driver, or when you use a swap chain that is incompatible with content protection",
        //     0x887A0006 = "DX11 ERROR CODE : DXGI_ERROR_DEVICE_HUNG\nDESCRIPTION : The application's device failed due to badly formed commands sent by the application. This is an design-time issue that should be investigated and fixed",
        //     0x887A0005 = "DX11 ERROR_CODE : DXGI_ERROR_DEVICE_REMOVED\nDESCRIPTION : The video card has been physically removed from the system, or a driver upgrade for the video card has occurred. The application should destroy and recreate the device. For help debugging the problem, call ID3DXXDevice::GetDeviceRemovedReason",
        //     0x887A0007 = "DX11 ERROR CODE : DXGI_ERROR_DEVICE_RESET\nDESCRIPTION : The device failed due to a badly formed command. This is a run-time issue; The application should destroy and recreate the device",
        //     0x887A0020 = "DX11 ERROR CODE : DXGI_ERROR_DRIVER_INTERNAL_ERROR\nDESCRIPTION : The driver encountered a problem and was put into the device removed state",
        //     0x887A000B = "DX11 ERROR CODE : DXGI_ERROR_FRAME_STATISTICS_DISJOINT\nDESCRIPTION : An event (for example, a power cycle) interrupted the gathering of presentation statistics",
        //     0x887A000C = "DX11 ERROR CODE : DXGI_ERROR_GRAPHICS_VIDPN_SOURCE_IN_USE\nDESCRIPTION : The application attempted to acquire exclusive ownership of an output, but failed because some other application (or device within the application) already acquired ownership",
        //     0x887A0001 = "DX11 ERROR CODE : DXGI_ERROR_INVALID_CALL\nDESCRIPTION : The application provided invalid parameter data; this must be debugged and fixed before the application is released",
        //     0x887A0003 = "DX11 ERROR CODE : DXGI_ERROR_MORE_DATA\nDESCRIPTION : The buffer supplied by the application is not big enough to hold the requested data",
        //     0x887A002C = "DX11 ERROR CODE : DXGI_ERROR_NAME_ALREADY_EXISTS\nDESCRIPTION : The supplied name of a resource in a call to IDXGIResource1::CreateSharedHandle is already associated with some other resource",
        //     0x887A0021 = "DX11 ERROR CODE : DXGI_ERROR_NONEXCLUSIVE\nDESCRIPTION : A global counter resource is in use, and the Direct3D device can't currently use the counter resource",
        //     0x887A0022 = "DX11 ERROR CODE : DXGI_ERROR_NOT_CURRENTLY_AVAILABLE\nDESCRIPTION : The resource or request is not currently available, but it might become available later",
        //     0x887A0002 = "DX11 ERROR CODE : DXGI_ERROR_NOT_FOUND\nDESCRIPTION : When calling IDXGIObject::GetPrivateData, the GUID passed in is not recognized as one previously passed to IDXGIObject::SetPrivateData or IDXGIObject::SetPrivateDataInterface. When calling IDXGIFactory::EnumAdapters or IDXGIAdapter::EnumOutputs, the enumerated ordinal is out of range", 
        //     0x887A0029 = "DX11 ERROR CODE : DXGI_ERROR_RESTRICT_TO_OUTPUT_STALE\nDESCRIPTION : The DXGI output (monitor) to which the swap chain content was restricted is now disconnected or changed",
        //     0x887A002D = "DX11 ERROR CODE : DXGI_ERROR_SDK_COMPONENT_MISSING\nDESCRIPTION : The operation depends on an SDK component that is missing or mismatched", 
        //     0x887A0028 = "DX11 ERROR CODE : DXGI_ERROR_SESSION_DISCONNECTED\nDESCRIPTION : The Remote Desktop Services session is currently disconnected",
        //     0x887A0004 = "DX11 ERROR CODE : DXGI_ERROR_UNSUPPORTED\nDESCRIPTION : The requested functionality is not supported by the device or the driver",
        //     0x887A0027 = "DX11 ERROR CODE : DXGI_ERROR_WAIT_TIMEOUT\nDESCRIPTION : The time-out interval elapsed before the next desktop frame was available",
        //     0x887A000A = "DX11 ERROR CODE : DXGI_ERROR_WAS_STILL_DRAWING\nDESCRIPTION : The GPU was busy at the moment when a call was made to perform an operation, and did not execute or schedule the operation",
        // }

        if hr != 0{
            hr_index := int(hr) & 0xFFFFFFFF
            //err_code := HR_ERR_MAP[hr_index]
            fmt.printf("RAW ERROR ID : %x\n look RAW ERROR ID description at https://learn.microsoft.com/en-us/windows/win32/direct3d11/d3d11-graphics-reference-returnvalues or https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/dxgi-error\nLOCATION : %v", hr_index, loc)

            if panic_on_fail{
                panic("DX11 Initialization Failed", loc)
            }
        }
    }
}


@(private)
@(optimization_mode="speed")
DX_END :: proc(hr : d3d11.HRESULT, auto_free_ptr : rawptr, panic_on_fail := false, loc := #caller_location) {
    if hr == 0 && auto_free_ptr != nil{
        unknown_ptr := cast(^d3d11.IUnknown)auto_free_ptr

        unknown_ptr->Release()
        unknown_ptr = nil
    }
}


@(optimization_mode="size")
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

@(optimization_mode="size")
CREATE_PROFILER_BUFFER :: #force_inline proc(tid : u32, pid :u32= 0){
    when #config(PROFILE,true){
        if created == false{
            created = true

            profiler_backer := make([]u8, spall.BUFFER_DEFAULT_SIZE)
            profiler_buffer = spall.buffer_create(profiler_backer, tid, pid)
        }
    }
}

@(optimization_mode="size")
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

@(optimization_mode="size")
FREE_PROFILER_BUFFER :: #force_inline proc(){
    when #config(PROFILE,true){
        if created == true{
                        
        created = false

        defer delete(profiler_buffer.data)
		spall.buffer_destroy(&profiler_context, &profiler_buffer)
        }
    }
}

@(optimization_mode="speed")
BEGIN_EVENT :: proc(name : string){
    when #config(PROFILER, true){
        if created{
            spall._buffer_begin(&profiler_context, &profiler_buffer, name)
        }
    }
}

@(optimization_mode="speed")
END_EVENT :: proc(){
    when #config(PROFILER, true){
        if created{
            spall._buffer_end(&profiler_context, &profiler_buffer)
        }
    }
}

//////////////////// CORE DATA /////////////////////////


@(private) profiler_context : spall.Context
@(private) @(thread_local) profiler_buffer : spall.Buffer
@(private) @(thread_local) created : bool

/////////////////////////////////////////////////////////

/////////////////// RENDERER DATA ///////////////////////
MAX_SPRITE_BATCH :: 2048

INSTANCE_BYTE_WIDTH :: size_of(SpriteInstanceData) << 11

SpriteIndex :: struct{
    position : hlsl.float2,
}

GlobalDynamicConstantBuffer :: struct #align 16{
    viewport_size : hlsl.float2,
    time : f32,
    delta_time : f32,
}

RenderParam :: struct {
    vertex_shader : ^d3d11.IVertexShader,
    vertex_blob : ^d3d_compiler.ID3DBlob,

    pixel_shader : ^d3d11.IPixelShader,
    pixel_blob : ^d3d_compiler.ID3DBlob,

    layout_input : ^d3d11.IInputLayout,

    texture_resource : ^d3d11.IShaderResourceView,

}


//TODO: we don't need a mutex nor a cond 

RenderBatchBuffer :: struct #align 64  {
    changed_flag : bool,
    batches : []SpriteBatch,
    shared : []SpriteBatchShared,
}

SpriteHandle :: struct{
    batch_handle : uint,
    sprite_handle : int,
}

SpriteBatchShared :: struct{
    texture : rawptr,
    width : i32,
    height : i32,
    shader_cache : u32,
    identifier : u32,
}

SpriteBatch :: struct{
    sprite_batch : [dynamic]SpriteInstanceData,
}

SpriteInstanceData :: struct{
    transform : hlsl.float4x4,
    src_rect : hlsl.float4,
    hue_displacement : hlsl.float,
    // We will be sorting by zdepth
    z_depth : hlsl.uint,
}

@(optimization_mode="size")
create_game_entity :: proc(batch_handle : uint, instance_data : SpriteInstanceData) -> ecs.Entity{
    ecs_context := cast(^ecs.Context)context.user_ptr
    target_batch := ecs.get_component_unchecked(ecs_context, ecs.Entity(batch_handle), SpriteBatch)

    game_sprite_handle := sprite_batch_append(target_batch, instance_data)

    game_entity := ecs.create_entity(ecs_context)

    ecs.add_component_unchecked(ecs_context, game_entity, SpriteHandle{
        sprite_handle = game_sprite_handle,
        batch_handle = batch_handle,
    })

    return game_entity
}

@(optimization_mode="size")
create_sprite_batcher :: proc($tex_path : cstring, $shader_cache : u32) -> uint{
    ecs_context := cast(^ecs.Context)context.user_ptr
    
    identifier_idx := u32(len(ecs_context.component_map[SpriteBatchShared].entity_indices))

    sprite_batch_entity := ecs.create_entity(ecs_context)

    batch := ecs.add_component_unchecked(ecs_context,sprite_batch_entity, SpriteBatch{
        sprite_batch = make_dynamic_array_len_cap([dynamic]SpriteInstanceData,0, DEFAULT_BATCH_SIZE),
    })
    shared := ecs.add_component_unchecked(ecs_context, sprite_batch_entity, SpriteBatchShared{
        identifier = identifier_idx,
    })

    shared.texture = image.load(tex_path,&shared.width,&shared.height,nil,  4)
    shared.shader_cache = shader_cache
    
    return uint(sprite_batch_entity)
}

@(optimization_mode="size")
sprite_batch_append :: proc(sprite_batch : ^SpriteBatch, data : SpriteInstanceData) -> int{
    assert(len(sprite_batch.sprite_batch) < MAX_SPRITE_BATCH, "The sprite batcher has reach it maximum batch and is trying to append a batch maximum 2048")
    append(&sprite_batch.sprite_batch, data)
    return len(sprite_batch.sprite_batch) - 1
}

@(optimization_mode="speed")
sprite_batch_set :: #force_inline proc(sprite_batch : ^SpriteBatch, handle : int, data : SpriteInstanceData){
    #no_bounds_check{
        sprite_batch.sprite_batch[handle] = data
    }
}

@(optimization_mode="speed")
sprite_batch_free :: proc(){
    ecs_context := cast(^ecs.Context)context.user_ptr
    
    batcher_entity := ecs.get_entities_with_single_component_fast(ecs_context, SpriteBatch)

    for entity in batcher_entity{
        batcher, shared := ecs.get_components_2_unchecked(ecs_context, entity, SpriteBatch, SpriteBatchShared)

        image.image_free(shared.texture)
        shared.texture = nil

        delete(batcher.sprite_batch)

        ecs.remove_component(ecs_context, entity, SpriteBatch)
        ecs.remove_component(ecs_context, entity, SpriteBatchShared)
    }
}

////////////////////////////////////////////////////////


/////////////////// GAME DATA /////////////////////////

Position :: struct{
    Value : hlsl.float2,
}

Rotation :: struct{
    Value : f32,
    __Padding : f32,
}

Scale :: struct {
    Value : hlsl.float2,
}

Animator :: struct{
    clips :[]Animation,
    animation_speed : f64,
    current_clip : int,
    previous_frame : int, 
    animation_time : f64,
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

// CoolDownTimer:: struct{
//     cooldown_amount : u32,
//     cooldown_duration : u32,
// }

// Player :: struct{
//     //TODO: khal this structure doesn't hold. enemy can have cooldown timer and possibly objects
//     cooldown : [2]CoolDownTimer, 
// }

// GameEntity :: struct{
//     input_direction : int,
//     render_direction : sdl2.RendererFlip,
// }

