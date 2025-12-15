#include "core.hlsli"
#include "scene_data.hlsli"

struct FSInput
{
    float4 sv_position : SV_POSITION;
    float3 position    : TEXCOORD0;
};

static const float3 cube_vertices[8] =
{
    float3(1.0 , -1.0, -1.0),
    float3(1.0 , -1.0, 1.0),
    float3(-1.0 , -1.0, 1.0),
    float3(-1.0 , -1.0, -1.0),
    float3(1.0 , 1.0, -1.0),
    float3(1.0 , 1.0, 1.0),
    float3(-1.0 , 1.0, 1.0),
    float3(-1.0 , 1.0, -1.0),
};

static const uint cube_indices[36] =
{
    0, 1, 2, 2, 3, 0,
    4, 7, 6, 6, 5, 4,
    0, 4, 5, 5, 1, 0,
    1, 5, 6, 6, 2, 1,
    2, 6, 7, 7, 3, 2,
    3, 7, 4, 4, 0, 3
};

FSInput VSMain(uint vertex_id : SV_VertexID)
{
    FSInput output;

    float3 vertex_position = cube_vertices[cube_indices[vertex_id]];
    output.position = vertex_position;

    SceneData scene_data = root.scene_data_ptr.Load(0);

    float4x4 rotation = scene_data.view_matrix;
    // float4x4 rotation = float4x4(
    //     float4(1.0, 0.0, 0.0, 0.0),
    //     float4(0.0, 1.0, 0.0, 0.0),
    //     float4(0.0, 0.0, 1.0, 0.0),
    //     float4(0.0, 0.0, 0.0, 1.0)
    // );
    rotation[3] = float4(0.0, 0.0, 0.0, 1.0); // remove translation

    const float4x4 temp_projection_matrix = float4x4(
        float4(1.5829, 0.0, 0.0, 0.0),
        float4(0.0, 2.11053, 0.0, 0.0),
        float4(0.0, 0.0, 1.0001, 1.0),
        float4(0.0, 0.0, -0.10001, 0.0)
    );

    float4 world_position = float4(vertex_position, 1.0);
    output.sv_position = mul(world_position, rotation);
    output.sv_position = mul(output.sv_position, scene_data.projection_matrix);
    // output.sv_position = mul(output.sv_position, temp_projection_matrix);

    return output;
}

template <typename T>
T map_range(T value, T in_min, T in_max, T out_min, T out_max)
{
    return out_min + (out_max - out_min) * ((value - in_min) / (in_max - in_min));
}

float3 get_sky(const float pitch)
{
    // 0 to 1 
    float pitchMapped = smoothstep(0.0, 1.0, map_range<float>(pitch, -1.0/4.0, 1.0/4.0, 0.0, 1.0));
    return lerp(float3(0.7, 0.9, 1.0), float3(0.2, 0.5, 0.8), clamp(pitchMapped, 0.0, 1.0));
}

float4 FSMain(FSInput input) : SV_TARGET
{
    const float dy = input.position.y;
    const float dx = length(input.position.xz);
    const float pitch = atan2(dy, dx); // -pi/2 to pi/2
    // return float4(get_sky(pitch), 1.0);
    return float4(get_sky(pitch / (0.5 * PI)), 1.0);
    // return float4(input.position * 0.5 + 0.5, 1.0);
}