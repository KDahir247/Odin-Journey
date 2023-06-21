package system

import "vendor:sdl2"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"

import "core:math/linalg/hlsl"
import "core:c/libc"
import "core:fmt"

import "core:strings"
import "core:os"
import "core:path/filepath"

import "../ecs"
import "../container"


//TODO: khal move the struct to container
@(private)
SpriteIndex :: struct{
    position : hlsl.float2,
}

GlobalDynamicConstantBuffer :: struct #align 16{
    sprite_sheet_size : hlsl.float2,
    device_conversion : hlsl.float2,
    viewport_size : hlsl.float2,
    time : u32,
    delta_time : u32,
}


@(optimization_mode="size")
init_render_subsystem :: proc(winfo : ^sdl2.SysWMinfo){

    shared_data := cast(^container.SharedContext)context.user_ptr
    
    container.CREATE_PROFILER_BUFFER()

    assert(winfo.subsystem == .WINDOWS)

	native_win := dxgi.HWND(winfo.info.win.window)
    
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

    defer{
        container.FREE_PROFILER_BUFFER()

        //TODO khal doesn't seem to print cleaning render thread, so there is a issue here
        for render_param_entity in ecs.get_entities_with_single_component_fast(&shared_data.ecs, container.RenderParam){
            render_param := ecs.get_component_unchecked(&shared_data.ecs, render_param_entity, container.RenderParam)

                render_param.vertex_shader->Release()
                render_param.vertex_blob->Release()
                render_param.pixel_shader->Release()
                render_param.pixel_blob->Release()
                render_param.layout_input->Release()
                render_param.texture_resource->Release()
          
            ecs.remove_component(&shared_data.ecs, render_param_entity, container.RenderParam)
        }

        free(native_win)
        excl(&shared_data.Systems, container.System.DX11System)

        fmt.println("cleaning render thread")
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

    //TODO: khal move this
    viewport : d3d11.VIEWPORT = d3d11.VIEWPORT{
        Width = f32(swapchain_descriptor.Width),
        Height = f32(swapchain_descriptor.Height),
        MaxDepth = 1,
    }

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


    container.BEGIN_EVENT("Texture & Shader Construction")

    sprite_texture : ^d3d11.ITexture2D
    texture_resource : d3d11.SUBRESOURCE_DATA

    instance_layout_descriptor := [8]d3d11.INPUT_ELEMENT_DESC{
        {"QUAD_ID", 0, dxgi.FORMAT.R32G32_FLOAT, 0,0, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0},

        {"TRANSFORM",0, dxgi.FORMAT.R32G32B32A32_FLOAT,1,0, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",1, dxgi.FORMAT.R32G32B32A32_FLOAT,1,16, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",2, dxgi.FORMAT.R32G32B32A32_FLOAT,1,32, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",3, dxgi.FORMAT.R32G32B32A32_FLOAT,1,48, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"SRC_RECT", 0, dxgi.FORMAT.R32G32B32A32_FLOAT,1,64, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA,1},
        {"HUE_DISP", 0, dxgi.FORMAT.R32_FLOAT,1, 80, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA,1},
        {"Z_DEPTH", 0, dxgi.FORMAT.R32_FLOAT, 1, 84, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
    }

    shader_dir,match_err := filepath.glob(container.DEFAULT_SHADER_PATH)

    assert(match_err == filepath.Match_Error.None, "Failed to load shader directory")

    //TODO: khal optimize this
    for sprite_batch_entity in ecs.get_entities_with_single_component_fast(&shared_data.ecs, container.SpriteBatch){
        sprite_batch := ecs.get_component_unchecked(&shared_data.ecs, sprite_batch_entity, container.SpriteBatch)

        //////////////////////////////// TEXTURE SETUP ////////////////////////////////

        texture_descriptor := d3d11.TEXTURE2D_DESC{
            Width = u32(sprite_batch.width),
            Height = u32(sprite_batch.height),
            MipLevels = 1,
            ArraySize = 1,
            Format = dxgi.FORMAT.R8G8B8A8_UNORM,
            SampleDesc = dxgi.SAMPLE_DESC{
                Count = 1,
                Quality = 0,
            },
            Usage = d3d11.USAGE.IMMUTABLE,
            BindFlags = d3d11.BIND_FLAGS{.SHADER_RESOURCE},
           }
    
           texture_resource.pSysMem = sprite_batch.texture
           texture_resource.SysMemPitch = texture_descriptor.Width << 2
    
           container.DX_CALL(
            device->CreateTexture2D(&texture_descriptor, &texture_resource, &sprite_texture),
            sprite_texture,
           )
    
           sprite_shader_resource_view : ^d3d11.IShaderResourceView
           
           container.DX_CALL(
            device->CreateShaderResourceView(sprite_texture, nil, &sprite_shader_resource_view),
            nil,
           )

           //////////////////////////// SHADER SETUP //////////////////////////////////
           assert(u32(len(shader_dir) - 1) >= sprite_batch.shader_cache, "Invalid shader cache. the shader cache is larger then the maximum shader cache index")

           target_shader_path := shader_dir[sprite_batch.shader_cache]

           _, shader_file := filepath.split(target_shader_path)

           shader_src_name : cstring = strings.clone_to_cstring(shader_file)
   
           shader_path_byte, _ := os.read_entire_file_from_filename(target_shader_path)
           
           defer{
               delete_slice(shader_path_byte)
               delete_cstring(shader_src_name)
           }
   
           shader_bytecode := raw_data(shader_path_byte)
           shader_bytecode_length := uint(len(shader_path_byte))
   
           vertex_shader : ^d3d11.IVertexShader
           pixel_shader : ^d3d11.IPixelShader

           vertex_blob : ^d3d_compiler.ID3DBlob
           pixel_blob : ^d3d_compiler.ID3DBlob

           input_layout : ^d3d11.IInputLayout

           container.DX_CALL(
            d3d_compiler.Compile(shader_bytecode, shader_bytecode_length, shader_src_name, nil, nil, "vs_main","vs_5_0",15,0, &vertex_blob, nil),
            nil,
           )

           container.DX_CALL(
            d3d_compiler.Compile(shader_bytecode, shader_bytecode_length,shader_src_name, nil, nil, "ps_main", "ps_5_0", 15,0,&pixel_blob, nil),
            nil,
           )

           container.DX_CALL(
            device->CreateVertexShader(vertex_blob->GetBufferPointer(), vertex_blob->GetBufferSize(), nil, &vertex_shader),
            nil,
           )

           container.DX_CALL(
            device->CreatePixelShader(pixel_blob->GetBufferPointer(), pixel_blob->GetBufferSize(), nil, &pixel_shader),
            nil,
           )

           container.DX_CALL(
            device->CreateInputLayout(&instance_layout_descriptor[0], len(instance_layout_descriptor), vertex_blob->GetBufferPointer(), vertex_blob->GetBufferSize(),&input_layout),
            nil,
           )

           ////////////////////////////////////////////////////////////////////////
           render_param : container.RenderParam = container.RenderParam{
            vertex_shader,
            vertex_blob,
            pixel_shader,
            pixel_blob,
            input_layout,
            sprite_shader_resource_view,
           }

           ecs.add_component_unchecked(&shared_data.ecs, sprite_batch_entity, render_param)
    }

    delete_slice(shader_dir)

    texture_sampler : ^d3d11.ISamplerState

    sampler_descriptor := d3d11.SAMPLER_DESC{
        Filter = d3d11.FILTER.MIN_LINEAR_MAG_MIP_POINT,
        AddressU = d3d11.TEXTURE_ADDRESS_MODE.CLAMP,
        AddressV = d3d11.TEXTURE_ADDRESS_MODE.CLAMP,
        AddressW = d3d11.TEXTURE_ADDRESS_MODE.CLAMP,
        MipLODBias = 0,
        MaxAnisotropy = 1,
        ComparisonFunc = d3d11.COMPARISON_FUNC.ALWAYS,
        BorderColor = {0.0, 0.0, 0.0, 0.0},
        MinLOD = 0,
        MaxLOD = d3d11.FLOAT32_MAX,
    }

    container.DX_CALL(
        device->CreateSamplerState(&sampler_descriptor, &texture_sampler),
        texture_sampler,
    )

    container.END_EVENT()
    

    container.BEGIN_EVENT("Buffer Creation")
   
    vertex_buffer : ^d3d11.IBuffer
    instance_data_buffer : ^d3d11.IBuffer
    
    vertex_buffer_descriptor : d3d11.BUFFER_DESC = d3d11.BUFFER_DESC{
        ByteWidth = size_of(vertices),
        Usage = d3d11.USAGE.IMMUTABLE, 
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.VERTEX_BUFFER},
    }
    
    vertex_resource : d3d11.SUBRESOURCE_DATA = d3d11.SUBRESOURCE_DATA{
        pSysMem = (rawptr)(&vertices),
        SysMemPitch = 0,
        SysMemSlicePitch = 0,
    }

    instance_buffer_descriptor : d3d11.BUFFER_DESC = d3d11.BUFFER_DESC{
        ByteWidth = container.INSTANCE_BYTE_WIDTH,
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.VERTEX_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{d3d11.CPU_ACCESS_FLAG.WRITE},
    }

    container.DX_CALL(
        device->CreateBuffer(&vertex_buffer_descriptor, &vertex_resource, &vertex_buffer),
        vertex_buffer,
    )

    container.DX_CALL(
        device->CreateBuffer(&instance_buffer_descriptor, nil, &instance_data_buffer),
        instance_data_buffer,
    )

    buffer :[2]^d3d11.IBuffer = {vertex_buffer, instance_data_buffer}

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


    container.BEGIN_EVENT("StencilDepth Creation")

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

    VERTEX_STRIDE : [2]u32 = {size_of(SpriteIndex), size_of(container.SpriteInstanceData)} // size of Vertex
    VERTEX_OFFSET : [2]u32 = {0,0}

    device_context->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)
    device_context->IASetIndexBuffer(index_buffer, dxgi.FORMAT.R16_UINT, 0)

    device_context->RSSetState(raterizer_state)

    device_context->OMSetRenderTargets(1, &back_render_target_view, nil)
    device_context->OMSetDepthStencilState(stencil_depth_state, 0)
    device_context->OMSetBlendState(blend_state, &{1.0, 1.0, 1.0, 1.0}, 0xFFFFFFFF)
    device_context->RSSetViewports(1, &viewport)

    container.END_EVENT()

    mapped_constant_subresource : d3d11.MAPPED_SUBRESOURCE
    mapped_instance_subresource : d3d11.MAPPED_SUBRESOURCE

    for (container.System.WindowSystem in shared_data.Systems){
        
        container.DX_CALL(
            device_context->Map(vs_cbuffer_0,0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_constant_subresource),
            nil,
            true,
        )

        {
            constants := (^GlobalDynamicConstantBuffer)(mapped_constant_subresource.pData)

            constants.sprite_sheet_size = {0,0}
            constants.device_conversion = {2.0 / viewport.Width, -2.0 / viewport.Height}
            constants.viewport_size = {viewport.Width, viewport.Height}
            constants.time = u32(shared_data.time)
            constants.delta_time = 0
        }

        device_context->Unmap(vs_cbuffer_0, 0)

        device_context->ClearRenderTargetView(back_render_target_view, &{0.0, 0.4, 0.5, 1.0})

        for render_entity in ecs.get_entities_with_single_component_fast(&shared_data.ecs, container.RenderParam){
            container.BEGIN_EVENT("Draw Call")

            render_param, sprite_batch := ecs.get_components_2_unchecked(&shared_data.ecs, render_entity, container.RenderParam, container.SpriteBatch)

            device_context->IASetInputLayout(render_param.layout_input)

            device_context->VSSetShader(render_param.vertex_shader, nil, 0)
            device_context->PSSetShader(render_param.pixel_shader, nil, 0)


            container.DX_CALL(
                device_context->Map(instance_data_buffer, 0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_instance_subresource),
                nil,
                true,
            )

            libc.memcpy(mapped_instance_subresource.pData, &sprite_batch.sprite_batch[0], size_of(container.SpriteInstanceData) * len(sprite_batch.sprite_batch))

            device_context->Unmap(instance_data_buffer, 0)

            device_context->IASetVertexBuffers(0, 2, &buffer[0], &VERTEX_STRIDE[0], &VERTEX_OFFSET[0])

            device_context->VSSetConstantBuffers(0,1,&vs_cbuffer_0)


            device_context->PSSetShaderResources(0,1, &render_param.texture_resource)
            device_context->PSSetSamplers(0,1,&texture_sampler)

            device_context->DrawIndexedInstanced(6, u32(len(sprite_batch.sprite_batch)),0,0,0)

            container.DX_CALL(
                swapchain->Present(1,0),
                nil,
                true,
            )

            device_context->OMSetRenderTargets(1, &back_render_target_view, nil) 

            container.END_EVENT()
           
        }

    }

}