pub fn BufferPtr(comptime T: type) type {
    return extern struct {
        const _ = T;
        buffer: gpu.Descriptor.Index,
        offset: u32,
    };
}

pub const FullscreenBlit = extern struct {
    texture_index: gpu.Descriptor.Index,
    sampler_index: gpu.Descriptor.Index,
    mip_level: u32 = 0,
    array_layer_or_depth: f32 = 0.0,
};

// in a normal render (3d):
// b0 (32 bytes so 8 f32, or 4 buffer ptrs)
//  - scene constants (1 buffer ptr)
// b1
//  - per-object constants (as big as needed)
// b2
//  - material data (as big as needed)

pub const SceneConstants = extern struct {
    view_matrix: Mat,
    projection_matrix: Mat,
    view_projection_matrix: Mat,

    sun_light_direction: Vec, // xyz: direction, w: intensity
    sun_light_color: Vec, // rgb: color, a: unused
    ambient_light_color: Vec, // rgb: color, a: unused
};

pub const RootConstants = extern struct {
    scene_constants: BufferPtr(SceneConstants),
};

pub const Mat = [16]f32; // 4x4 matrix stored in column-major order
pub const Vec = [4]f32; // 4D vector

const std = @import("std");
const gpu = @import("../gpu/root.zig");
const linalg = @import("../math/linalg.zig");
