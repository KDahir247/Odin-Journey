package common

import "vendor:sdl2"
import "vendor:directx/d3d_compiler"
import "vendor:directx/d3d11"
import "vendor:stb/image"

import "core:sys/windows"
import "core:sync"
import "core:prof/spall"
import "core:math/linalg/hlsl"
import "core:fmt"

//TODO:remove
import "../mathematics"
import "../ecs"

//////////////////// COMMAN MATH ///////////////////////


IDENTITY : hlsl.float4x4 :  {
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
}


//////////////////// COMMON PATH ///////////////////////


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

//////////////////// Utility FN ////////////////////////
 
@(private)
DX11_ERR :: struct{
    err : string,
    description : string,
}

@(private)
HR_ERR_MAP : map[int]DX11_ERR = {
    0x887C0002 = DX11_ERR{
        err = "D3D11_ERROR_FILE_NOT_FOUND",
        description = "The file was not found",
    },
    0x887C0001 = DX11_ERR{
        err = "D3D11_ERROR_TOO_MANY_UNIQUE_STATE_OBJECTS",
        description = "There are too many unique instances of a particular type of state object",
    },
    0x887C0003 = DX11_ERR{
        err = "D3D11_ERROR_TOO_MANY_UNIQUE_VIEW_OBJECTS",
        description = "There are too many unique instances of a particular type of view object",
    },
    0x887C0004 = DX11_ERR{
        err = "D3D11_ERROR_DEFERRED_CONTEXT_MAP_WITHOUT_INITIAL_DISCARD",
        description = "The first call to ID3D11DeviceContext::Map after either ID3D11Device::CreateDeferredContext or ID3D11DeviceContext::FinishCommandList per Resource was not D3D11_MAP_WRITE_DISCARD",
    },
    0x80004005 = DX11_ERR{
        err = "E_FAIL",
        description = "Attempted to create a device with the debug layer enabled and the layer is not installed",
    },
    0x80070057 = DX11_ERR{
        err = "E_INVALIDARG",
        description = "An invalid parameter was passed to the returning function",
    },
    0x8007000E = DX11_ERR{
        err = "E_OUTOFMEMORY",
        description = "Direct3D could not allocate sufficient memory to complete the call",
    },
    0x80004001 = DX11_ERR{
        err = "E_NOTIMPL",
        description = "The method call isn't implemented with the passed parameter combination",
    },
    1 = DX11_ERR{
        err = "S_FALSE",
        description = "Alternate success value, indicating a successful but nonstandard completion (the precise meaning depends on context)",
    },

    0x887A002B = DX11_ERR{
        err = "DXGI_ERROR_ACCESS_DENIED",
        description = "You tried to use a resource to which you did not have the required access privileges. This error is most typically caused when you write to a shared resource with read-only access",
    },
    0x887A0026 = DX11_ERR{
        err = "DXGI_ERROR_ACCESS_LOST",
        description = "The desktop duplication interface is invalid. The desktop duplication interface typically becomes invalid when a different type of image is displayed on the desktop",
    },
    0x887A0036 = DX11_ERR{
        err = "DXGI_ERROR_ALREADY_EXISTS",
        description = "The desired element already exists. This is returned by DXGIDeclareAdapterRemovalSupport if it is not the first time that the function is called",
    },
    0x887A002A = DX11_ERR{
        err = "DXGI_ERROR_CANNOT_PROTECT_CONTENT",
        description = "DXGI can't provide content protection on the swap chain. This error is typically caused by an older driver, or when you use a swap chain that is incompatible with content protection",
    },
    0x887A0006 = DX11_ERR{
        err = "DXGI_ERROR_DEVICE_HUNG",
        description = "The application's device failed due to badly formed commands sent by the application. This is an design-time issue that should be investigated and fixed",
    },
    0x887A0005 = DX11_ERR{
        err = "DXGI_ERROR_DEVICE_REMOVED",
        description = "The video card has been physically removed from the system, or a driver upgrade for the video card has occurred. The application should destroy and recreate the device. For help debugging the problem, call ID3DXXDevice::GetDeviceRemovedReason",
    },
    0x887A0007 = DX11_ERR{
        err = "DXGI_ERROR_DEVICE_RESET",
        description = "The device failed due to a badly formed command. This is a run-time issue; The application should destroy and recreate the device",
    },
    0x887A0020 = DX11_ERR{
        err = "DXGI_ERROR_DRIVER_INTERNAL_ERROR",
        description = "The driver encountered a problem and was put into the device removed state",
    },
    0x887A000B = DX11_ERR{
        err = "DXGI_ERROR_FRAME_STATISTICS_DISJOINT",
        description = "An event (for example, a power cycle) interrupted the gathering of presentation statistics",
    },
    0x887A000C = DX11_ERR{
        err = "DXGI_ERROR_GRAPHICS_VIDPN_SOURCE_IN_USE",
        description = "The application attempted to acquire exclusive ownership of an output, but failed because some other application (or device within the application) already acquired ownership",
    },
    0x887A0001 = DX11_ERR{
        err = "DXGI_ERROR_INVALID_CALL",
        description = "The application provided invalid parameter data; this must be debugged and fixed before the application is released",
    },
    0x887A0003 = DX11_ERR{
        err = "DXGI_ERROR_MORE_DATA",
        description = "The buffer supplied by the application is not big enough to hold the requested data",
    },
    0x887A002C = DX11_ERR{
        err = "DXGI_ERROR_NAME_ALREADY_EXISTS",
        description = "The supplied name of a resource in a call to IDXGIResource1::CreateSharedHandle is already associated with some other resource",
    },
    0x887A0021 = DX11_ERR{
        err = "DXGI_ERROR_NONEXCLUSIVE",
        description = "A global counter resource is in use, and the Direct3D device can't currently use the counter resource",
    },
    0x887A0022 = DX11_ERR{
        err = "DXGI_ERROR_NOT_CURRENTLY_AVAILABLE",
        description = "The resource or request is not currently available, but it might become available later",
    },
    0x887A0002 = DX11_ERR{
        err = "DXGI_ERROR_NOT_FOUND",
        description = "When calling IDXGIObject::GetPrivateData, the GUID passed in is not recognized as one previously passed to IDXGIObject::SetPrivateData or IDXGIObject::SetPrivateDataInterface. When calling IDXGIFactory::EnumAdapters or IDXGIAdapter::EnumOutputs, the enumerated ordinal is out of range",
    },
    0x887A0029 = DX11_ERR{
        err = "DXGI_ERROR_RESTRICT_TO_OUTPUT_STALE",
        description = "The DXGI output (monitor) to which the swap chain content was restricted is now disconnected or changed",
    },
    0x887A002D = DX11_ERR{
        err = "DXGI_ERROR_SDK_COMPONENT_MISSING",
        description = "The operation depends on an SDK component that is missing or mismatched",
    },
    0x887A0028 = DX11_ERR{
        err = "DXGI_ERROR_SESSION_DISCONNECTED",
        description = "The Remote Desktop Services session is currently disconnected",
    },
    0x887A0004 = DX11_ERR{
        err = "DXGI_ERROR_UNSUPPORTED",
        description = "The requested functionality is not supported by the device or the driver",
    },
    0x887A0027 = DX11_ERR{
        err = "DXGI_ERROR_WAIT_TIMEOUT",
        description = "The time-out interval elapsed before the next desktop frame was available",
    },
    0x887A000A = DX11_ERR{
        err = "DXGI_ERROR_WAS_STILL_DRAWING",
        description = "The GPU was busy at the moment when a call was made to perform an operation, and did not execute or schedule the operation",
    },
}

