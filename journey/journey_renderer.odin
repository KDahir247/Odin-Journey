package journey

import "core:fmt"
import "core:thread"
import "core:sync"
import "core:intrinsics"
import "core:sys/windows"
import "core:strings"
import "core:os"
import "core:math/linalg/hlsl"

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"

RenderBackend :: enum int{
    DX11 = 0,
    DX12,
    VULKAN,
    METAL,
    OPENGL,
}

//TODO: khal this look like it is specific for DX
// we need sdl2.Vulkan_CreateSurface(....) to pass to the render thread
// DX11 need window's HWND DX12 can possible also use HWND handle not 100 percent sure haven't check.
// Not sure of Metal (Don't have mac_os) 
// Not sure of OpenGL, but can figure out relatively easily.
run_renderer :: proc(backend : RenderBackend, render_window : rawptr, render_buffer : ^RenderBatchBuffer) -> ^thread.Thread {
    conditional_variable :=  &sync.Cond{}

    render_thread := thread.create(_render_backend_proc[backend])
    render_thread.data = render_buffer
    render_thread.user_args[0] = render_window
    render_thread.user_args[1] = conditional_variable

    thread.start(render_thread)

    {
        sync.guard(&render_thread.mutex)
        sync.cond_wait(conditional_variable, &render_thread.mutex)
    }
    
    return render_thread
}


stop_renderer :: proc(render_thread : ^thread.Thread){
	sync.atomic_store_explicit(&render_thread.flags, {.Done},sync.Atomic_Memory_Order.Release)
    thread.destroy(render_thread)
}


// Used through out the game (SpriteSheet, FontAtlas, TileMapping)
@(private) 
RenderInstanceData :: struct #align 16{
    model : matrix[4,4]f32,
    src_rect : Rect,
}

@(private)
backend_proc :: #type proc(current_thread : ^thread.Thread)

@(private)
_render_backend_proc : [RenderBackend]backend_proc

@(private)
RenderParam :: struct {
    vertex_shader : ^d3d11.IVertexShader,
    vertex_blob : ^d3d_compiler.ID3DBlob,

    pixel_shader : ^d3d11.IPixelShader,
    pixel_blob : ^d3d_compiler.ID3DBlob,

    layout_input : ^d3d11.IInputLayout,

    texture_resource : ^d3d11.IShaderResourceView,
}

@(private)
@(init)
init_render_backend :: proc(){
    for index in 0..<5{
        _render_backend_proc[RenderBackend(index)] = init_render_nil_subsystem
    }

    when ODIN_OS_STRING == "windows"{
        _render_backend_proc[RenderBackend.DX11] = init_render_dx11_subsystem
        _render_backend_proc[RenderBackend.DX12] = init_render_dx12_subsystem
        _render_backend_proc[RenderBackend.VULKAN] = init_render_vulkan_subsystem
        _render_backend_proc[RenderBackend.OPENGL] = init_render_opengl_subsystem

    }else when ODIN_OS_STRING == "linux"{
        _render_backend_proc[RenderBackend.VULKAN] = init_render_vulkan_subsystem
        _render_backend_proc[RenderBackend.OPENGL] = init_render_vulkan_subsystem

    }else when ODIN_OS_STRING == "darwin"{
        _render_backend_proc[RenderBackend.METAL] = init_render_metal_subsystem
    }
}


///////////////////////////// Nil Subsystem //////////////////////////////////
@(private)
init_render_nil_subsystem ::  proc(current_thread : ^thread.Thread){}

//////////////////////////////////////////////////////////////////////////////

//////////////////////////// Metal Subsystem /////////////////////////////////

@(private)
init_render_metal_subsystem ::  proc(current_thread : ^thread.Thread){
    //Not implemented
}

///////////////////////////////////////////////////////////////////////////////

//////////////////////////// Vulkan Subsystem /////////////////////////////////

@(private)
init_render_vulkan_subsystem ::  proc(current_thread : ^thread.Thread){
    //Not implemented
}

///////////////////////////////////////////////////////////////////////////////


//////////////////////////// OpenGL Subsystem /////////////////////////////////


@(private)
init_render_opengl_subsystem ::  proc(current_thread : ^thread.Thread){
    //Not implemented
}

///////////////////////////////////////////////////////////////////////////////


/////////////////////////// Direct X Subsystem ///////////////////////////////


