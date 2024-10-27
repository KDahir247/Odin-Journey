cbuffer Param : register(b0){
     float4x4 projection_matrix; 
     float4x4 view_matrix;
};

void vs_main(
    inout float4 color    : COLOR0,
    inout float2 texCoord : TEXCOORD0,
    inout float4 position : SV_Position){

        position = mul(view_matrix, position);
        position = mul(projection_matrix,position);
    }

Texture2D<float4> SpriteTexture : register(t0);
SamplerState SpriteSampler : register (s0);

float4 ps_main(
    float4 color         : COLOR0,
    float2 texture_coord : TEXCOORD0) : SV_TARGET{
        
        float4 tex_color = SpriteTexture.Sample(SpriteSampler, texture_coord);
        float3 color_blend = lerp(tex_color.rgb, color.rgb, tex_color.aaa);
        
        return float4(color_blend.rgb, tex_color.a * color.a);
    }