@(deferred_in=DX_END)
@(optimization_mode="speed")
DX_CALL :: #force_inline proc(hr : d3d11.HRESULT, auto_free_ptr : rawptr, panic_on_fail := false, loc := #caller_location)  {
    when ODIN_DEBUG{
        if hr != 0{
            hr_index := int(hr) & 0xFFFFFFFF
            err_code := HR_ERR_MAP[hr_index]
            fmt.printf("\n\nDX11 ERROR CODE : %v\nDX 11 ERROR : %s\nDESCRIPTION : %s \nLOCATION : %s\n\n", hr_index, err_code.err, err_code.description, loc)

            if panic_on_fail{
                panic("DX11 Initialization Failed", loc)
            }
        }
    }
}


@(private)
@(optimization_mode="speed")
DX_END :: #force_inline proc(hr : d3d11.HRESULT, auto_free_ptr : rawptr, panic_on_fail := false, loc := #caller_location) {
    if hr == 0 && auto_free_ptr != nil{
        unknown_ptr := cast(^d3d11.IUnknown)auto_free_ptr

        unknown_ptr->Release()
        unknown_ptr = nil
    }
    
}


//TODO got to look at this lol....
@(optimization_mode="speed")
CREATE_PROFILER :: proc(name : string,thread_id : int = 0){
    when #config(PROFILE,true){
        profiler_context = spall.context_create_with_sleep(name)
    }

    CREATE_PROFILER_BUFFER(thread_id)
}