@(private)
@(deferred_in=DX_END)
DX_CALL ::  proc(hr : d3d11.HRESULT, auto_free_ptr : rawptr, panic_on_fail := false, loc := #caller_location)  {
    when ODIN_DEBUG{
        if hr != 0{
            hr_index := int(hr) & 0xFFFFFFFF
            //err_code := HR_ERR_MAP[hr_index]
            fmt.printf("RAW ERROR ID : %x\n look description in the resource/debug : %v", hr_index, loc)

            if panic_on_fail{
                panic("DX11 Initialization Failed", loc)
            }
        }
    }
}


@(private)
DX_END :: proc(hr : d3d11.HRESULT, auto_free_ptr : rawptr, panic_on_fail := false, loc := #caller_location) {
    if hr == 0 && auto_free_ptr != nil{
        unknown_ptr := cast(^d3d11.IUnknown)auto_free_ptr

        unknown_ptr->Release()
        unknown_ptr = nil
    }
}



@(private)
init_render_dx12_subsystem ::  proc(current_thread : ^thread.Thread){
    //Not implemented
}


//TODO:khal we need to handle window resize
@(private)
init_render_dx11_subsystem :: proc(current_thread : ^thread.Thread){
    //TODO: DATA NEED ALIGNMENT TO 16 BOTH STRUCT AND PTR.

    vs_buffer_data := new(GlobalDynamicVSConstantBuffer)
    defer free(vs_buffer_data)

    batches : []SpriteBatch

    current_buffer_index := 0

    //TODO: khal the size will change when we introduce other thing to render such as tilemapping
    vertex_buffers : [2]^d3d11.IBuffer
    mapped_subresources := [2]d3d11.MAPPED_SUBRESOURCE{}

    vertex_buffer_stride : [2]u32 = {size_of(hlsl.float2), size_of(SpriteInstanceData)} // size of Vertex
    vertex_buffer_offset : [2]u32 = {0,0}

    vertices := [4]hlsl.float2{
        {0.0, 0.0},
        {1, 0.0},
        {1, 1},
        {0, 1},
    }

    indices := [6]u16{
        0, 1, 2, 3, 0, 2,
    }

    render_batch_buffer := cast(^RenderBatchBuffer)current_thread.data

    CREATE_PROFILER_BUFFER(u32(current_thread.id))

    window := windows.HWND(current_thread.user_args[0])
    
    render_params := make([dynamic]RenderParam)

    window_rect : windows.RECT
    windows.GetWindowRect(window, &window_rect)

    window_width := window_rect.right - window_rect.left
    window_height := window_rect.bottom - window_rect.top

    d3d_feature_level := [2]d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0, d3d11.FEATURE_LEVEL._11_1}

    viewport : d3d11.VIEWPORT = d3d11.VIEWPORT{
        Width = f32(window_width),
        Height = f32(window_height),
        MaxDepth = 1,
    }

    vs_buffer_data.viewport_x = viewport.TopLeftX
    vs_buffer_data.viewport_y = viewport.TopLeftY
    vs_buffer_data.viewport_width = viewport.Width
    vs_buffer_data.viewport_height = viewport.Height

    base_device : ^d3d11.IDevice
    base_device_context : ^d3d11.IDeviceContext

    device : ^d3d11.IDevice
    device_context : ^d3d11.IDeviceContext

    back_buffer : [2]^d3d11.ITexture2D
    back_render_target_view : [2]^d3d11.IRenderTargetView
    swapchain : ^dxgi.ISwapChain1

    dxgi_device: ^dxgi.IDevice
	dxgi_adapter: ^dxgi.IAdapter
    dxgi_factory : ^dxgi.IFactory4

    vs_global_cbuffer : ^d3d11.IBuffer

    sprite_texture : ^d3d11.ITexture2D
    
    texture_sampler : ^d3d11.ISamplerState

    index_buffer : ^d3d11.IBuffer

    raterizer_state : ^d3d11.IRasterizerState

    stencil_depth_state : ^d3d11.IDepthStencilState

    blend_state : ^d3d11.IBlendState

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

    vs_constant_buffer_descriptor := d3d11.BUFFER_DESC{
        ByteWidth = size_of(GlobalDynamicVSConstantBuffer),
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.CONSTANT_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{.WRITE},
    }

    sprite_texture_descriptor := d3d11.TEXTURE2D_DESC{
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
        ByteWidth = INSTANCE_BYTE_WIDTH,
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.VERTEX_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{d3d11.CPU_ACCESS_FLAG.WRITE},
    }

    instance_layout_descriptor := [6]d3d11.INPUT_ELEMENT_DESC{
        {"QUAD_ID", 0, dxgi.FORMAT.R32G32_FLOAT, 0,0, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0},

        {"TRANSFORM",0, dxgi.FORMAT.R32G32B32A32_FLOAT,1,0, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",1, dxgi.FORMAT.R32G32B32A32_FLOAT,1,16, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",2, dxgi.FORMAT.R32G32B32A32_FLOAT,1,32, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"TRANSFORM",3, dxgi.FORMAT.R32G32B32A32_FLOAT,1,48, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA, 1},
        {"SRC_RECT", 0, dxgi.FORMAT.R32G32B32A32_FLOAT,1,64, d3d11.INPUT_CLASSIFICATION.INSTANCE_DATA,1},
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
        IndependentBlendEnable = false, 
    }

    blend_descriptor.RenderTarget[0] = d3d11.RENDER_TARGET_BLEND_DESC{
        BlendEnable = true,
        SrcBlend = d3d11.BLEND.ONE,
        SrcBlendAlpha = d3d11.BLEND.ONE,

        DestBlend = d3d11.BLEND.INV_SRC_ALPHA,
        DestBlendAlpha = d3d11.BLEND.ONE,
        
        BlendOp = d3d11.BLEND_OP.ADD,
        BlendOpAlpha = d3d11.BLEND_OP.ADD,

        RenderTargetWriteMask = 15,
    }

    defer{
        for  render_param in render_params{

                render_param.vertex_shader->Release()
                render_param.vertex_blob->Release()
                render_param.pixel_shader->Release()
                render_param.pixel_blob->Release()
                render_param.layout_input->Release()
                render_param.texture_resource^->Release()
          
        }

        delete(render_params)

        //TODO: khal seem like a leak on the back buffer
        FREE_PROFILER_BUFFER()
    }

    BEGIN_EVENT("Device Construction & Query")

    DX_CALL(
        d3d11.CreateDevice(nil, d3d11.DRIVER_TYPE.HARDWARE, nil, d3d11.CREATE_DEVICE_FLAGS{},&d3d_feature_level[0],len(d3d_feature_level), d3d11.SDK_VERSION,&base_device, nil, &base_device_context),
        base_device,
    )

    DX_CALL(
        base_device->QueryInterface(d3d11.IDevice_UUID, (^rawptr)(&device)),
        device,
    )

    DX_CALL(
        base_device_context->QueryInterface(d3d11.IDeviceContext_UUID, (^rawptr)(&device_context)),
        device_context,
    )

    DX_CALL(
        device->QueryInterface(dxgi.IDevice_UUID, (^rawptr)(&dxgi_device)),
        dxgi_device,
    )

    DX_CALL(
        dxgi_device->GetAdapter(&dxgi_adapter),
        dxgi_adapter,
    )

    DX_CALL(
        dxgi_adapter->GetParent(dxgi.IFactory4_UUID, (^rawptr)(&dxgi_factory)),
        dxgi_factory,
    )

    END_EVENT()

    BEGIN_EVENT("SwapChain Construction")
    
    DX_CALL(
        dxgi_factory->CreateSwapChainForHwnd(device, window, &swapchain_descriptor, nil,nil,&swapchain ),
        swapchain,
    )
    
    DX_CALL(
        swapchain->GetDesc1(&swapchain_descriptor),
         nil,
    )

    DX_CALL(
        swapchain->GetBuffer(0,d3d11.ITexture2D_UUID,(^rawptr)(&back_buffer[0])),
        back_buffer[0],
    )

    DX_CALL(
        swapchain->GetBuffer(0,d3d11.ITexture2D_UUID,(^rawptr)(&back_buffer[1])),
        back_buffer[1],
    )
    
    DX_CALL(
        device->CreateRenderTargetView(back_buffer[0], nil, &back_render_target_view[0]),
         back_render_target_view[0],
    )

    DX_CALL(
        device->CreateRenderTargetView(back_buffer[1], nil, &back_render_target_view[1]),
        back_render_target_view[1],
        )


    END_EVENT()

    BEGIN_EVENT("CBuffer Construction")

    DX_CALL(
        device->CreateBuffer(&vs_constant_buffer_descriptor, nil,&vs_global_cbuffer),
        vs_global_cbuffer,
    )

    END_EVENT()

    BEGIN_EVENT("Sampler Construction")

    DX_CALL(
        device->CreateSamplerState(&sampler_descriptor, &texture_sampler),
        texture_sampler,
    )

    END_EVENT()


    BEGIN_EVENT("Buffer Creation")

    vertex_resource : d3d11.SUBRESOURCE_DATA = d3d11.SUBRESOURCE_DATA{
        pSysMem = (rawptr)(&vertices),
        SysMemPitch = 0,
        SysMemSlicePitch = 0,
    }
   
    DX_CALL(
        device->CreateBuffer(&vertex_buffer_descriptor, &vertex_resource, &vertex_buffers[0]),
        vertex_buffers[0],
    )

    DX_CALL(
        device->CreateBuffer(&instance_buffer_descriptor, nil, &vertex_buffers[1]),
        vertex_buffers[1],
    )

    index_resource := d3d11.SUBRESOURCE_DATA{
        pSysMem = (rawptr)(&indices),
    }

    DX_CALL(
        device->CreateBuffer(&index_buffer_descriptor, &index_resource, &index_buffer),
        index_buffer,
    )

    END_EVENT()

    BEGIN_EVENT("RasterizerState Creation")
    
    DX_CALL(
        device->CreateRasterizerState(&raterizer_descriptor,&raterizer_state),
        raterizer_state,
    )

    END_EVENT()

    BEGIN_EVENT("StencilDepth Creation")

    DX_CALL(
        device->CreateDepthStencilState(&stencil_depth_descriptor, &stencil_depth_state),
        stencil_depth_state,
    )

    END_EVENT()

    BEGIN_EVENT("BlendState Creation")

    DX_CALL(
        device->CreateBlendState(&blend_descriptor, &blend_state),
        blend_state,
    )

    END_EVENT()

    BEGIN_EVENT("Binding")

    device_context->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)
    device_context->IASetIndexBuffer(index_buffer, dxgi.FORMAT.R16_UINT, 0)

    device_context->RSSetState(raterizer_state)

    device_context->PSSetSamplers(0,1,&texture_sampler)


    device_context->OMSetDepthStencilState(stencil_depth_state, 0)
    device_context->OMSetBlendState(blend_state, &{1.0, 1.0, 1.0, 1.0}, 0xFFFFFFFF)
    device_context->RSSetViewports(1, &viewport)
    
    device_context->GSSetShader(nil, nil, 0)
    device_context->HSSetShader(nil, nil, 0)
    device_context->DSSetShader(nil, nil, 0)
    device_context->CSSetShader(nil, nil, 0)

    END_EVENT()

    {
        sync.guard(&current_thread.mutex)
        sync.signal((^sync.Cond)(current_thread.user_args[1]))

    }

    for (.Started in intrinsics.atomic_load_explicit(&current_thread.flags, sync.Atomic_Memory_Order.Acquire)){
        {
            if sync.atomic_load_explicit(&render_batch_buffer.changed_flag, sync.Atomic_Memory_Order.Acquire){

                batches = render_batch_buffer.batches
                BEGIN_EVENT("Updating Shared Render Data")

                render_param_len := len(render_params)
                shared_len := len(render_batch_buffer.shared)

                //TODO: khal we can later use offset to index the smaller chunk of shared to update the render param rather then iterate over all shared.
                for index in 0..<shared_len{
                    batch_shared := render_batch_buffer.shared[index]

                    sprite_shader_resource_view : ^d3d11.IShaderResourceView
    
                    vertex_shader : ^d3d11.IVertexShader
                    pixel_shader : ^d3d11.IPixelShader
            
                    vertex_blob : ^d3d_compiler.ID3DBlob
                    pixel_blob : ^d3d_compiler.ID3DBlob
            
                    input_layout : ^d3d11.IInputLayout

                    sprite_texture_descriptor.Width = u32(batch_shared.width)
                    sprite_texture_descriptor.Height = u32(batch_shared.height)

                    sprite_texture_resource := d3d11.SUBRESOURCE_DATA{
                        pSysMem = batch_shared.texture,
                        SysMemPitch = sprite_texture_descriptor.Width << 2,    
                    }

                    //////////////////////////////// TEXTURE SETUP ////////////////////////////////
            
                    DX_CALL(
                        device->CreateTexture2D(&sprite_texture_descriptor, &sprite_texture_resource, &sprite_texture),
                        sprite_texture,
                    )
            
                    DX_CALL(
                        device->CreateShaderResourceView(sprite_texture, nil, &sprite_shader_resource_view),
                        nil,
                    )
            
                    //////////////////////////// SHADER SETUP //////////////////////////////////
                    assert(u32(len(CACHED_SHARED_PATH) - 1) >= batch_shared.shader_cache, "Invalid shader cache. the shader cache is larger then the maximum shader cache index")
            
                    target_shader_path := CACHED_SHARED_PATH[batch_shared.shader_cache]
            
                    shader_file := target_shader_path[16:]
            
                    shader_src_name : cstring = strings.clone_to_cstring(shader_file)
               
                    shader_path_byte, _ := os.read_entire_file_from_filename(target_shader_path)
                       
                    defer{
                        delete_slice(shader_path_byte)
                        delete_cstring(shader_src_name)
                    }
               
                    shader_bytecode := raw_data(shader_path_byte)
                    shader_bytecode_length := uint(len(shader_path_byte))
            
                    DX_CALL(
                        d3d_compiler.Compile(shader_bytecode, shader_bytecode_length, shader_src_name, nil, nil, "vs_main","vs_5_0",15,0, &vertex_blob, nil),
                        nil,
                    )
            
                    DX_CALL(
                        d3d_compiler.Compile(shader_bytecode, shader_bytecode_length,shader_src_name, nil, nil, "ps_main", "ps_5_0", 15,0,&pixel_blob, nil),
                        nil,
                    )
            
                    DX_CALL(
                        device->CreateVertexShader(vertex_blob->GetBufferPointer(), vertex_blob->GetBufferSize(), nil, &vertex_shader),
                        nil,
                    )
            
                    DX_CALL(
                        device->CreatePixelShader(pixel_blob->GetBufferPointer(), pixel_blob->GetBufferSize(), nil, &pixel_shader),
                        nil,
                    )
            
                    DX_CALL(
                        device->CreateInputLayout(&instance_layout_descriptor[0], len(instance_layout_descriptor), vertex_blob->GetBufferPointer(), vertex_blob->GetBufferSize(),&input_layout),
                        nil,
                    )
            
                    ////////////////////////////////////////////////////////////////////////

                    append(&render_params,RenderParam{
                        vertex_shader,
                        vertex_blob,
                        pixel_shader,
                        pixel_blob,
                        input_layout,
                        sprite_shader_resource_view,
                    })
                }

                sync.atomic_store_explicit(&render_batch_buffer.changed_flag, false, sync.Atomic_Memory_Order.Relaxed)
            
                END_EVENT()
            }
        }

        BEGIN_EVENT("Draw Call")

        //Nvidia recommend using Map rather the UpdateSubResource so we will follow thier guidence.
        DX_CALL(
            device_context->Map(vs_global_cbuffer,0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_subresources[1]),
            nil,
            true,
        )

        intrinsics.mem_copy_non_overlapping(mapped_subresources[1].pData,vs_buffer_data, size_of(GlobalDynamicVSConstantBuffer))

        device_context->Unmap(vs_global_cbuffer, 0)

        device_context->ClearRenderTargetView(back_render_target_view[current_buffer_index], &{0.0, 0.4, 0.5, 1.0})
        device_context->OMSetRenderTargets(1, &back_render_target_view[current_buffer_index], nil) 

        for index in 0..<len(render_params){
            current_batch := batches[index]
            render_param := render_params[index]

            // if len(current_batch.sprite_batch) <= 0 {
            //     //TODO: khal there is no batches we might want to filter out zero entity in batch in the game loop rather then
            //     // check it in the render loop. 
            //     break
            // }

            //handle the changes here.

    
            device_context->IASetInputLayout(render_param.layout_input)
    
            device_context->VSSetShader(render_param.vertex_shader, nil, 0)
            device_context->PSSetShader(render_param.pixel_shader, nil, 0)
    
            DX_CALL(
                device_context->Map(vertex_buffers[1], 0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_subresources[0]),
                nil,
                true,
            )

            instance_data := ([^]RenderInstanceData)(mapped_subresources[0].pData)


            
            //TODO:khal this will change since the data is relatively large and is updated frequently
            intrinsics.mem_copy_non_overlapping(mapped_subresources[0].pData, &current_batch.sprite_batch[0], size_of(SpriteInstanceData) * len(current_batch.sprite_batch))
    
        
            device_context->Unmap(vertex_buffers[1], 0)
   
            device_context->IASetVertexBuffers(0, 2, &vertex_buffers[0], &vertex_buffer_stride[0], &vertex_buffer_offset[0])
    
            device_context->VSSetConstantBuffers(0,1,&vs_global_cbuffer)
            //device_context->PSSetConstantBuffers() //this will hold Time, Delta Time and other notion of time in our game.
    
            device_context->PSSetShaderResources(0,1, &render_param.texture_resource)
    
            device_context->DrawIndexedInstanced(6, u32(len(current_batch.sprite_batch)),0,0,0)
        }

        current_buffer_index = (current_buffer_index + 1) & 1

        DX_CALL(
            swapchain->Present(1,0),
            nil,
            true,
        )

       END_EVENT()

        free_all(context.temp_allocator)
    }
}

/////////////////////////////////////////////////////////////////////////////////