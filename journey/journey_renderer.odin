package journey

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

RenderBackend :: enum int{
    DX11 = 0,
    DX12,
    VULKAN,
    METAL,
    OPENGL,
}

run_renderer :: proc(backend : RenderBackend, render_window : rawptr, render_buffer : ^RenderBatchBuffer) -> ^sync.Barrier {
    //Create a barrier and return a barrier.
    barrier :=  &sync.Barrier{}
	sync.barrier_init(barrier, 2)

    render_thread = thread.create(_render_backend_proc[backend])
    render_thread.data = render_buffer
    render_thread.user_args[0] = render_window
    render_thread.user_args[1] = barrier

    thread.start(render_thread)

    return barrier
    //defer thread.destroy(render_thread)
}


stop_renderer :: proc(){
	sync.atomic_store_explicit(&render_thread.flags, {.Done},sync.Atomic_Memory_Order.Release)
    thread.destroy(render_thread)
}

@(private)
render_thread : ^thread.Thread

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
    }else when ODIN_OS_STRING == "linux"{
        _render_backend_proc[RenderBackend.VULKAN] = init_render_vulkan_subsystem
        _render_backend_proc[RenderBackend.OPENGL] = init_render_vulkan_subsystem

    }else when ODIN_OS_STRING == "darwin"{
        _render_backend_proc[RenderBackend.METAL] = init_render_metal_subsystem
    }
}


///////////////////////////// Nil Subsystem //////////////////////////////////
@(private)
@(optimization_mode="size")
init_render_nil_subsystem ::  proc(current_thread : ^thread.Thread){}

//////////////////////////////////////////////////////////////////////////////

//////////////////////////// Metal Subsystem /////////////////////////////////

@(private)
@(optimization_mode="size")
init_render_metal_subsystem ::  proc(current_thread : ^thread.Thread){
    //Not implemented
}

///////////////////////////////////////////////////////////////////////////////

//////////////////////////// Vulkan Subsystem /////////////////////////////////

@(private)
@(optimization_mode="size")
init_render_vulkan_subsystem ::  proc(current_thread : ^thread.Thread){
    //Not implemented
}

///////////////////////////////////////////////////////////////////////////////


//////////////////////////// OpenGL Subsystem /////////////////////////////////


@(private)
@(optimization_mode="size")
init_render_opengl_subsystem ::  proc(current_thread : ^thread.Thread){
    //Not implemented
}

///////////////////////////////////////////////////////////////////////////////


/////////////////////////// Direct X Subsystem ///////////////////////////////


@(private)
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



@(private)
@(optimization_mode="size")
init_render_dx12_subsystem ::  proc(current_thread : ^thread.Thread){
    //Not implemented
}


