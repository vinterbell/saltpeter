#include "core.hlsli"

// put in b2
struct SceneData
{
    // camera
    row_major float4x4 view_matrix;
    row_major float4x4 projection_matrix;
    row_major float4x4 view_projection_matrix;

    // lighting
    // sun
    float4 sun_light_direction; // xyz: direction, w: intensity
    float4 sun_light_color;     // rgb: color, a: unused
    // ambient
    float4 ambient_light_color; // rgb: color, a: unused
};

struct RootConstants 
{
    BufferPtr<SceneData> scene_data_ptr;
};

ConstantBuffer<RootConstants> root : register(b0);