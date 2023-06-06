cbuffer VS_CONSTANT_BUFFER : register(b0){
    float2 window_size;
};

struct VSIn{
    float2 pos : POSITION;
    float2 uv : UV;
    uint spriteid : SV_INSTANCEID;
    uint vertexid : SV_VERTEXID;
};

struct VsOut{
    float4 pos : SV_POSITION;
    float2 uv : UV;
};

Texture2D<float4>       atlastexture        :       register(t0);

SamplerState        pointsampler        :       register (s0);

VsOut vs_main(VSIn vs_in)
{
    VsOut vso;

    float2 position = vs_in.pos * window_size * 4 - float2(1.0, -1.0);
    vso.pos = float4(position.x, position.y, 0.0f,1.0f);
    vso.uv = vs_in.uv;

    return vso;
}

float4 ps_main(VsOut vs_out) : SV_TARGET{

    float2 target_uv = vs_out.uv * float2(1.0 / 663, 1.0 / 400);
    float4 color = atlastexture.Sample(pointsampler, target_uv);
    if (color.a == 0) discard;
    return color;

}