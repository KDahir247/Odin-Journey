 package journey

import "core:mem"
import "core:fmt"
import "core:thread"
import "core:sync"
import "core:intrinsics"
import "core:sys/windows"
import "core:os"

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"
import "core:math/linalg/hlsl"
import "vendor:microui"

//////////////////////// Editor //////////////////////////
game_editor_vertex_index := 0

draw_icon :: proc(vertex_data : []VertexData, icon_id : u32, icon_rect : microui.Rect, icon_color : microui.Color){
    icon_source_rect := microui.default_atlas[icon_id] 
    x := icon_rect.x + (icon_rect.w - icon_source_rect.w) >> 1
    y := icon_rect.y + (icon_rect.h - icon_source_rect.h) >> 1

    dest_rect := microui.Rect{
        x = x, y = y, w = icon_source_rect.w, h = icon_source_rect.h,
    }

    push_quad(vertex_data,dest_rect, icon_source_rect, icon_color)
}

draw_rect :: proc(vertex_data : []VertexData, dest_rect : microui.Rect, color : microui.Color){
    push_quad(vertex_data, dest_rect, microui.default_atlas[microui.DEFAULT_ATLAS_WHITE], color)
}

draw_text :: proc(vertex_data : []VertexData,text : string, position : microui.Vec2, color : microui.Color){
    text_destination_rect := microui.Rect{position.x, position.y, 0, 0}

    for ch in text{
        if ch&0xc0 == 0x80 {
			continue
		}
        r := min(int(ch), 127)
        text_source_rect := microui.default_atlas[microui.DEFAULT_ATLAS_FONT + r]
        
        text_destination_rect.w = text_source_rect.w
        text_destination_rect.h = text_source_rect.h

        push_quad(vertex_data, text_destination_rect, text_source_rect, color)
        text_destination_rect.x += text_destination_rect.w
    }



}


push_quad :: proc(vertex_data : []VertexData, destination_rect : microui.Rect, src_rect : microui.Rect, color : microui.Color){
    HALF_SCREEN_RES_X :: SCREEN_RESOLUTION.x >> 1
    HALF_SCREEN_RES_Y :: SCREEN_RESOLUTION.y >> 1

    RCP_NORM_COLOR : f32 : 1.0 / 255.0
    RCP_NORM_U : f32 : 1.0 / microui.DEFAULT_ATLAS_WIDTH
    RCP_NORM_V : f32 : 1.0 / microui.DEFAULT_ATLAS_HEIGHT


    left_vertex := f32(destination_rect.x )
    right_vertex := f32(destination_rect.x + destination_rect.w)
    
    bottom_vertex := f32(destination_rect.y)
    top_vertex := f32(destination_rect.y + destination_rect.h )

    u0 := f32(src_rect.x ) * RCP_NORM_U
    v0 := f32(src_rect.y ) * RCP_NORM_V

    u1 := f32(src_rect.x + src_rect.w) * RCP_NORM_U
    v1 := f32(src_rect.y + src_rect.h) * RCP_NORM_V

    target_color := [4]f32{f32(color.r), f32(color.g), f32(color.b), f32(color.a)} * RCP_NORM_COLOR

    bottom_left := VertexData{
        position = {left_vertex, bottom_vertex},
        uv = {u0,v0},
        color = target_color,
    }

    bottom_right := VertexData{
        position = {right_vertex, bottom_vertex},
        uv = {u1, v0},
        color =  target_color,
    }

    top_left := VertexData{
        position = {left_vertex, top_vertex},
        uv = {u0, v1},
        color = target_color,
    }

    top_right := VertexData{
        position = {right_vertex, top_vertex},
        uv = {u1, v1},
        color = target_color,
    }

    current_editor_vertex_index := game_editor_vertex_index

    vertex_data[current_editor_vertex_index] = bottom_left
    vertex_data[current_editor_vertex_index+ 1] = top_left

    vertex_data[current_editor_vertex_index + 2] = top_right
    vertex_data[current_editor_vertex_index + 3] = bottom_right

    game_editor_vertex_index += 4
}

