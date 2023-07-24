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
    float2 viewportSize;
    float time;
    float delta_time;
};

struct VSIn{
    float2 quadid : QUAD_ID;
    matrix transform : TRANSFORM;
    float4 src_rect : SRC_RECT;
    float color : HUE_DISP;
    float depth : Z_DEPTH;
    uint spriteid : SV_INSTANCEID;
    uint vertexid : SV_VERTEXID;
};

struct VsOut{
    float color : COL;
    float4 position : SV_POSITION;
    float2 uv : UV;
};

Texture2D<float4> SpriteTexture : register(t0);
SamplerState SpriteSampler : register (s0);

VsOut vs_main(in VSIn vs_in)
{
    VsOut vso;
    
    float4 scaled_quad = float4(vs_in.quadid * vs_in.src_rect.zw, 0.0, 1.0);

    
    float2 device_conversion = float2(4.0, -4.0) / viewportSize;
    float2 position = mul(scaled_quad, vs_in.transform).xy * device_conversion - float2(1.0, -1.0);

    vso.position = float4(position.x, position.y, 0.0f,1.0f);
    vso.uv = scaled_quad.xy + vs_in.src_rect.xy;
    vso.color = vs_in.color;

    return vso;
}

float4 ps_main(in VsOut vs_out) : SV_TARGET{
    float width = 0;
    float height = 0;

    SpriteTexture.GetDimensions(width,height);

    float2 target_uv = vs_out.uv  * float2(1.0 / width, 1.0 / height); //TODO: khal don't hardcode the rcp sprite sheet size 
    float4 color = SpriteTexture.Sample(SpriteSampler, target_uv);
    return color;

}