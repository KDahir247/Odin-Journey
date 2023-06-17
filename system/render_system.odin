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

import "core:strings"
import "core:os"
import "core:unicode/utf16"
import "core:path/filepath"

import "../ecs"
import "../container"

//MAX_BATCH_SIZE :: 1024
//SpriteData := [MAX_BATCH_SIZE]SpriteInstanceData{}



@(private)
SpriteIndex :: struct{
    position : hlsl.float2, //UV has the same values as position.
}


GlobalDynamicConstantBuffer :: struct #align 16{
    sprite_sheet_size : hlsl.float2,
    device_conversion : hlsl.float2,
    viewport_size : hlsl.float2,
    time : u32,
    delta_time : u32,
}


@(private)
Shader :: struct{
    vertex_shader : ^d3d11.IVertexShader,
    vertex_blob : ^d3d_compiler.ID3DBlob,

    pixel_shader : ^d3d11.IPixelShader,
    pixel_blob : ^d3d_compiler.ID3DBlob,

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

    vertices := [4]SpriteIndex{
        {{0.0, 0.0}},
        {{1, 0.0}},
        {{1, 1}},
        {{0, 1}},
    }

    indices := [6]u16{
        0, 1, 2, 3, 0, 2,
    }

    cached_shaders : map[string]Shader = make(map[string]Shader)
    cached_layout : map[string]^d3d11.IInputLayout = make(map[string]^d3d11.IInputLayout)

    //TODO: issue with defer something doesn't work or the thread exit early (get destroyed)........
    defer{
        container.FREE_PROFILER_BUFFER()


        for _, cache in cached_shaders{
            if cache.vertex_shader != nil do cache.vertex_shader->Release() 
            if cache.vertex_blob != nil do cache.vertex_blob->Release()
            if cache.pixel_shader != nil do cache.pixel_shader->Release()
            if cache.pixel_blob != nil do cache.pixel_blob->Release()
        }


        for _, cache in cached_layout{
            if cache != nil do cache->Release()
        }


        delete_map(cached_layout)
        delete_map(cached_shaders)

        free(native_win)
        excl(&shared_data.Systems, container.System.DX11System)

    }

    container.BEGIN_EVENT("Device Construction & Query")

    d3d_feature_level := [2]d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0, d3d11.FEATURE_LEVEL._11_1}

    container.DX_CALL(
        d3d11.CreateDevice(nil, d3d11.DRIVER_TYPE.HARDWARE, nil, d3d11.CREATE_DEVICE_FLAGS{.SINGLETHREADED},&d3d_feature_level[0],len(d3d_feature_level), d3d11.SDK_VERSION,&base_device, nil, &base_device_context),

        base_device,
    )

    container.DX_CALL(
        base_device->QueryInterface(d3d11.IDevice_UUID, (^rawptr)(&device)),
        device,
    )

    container.DX_CALL(
        base_device_context->QueryInterface(d3d11.IDeviceContext_UUID, (^rawptr)(&device_context)),
        device_context,
    )

    container.DX_CALL(
        device->QueryInterface(dxgi.IDevice_UUID, (^rawptr)(&dxgi_device)),
        dxgi_device,
    )

    container.DX_CALL(
        dxgi_device->GetAdapter(&dxgi_adapter),
        dxgi_adapter,
    )

    container.DX_CALL(
        dxgi_adapter->GetParent(dxgi.IFactory4_UUID, (^rawptr)(&dxgi_factory)),
        dxgi_factory,
    )

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
    
    container.DX_CALL(
        dxgi_factory->CreateSwapChainForHwnd(device, native_win, &swapchain_descriptor, nil,nil,&swapchain ),
        swapchain,
    )
    
    container.DX_CALL(swapchain->GetDesc1(&swapchain_descriptor), nil)

    container.DX_CALL(
        swapchain->GetBuffer(0,d3d11.ITexture2D_UUID,(^rawptr)(&back_buffer)),
        nil,
    )
    
    container.DX_CALL(
        device->CreateRenderTargetView(back_buffer, nil, &back_render_target_view),
         back_render_target_view,
    )

    back_buffer->Release()

    container.END_EVENT()

   
    viewport : d3d11.VIEWPORT

    viewport.Width = f32(swapchain_descriptor.Width)
    viewport.Height = f32(swapchain_descriptor.Height)
    viewport.MaxDepth = 1

    container.BEGIN_EVENT("CBuffer Construction")

    vs_cbuffer_0 : ^d3d11.IBuffer

    constant_buffer_descriptor := d3d11.BUFFER_DESC{
        ByteWidth = size_of(GlobalDynamicConstantBuffer),
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.CONSTANT_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{.WRITE},
    }

    container.DX_CALL(
        device->CreateBuffer(&constant_buffer_descriptor, nil,&vs_cbuffer_0),
         vs_cbuffer_0,
    )

    container.END_EVENT()

    container.BEGIN_EVENT("Image Texture Construction")
    
    //TODO: Khal this need working on not right
    sprite_texture_resource_view : ^d3d11.IShaderResourceView
    sprite_texture : ^d3d11.ITexture2D
    sprite_sheet_resource : d3d11.SUBRESOURCE_DATA
    atlas_texture_descriptor := d3d11.TEXTURE2D_DESC{}

    width : i32 = 0
    height : i32 = 0
    channel : i32 = 0
    desired_channel : i32 = 4

    for tex in ecs.get_component_list(&shared_data.ecs, container.SpriteCache){
        img_data := image.load(tex.Val, &width, &height, &channel, desired_channel)
    
        img_pitch := u32(width * 4)
        
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
        
        container.DX_CALL(
            device->CreateTexture2D(&atlas_texture_descriptor, &sprite_sheet_resource, &sprite_texture),
            nil,
        ) // IO  BLOCK fun!
    
        container.DX_CALL(
            device->CreateShaderResourceView(sprite_texture,nil,&sprite_texture_resource_view),
            nil,
        )
    }
  
    texture_sampler : ^d3d11.ISamplerState

    sampler_descriptor := d3d11.SAMPLER_DESC{}

    sampler_descriptor.Filter = d3d11.FILTER.MIN_LINEAR_MAG_MIP_POINT
    sampler_descriptor.AddressU = d3d11.TEXTURE_ADDRESS_MODE.CLAMP
    sampler_descriptor.AddressV = d3d11.TEXTURE_ADDRESS_MODE.CLAMP
    sampler_descriptor.AddressW = d3d11.TEXTURE_ADDRESS_MODE.CLAMP
    sampler_descriptor.MipLODBias = 0
    sampler_descriptor.MaxAnisotropy = 1
    sampler_descriptor.ComparisonFunc = d3d11.COMPARISON_FUNC.ALWAYS
    sampler_descriptor.BorderColor[0] = 0
    sampler_descriptor.BorderColor[1] = 0
    sampler_descriptor.BorderColor[2] = 0
    sampler_descriptor.BorderColor[3] = 0
    sampler_descriptor.MinLOD = 0
    sampler_descriptor.MaxLOD = d3d11.FLOAT32_MAX
    
    container.DX_CALL(
        device->CreateSamplerState(&sampler_descriptor, &texture_sampler),
        texture_sampler,
    )

    container.END_EVENT()
    
    container.BEGIN_EVENT("Shader Construction")

    instance_layout_descriptor := [6]d3d11.INPUT_ELEMENT_DESC{
        {"QUAD_ID", 0, dxgi.FORMAT.R32G32_FLOAT, 0,0, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0},

        {"TRANSFORM",0, dxgi.FORMAT.R32G32B32A32_FLOAT,1,0, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",1, dxgi.FORMAT.R32G32B32A32_FLOAT,1,16, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",2, dxgi.FORMAT.R32G32B32A32_FLOAT,1,32, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",3, dxgi.FORMAT.R32G32B32A32_FLOAT,1,48, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"SRC_RECT", 0, dxgi.FORMAT.R32G32B32A32_FLOAT,1,64, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA,1},
    }

    shader_dir,match_err := filepath.glob(`shaders\*.hlsl`)

    //TODO: khal we can optimize this.
    for shader_path in shader_dir{

        shader_dir, shader_file := filepath.split(shader_path)

        c_shader_file : cstring = strings.clone_to_cstring(shader_file)

        shader_path_byte, _ := os.read_entire_file_from_filename(shader_path)
        
        defer{
            delete(shader_path_byte)
            delete_cstring(c_shader_file)
        }

        shader_bytecode := raw_data(shader_path_byte)
        shader_bytecode_length := uint(len(shader_path_byte))

         shader : Shader

         container.DX_CALL(
            d3d_compiler.Compile(shader_bytecode, shader_bytecode_length, c_shader_file, nil, nil, "vs_main", "vs_5_0",15,0,&shader.vertex_blob, nil),
            nil,
         )

       container.DX_CALL(
        d3d_compiler.Compile(shader_bytecode, shader_bytecode_length, c_shader_file, nil, nil, "ps_main", "ps_5_0",15,0,&shader.pixel_blob, nil),
         nil,
        )

        container.DX_CALL(
            device->CreateVertexShader(shader.vertex_blob->GetBufferPointer(),shader.vertex_blob->GetBufferSize(), nil, &shader.vertex_shader),
            nil,
        )

        container.DX_CALL(
            device->CreatePixelShader(shader.pixel_blob->GetBufferPointer(), shader.pixel_blob->GetBufferSize(), nil, &shader.pixel_shader),
            nil,
        )

        cache_key := shader_file[0:len(shader_file) - 5]

        layout : ^d3d11.IInputLayout
        container.DX_CALL(
            device->CreateInputLayout(&instance_layout_descriptor[0], len(instance_layout_descriptor), shader.vertex_blob->GetBufferPointer(), shader.vertex_blob->GetBufferSize(), &layout),
            nil,
        )

        cached_layout[cache_key] = layout

        if !(cache_key in cached_shaders){
            cached_shaders[cache_key] = shader
        }
    }

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

    container.DX_CALL(
        device->CreateBuffer(&vertex_buffer_descriptor, &vertex_resource, &vertex_buffer),
        vertex_buffer,
    )

    index_buffer : ^d3d11.IBuffer
    index_buffer_descriptor : d3d11.BUFFER_DESC
    index_resource : d3d11.SUBRESOURCE_DATA

    index_buffer_descriptor.ByteWidth = size_of(indices)
    index_buffer_descriptor.BindFlags = {.INDEX_BUFFER}
    index_buffer_descriptor.StructureByteStride = size_of(u16)
    index_buffer_descriptor.Usage = d3d11.USAGE.DEFAULT

    index_resource.pSysMem = (rawptr)(&indices)

    container.DX_CALL(
        device->CreateBuffer(&index_buffer_descriptor, &index_resource, &index_buffer),
        index_buffer,
    )

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
    
    container.DX_CALL(
        device->CreateRasterizerState(&raterizer_descriptor,&raterizer_state),
        raterizer_state,
    )

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

    container.DX_CALL(
        device->CreateDepthStencilState(&stencil_depth_descriptor, &stencil_depth_state),
        stencil_depth_state,
    )

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

    container.DX_CALL(
        device->CreateBlendState(&blend_descriptor, &blend_state),
        blend_state,
    )

    container.END_EVENT()

    ////////////////////////////////////////////////////

    container.BEGIN_EVENT("Binding")

    VERTEX_STRIDE : u32 = size_of(SpriteIndex) // size of Vertex
    VERTEX_OFFSET : u32 = 0

    device_context->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)
    device_context->IASetVertexBuffers(0, 1, &vertex_buffer, &VERTEX_STRIDE, &VERTEX_OFFSET)
    device_context->IASetIndexBuffer(index_buffer, dxgi.FORMAT.R16_UINT, 0)

    device_context->RSSetState(raterizer_state)

    device_context->OMSetRenderTargets(1, &back_render_target_view, nil)
    device_context->OMSetDepthStencilState(stencil_depth_state, 0)
    device_context->OMSetBlendState(blend_state, &{1.0, 1.0, 1.0, 1.0}, 0xFFFFFFFF)
    device_context->RSSetViewports(1, &viewport)

    container.END_EVENT()

    for (container.System.WindowSystem in shared_data.Systems){

        // Set global constant buffer 
        mapped_subresource : d3d11.MAPPED_SUBRESOURCE
        
        container.DX_CALL(
            device_context->Map(vs_cbuffer_0,0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_subresource),
            nil,
        )

        {
            constants := (^GlobalDynamicConstantBuffer)(mapped_subresource.pData)

            constants.sprite_sheet_size = {0,0}
            constants.device_conversion = {2.0 / viewport.Width, -2.0 / viewport.Height}
            constants.viewport_size = {viewport.Width, viewport.Height}
            constants.time = u32(shared_data.time)
            constants.delta_time = 0
        }
        device_context->Unmap(vs_cbuffer_0, 0)

        device_context->ClearRenderTargetView(back_render_target_view, &{0.0, 0.4, 0.5, 1.0})

        for render_entity_id in ecs.get_entities_with_components(&shared_data.ecs, {container.ShaderCache}){
        container.BEGIN_EVENT("Draw Call")
           
            //TODO: Handle null check. passing null will result in the gpu to crash x.x
            target_shader_cache_key := ecs.get_component_unchecked(&shared_data.ecs, render_entity_id, container.ShaderCache)
            shader_cache, _ := cached_shaders[target_shader_cache_key.Val]
            
            device_context->IASetInputLayout(cached_layout[target_shader_cache_key.Val])

            device_context->VSSetShader(shader_cache.vertex_shader, nil, 0)
            device_context->PSSetShader(shader_cache.pixel_shader, nil, 0)
            
            device_context->VSSetConstantBuffers(0,1,&vs_cbuffer_0)

            device_context->PSSetShaderResources(0,1,&sprite_texture_resource_view)
            device_context->PSSetSamplers(0,1, &texture_sampler)

            device_context->DrawIndexed(len(indices),0,0)
            //device_context->DrawIndexedInstanced(len(indices),1,0,0,0)

            container.DX_CALL(
                swapchain->Present(1,0),
                nil,
            )

            device_context->OMSetRenderTargets(1, &back_render_target_view, nil)
    container.END_EVENT()

        }

    }

}