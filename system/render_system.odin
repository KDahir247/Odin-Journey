package system

import "core:fmt"
import "core:thread"
import "core:sync"
import "core:intrinsics"

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"
import "core:sys/windows"

import "core:strings"
import "core:os"
import "core:path/filepath"

import "../ecs"
import "../common"

@(optimization_mode="size")
init_render_subsystem :: proc(current_thread : ^thread.Thread){
    render_batch_buffer := cast(^common.RenderBatchBuffer)current_thread.data
    batches : []common.SpriteBatch
    
    window := windows.HWND(current_thread.user_args[0])

    common.CREATE_PROFILER_BUFFER(u32(current_thread.id))
    render_params := make(map[u32]common.RenderParam)

    shader_dir,match_err := filepath.glob(common.DEFAULT_SHADER_PATH)
    assert(match_err == filepath.Match_Error.None, "Failed to load shader directory")

    window_rect : windows.RECT
    windows.GetWindowRect(window, &window_rect)

    window_width := window_rect.right - window_rect.left
    window_height := window_rect.bottom - window_rect.top

    vertex_stride : [2]u32 = {size_of(common.SpriteIndex), size_of(common.SpriteInstanceData)} // size of Vertex
    vertex_offset : [2]u32 = {0,0}

    d3d_feature_level := [2]d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0, d3d11.FEATURE_LEVEL._11_1}

    vertices := [4]common.SpriteIndex{
        {{0.0, 0.0}},
        {{1, 0.0}},
        {{1, 1}},
        {{0, 1}},
    }

    indices := [6]u16{
        0, 1, 2, 3, 0, 2,
    }

    viewport : d3d11.VIEWPORT = d3d11.VIEWPORT{
        Width = f32(window_width),
        Height = f32(window_height),
        MaxDepth = 1,
    }

    //

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

    vs_cbuffer_0 : ^d3d11.IBuffer

    texture_resource : d3d11.SUBRESOURCE_DATA
    sprite_texture : ^d3d11.ITexture2D

    texture_sampler : ^d3d11.ISamplerState

    vertex_buffer : ^d3d11.IBuffer
    instance_data_buffer : ^d3d11.IBuffer

    index_buffer : ^d3d11.IBuffer

    raterizer_state : ^d3d11.IRasterizerState

    stencil_depth_state : ^d3d11.IDepthStencilState

    blend_state : ^d3d11.IBlendState

    //
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

    constant_buffer_descriptor := d3d11.BUFFER_DESC{
        ByteWidth = size_of(common.GlobalDynamicConstantBuffer),
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.CONSTANT_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{.WRITE},
    }

    texture_descriptor := d3d11.TEXTURE2D_DESC{
        Width = 0,
        Height = 0,
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

    vertex_buffer_descriptor : d3d11.BUFFER_DESC = d3d11.BUFFER_DESC{
        ByteWidth = size_of(vertices),
        Usage = d3d11.USAGE.IMMUTABLE, 
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.VERTEX_BUFFER},
    }

    instance_buffer_descriptor : d3d11.BUFFER_DESC = d3d11.BUFFER_DESC{
        ByteWidth = common.INSTANCE_BYTE_WIDTH,
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.VERTEX_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{d3d11.CPU_ACCESS_FLAG.WRITE},
    }

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

    index_buffer_descriptor := d3d11.BUFFER_DESC{
        ByteWidth = size_of(indices),
        BindFlags = {.INDEX_BUFFER},
        StructureByteStride = size_of(u16),
        Usage = d3d11.USAGE.DEFAULT,
    }

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

    defer{
        for key, render_param in render_params{

                render_param.vertex_shader->Release()
                render_param.vertex_blob->Release()
                render_param.pixel_shader->Release()
                render_param.pixel_blob->Release()
                render_param.layout_input->Release()
                render_param.texture_resource->Release()
          
        }

        delete_slice(shader_dir)

        delete(render_params)

        common.FREE_PROFILER_BUFFER()
    }

    common.BEGIN_EVENT("Device Construction & Query")

    //TODO: khal pf
    common.DX_CALL(
        d3d11.CreateDevice(nil, d3d11.DRIVER_TYPE.HARDWARE, nil, d3d11.CREATE_DEVICE_FLAGS{},&d3d_feature_level[0],len(d3d_feature_level), d3d11.SDK_VERSION,&base_device, nil, &base_device_context),
        base_device,
    )

    common.DX_CALL(
        base_device->QueryInterface(d3d11.IDevice_UUID, (^rawptr)(&device)),
        device,
    )

    common.DX_CALL(
        base_device_context->QueryInterface(d3d11.IDeviceContext_UUID, (^rawptr)(&device_context)),
        device_context,
    )

    common.DX_CALL(
        device->QueryInterface(dxgi.IDevice_UUID, (^rawptr)(&dxgi_device)),
        dxgi_device,
    )

    common.DX_CALL(
        dxgi_device->GetAdapter(&dxgi_adapter),
        dxgi_adapter,
    )

    common.DX_CALL(
        dxgi_adapter->GetParent(dxgi.IFactory4_UUID, (^rawptr)(&dxgi_factory)),
        dxgi_factory,
    )

    common.END_EVENT()

    common.BEGIN_EVENT("SwapChain Construction")
    
    common.DX_CALL(
        dxgi_factory->CreateSwapChainForHwnd(device, window, &swapchain_descriptor, nil,nil,&swapchain ),
        swapchain,
    )
    
    common.DX_CALL(swapchain->GetDesc1(&swapchain_descriptor), nil)

    common.DX_CALL(
        swapchain->GetBuffer(0,d3d11.ITexture2D_UUID,(^rawptr)(&back_buffer)),
        nil,
    )
    
    common.DX_CALL(
        device->CreateRenderTargetView(back_buffer, nil, &back_render_target_view),
         back_render_target_view,
    )

    back_buffer->Release()

    common.END_EVENT()

    common.BEGIN_EVENT("CBuffer Construction")

    common.DX_CALL(
        device->CreateBuffer(&constant_buffer_descriptor, nil,&vs_cbuffer_0),
         vs_cbuffer_0,
    )

    common.END_EVENT()

    common.BEGIN_EVENT("Sampler Construction")

    common.DX_CALL(
        device->CreateSamplerState(&sampler_descriptor, &texture_sampler),
        texture_sampler,
    )

    common.END_EVENT()


    common.BEGIN_EVENT("Buffer Creation")
   
    vertex_resource : d3d11.SUBRESOURCE_DATA = d3d11.SUBRESOURCE_DATA{
        pSysMem = (rawptr)(&vertices),
        SysMemPitch = 0,
        SysMemSlicePitch = 0,
    }
   
    common.DX_CALL(
        device->CreateBuffer(&vertex_buffer_descriptor, &vertex_resource, &vertex_buffer),
        vertex_buffer,
    )

    common.DX_CALL(
        device->CreateBuffer(&instance_buffer_descriptor, nil, &instance_data_buffer),
        instance_data_buffer,
    )

    index_resource := d3d11.SUBRESOURCE_DATA{
        pSysMem = (rawptr)(&indices),
    }

    common.DX_CALL(
        device->CreateBuffer(&index_buffer_descriptor, &index_resource, &index_buffer),
        index_buffer,
    )

    common.END_EVENT()

    common.BEGIN_EVENT("RasterizerState Creation")
    
    common.DX_CALL(
        device->CreateRasterizerState(&raterizer_descriptor,&raterizer_state),
        raterizer_state,
    )

    common.END_EVENT()

    common.BEGIN_EVENT("StencilDepth Creation")

    common.DX_CALL(
        device->CreateDepthStencilState(&stencil_depth_descriptor, &stencil_depth_state),
        stencil_depth_state,
    )

    common.END_EVENT()

    common.BEGIN_EVENT("BlendState Creation")

    common.DX_CALL(
        device->CreateBlendState(&blend_descriptor, &blend_state),
        blend_state,
    )

    common.END_EVENT()

    common.BEGIN_EVENT("Binding")

    device_context->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)
    device_context->IASetIndexBuffer(index_buffer, dxgi.FORMAT.R16_UINT, 0)

    device_context->RSSetState(raterizer_state)

    device_context->OMSetRenderTargets(1, &back_render_target_view, nil)
    device_context->OMSetDepthStencilState(stencil_depth_state, 0)
    device_context->OMSetBlendState(blend_state, &{1.0, 1.0, 1.0, 1.0}, 0xFFFFFFFF)
    device_context->RSSetViewports(1, &viewport)
    
    device_context->GSSetShader(nil, nil, 0)
    device_context->HSSetShader(nil, nil, 0)
    device_context->DSSetShader(nil, nil, 0)
    device_context->CSSetShader(nil, nil, 0)

    common.END_EVENT()

    buffer :[2]^d3d11.IBuffer = {vertex_buffer, instance_data_buffer}

    mapped_constant_subresource : d3d11.MAPPED_SUBRESOURCE
    mapped_instance_subresource : d3d11.MAPPED_SUBRESOURCE

    sync.barrier_wait(&render_batch_buffer.barrier)

    for (.Started in intrinsics.atomic_load_explicit(&current_thread.flags, sync.Atomic_Memory_Order.Acquire)){
        {
            //TODO: khal if we add another batch shared we might want to use a blocking lock. since this operation will take a while.
            // and we don't want to calculate the position and other properties, since this will add a fast stutter movement because
            // the update loop and fixed update loop get called more.
            if render_batch_buffer.modified && sync.try_lock(&render_batch_buffer.mutex){
                common.BEGIN_EVENT("Applying Sync Render data")

                render_batch_buffer.modified = false
                
                //TODO: need a way to check prior if this has been modfied.
                batches = render_batch_buffer.batches

                for batch_shared in  render_batch_buffer.shared{
                    if _, valid := render_params[batch_shared.identifier]; !valid{

                        sprite_shader_resource_view : ^d3d11.IShaderResourceView
        
                        vertex_shader : ^d3d11.IVertexShader
                        pixel_shader : ^d3d11.IPixelShader
                
                        vertex_blob : ^d3d_compiler.ID3DBlob
                        pixel_blob : ^d3d_compiler.ID3DBlob
                
                        input_layout : ^d3d11.IInputLayout
                
                        //////////////////////////////// TEXTURE SETUP ////////////////////////////////
                
                        texture_descriptor.Width = u32(batch_shared.width)
                        texture_descriptor.Height = u32(batch_shared.height)
                        
                        texture_resource.pSysMem = batch_shared.texture
                        texture_resource.SysMemPitch = texture_descriptor.Width << 2
                    
                        common.DX_CALL(
                            device->CreateTexture2D(&texture_descriptor, &texture_resource, &sprite_texture),
                            sprite_texture,
                        )
                
                           
                        common.DX_CALL(
                            device->CreateShaderResourceView(sprite_texture, nil, &sprite_shader_resource_view),
                            nil,
                        )
                
                        //////////////////////////// SHADER SETUP //////////////////////////////////
                        assert(u32(len(shader_dir) - 1) >= batch_shared.shader_cache, "Invalid shader cache. the shader cache is larger then the maximum shader cache index")
                
                        target_shader_path := shader_dir[batch_shared.shader_cache]
                
                        shader_file := target_shader_path[16:]
                
                        shader_src_name : cstring = strings.clone_to_cstring(shader_file)
                   
                        shader_path_byte, _ := os.read_entire_file_from_filename(target_shader_path)
                           
                        defer{
                            delete_slice(shader_path_byte)
                            delete_cstring(shader_src_name)
                            delete_string(target_shader_path)
                        }
                   
                        shader_bytecode := raw_data(shader_path_byte)
                        shader_bytecode_length := uint(len(shader_path_byte))
                
                        common.DX_CALL(
                            d3d_compiler.Compile(shader_bytecode, shader_bytecode_length, shader_src_name, nil, nil, "vs_main","vs_5_0",15,0, &vertex_blob, nil),
                            nil,
                        )
                
                        common.DX_CALL(
                            d3d_compiler.Compile(shader_bytecode, shader_bytecode_length,shader_src_name, nil, nil, "ps_main", "ps_5_0", 15,0,&pixel_blob, nil),
                            nil,
                        )
                
                        common.DX_CALL(
                            device->CreateVertexShader(vertex_blob->GetBufferPointer(), vertex_blob->GetBufferSize(), nil, &vertex_shader),
                            nil,
                        )
                
                        common.DX_CALL(
                            device->CreatePixelShader(pixel_blob->GetBufferPointer(), pixel_blob->GetBufferSize(), nil, &pixel_shader),
                            nil,
                        )
                
                        common.DX_CALL(
                            device->CreateInputLayout(&instance_layout_descriptor[0], len(instance_layout_descriptor), vertex_blob->GetBufferPointer(), vertex_blob->GetBufferSize(),&input_layout),
                            nil,
                        )
                
                        ////////////////////////////////////////////////////////////////////////

                        render_params[batch_shared.identifier] = common.RenderParam{
                            vertex_shader,
                            vertex_blob,
                            pixel_shader,
                            pixel_blob,
                            input_layout,
                            sprite_shader_resource_view,
                        }
                    }
                }
            sync.unlock(&render_batch_buffer.mutex)

            common.END_EVENT()

            }
        }

        common.BEGIN_EVENT("Draw Call")
        
        common.DX_CALL(
            device_context->Map(vs_cbuffer_0,0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_constant_subresource),
            nil,
            true,
        )

        {
            constants := (^common.GlobalDynamicConstantBuffer)(mapped_constant_subresource.pData)

            constants.sprite_sheet_size = {0,0} //?
            constants.device_conversion = {2.0 / viewport.Width, -2.0 / viewport.Height}
            constants.viewport_size = {viewport.Width, viewport.Height}
            constants.time = 0
            constants.delta_time = 0
        }

        device_context->Unmap(vs_cbuffer_0, 0)

        device_context->ClearRenderTargetView(back_render_target_view, &{0.0, 0.4, 0.5, 1.0})
        for key, render_param in render_params {

            sprite_batch := batches[key]


            device_context->IASetInputLayout(render_param.layout_input)

            device_context->VSSetShader(render_param.vertex_shader, nil, 0)
            device_context->PSSetShader(render_param.pixel_shader, nil, 0)

            common.DX_CALL(
                device_context->Map(instance_data_buffer, 0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_instance_subresource),
                nil,
                true,
            )

            intrinsics.mem_copy_non_overlapping(mapped_instance_subresource.pData, &sprite_batch.sprite_batch[0], size_of(common.SpriteInstanceData) * len(sprite_batch.sprite_batch))

            device_context->Unmap(instance_data_buffer, 0)

            device_context->IASetVertexBuffers(0, 2, &buffer[0], &vertex_stride[0], &vertex_offset[0])

            device_context->VSSetConstantBuffers(0,1,&vs_cbuffer_0)

            tex_res := render_param.texture_resource
            device_context->PSSetShaderResources(0,1, &tex_res)
            device_context->PSSetSamplers(0,1,&texture_sampler)

            device_context->DrawIndexedInstanced(6, u32(len(sprite_batch.sprite_batch)),0,0,0)

            //TODO: khal we maybe want to lock and unlock to use for the game loop, ideally we want the game loop to happen the same frame as the render loop and no greater, since it will introduce jitter.
            //TODO: khal pf
            common.DX_CALL(
                swapchain->Present(1,0),
                nil,
                true,
            )

            device_context->OMSetRenderTargets(1, &back_render_target_view, nil) 

        }
        common.END_EVENT()

        free_all(context.temp_allocator)
    }
}