@(private)
@(optimization_mode="size")
init_render_dx11_subsystem :: proc(current_thread : ^thread.Thread){
    render_batch_buffer := cast(^RenderBatchBuffer)current_thread.data

    batches : []SpriteBatch
    
    CREATE_PROFILER_BUFFER(u32(current_thread.id))

    barrier := cast(^sync.Barrier)(current_thread.user_args[1])
    window := windows.HWND(current_thread.user_args[0])
    
    render_params := make([dynamic]RenderParam)

    //mem_hi os.read_dir()
    //shader_dir,match_err := filepath.glob(common.DEFAULT_SHADER_PATH)
    //assert(match_err == filepath.Match_Error.None, "Failed to load shader directory")

    window_rect : windows.RECT
    windows.GetWindowRect(window, &window_rect)

    window_width := window_rect.right - window_rect.left
    window_height := window_rect.bottom - window_rect.top


    current_buffer_index := 0
    vertex_stride : [2]u32 = {size_of(SpriteIndex), size_of(SpriteInstanceData)} // size of Vertex
    vertex_offset : [2]u32 = {0,0}

    d3d_feature_level := [2]d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0, d3d11.FEATURE_LEVEL._11_1}

    vertices := [4]SpriteIndex{
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
    back_buffer : [2]^d3d11.ITexture2D
    back_render_target_view : [2]^d3d11.IRenderTargetView

    dxgi_device: ^dxgi.IDevice
	dxgi_adapter: ^dxgi.IAdapter
    dxgi_factory : ^dxgi.IFactory4

    vs_cbuffer_0 : ^d3d11.IBuffer

    texture_sampler : ^d3d11.ISamplerState

    staging_buffer : ^d3d11.IBuffer
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
        BufferCount = 3,
        Stereo = false,
        Flags = 0x0,
    }

    constant_buffer_descriptor := d3d11.BUFFER_DESC{
        ByteWidth = size_of(GlobalDynamicConstantBuffer),
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.CONSTANT_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{.WRITE},
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

    staging_buffer_descriptor : d3d11.BUFFER_DESC = d3d11.BUFFER_DESC{
        ByteWidth = INSTANCE_BYTE_WIDTH,
        Usage = d3d11.USAGE.STAGING,
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{d3d11.CPU_ACCESS_FLAG.WRITE, d3d11.CPU_ACCESS_FLAG.READ},
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
        for  render_param in render_params{

                render_param.vertex_shader->Release()
                render_param.vertex_blob->Release()
                render_param.pixel_shader->Release()
                render_param.pixel_blob->Release()
                render_param.layout_input->Release()
                render_param.texture_resource^->Release()
          
        }

        //delete_slice(shader_dir)

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
        device->CreateBuffer(&constant_buffer_descriptor, nil,&vs_cbuffer_0),
         vs_cbuffer_0,
    )

    END_EVENT()

    BEGIN_EVENT("Sampler Construction")

    DX_CALL(
        device->CreateSamplerState(&sampler_descriptor, &texture_sampler),
        texture_sampler,
    )

    END_EVENT()


    BEGIN_EVENT("Buffer Creation")
   
    DX_CALL(
        device->CreateBuffer(&staging_buffer_descriptor, nil, &staging_buffer),
        staging_buffer,
    )

    vertex_resource : d3d11.SUBRESOURCE_DATA = d3d11.SUBRESOURCE_DATA{
        pSysMem = (rawptr)(&vertices),
        SysMemPitch = 0,
        SysMemSlicePitch = 0,
    }
   
    DX_CALL(
        device->CreateBuffer(&vertex_buffer_descriptor, &vertex_resource, &vertex_buffer),
        vertex_buffer,
    )

    DX_CALL(
        device->CreateBuffer(&instance_buffer_descriptor, nil, &instance_data_buffer),
        instance_data_buffer,
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

    buffer :[2]^d3d11.IBuffer = {vertex_buffer, instance_data_buffer}

    mapped_subresources := [2]d3d11.MAPPED_SUBRESOURCE{}
    
    sync.barrier_wait(barrier)

    for (.Started in intrinsics.atomic_load_explicit(&current_thread.flags, sync.Atomic_Memory_Order.Acquire)){
        {
            //TODO: not fairness
            if sync.atomic_load_explicit(&render_batch_buffer.changed_flag, sync.Atomic_Memory_Order.Acquire){

                batches = render_batch_buffer.batches

                BEGIN_EVENT("Updating Shared Render Data")

                render_param_len := len(render_params)
                shared_len := len(render_batch_buffer.shared)

                for index in 0..<shared_len{
                    sprite_shader_resource_view : ^d3d11.IShaderResourceView
    
                    vertex_shader : ^d3d11.IVertexShader
                    pixel_shader : ^d3d11.IPixelShader
            
                    vertex_blob : ^d3d_compiler.ID3DBlob
                    pixel_blob : ^d3d_compiler.ID3DBlob
            
                    input_layout : ^d3d11.IInputLayout

                    texture_resource : d3d11.SUBRESOURCE_DATA
                    sprite_texture : ^d3d11.ITexture2D

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

                    batch_shared := render_batch_buffer.shared[index]
            
                    //////////////////////////////// TEXTURE SETUP ////////////////////////////////
            
                    texture_descriptor.Width = u32(batch_shared.width)
                    texture_descriptor.Height = u32(batch_shared.height)
                    
                    texture_resource.pSysMem = batch_shared.texture
                    texture_resource.SysMemPitch = texture_descriptor.Width << 2
                
                    DX_CALL(
                        device->CreateTexture2D(&texture_descriptor, &texture_resource, &sprite_texture),
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
        
        DX_CALL(
            device_context->Map(vs_cbuffer_0,0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_subresources[1]),
            nil,
            true,
        )

        //TODO: khal update dt and time.
        {
            constants := (^GlobalDynamicConstantBuffer)(mapped_subresources[1].pData)
            constants.viewport_size = {viewport.Width, viewport.Height}
            constants.time = 0
            constants.delta_time = 0
        }

        device_context->Unmap(vs_cbuffer_0, 0)

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
    
            device_context->IASetInputLayout(render_param.layout_input)
    
            device_context->VSSetShader(render_param.vertex_shader, nil, 0)
            device_context->PSSetShader(render_param.pixel_shader, nil, 0)
    
            DX_CALL(
                device_context->Map(staging_buffer, 0, d3d11.MAP.WRITE, {}, &mapped_subresources[0]),
                nil,
                true,
            )
    
            intrinsics.mem_copy_non_overlapping(mapped_subresources[0].pData, &current_batch.sprite_batch[0], size_of(SpriteInstanceData) * len(current_batch.sprite_batch))
    
            device_context->Unmap(staging_buffer, 0)
    
            device_context->CopyResource(instance_data_buffer, staging_buffer)
    
            device_context->IASetVertexBuffers(0, 2, &buffer[0], &vertex_stride[0], &vertex_offset[0])
    
            device_context->VSSetConstantBuffers(0,1,&vs_cbuffer_0)
    
            device_context->PSSetShaderResources(0,1, &render_param.texture_resource)
    
            device_context->DrawIndexedInstanced(6, u32(len(current_batch.sprite_batch)),0,0,0)
        }

        current_buffer_index = (current_buffer_index + 1) % 2;

        DX_CALL(
            swapchain->Present(0,0),
            nil,
            true,
        )

       END_EVENT()

        free_all(context.temp_allocator)
    }
}


/////////////////////////////////////////////////////////////////////////////////