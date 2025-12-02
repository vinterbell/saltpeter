pub const BlitConstants = extern struct {
    texture_index: gpu.Descriptor.Index,
    sampler_index: gpu.Descriptor.Index,
    rect: [4]f32 = .{
        -1.0, 1.0,
        1.0,  -1.0,
    },
};

const gpu = @import("../gpu/root.zig");
