#include "core.hlsli"
#include "scene_data.hlsli"

struct FSInput
{
    float4 position : SV_POSITION;
};

static const float3 cube_vertices[8] =
{
    float3(-1.0, -1.0, -1.0),
    float3( 1.0, -1.0, -1.0),
    float3(-1.0,  1.0, -1.0),
    float3( 1.0,  1.0, -1.0),
    float3(-1.0, -1.0,  1.0),
    float3( 1.0, -1.0,  1.0),
    float3(-1.0,  1.0,  1.0),
    float3( 1.0,  1.0,  1.0),
};

static const uint cube_indices[36] =
{
    0, 1, 2, 2, 1, 3,
    1, 5, 3, 3, 5, 7,
    5, 4, 7, 7, 4, 6,
    4, 0, 6, 6, 0, 2,
    2, 3, 6, 6, 3, 7,
    4, 5, 0, 0, 5, 1,
};


FSInput VSMain(uint vertex_id : SV_VertexID)
{
    FSInput output;

    float3 vertex_position = cube_vertices[cube_indices[vertex_id]];

    SceneData scene_data = root.scene_data_ptr.Load(0);

    // remember its row major
    float4x4 rotation = scene_data.view_matrix;
    rotation[3] = float4(0.0, 0.0, 0.0, 1.0); // remove translation

    float4 world_position = float4(vertex_position, 1.0);
    output.position = mul(rotation, world_position);
    output.position = mul(scene_data.projection_matrix, output.position);

    return output;
}

float3 get_sky(const float pitch)
{
    // map pitch from -pi/2..pi/2 to 0..1
    const float t = (pitch + 1.57079633) / 3.14159265;
    return lerp(float3(0.7, 0.9, 1.0), float3(0.3, 0.6, 0.9), saturate(t));
}

float4 FSMain(FSInput input) : SV_TARGET
{
    const float dy = input.position.y;
    const float dx = length(input.position.xz);
    const float pitch = atan2(dy, dx); // -pi/2 to pi/2
    return float4(get_sky(pitch), 1.0);
}