//Editor will only be available on debug build

u8_slider :: proc(ctx: ^microui.Context, val: ^u8, lo, hi: u8) -> (res: microui.Result_Set) {
	microui.push_id(ctx, uintptr(val))

	@static tmp: microui.Real
	tmp = microui.Real(val^)
	res = microui.slider(ctx, &tmp, microui.Real(lo), microui.Real(hi), 0, "%.0f", {.ALIGN_CENTER})
	val^ = u8(tmp)
	microui.pop_id(ctx)
	return
}


all_windows :: proc(ctx: ^microui.Context)
{
    @static header_option := microui.Options{.NO_CLOSE,.NO_TITLE,.NO_RESIZE,.NO_SCROLL, .NO_INTERACT}

    ctx.style.colors = HEADER_COLORMAP

    if microui.window(ctx, "Header", {0,0,SCREEN_RESOLUTION.x, HEADER_SCALE_FACTOR}, header_option){
        microui.layout_row(ctx, {64, 64, 64 ,64, 64 ,64}, HEADER_SCALE_FACTOR - 5)

        if .SUBMIT in microui.button(ctx, "File", .NONE, {.ALIGN_CENTER}) { }
		if .SUBMIT in microui.button(ctx, "Edit", .NONE, {.ALIGN_CENTER}) {}
		if .SUBMIT in microui.button(ctx, "View", .NONE, {.ALIGN_CENTER}) {}
		if .SUBMIT in microui.button(ctx, "Project", .NONE, {.ALIGN_CENTER}) {}
		if .SUBMIT in microui.button(ctx, "Debug", .NONE, {.ALIGN_CENTER}){}
		if .SUBMIT in microui.button(ctx, "Help", .NONE, {.ALIGN_CENTER}){}

    }

    ctx.style.colors =  ASSET_COLORMAP
    ctx.style.padding = 0

    if microui.window(ctx, "Asset", {0,HEADER_SCALE_FACTOR,250, SCREEN_RESOLUTION.y - (HEADER_SCALE_FACTOR << 1)}, {.NO_CLOSE,.NO_RESIZE,.NO_SCROLL, .NO_INTERACT, .NO_TITLE}){
		microui.layout_row(ctx, {-18}, -2)
		id := microui.get_id(ctx, "AssetFolder")

		microui.update_control(ctx, id ,microui.Rect{1,(HEADER_SCALE_FACTOR << 1), 250 - 18, SCREEN_RESOLUTION.y - (HEADER_SCALE_FACTOR << 1) - 2}, {.ALIGN_CENTER,} )
		microui.begin_panel(ctx, "AssetFolder")
		ctx.style.padding = 20
		microui.label(ctx, "Asset")
		ctx.style.padding = 1

		if ctx.mouse_pressed_bits == {.RIGHT} && ctx.focus_id == id{
			microui.open_popup(ctx,"AssetPopup")	
		}

		if microui.begin_popup(ctx, "AssetPopup"){
			microui.button(ctx, "Load Asset")

			microui.end_popup(ctx)
		}
        microui.end_panel(ctx)
		
    }

    ctx.style.colors =  ASSET_COLORMAP

    if microui.window(ctx, "Inspector", {SCREEN_RESOLUTION.x - 400, HEADER_SCALE_FACTOR, 400,SCREEN_RESOLUTION.y - (HEADER_SCALE_FACTOR << 1)}, {.NO_CLOSE,.NO_RESIZE,.NO_SCROLL, .NO_INTERACT, .NO_TITLE}){
		microui.layout_row(ctx, {18, -1}, -2)

        microui.layout_next(ctx)

        ctx.style.colors = HEADER_COLORMAP
        microui.begin_panel(ctx, "Sub Inspector", {.ALIGN_CENTER})
        ctx.style.colors =  ASSET_COLORMAP
        
        microui.layout_row(ctx, {-1}, (SCREEN_RESOLUTION.y - (HEADER_SCALE_FACTOR << 1)) / 2)
        microui.begin_panel(ctx, "Entity Panel", {.ALIGN_CENTER})
        
        ctx.style.padding = 20
        microui.label(ctx,"Entity")
        ctx.style.padding = 1

        microui.end_panel(ctx)

        microui.layout_row(ctx, {-1}, (SCREEN_RESOLUTION.y - (HEADER_SCALE_FACTOR << 1)) / 2)
        microui.begin_panel(ctx, "Component Panel", {.ALIGN_CENTER})

        ctx.style.padding = 20
        microui.label(ctx,"Component")
        ctx.style.padding = 1


        microui.end_panel(ctx)

        microui.end_panel(ctx)
    }

    @static buf: [128]byte
    @static buf_len: int
    if microui.window(ctx, "Console Window", {250,  SCREEN_RESOLUTION.y - 200 - HEADER_SCALE_FACTOR, SCREEN_RESOLUTION.x - 400 - 250, 200}, {.NO_CLOSE,.NO_RESIZE,.NO_SCROLL, .NO_INTERACT, .NO_TITLE}){
        
        microui.layout_row(ctx, {-1}, 20)
        microui.layout_next(ctx) //Padding

        microui.layout_row(ctx, {-1}, -1)
        microui.begin_panel(ctx, "Log", {})

        microui.layout_row(ctx, {-1}, -1)

        microui.text(ctx, "")

    
        //if buffer has been updated
        if true{
            panel := microui.get_current_container(ctx)
			panel.scroll.y = panel.content_size.y
            //buffer updated = false
        }

        microui.end_panel(ctx)

    }

    if microui.window(ctx, "Footer", {0, SCREEN_RESOLUTION.y - HEADER_SCALE_FACTOR, SCREEN_RESOLUTION.x, HEADER_SCALE_FACTOR}, {.NO_CLOSE,.NO_RESIZE,.NO_SCROLL, .NO_INTERACT, .NO_TITLE}){
        
    


    }



    ctx.style.padding = 5
    

}
	
