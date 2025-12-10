// this is set to slot 1
cbuffer BlitConstants : register(b1)
{
    uint texture_index;
    uint sampler_index;
    float top_left_x;
    float top_left_y;
    float bottom_right_x;
    float bottom_right_y;
    uint mip_level;
    float array_layer_or_depth;
};

struct FSInput
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
};

FSInput VSMain(uint vertexID : SV_VertexID)
{
    float2 top_left = float2(top_left_x, top_left_y);
    float2 top_right = float2(bottom_right_x, top_left_y);
    float2 bottom_left = float2(top_left_x, bottom_right_y);
    float2 bottom_right = float2(bottom_right_x, bottom_right_y);
    
    float4 positions[6] = {
        float4(top_left.x, top_left.y, 0.0f, 1.0f),
        float4(bottom_right.x, bottom_right.y, 0.0f, 1.0f),
        float4(bottom_left.x, bottom_left.y, 0.0f, 1.0f),
        float4(top_left.x, top_left.y, 0.0f, 1.0f),
        float4(top_right.x, top_right.y, 0.0f, 1.0f),
        float4(bottom_right.x, bottom_right.y, 0.0f, 1.0f),
    };

    float2 uvs[6] = {
        float2(0.0f, 0.0f),
        float2(1.0f, 1.0f),
        float2(0.0f, 1.0f),
        float2(0.0f, 0.0f),
        float2(1.0f, 0.0f),
        float2(1.0f, 1.0f),
    };

    FSInput output;
    output.position = positions[vertexID];
    output.uv = uvs[vertexID];

    return output;
}

// BLIT_FROM_2D_TEXTURE
// BLIT_FROM_2D_TEXTURE_ARRAY
// BLIT_FROM_3D_TEXTURE
// BLIT_FROM_CUBE_TEXTURE
// BLIT_FROM_CUBE_TEXTURE_ARRAY

float4 FSMain(FSInput input) : SV_TARGET
{
#if ZOOG == 2
    return float4(1.0f, 0.0f, 1.0f, 1.0f); // magenta for ZOOG2
#endif
    SamplerState s = SamplerDescriptorHeap[sampler_index];
#ifdef BLIT_FROM_2D_TEXTURE
    Texture2D tex = ResourceDescriptorHeap[texture_index];
    return tex.Sample(s, input.uv, mip_level);
#elif defined(BLIT_FROM_2D_TEXTURE_ARRAY)
    Texture2DArray tex = ResourceDescriptorHeap[texture_index];
    return tex.SampleLevel(s, float3(input.uv, (uint)array_layer_or_depth), mip_level);
#elif defined(BLIT_FROM_3D_TEXTURE)
    Texture3D tex = ResourceDescriptorHeap[texture_index];
    return tex.SampleLevel(s, float3(input.uv, array_layer_or_depth), mip_level);
#elif defined(BLIT_FROM_CUBE_TEXTURE)
    TextureCube tex = ResourceDescriptorHeap[texture_index];
    float2 uv_mapped = input.uv * 2.0f - 1.0f;
    float3 coord;
    switch ((uint)array_layer_or_depth) {
        case 0: // +X
            coord = float3(1.0f, -uv_mapped.y, -uv_mapped.x);
        case 1: // -X
            coord = float3(-1.0f, -uv_mapped.y, uv_mapped.x);
        case 2: // +Y
            coord = float3(uv_mapped.x, 1.0f, uv_mapped.y);
        case 3: // -Y
            coord = float3(uv_mapped.x, -1.0f, -uv_mapped.y);
        case 4: // +Z
            coord = float3(uv_mapped.x, -uv_mapped.y, 1.0f);
        case 5: // -Z
            coord = float3(-uv_mapped.x, -uv_mapped.y, -1.0f);
        default:
            return float4(1.0f, 0.0f, 1.0f, 1.0f); // magenta for invalid layer
    }
    return tex.SampleLevel(s, coord, mip_level);
#elif defined(BLIT_FROM_CUBE_TEXTURE_ARRAY)
    TextureCubeArray tex = ResourceDescriptorHeap[texture_index];
    float2 uv_mapped = input.uv * 2.0f - 1.0f;
    float3 coord;
    uint array_index = (uint)array_layer_or_depth / 6;
    uint face_index = (uint)array_layer_or_depth % 6;
    switch (face_index) {
        case 0: // +X
            coord = float3(1.0f, -uv_mapped.y, -uv_mapped.x);
        case 1: // -X
            coord = float3(-1.0f, -uv_mapped.y, uv_mapped.x);
        case 2: // +Y
            coord = float3(uv_mapped.x, 1.0f, uv_mapped.y);
        case 3: // -Y
            coord = float3(uv_mapped.x, -1.0f, -uv_mapped.y);
        case 4: // +Z
            coord = float3(uv_mapped.x, -uv_mapped.y, 1.0f);
        case 5: // -Z
            coord = float3(-uv_mapped.x, -uv_mapped.y, -1.0f);
        default:
            return float4(1.0f, 0.0f, 1.0f, 1.0f); // magenta for invalid layer
    }
    return tex.SampleLevel(s, float4(coord, array_index), mip_level);
#else
    return float4(1.0f, 0.0f, 1.0f, 1.0f); // magenta for unimplemented
#endif
}