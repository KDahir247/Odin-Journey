//  Shader assembly Legend
//ALT I for build compile,
//ALT O for run compile,
//SHIFT ALT O for recompile

/*
BEGIN_SHADER_DECLARATIONS
{
    "Shaders": [
        {
            "ShaderName": "vs_main",
            "ShaderCompiler": "dxc",
            "ShaderType": "vs",
            "ShaderModel": "5_0",
            "EntryPoint": "vs_main",
            "Defines": [],
            "Optimization": "0",
            "AdditionalArgs": []
        }
    ]
}
END_SHADER_DECLARATIONS
*/

cbuffer VS_CONSTANT_BUFFER : register(b0){
    matrix projection_matrix;
    matrix view_matrix;

    float viewport_x;
    float viewport_y;
    float viewport_width;
    float viewport_height;
};

struct VSIn{
    float2 quadid : QUAD_ID; //vertex

    matrix transform : TRANSFORM;
    float4 src_rect : SRC_RECT;
    float4 color : COLOR;
    
    //naming is bad will change, but it will hold 2 vec2 (flip x bit, flip y bit, pivot point x, pivot point y)
    float4 sprite_detail : SPRITE;
    uint spriteid : SV_INSTANCEID;
    uint vertexid : SV_VERTEXID;
};

struct VsOut{
    float4 position : SV_POSITION;
    float4 color : COLOR;
    float2 uv : UV;
};

Texture2D<float4> SpriteTexture : register(t0);
SamplerState SpriteSampler : register (s0);

VsOut vs_main(in VSIn vs_in)
{
    VsOut vso;
    
    float4 scaled_quad = float4(vs_in.quadid * vs_in.src_rect.zw, 0.0, 1.0);

    float4 center_pivot = float4(vs_in.src_rect.zw * 0.5, 0.0, 0.0);

    float4 position = scaled_quad - center_pivot;
    position = mul(position, vs_in.transform);
    position = mul(position, view_matrix);
    position = mul(position, projection_matrix);

    float2 flipped_scaled_quad = float2(
        (scaled_quad.x * vs_in.sprite_detail.x) + (vs_in.src_rect.z - scaled_quad.x) * (1 - vs_in.sprite_detail.x),
        (scaled_quad.y * vs_in.sprite_detail.y) + (vs_in.src_rect.w - scaled_quad.y) * (1 - vs_in.sprite_detail.y)
    );

    vso.position = position;
    vso.uv = flipped_scaled_quad + vs_in.src_rect.xy;
    vso.color = vs_in.color;

    return vso;
}

float4 ps_main(in VsOut vs_out) : SV_TARGET{
    float width = 0;
    float height = 0;

    //TODO: this will change
    SpriteTexture.GetDimensions(width,height);
    float2 target_uv = vs_out.uv  * float2(1.0 / width , 1.0 / height); //TODO: khal don't hardcode the rcp sprite sheet size 

    float4 tex_color = SpriteTexture.Sample(SpriteSampler, target_uv);
    float3 color_blend = lerp(tex_color.rgb, vs_out.color.rgb, tex_color.a * vs_out.color.a);
    return float4(color_blend, tex_color.a);

}