Editor :: struct{
    editor_context : microui.Context,
    atlas_texture : ^d3d11.IShaderResourceView,
}

/////////////////////////////////////////////////////////
create_renderer :: proc(render_descriptor : ^RenderDescriptor, allocator : mem.Allocator = context.allocator) -> ^thread.Thread {
    conditional_variable :=  &sync.Cond{}
    render_descriptor.cond = conditional_variable
    
    render_thread := thread.create(init_render_dx11_subsystem)
    render_thread.data = render_descriptor
    thread.start(render_thread)

    {
        sync.guard(&render_thread.mutex)
        sync.cond_wait(conditional_variable, &render_thread.mutex)
    }

    return render_thread
}


stop_renderer :: proc(render_thread : ^thread.Thread){
    intrinsics.atomic_store(&render_thread.flags, render_thread.flags + {.Done})
    thread.destroy(render_thread)
}


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
@(deferred_in=DX_END)
DX_CALL ::  proc(hr : d3d11.HRESULT, auto_free_ptr : rawptr, panic_on_fail := false, loc := #caller_location)  {
    when ODIN_DEBUG{
        if hr != 0{
            hr_index := int(hr) & 0xFFFFFFFF
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
    unimplemented()
}


@(private)
init_render_dx11_subsystem :: proc(render_thread : ^thread.Thread){
    render_desc : ^RenderDescriptor = (^RenderDescriptor)(render_thread.data)
      
    window := windows.HWND(render_desc.render_handle)

    current_back_buffer_index := 0

    vertex_buffer_stride : u32 = size_of(VertexData)
    vertex_buffer_offset : u32 = 0

    indices := make_slice([]u16, BATCH_LIMIT * INDICES_PER_SPRITE)

    common_shader_bytes,_ := os.read_entire_file_from_filename(DEFAULT_SHADER)

    game_editor : Editor 
    game_editor_vertices := make_slice([]VertexData, BATCH_LIMIT * VERTICES_PER_SPRITE) //TODO: excessively large.
    vs_buffer_data := new(GlobalDynamicVSConstantBuffer)


    when ODIN_DEBUG{
        microui.init(&game_editor.editor_context)

        game_editor.editor_context.text_width = microui.default_atlas_text_width
        game_editor.editor_context.text_height = microui.default_atlas_text_height
    }

    defer{
        delete(game_editor_vertices)
        delete(indices)
        delete(common_shader_bytes)
    }

    //Device Construction & Query

    base_device : ^d3d11.IDevice
    base_device_context : ^d3d11.IDeviceContext

    device : ^d3d11.IDevice
    device_context : ^d3d11.IDeviceContext

    d3d_feature_level := [2]d3d11.FEATURE_LEVEL{d3d11.FEATURE_LEVEL._11_0, d3d11.FEATURE_LEVEL._11_1}

    //TODO:khal maybe pass the best adapter rather then the first adapter. iterate over the adapters and find the one with the most mem.
    DX_CALL(
        d3d11.CreateDevice(nil, d3d11.DRIVER_TYPE.HARDWARE, nil, d3d11.CREATE_DEVICE_FLAGS{.SINGLETHREADED}, &d3d_feature_level[0], len(d3d_feature_level), d3d11.SDK_VERSION, &base_device, nil, &base_device_context),
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

    dxgi_device: ^dxgi.IDevice
	dxgi_adapter: ^dxgi.IAdapter
    dxgi_factory : ^dxgi.IFactory4

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

    //SwapChain Construction
    swapchain : ^dxgi.ISwapChain1
    
   // DXGI_SWAP_EFFECT_FLIP_DISCARD should be preferred when applications fully render over the backbuffer before presenting it or are interested in supporting multi-adapter scenarios easily.
    // DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL should be used by applications that rely on partial presentation optimizations or regularly read from previously presented backbuffers.

    swapchain_descriptor := dxgi.SWAP_CHAIN_DESC1{
        Width = u32(SCREEN_RESOLUTION.x),
        Height = u32(SCREEN_RESOLUTION.y),
        Format = dxgi.FORMAT.R8G8B8A8_UNORM, //play around with the format
        Stereo = false,
        SampleDesc = {1, 0},
        BufferUsage = dxgi.USAGE{.RENDER_TARGET_OUTPUT},
        BufferCount = 2,
        SwapEffect = dxgi.SWAP_EFFECT.FLIP_DISCARD,
        Flags = {},//0x0,
    }

    //SwapChain is only windowed, so the game doesn't support fullscreen yet.
    DX_CALL(
        dxgi_factory->CreateSwapChainForHwnd(device, window, &swapchain_descriptor, nil, nil, &swapchain),
        swapchain,
    )
    
    DX_CALL(
        swapchain->GetDesc1(&swapchain_descriptor),
         nil,
    )

    back_buffer : [2]^d3d11.ITexture2D
    back_render_target_view : [2]^d3d11.IRenderTargetView

    DX_CALL(
        swapchain->GetBuffer(0,d3d11.ITexture2D_UUID,(^rawptr)(&back_buffer.x)),
        back_buffer.x,
    )

    DX_CALL(
        swapchain->GetBuffer(0,d3d11.ITexture2D_UUID,(^rawptr)(&back_buffer.y)),
        back_buffer.y,
    )
    
    DX_CALL(
        device->CreateRenderTargetView(back_buffer.x, nil, &back_render_target_view.x),
         back_render_target_view.x,
    )

    DX_CALL(
        device->CreateRenderTargetView(back_buffer.y, nil, &back_render_target_view.y),
        back_render_target_view.y,
    )

    //Buffer Construction
    dynamic_vertex_buffer : ^d3d11.IBuffer

    vertex_buffer_descriptor : d3d11.BUFFER_DESC = d3d11.BUFFER_DESC{
        ByteWidth = size_of(VertexData) * BATCH_LIMIT * VERTICES_PER_SPRITE,
        Usage = d3d11.USAGE.DYNAMIC, 
        BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.VERTEX_BUFFER},
        CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{.WRITE}
    }


    DX_CALL(
        device->CreateBuffer(&vertex_buffer_descriptor, nil, &dynamic_vertex_buffer),
        dynamic_vertex_buffer,
    )

    index_buffer : ^d3d11.IBuffer

    index_buffer_descriptor := d3d11.BUFFER_DESC{
        ByteWidth = size_of(u16) * BATCH_LIMIT * INDICES_PER_SPRITE,
        BindFlags = {.INDEX_BUFFER},
        StructureByteStride = size_of(u16),
        Usage = d3d11.USAGE.DEFAULT, //TODO: can i make this immutable, since we are creating the index buffer once and passing it to the GPU once.
    }

    for i in 0..<BATCH_LIMIT{
    
        indices_index := i * 6
        vertex_index := u16(i * 4)

        indices[indices_index] = vertex_index
        indices[indices_index + 1] = 1 + vertex_index
        indices[indices_index + 2] = 2 + vertex_index


        indices[indices_index + 3] = 0 + vertex_index
        indices[indices_index + 4] = 2 + vertex_index
        indices[indices_index + 5] = 3 + vertex_index
    }

    index_resource := d3d11.SUBRESOURCE_DATA{
        pSysMem = raw_data(indices),
    }

    DX_CALL(
        device->CreateBuffer(&index_buffer_descriptor, &index_resource, &index_buffer),
        index_buffer,
    )

    //Shader Construction

    vertex_shader : ^d3d11.IVertexShader
    pixel_shader : ^d3d11.IPixelShader

    vertex_blob : ^d3d_compiler.ID3DBlob
    pixel_blob : ^d3d_compiler.ID3DBlob

    input_layout : ^d3d11.IInputLayout

    instance_layout_descriptor := [3]d3d11.INPUT_ELEMENT_DESC{
        {"COLOR", 0, dxgi.FORMAT.R32G32B32A32_FLOAT, 0, d3d11.APPEND_ALIGNED_ELEMENT, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0},
        {"SV_POSITION", 0, dxgi.FORMAT.R32G32_FLOAT, 0, d3d11.APPEND_ALIGNED_ELEMENT, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0},
        {"TEXCOORD", 0, dxgi.FORMAT.R32G32_FLOAT, 0, d3d11.APPEND_ALIGNED_ELEMENT , d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0},
    }

    DX_CALL(
        d3d_compiler.Compile(raw_data(common_shader_bytes), uint(len(common_shader_bytes)), "", nil, nil, "vs_main", "vs_5_0", u32(d3d_compiler.D3DCOMPILE_OPTIMIZATION_LEVEL3), 0, &vertex_blob, nil),
        vertex_blob,
    )

    DX_CALL(
        d3d_compiler.Compile(raw_data(common_shader_bytes), uint(len(common_shader_bytes)), "", nil, nil, "ps_main", "ps_5_0", u32(d3d_compiler.D3DCOMPILE_OPTIMIZATION_LEVEL3), 0, &pixel_blob, nil),
        pixel_blob,
    )

    DX_CALL(
        device->CreateVertexShader(vertex_blob->GetBufferPointer(), vertex_blob->GetBufferSize(), nil, &vertex_shader),
        vertex_shader,
    )

    DX_CALL(
        device->CreatePixelShader(pixel_blob->GetBufferPointer(), pixel_blob->GetBufferSize(), nil, &pixel_shader),
        pixel_shader,
    )

    DX_CALL(
        device->CreateInputLayout(&instance_layout_descriptor[0], len(instance_layout_descriptor), vertex_blob->GetBufferPointer(), vertex_blob->GetBufferSize(), &input_layout),
        input_layout,
    )

    //Texture Construction
    sprite_texture : ^d3d11.ITexture2D
    editor_texture : ^d3d11.ITexture2D
    editor_texture_view : ^d3d11.IShaderResourceView
    
    sprite_texture_descriptor := d3d11.TEXTURE2D_DESC{
        Width = 0,
        Height = 0,
        MipLevels = 1,
        ArraySize = 1,
        Format = dxgi.FORMAT.R8G8B8A8_UNORM, //play around with the format
        SampleDesc = dxgi.SAMPLE_DESC{1,0},
        Usage = d3d11.USAGE.IMMUTABLE,
        BindFlags = d3d11.BIND_FLAGS{.SHADER_RESOURCE},
        MiscFlags = {},
    }

    editor_texture_descriptor := d3d11.TEXTURE2D_DESC{
        Width = microui.DEFAULT_ATLAS_WIDTH, 
        Height = microui.DEFAULT_ATLAS_HEIGHT,
        MipLevels = 1,
        ArraySize = 1,
        Format = dxgi.FORMAT.A8_UNORM,
        SampleDesc = dxgi.SAMPLE_DESC{1,0},
        Usage = d3d11.USAGE.IMMUTABLE,
        BindFlags = d3d11.BIND_FLAGS{.SHADER_RESOURCE},
        MiscFlags = {},
    }

    editor_texture_resource := d3d11.SUBRESOURCE_DATA{
        pSysMem = raw_data(microui.default_atlas_alpha[:]),//raw_data(a),
        SysMemPitch = editor_texture_descriptor.Width,
    }

    DX_CALL(
        device->CreateTexture2D(&editor_texture_descriptor, &editor_texture_resource, &editor_texture),
        editor_texture,
    )

    DX_CALL(
        device->CreateShaderResourceView(editor_texture, nil, &editor_texture_view),
        editor_texture_view
    )


        //     sprite_texture_descriptor.Width = u32(tex_parameter.width)
    //     sprite_texture_descriptor.Height = u32(tex_parameter.height)

    //     sprite_texture_resource := d3d11.SUBRESOURCE_DATA{
    //         pSysMem = tex_parameter.texture,
    //         SysMemPitch = sprite_texture_descriptor.Width << 2,    
    //     }

    //     //////////////////////////////// TEXTURE SETUP ////////////////////////////////

    //     DX_CALL(
    //         device->CreateTexture2D(&sprite_texture_descriptor, &sprite_texture_resource, &sprite_texture),
    //         sprite_texture,
    //     )

    //     DX_CALL(
    //         device->CreateShaderResourceView(sprite_texture, nil, &sprite_shader_resource_view),
    //         nil,
    //     )

       
    //Viewport Construction
    viewport : d3d11.VIEWPORT = d3d11.VIEWPORT{
        Width = f32(SCREEN_RESOLUTION.x),
        Height = f32(SCREEN_RESOLUTION.y),
        MinDepth = 0.01,
        MaxDepth = 1,
    }

  //Constant Buffer Construction
  vs_cbuffer : ^d3d11.IBuffer

  vs_cbuffer_descriptor := d3d11.BUFFER_DESC{
      ByteWidth = size_of(GlobalDynamicVSConstantBuffer),
      Usage = d3d11.USAGE.DYNAMIC,
      BindFlags = d3d11.BIND_FLAGS{d3d11.BIND_FLAG.CONSTANT_BUFFER},
      CPUAccessFlags = d3d11.CPU_ACCESS_FLAGS{.WRITE},
  }
  
//   vs_buffer_data.projection_matrix = dx11_ortho_lhs(viewport.Width,viewport.Height,viewport.MinDepth, viewport.MaxDepth)
//   vs_buffer_data.view_matrix = dx11_lookat_lhs(hlsl.float3{5.0, 0.0, 0.0}, hlsl.float3{5.0, 0.0, 1.0}, hlsl.float3{0.0, -1.0, 0.0})

  vs_buffer_data.projection_matrix =dx11_ortho_lhs(viewport.Width,viewport.Height,0.1, 10)
  vs_buffer_data.view_matrix = dx11_lookat_lhs({0,0,1}, {0,0,0}, {0,1,0})
 
  vs_cbuffer_resource := d3d11.SUBRESOURCE_DATA{
    pSysMem = vs_buffer_data,
}

  DX_CALL(
      device->CreateBuffer(&vs_cbuffer_descriptor, &vs_cbuffer_resource,&vs_cbuffer),
      vs_cbuffer,
  )


    //Rasterizer Construction
    raterizer_state : ^d3d11.IRasterizerState

    raterizer_descriptor := d3d11.RASTERIZER_DESC{
        FillMode = d3d11.FILL_MODE.SOLID,
        CullMode = d3d11.CULL_MODE.NONE, //BACK
        FrontCounterClockwise = false,
        DepthBias = 0.0,
        DepthBiasClamp = 0.0,
        SlopeScaledDepthBias = 0.0,
        DepthClipEnable = false,
        ScissorEnable = false,
        MultisampleEnable = true,
        AntialiasedLineEnable = false,
    }

    DX_CALL(
        device->CreateRasterizerState(&raterizer_descriptor,&raterizer_state),
        raterizer_state,
    )


    //Sampler Construction
    texture_sampler : ^d3d11.ISamplerState

    sampler_descriptor := d3d11.SAMPLER_DESC{
        Filter = d3d11.FILTER.MIN_MAG_MIP_POINT,
        AddressU = d3d11.TEXTURE_ADDRESS_MODE.WRAP,
        AddressV = d3d11.TEXTURE_ADDRESS_MODE.WRAP,
        AddressW = d3d11.TEXTURE_ADDRESS_MODE.WRAP,
        MipLODBias = 0,
        MaxAnisotropy = 1,
        ComparisonFunc = d3d11.COMPARISON_FUNC.ALWAYS, //?? What is Comparsion comparing against?
        BorderColor = {0.0, 0.0, 0.0, 0.0},
        MinLOD = 0,
        MaxLOD = d3d11.FLOAT32_MAX,
    }

    DX_CALL(
        device->CreateSamplerState(&sampler_descriptor, &texture_sampler),
        texture_sampler,
    )

    //BlendState Construction
    blend_state : ^d3d11.IBlendState

    blend_descriptor := d3d11.BLEND_DESC{
        AlphaToCoverageEnable = false,
        IndependentBlendEnable = false, 
    }

    blend_descriptor.RenderTarget[0] = d3d11.RENDER_TARGET_BLEND_DESC{
        BlendEnable = true,
        SrcBlend = d3d11.BLEND.SRC_ALPHA,
        SrcBlendAlpha = d3d11.BLEND.ONE,

        DestBlend = d3d11.BLEND.INV_SRC_ALPHA,
        DestBlendAlpha = d3d11.BLEND.ONE,
        
        BlendOp = d3d11.BLEND_OP.ADD,
        BlendOpAlpha = d3d11.BLEND_OP.ADD,

        RenderTargetWriteMask = 15,
    }

    DX_CALL(
        device->CreateBlendState(&blend_descriptor, &blend_state),
        blend_state,
    )

    //DepthStencil Construction
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

    DX_CALL(
        device->CreateDepthStencilState(&stencil_depth_descriptor, &stencil_depth_state),
        stencil_depth_state,
    )

    //Binding

    device_context->IASetVertexBuffers(0, 1, &dynamic_vertex_buffer, &vertex_buffer_stride, &vertex_buffer_offset)
    device_context->IASetIndexBuffer(index_buffer, dxgi.FORMAT.R16_UINT, 0)
    device_context->IASetInputLayout(input_layout)
    device_context->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)

    device_context->VSSetConstantBuffers(0,1,&vs_cbuffer)
    device_context->VSSetShader(vertex_shader, nil, 0)

    device_context->HSSetShader(nil, nil, 0)
    device_context->CSSetShader(nil, nil, 0)
    device_context->DSSetShader(nil, nil, 0)
    device_context->GSSetShader(nil, nil, 0)

    device_context->RSSetViewports(1, &viewport)
    device_context->RSSetState(raterizer_state)
    device_context->PSSetSamplers(0,1,&texture_sampler)
    device_context->PSSetShader(pixel_shader, nil, 0)

    device_context->OMSetBlendState(blend_state, &{1.0, 1.0, 1.0, 1.0}, 0xFFFFFFFF)
    device_context->OMSetDepthStencilState(stencil_depth_state, 0)
    
  
    {
        sync.guard(&render_thread.mutex)
        sync.signal(render_desc.cond)
    }

    for !thread.is_done(render_thread){
        when ODIN_DEBUG{
            microui.begin(&game_editor.editor_context)
            all_windows(&game_editor.editor_context)
            microui.end(&game_editor.editor_context)


            editor_command : ^microui.Command

            for editor_variant in microui.next_command_iterator(&game_editor.editor_context, &editor_command){
                if rect, ok := editor_variant.(^microui.Command_Rect); ok{
                    draw_rect(game_editor_vertices, rect.rect, rect.color)
                }

                #partial switch cmd in editor_variant{
                    case ^microui.Command_Jump, ^microui.Command_Clip:
                        //clipping will be avoided mostly because the game can't resize and txt size will 
                        // adjust on the monitor resoulution. This will be a flag passed from the game launcher.
                        //unreachable()

                    case ^microui.Command_Icon:
                        //handle 

                        icon := cmd.variant.(^microui.Command_Icon)
                        draw_icon(game_editor_vertices, u32(icon.id), icon.rect, icon.color)
                    
                    case ^microui.Command_Text:
                        text := cmd.variant.(^microui.Command_Text)
                        draw_text(game_editor_vertices, text.str, text.pos, text.color)
                        //text

                } 
            }
        }
       
        device_context->ClearRenderTargetView(back_render_target_view[current_back_buffer_index], &{0.3, 0.32, 0.34, 1.0})
        device_context->OMSetRenderTargets(1, &back_render_target_view[current_back_buffer_index], nil) 

       
        
        // //Draw Call
    
        // //TODO:khal place holder. We will change 0..<100 to the amount of unique texture.
        // //eg for tex in all_unique_textures {}
        // for index in 0..<100{
        //     //device_context->PSSetShaderResources(0,1, &render_param.texture_resource)

        //     mapped_buffer : d3d11.MAPPED_SUBRESOURCE

        //     //TODO:khal use D3D11_MAP_WRITE_NO_OVERWRITE. Keep the previous vertex buffer is kept and only the parts that changed are written.
        //     DX_CALL(
        //         device_context->Map(dynamic_vertex_buffer, 0, d3d11.MAP.WRITE_NO_OVERWRITE, {}, &mapped_buffer),
        //         nil,
        //         true,
        //     )

        //     //intrinsics.mem_copy_non_overlapping(mapped_subresources[0].pData, &current_batch.InstanceRenderData[0], GPUInstanceDataSize * len(current_batch.InstanceRenderData))
        
        //     device_context->Unmap(dynamic_vertex_buffer, 0)
   
    
        //     //device_context->DrawIndexed(2,0,0) IndexCount will be the current batch size of the current texture * the IndicesPerSprite
        // }


        // //UI Drawing?
        device_context->PSSetShaderResources(0,1, &editor_texture_view)

        mapped_buffer : d3d11.MAPPED_SUBRESOURCE

        DX_CALL(
            device_context->Map(dynamic_vertex_buffer, 0, d3d11.MAP.WRITE_DISCARD, {}, &mapped_buffer),
            nil,
            true,
        )

        intrinsics.mem_copy_non_overlapping(mapped_buffer.pData, &game_editor_vertices[0], size_of(VertexData) * game_editor_vertex_index)
        
        device_context->Unmap(dynamic_vertex_buffer, 0)

        //device_context->Draw(20, 0)
       device_context->DrawIndexed(u32(game_editor_vertex_index) * 6,0,0)

        current_back_buffer_index = (current_back_buffer_index + 1) & 1

        DX_CALL(
            swapchain->Present(1,{}),
            nil,
            true,
        )
        game_editor_vertex_index = 0


    }
}