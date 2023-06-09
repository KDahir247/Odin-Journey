package system

import "vendor:sdl2"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"
import "vendor:directx/dxc"
import "vendor:stb/image"

import win32 "core:sys/windows"
import "core:math/linalg/hlsl"
import "core:thread"
import "core:sync"
import "core:c/libc"
import "core:prof/spall"
import "core:fmt"

import "../container"



@(private)
SpriteIndex :: struct{
    position : hlsl.float2, //UV has the same values as position.
}

SpriteInstanceData :: struct{
    transform : hlsl.float4x4,
    src_rect : hlsl.float4,
}

GlobalDynamicConstantBuffer :: struct #align 16{
    sprite_sheet_size : hlsl.float2,
    device_conversion : hlsl.float2,
    viewport_size : hlsl.float2,
    time : f32,
    delta_time : f32,
}


@(optimization_mode = "size")
set_sprite_batch :: proc(shader_res : ^d3d11.IShaderResourceView){
    //TODO 
    //Set the cbuffer
}


@(optimization_mode="size")
init_render_subsystem :: proc(winfo : rawptr){

    shared_data := cast(^container.SharedContext)context.user_ptr
    window_system_info := cast(^sdl2.SysWMinfo)winfo
    
    container.CREATE_PROFILER_BUFFER()

    assert(window_system_info.subsystem == .WINDOWS)

	native_win := dxgi.HWND(window_system_info.info.win.window)

    base_device : ^d3d11.IDevice
    base_device_context : ^d3d11.IDeviceContext

    device : ^d3d11.IDevice
    device_context : ^d3d11.IDeviceContext

    swapchain : ^dxgi.ISwapChain1
    back_buffer : ^d3d11.ITexture2D 
    back_render_target_view : ^d3d11.IRenderTargetView

    dxgi_device: ^dxgi.IDevice
	dxgi_adapter: ^dxgi.IAdapter
    dxgi_factory : ^dxgi.IFactory4

    defer{
        excl(&shared_data.Systems, container.System.DX11System)

        container.FREE_PROFILER_BUFFER()
    }

    container.BEGIN_EVENT("Device Construction & Query")

    d3d_feature_level := [2]d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0, d3d11.FEATURE_LEVEL._11_1}

    d3d11.CreateDevice(nil, d3d11.DRIVER_TYPE.HARDWARE, nil, d3d11.CREATE_DEVICE_FLAGS{.SINGLETHREADED},&d3d_feature_level[0],len(d3d_feature_level), d3d11.SDK_VERSION,&base_device, nil, &base_device_context)
    
    container.AUTO_FREE(base_device)
    container.AUTO_FREE(base_device_context)

    base_device->QueryInterface(d3d11.IDevice_UUID, (^rawptr)(&device))
	base_device_context->QueryInterface(d3d11.IDeviceContext_UUID, (^rawptr)(&device_context))
    
    container.AUTO_FREE(device)
    container.AUTO_FREE(device_context)


    //TODO: khal we want to create all the Img texture and cache the data.
    //We then want to have a way to spawn the enemy that have died after a set condition.
    //We need to figure out a way to move from the sprite sheet to play the next animation sequence.

    width : i32 = 0
    height : i32 = 0
    channel : i32 = 0
    desired_channel : i32 = 4

    img_data := image.load("resource/padawan/pad.png", &width, &height, &channel, desired_channel)

    img_pitch := u32(width * 4)

    sprite_texture_resource_view : ^d3d11.IShaderResourceView
    sprite_texture : ^d3d11.ITexture2D
    sprite_sheet_resource : d3d11.SUBRESOURCE_DATA
    atlas_texture_descriptor := d3d11.TEXTURE2D_DESC{}

    atlas_texture_descriptor.Width = u32(width) //full sprite sheet width
    atlas_texture_descriptor.Height = u32(height) //full sprite sheet height
    atlas_texture_descriptor.MipLevels = 1
    atlas_texture_descriptor.ArraySize = 1
    atlas_texture_descriptor.Format = dxgi.FORMAT.R8G8B8A8_UNORM
    atlas_texture_descriptor.SampleDesc.Count = 1
    atlas_texture_descriptor.Usage = d3d11.USAGE.IMMUTABLE
    atlas_texture_descriptor.BindFlags = d3d11.BIND_FLAGS{.SHADER_RESOURCE}

    sprite_sheet_resource.pSysMem = img_data
    sprite_sheet_resource.SysMemPitch = img_pitch

    device->CreateTexture2D(&atlas_texture_descriptor, &sprite_sheet_resource, &sprite_texture) // IO  BLOCK fun

    device->CreateShaderResourceView(sprite_texture,nil,&sprite_texture_resource_view)



	device->QueryInterface(dxgi.IDevice_UUID, (^rawptr)(&dxgi_device))
	dxgi_device->GetAdapter(&dxgi_adapter)
	dxgi_adapter->GetParent(dxgi.IFactory4_UUID, (^rawptr)(&dxgi_factory))

    container.AUTO_FREE(dxgi_device)
    container.AUTO_FREE(dxgi_adapter)
    container.AUTO_FREE(dxgi_factory)


    container.END_EVENT()

    container.BEGIN_EVENT("SwapChain Construction")

    swapchain_descriptor := dxgi.SWAP_CHAIN_DESC1{
        Width = 0,
        Height = 0,
        Format = dxgi.FORMAT.R8G8B8A8_UNORM,
        SampleDesc = {1, 0},
        BufferUsage = dxgi.USAGE{.RENDER_TARGET_OUTPUT},
        SwapEffect = dxgi.SWAP_EFFECT.FLIP_DISCARD,
        BufferCount = 2,
        Stereo = false,
        Flags = 0x0,
    }
    
    dxgi_factory->CreateSwapChainForHwnd(device, native_win, &swapchain_descriptor, nil,nil,&swapchain )
    
    swapchain->GetDesc1(&swapchain_descriptor)

    swapchain->GetBuffer(
        0,
        d3d11.ITexture2D_UUID,
        (^rawptr)(&back_buffer),
    )

    device->CreateRenderTargetView(back_buffer, nil, &back_render_target_view)
    container.AUTO_FREE(back_render_target_view)

    back_buffer->Release()

    container.END_EVENT()

    vertices := [4]SpriteIndex{
        {{0.0, 0.0}},
        {{1, 0.0}},
        {{1, 1}},
        {{0, 1}},
    }

    indices := [6]u16{
        0, 1, 2, 3, 0, 2,
    }

    viewport : d3d11.VIEWPORT

    viewport.Width = f32(swapchain_descriptor.Width)
    viewport.Height = f32(swapchain_descriptor.Height)
    viewport.MaxDepth = 1

    container.BEGIN_EVENT("CBuffer Construction")

    cbuffer_1 : ^d3d11.IBuffer

    global_constant_data : d3d11.SUBRESOURCE_DATA

    global_cbuffer_data := GlobalDynamicConstantBuffer{
        sprite_sheet_size = {0,0},
        device_conversion = {2.0 / viewport.Width, -2.0 / viewport.Height},
        viewport_size = {viewport.Width, viewport.Height},
        time = 0,
        delta_time = 0,
    }

    constant_buffer_descriptor := d3d11.BUFFER_DESC{
        ByteWidth = size_of(GlobalDynamicConstantBuffer),
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.CONSTANT_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{.WRITE},
    }

    global_constant_data.pSysMem = (rawptr)(&global_cbuffer_data)

    device->CreateBuffer(&constant_buffer_descriptor, &global_constant_data,&cbuffer_1)

    container.END_EVENT()

    container.BEGIN_EVENT("Image Texture Construction")

    

    //Sampler can stay the same
    texture_sampler : ^d3d11.ISamplerState

    sampler_descriptor := d3d11.SAMPLER_DESC{}

    sampler_descriptor.Filter = d3d11.FILTER.MIN_LINEAR_MAG_MIP_POINT
    sampler_descriptor.AddressU = d3d11.TEXTURE_ADDRESS_MODE.CLAMP
    sampler_descriptor.AddressV = d3d11.TEXTURE_ADDRESS_MODE.CLAMP
    sampler_descriptor.ComparisonFunc = d3d11.COMPARISON_FUNC.ALWAYS
    sampler_descriptor.MaxAnisotropy = 1
    sampler_descriptor.MaxLOD = d3d11.FLOAT32_MAX
    
    device->CreateSamplerState(&sampler_descriptor, &texture_sampler)

    container.END_EVENT()
    
    container.BEGIN_EVENT("Shader Construction")

    vertex_shader : ^d3d11.IVertexShader
    pixel_shader : ^d3d11.IPixelShader

    vs_blob : ^d3d_compiler.ID3DBlob
    ps_blob : ^d3d_compiler.ID3DBlob

    shader_byte := #load("../shaders/sprite_instancing.hlsl")
    shader_raw_data := raw_data(shader_byte)
    shader_byte_len := len(shader_byte)


    d3d_compiler.Compile(shader_raw_data, uint(shader_byte_len), "sprite_instancing.hlsl", nil, nil, "vs_main", "vs_5_0",0,0, &vs_blob, nil)
    device->CreateVertexShader(vs_blob->GetBufferPointer(), vs_blob->GetBufferSize(), nil, &vertex_shader)

    d3d_compiler.Compile(shader_raw_data, uint(shader_byte_len), "sprite_instancing.hlsl", nil, nil, "ps_main", "ps_5_0", 0, 0, &ps_blob, nil)
    device->CreatePixelShader(ps_blob->GetBufferPointer(), ps_blob->GetBufferSize(), nil, &pixel_shader)

    //TODO add the INSTANCE_DATA MVP matrix, Color??? (Prob not), SRC Rect 
    //TODO set vertex buffer count to 2
    input_layout : ^d3d11.IInputLayout
    input_layout_descriptor := [6]d3d11.INPUT_ELEMENT_DESC{
        {"QUAD_ID", 0, dxgi.FORMAT.R32G32_FLOAT, 0,0, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0},

        {"TRANSFORM",0, dxgi.FORMAT.R32G32B32A32_FLOAT,1,0, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",1, dxgi.FORMAT.R32G32B32A32_FLOAT,1,16, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",2, dxgi.FORMAT.R32G32B32A32_FLOAT,1,32, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",3, dxgi.FORMAT.R32G32B32A32_FLOAT,1,48, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"SRC_RECT", 0, dxgi.FORMAT.R32G32B32A32_FLOAT,1,64, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA,1},
    }

    device->CreateInputLayout(&input_layout_descriptor[0], len(input_layout_descriptor), vs_blob->GetBufferPointer(), vs_blob->GetBufferSize(), &input_layout)

    container.END_EVENT()


    container.BEGIN_EVENT("Buffer Creation")
   
    vertex_buffer : ^d3d11.IBuffer
    vertex_buffer_descriptor : d3d11.BUFFER_DESC
    vertex_resource : d3d11.SUBRESOURCE_DATA

    vertex_buffer_descriptor.ByteWidth = size_of(vertices)
    vertex_buffer_descriptor.BindFlags = {.VERTEX_BUFFER}
    vertex_buffer_descriptor.StructureByteStride = size_of(SpriteIndex)
    vertex_buffer_descriptor.Usage = d3d11.USAGE.DEFAULT

    vertex_resource.pSysMem = (rawptr)(&vertices)

    device->CreateBuffer(&vertex_buffer_descriptor, &vertex_resource, &vertex_buffer)

    index_buffer : ^d3d11.IBuffer
    index_buffer_descriptor : d3d11.BUFFER_DESC
    index_resource : d3d11.SUBRESOURCE_DATA

    index_buffer_descriptor.ByteWidth = size_of(indices)
    index_buffer_descriptor.BindFlags = {.INDEX_BUFFER}
    index_buffer_descriptor.StructureByteStride = size_of(u16)
    index_buffer_descriptor.Usage = d3d11.USAGE.DEFAULT

    index_resource.pSysMem = (rawptr)(&indices)

    device->CreateBuffer(&index_buffer_descriptor, &index_resource, &index_buffer)

    container.END_EVENT()

    container.BEGIN_EVENT("RasterizerState Creation")

    raterizer_state : ^d3d11.IRasterizerState

    raterizer_descriptor := d3d11.RASTERIZER_DESC{
        FillMode = d3d11.FILL_MODE.SOLID,
        CullMode = d3d11.CULL_MODE.NONE,
        DepthBias = 0,
        DepthBiasClamp = 1,
        SlopeScaledDepthBias = 0,
        DepthClipEnable = false,
        ScissorEnable = false,
        MultisampleEnable = true,
    }
    
    device->CreateRasterizerState(&raterizer_descriptor,&raterizer_state)

    container.END_EVENT()


    container.BEGIN_EVENT("Stencil Depth Creation")

    stencil_depth_state : ^d3d11.IDepthStencilState

    stencil_depth_descriptor := d3d11.DEPTH_STENCIL_DESC{
        DepthEnable = false,
        DepthWriteMask = d3d11.DEPTH_WRITE_MASK.ALL,
        DepthFunc = d3d11.COMPARISON_FUNC.LESS,
        StencilEnable = false,
        StencilReadMask = d3d11.DEFAULT_STENCIL_READ_MASK,
        StencilWriteMask = d3d11.DEFAULT_STENCIL_WRITE_MASK,
        FrontFace = {
            StencilFailOp = d3d11.STENCIL_OP.KEEP,
            StencilPassOp = d3d11.STENCIL_OP.REPLACE,
            StencilDepthFailOp = d3d11.STENCIL_OP.KEEP,
            StencilFunc = d3d11.COMPARISON_FUNC.ALWAYS,
        },
        BackFace = {
            StencilFailOp = d3d11.STENCIL_OP.KEEP,
            StencilPassOp = d3d11.STENCIL_OP.REPLACE,
            StencilDepthFailOp = d3d11.STENCIL_OP.KEEP,
            StencilFunc = d3d11.COMPARISON_FUNC.ALWAYS,
        },
    }

    device->CreateDepthStencilState(&stencil_depth_descriptor, &stencil_depth_state)

    container.END_EVENT()

    container.BEGIN_EVENT("BlendState Creation")

    blend_state : ^d3d11.IBlendState

    blend_descriptor := d3d11.BLEND_DESC{
        AlphaToCoverageEnable = false,
        IndependentBlendEnable = false, // use only render_target[0]
    }

    blend_descriptor.RenderTarget[0] = d3d11.RENDER_TARGET_BLEND_DESC{
        BlendEnable = true,
        SrcBlend = d3d11.BLEND.ONE,
        SrcBlendAlpha = d3d11.BLEND.ONE,

        DestBlend = d3d11.BLEND.INV_SRC_ALPHA,
        DestBlendAlpha = d3d11.BLEND.ONE,
        
        BlendOp = d3d11.BLEND_OP.ADD,
        BlendOpAlpha = d3d11.BLEND_OP.ADD,

        RenderTargetWriteMask = 15, //ALL
    }

    device->CreateBlendState(&blend_descriptor, &blend_state)

    container.END_EVENT()

    ////////////////////////////////////////////////////

    container.BEGIN_EVENT("Binding")

    device_context->IASetInputLayout(input_layout)
    
    VERTEX_STRIDE : u32 = size_of(SpriteIndex) // size of Vertex
    VERTEX_OFFSET : u32 = 0

    device_context->IASetVertexBuffers(0, 1, &vertex_buffer, &VERTEX_STRIDE, &VERTEX_OFFSET)
    device_context->IASetIndexBuffer(index_buffer, dxgi.FORMAT.R16_UINT, 0)
    device_context->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)
    
    device_context->VSSetConstantBuffers(0,1,&cbuffer_1)
    device_context->VSSetShader(vertex_shader, nil, 0)

    device_context->RSSetViewports(1, &viewport)

    device_context->PSSetShaderResources(0,1,&sprite_texture_resource_view)
    device_context->PSSetSamplers(0,1, &texture_sampler)

    device_context->PSSetShader(pixel_shader, nil, 0)

    device_context->RSSetState(raterizer_state)
    
    device_context->OMSetRenderTargets(1, &back_render_target_view, nil)
    device_context->OMSetBlendState(blend_state, &{1.0, 1.0, 1.0, 1.0}, 0xFFFFFFFF)

    device_context->OMSetDepthStencilState(stencil_depth_state, 0)
    container.END_EVENT()

    for (container.System.WindowSystem in shared_data.Systems){


        device_context->ClearRenderTargetView(back_render_target_view, &{0.0, 0.4, 0.5, 1.0})
    


       device_context->DrawIndexedInstanced(len(indices),1,0,0,0)

        swapchain->Present(1,0)


        device_context->OMSetRenderTargets(1, &back_render_target_view, nil)
    }
}