@(optimization_mode="speed")
CREATE_PROFILER_BUFFER :: #force_inline proc(thread_id : int){
    when #config(PROFILE,true){
        profiler_backer = make([]u8, spall.BUFFER_DEFAULT_SIZE)
        profiler_buffer = spall.buffer_create(profiler_backer, u32(thread_id), 0)
    }
}

@(optimization_mode="speed")
FREE_PROFILER :: proc(){
    spall.buffer_destroy(&profiler_context, &profiler_buffer)
    FREE_PROFILER_CONTEXT()
}

@(optimization_mode="speed")
FREE_PROFILER_BUFFER :: #force_inline proc(){
    when #config(PROFILE,true){
		spall.buffer_destroy(&profiler_context, &profiler_buffer)
            delete(profiler_backer)
    }
}

@(optimization_mode="speed")
FREE_PROFILER_CONTEXT :: #force_inline proc(){
    when #config(PROFILE,true){
		spall.context_destroy(&profiler_context)
    }
}

@(optimization_mode="speed")
BEGIN_EVENT :: #force_inline proc(name : string){
    when #config(PROFILER, true){
        spall._buffer_begin(&profiler_context, &profiler_buffer, name)
    }
}

@(optimization_mode="speed")
END_EVENT :: #force_inline proc(){
    when #config(PROFILER, true){
        spall._buffer_end(&profiler_context, &profiler_buffer)
    }
}

//////////////////// CORE DATA /////////////////////////


@(private) profiler_context : spall.Context
@(private) @(thread_local) profiler_buffer : spall.Buffer
@(private) @(thread_local) profiler_backer : []u8

Window :: struct #align 64 {
    handle : windows.HWND,
    width : f32,
    height : f32,
}

SharedContext :: struct #align 64 {
    barrier : ^sync.Barrier,
	Systems : SystemInitFlags,
	Mutex : sync.Mutex,
	Cond : sync.Cond,
    time : f64, //TODO: remove
    ecs : ecs.Context,
}
System :: enum u8{
	GameSystem,
	WindowSystem,
	DX11System,
    AudioSystem,
    UISystem,
}

SystemInitFlags :: bit_set[System; u32]
/////////////////////////////////////////////////////////

/////////////////// RENDERER DATA ///////////////////////
MAX_SPRITE_BATCH :: 2048

INSTANCE_BYTE_WIDTH :: size_of(SpriteInstanceData) << 11

SpriteIndex :: struct{
    position : hlsl.float2,
}

GlobalDynamicConstantBuffer :: struct #align 16{
    sprite_sheet_size : hlsl.float2,
    device_conversion : hlsl.float2,
    viewport_size : hlsl.float2,
    time : f32,
    delta_time : f32,
}

RenderParam :: struct {
    batch_id : ecs.Entity,

    vertex_shader : ^d3d11.IVertexShader,
    vertex_blob : ^d3d_compiler.ID3DBlob,

    pixel_shader : ^d3d11.IPixelShader,
    pixel_blob : ^d3d_compiler.ID3DBlob,

    layout_input : ^d3d11.IInputLayout,

    texture_resource : ^d3d11.IShaderResourceView,
}

SpriteHandle :: struct{
    batch_handle : uint,
    sprite_handle : int,
}

SpriteBatch :: struct{
    sprite_batch : [dynamic]SpriteInstanceData,

    //Shared
    texture : rawptr,
    width : i32,
    height : i32,
    shader_cache : u32,
}

SpriteInstanceData :: struct{
    transform : hlsl.float4x4,
    src_rect : hlsl.float4,
    hue_displacement : hlsl.float,
    // We will be sorting by zdepth
    z_depth : hlsl.uint,
}


@(optimization_mode="speed")
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
sprite_batch_free :: proc(sprite_batch : ^SpriteBatch){
    delete(sprite_batch.sprite_batch)

    if sprite_batch.texture != nil{
        image.image_free(sprite_batch.texture)
        sprite_batch.texture = nil
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

Animation :: struct{
    width : int, // (the sprite width for the animation clip)
    height : int, // (the sprite height for the animation clip)
    index : int, // (the row the animation strip is in)
    len : int, // (how much column the animation has aka. the number of clips)
    carry_over : int, // (if the animation continues over from the index to the next index what index is it carried over to and how much column does it take up. 0 mean no carry over 1 mean the it will take 1 column from the next row, etc...)
    offset_slice : int, // (how much column should be be skipped in the sprite sheet)
    animation_speed : int, // (the speed of the animation 1.0x mean normal, 2.0x mean 2 times etc...)
    loop : int, // (looping animation clip. 1 is looping, 0 mean doesn't loop)
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