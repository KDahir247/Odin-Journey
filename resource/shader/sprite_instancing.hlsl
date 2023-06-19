cbuffer VS_CONSTANT_BUFFER : register(b0){
    //vp matrix,
    float2 spriteSize;
    float2 deviceConversion;
    float2 viewportSize;
    uint time;
    uint delta_time;
};

struct VSIn{
    float2 quadid : QUAD_ID;
    matrix transform : TRANSFORM;
    float4 src_rect : SRC_RECT;
    uint spriteid : SV_INSTANCEID;
    uint vertexid : SV_VERTEXID;
};

struct VsOut{
    float4 position : SV_POSITION;
    float2 uv : UV;
};

//TODO use inputlayout x.x
Texture2D<float4> SpriteTexture : register(t0);
SamplerState SpriteSampler : register (s0);

VsOut vs_main(in VSIn vs_in)
{
    VsOut vso;

    // float2 position_screen_space = float4(vs_in.position * src_rect.zw, 0.0, 1.0)
    // position_screen_space = mul(position_screen_space, mvp_matrix)

    // float2 position_device_space = position_screen_space / viewport_size
    // position_device_space *= device_conversion - float2(1.0, -1.0)
    
    float2 scaled_quad = vs_in.quadid * float2(39, 41);

    float2 position = scaled_quad * deviceConversion * 2  - float2(1.0, -1.0);
    vso.position = float4(position.x, position.y, 0.0f,1.0f) ;
    vso.uv = scaled_quad;

    return vso;
}

float4 ps_main(in VsOut vs_out) : SV_TARGET{
    float2 target_uv = vs_out.uv  * float2(1.0 / 663, 1.0 / 400); //+ ( float2(39, 0) * float2(1.0 / 663, 1.0 / 400)); 
    float4 color = SpriteTexture.Sample(SpriteSampler, target_uv);
    return color;

}