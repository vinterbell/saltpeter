pub const backbuffer_count = 3;
pub const max_root_constant_size_bytes = 32;
pub const max_resource_descriptor_count = 65536;
pub const max_sampler_descriptor_count = 128;

pub const Options = struct {
    backend: Backend = .default,
    power_preference: enum {
        high_performance,
        low_power,
    } = .high_performance,
    validation: bool = switch (builtin.mode) {
        .Debug => true,
        else => false,
    },
};

pub fn init(allocator: std.mem.Allocator, options: Options) !Interface {
    switch (options.backend) {
        .d3d12 => {
            if (builtin.os.tag != .windows) {
                return error.Unknown;
            }
            const D3D12Device = @import("d3d12.zig").Device;
            const device = try allocator.create(D3D12Device);
            errdefer allocator.destroy(device);
            try device.init(allocator, options);
            return device.interface();
        },
        else => @panic("Unsupported backend"),
    }
}

pub const Interface = @import("Interface.zig");

pub const Error = error{
    Unknown,
    OutOfMemory,
    Gpu,
    InvalidOperation,
    /// when setting a resource name
    InvalidUtf8,
};

pub const Buffer = opaque {
    pub const GpuAddress = enum(u64) {
        null = 0,
        _,

        pub fn toInt(self: GpuAddress) u64 {
            return @intFromEnum(self);
        }
    };

    pub const Desc = struct {
        shader_write: bool,
        size: usize,
        location: MemoryLocation,

        pub fn readonlyBuffer(size: usize, location: MemoryLocation) Desc {
            return .{
                .shader_write = false,
                .size = size,
                .location = location,
            };
        }

        pub fn readWriteBuffer(size: usize, location: MemoryLocation) Desc {
            return .{
                .shader_write = true,
                .size = size,
                .location = location,
            };
        }
    };

    pub const Location = struct {
        buffer: *Buffer,
        offset: usize,

        pub fn start(buffer: *Buffer) Location {
            return .{
                .buffer = buffer,
                .offset = 0,
            };
        }
    };

    pub const Slice = struct {
        buffer: *Buffer,
        offset: usize,
        size: Size,

        pub fn sub(buffer: *Buffer, offset: usize, size: Size) Slice {
            return .{
                .buffer = buffer,
                .offset = offset,
                .size = size,
            };
        }

        pub fn whole(buffer: *Buffer) Slice {
            return .{
                .buffer = buffer,
                .offset = 0,
                .size = .whole,
            };
        }

        pub fn location(self: Slice, offset: usize) Location {
            return .{
                .buffer = self.buffer,
                .offset = self.offset + offset,
            };
        }

        pub fn offsetted(self: Slice, additional_offset: usize) Slice {
            return .{
                .buffer = self.buffer,
                .offset = self.offset + additional_offset,
                .size = switch (self.size) {
                    .whole => .whole,
                    else => |s| .fromInt(s.toInt().? - additional_offset),
                },
            };
        }
    };
};

pub const CommandList = opaque {};

pub const Fence = opaque {};

pub const Descriptor = opaque {
    pub const Kind = enum {
        shader_read_texture_2d,
        shader_read_texture_2d_array,
        shader_read_texture_cube,
        shader_read_texture_3d,
        shader_read_buffer,
        shader_read_top_level_acceleration_structure,

        shader_write_texture_2d,
        shader_write_texture_2d_array,
        shader_write_texture_3d,
        shader_write_buffer,

        constant_buffer,

        sampler,
    };

    pub const Filter = enum(u32) {
        nearest,
        linear,
        anisotropic,
    };

    pub const FilterExt = enum(u32) {
        none,
        min,
        max,
    };

    pub const MipmapMode = enum(u32) {
        nearest,
        linear,
    };

    pub const AddressMode = enum(u32) {
        repeat,
        mirror_repeat,
        clamp_to_edge,
    };

    pub const AddressModes = struct {
        u: AddressMode = .repeat,
        v: AddressMode = .repeat,
        w: AddressMode = .repeat,
    };

    pub const Filters = struct {
        min: Filter = .nearest,
        mag: Filter = .nearest,
        mip: Filter = .nearest,
        ext: FilterExt = .none,
    };

    pub const SamplerDesc = struct {
        filters: Filters = .{},
        anisotropy: u32 = 1,
        mip_bias: f32 = 0.0,
        mip_min: f32 = 0.0,
        mip_max: f32 = 0.0,
        address_modes: AddressModes = .{},
        compare_op: Pipeline.CompareOp = .never,
        border_color: [4]f32 = @splat(0.0),
    };

    pub const Desc = struct {
        kind: Kind,
        format: Format,

        resource: union(enum) {
            buffer: Buffer.Slice,
            texture: Texture.Slice,
            tlas: void, // currently unimplemented
            sampler: SamplerDesc,
        },

        pub fn readTexture2D(slice: Texture.Slice, format: Format) Desc {
            return .{
                .kind = .shader_read_texture_2d,
                .format = format,
                .resource = .{ .texture = slice },
            };
        }

        pub fn readTexture2DArray(slice: Texture.Slice, format: Format) Desc {
            return .{
                .kind = .shader_read_texture_2d_array,
                .format = format,
                .resource = .{ .texture = slice },
            };
        }

        pub fn readTextureCube(slice: Texture.Slice, format: Format) Desc {
            return .{
                .kind = .shader_read_texture_cube,
                .format = format,
                .resource = .{ .texture = slice },
            };
        }

        pub fn readTexture3D(slice: Texture.Slice, format: Format) Desc {
            return .{
                .kind = .shader_read_texture_3d,
                .format = format,
                .resource = .{ .texture = slice },
            };
        }

        pub fn readBuffer(region: Buffer.Slice) Desc {
            return .{
                .kind = .shader_read_buffer,
                .format = .unknown,
                .resource = .{ .buffer = region },
            };
        }

        // pub fn readTopLevelAccelerationStructure() Desc {
        //     return .{
        //         .kind = .shader_read_top_level_acceleration_structure,
        //         .format = .unknown,
        //         .resource = .{ .tlas = {} },
        //     };
        // }

        pub fn writeTexture2D(slice: Texture.Slice, format: Format) Desc {
            return .{
                .kind = .shader_write_texture_2d,
                .format = format,
                .resource = .{ .texture = slice },
            };
        }

        pub fn writeTexture2DArray(slice: Texture.Slice, format: Format) Desc {
            return .{
                .kind = .shader_write_texture_2d_array,
                .format = format,
                .resource = .{ .texture = slice },
            };
        }

        pub fn writeTexture3D(slice: Texture.Slice, format: Format) Desc {
            return .{
                .kind = .shader_write_texture_3d,
                .format = format,
                .resource = .{ .texture = slice },
            };
        }

        pub fn writeBuffer(region: Buffer.Region) Desc {
            return .{
                .kind = .shader_write_buffer,
                .format = .unknown,
                .resource = .{ .buffer = region },
            };
        }

        pub fn constantBuffer(region: Buffer.Region) Desc {
            return .{
                .kind = .constant_buffer,
                .format = .unknown,
                .resource = .{ .buffer = region },
            };
        }

        pub fn sampler(desc: SamplerDesc) Desc {
            return .{
                .kind = .sampler,
                .format = .unknown,
                .resource = .{ .sampler = desc },
            };
        }
    };

    /// a handle which can be passed into a shader (through a constant or buffer) to access a resource; api specific
    /// for example, ResourceDescriptorHeap/SamplerDescriptorHeap in d3d12
    /// global descriptor set (tbd which slots) in vulkan
    /// a big metal arg buffer
    pub const Index = enum(u32) {
        invalid = std.math.maxInt(u32),
        _,

        pub fn toInt(self: Index) u32 {
            return @intFromEnum(self);
        }
    };
};

pub const Pipeline = opaque {
    pub const Kind = enum(u32) {
        graphics,
        compute,
    };

    pub const Primitive = enum(u32) {
        triangle_list,
        triangle_strip,
        line_list,
        line_strip,
        point_list,
    };

    pub const FillMode = enum(u32) {
        solid,
        wireframe,
    };

    pub const CullMode = enum(u32) {
        none,
        front,
        back,
    };

    pub const FrontFace = enum(u32) {
        counter_clockwise,
        clockwise,
    };

    pub const CompareOp = enum(u32) {
        never,
        less,
        equal,
        less_or_equal,
        greater,
        not_equal,
        greater_or_equal,
        always,
    };

    pub const StencilOp = enum(u32) {
        keep,
        zero,
        replace,
        increment_and_clamp,
        decrement_and_clamp,
        invert,
        increment_and_wrap,
        decrement_and_wrap,
    };

    pub const BlendOp = enum(u32) {
        add,
        subtract,
        reverse_subtract,
        min,
        max,
    };

    pub const BlendFactor = enum(u32) {
        zero,
        one,
        src_color,
        inv_src_color,
        dst_color,
        inv_dst_color,
        src_alpha,
        inv_src_alpha,
        dst_alpha,
        inv_dst_alpha,
        constant_color,
        inv_constant_color,
        src_alpha_saturated,
    };

    pub const StencilState = struct {
        fail: StencilOp = .keep,
        pass: StencilOp = .keep,
        depth_fail: StencilOp = .keep,
        compare: CompareOp = .always,

        pub fn stencil(fail: StencilOp, pass: StencilOp, depth_fail: StencilOp, compare: CompareOp) StencilState {
            return .{
                .fail = fail,
                .pass = pass,
                .depth_fail = depth_fail,
                .compare = compare,
            };
        }
    };

    pub const ColorAttachmentBlendState = struct {
        pub const ChannelBlend = struct {
            src: BlendFactor = .one,
            dst: BlendFactor = .zero,
            op: BlendOp = .add,

            pub fn channelBlend(src: BlendFactor, dst: BlendFactor, op: BlendOp) ChannelBlend {
                return .{
                    .src = src,
                    .dst = dst,
                    .op = op,
                };
            }
        };

        pub const Mask = packed struct {
            r: bool = false,
            g: bool = false,
            b: bool = false,
            a: bool = false,

            pub const all: Mask = .{ .r = true, .g = true, .b = true, .a = true };
            pub const rgb: Mask = .{ .r = true, .g = true, .b = true, .a = false };
        };

        color: ChannelBlend = .{},
        alpha: ChannelBlend = .{},
        mask: Mask = .all,

        pub fn colorAlphaBlend(
            color: ChannelBlend,
            alpha: ChannelBlend,
            mask: Mask,
        ) ColorAttachmentBlendState {
            return .{
                .color = color,
                .alpha = alpha,
                .mask = mask,
            };
        }
    };

    pub const RasterizationState = struct {
        const DepthBias = struct {
            constant_factor: f32,
            clamp: f32,
            slope_factor: f32,

            pub const default: DepthBias = .{
                .constant_factor = 0.0,
                .clamp = 0.0,
                .slope_factor = 1.0,
            };
        };

        fill_mode: FillMode,
        cull_mode: CullMode,
        front_face: FrontFace,
        depth_bias: ?DepthBias,
        enable_depth_clipping: bool,

        pub const default: RasterizationState = .{
            .fill_mode = .solid,
            .cull_mode = .none,
            .front_face = .clockwise,
            .depth_bias = null,
            .enable_depth_clipping = false,
        };
    };

    pub const MultisampleState = struct {
        sample_count: Texture.SampleCount,
        sample_mask: ?u32,
        enable_alpha_to_coverage: bool,

        pub const default: MultisampleState = .{
            .sample_count = .x1,
            .sample_mask = null,
            .enable_alpha_to_coverage = false,
        };
    };

    pub const DepthStencilState = struct {
        pub const DepthTest = struct {
            op: CompareOp = .less,

            pub fn depthTest(op: CompareOp) DepthTest {
                return .{ .op = op };
            }
        };

        pub const StencilTest = struct {
            back: StencilState = .{},
            front: StencilState = .{},
            compare_mask: u8 = 0xFF,
            write_mask: u8 = 0xFF,

            pub fn stencilTest(front: StencilState, back: StencilState, compare_mask: u8, write_mask: u8) StencilTest {
                return .{
                    .front = front,
                    .back = back,
                    .compare_mask = compare_mask,
                    .write_mask = write_mask,
                };
            }
        };

        depth_test: ?DepthTest = null,
        stencil_test: ?StencilTest = null,
        depth_write: bool = true,

        pub const no_depth_stencil: DepthStencilState = .{
            .depth_test = null,
            .stencil_test = null,
            .depth_write = false,
        };

        pub fn withDepth(
            depth_test: DepthTest,
            depth_write: enum { write_depth, no_write_depth },
        ) DepthStencilState {
            return .{
                .depth_test = depth_test,
                .stencil_test = null,
                .depth_write = depth_write == .write_depth,
            };
        }

        pub fn withDepthStencil(
            depth_test: DepthTest,
            stencil_test: StencilTest,
            depth_write: enum { write_depth, no_write_depth },
        ) DepthStencilState {
            return .{
                .depth_test = depth_test,
                .stencil_test = stencil_test,
                .depth_write = depth_write == .write_depth,
            };
        }
    };

    pub const ColorAttachmentState = struct {
        format: Format,
        blend: ?ColorAttachmentBlendState,

        pub fn noBlend(format: Format) ColorAttachmentState {
            return .{
                .format = format,
                .blend = null,
            };
        }

        pub fn withBlend(format: Format, blend: ColorAttachmentBlendState) ColorAttachmentState {
            return .{
                .format = format,
                .blend = blend,
            };
        }
    };

    pub const TargetState = struct {
        color_attachments: [8]ColorAttachmentState,
        depth_stencil_format: ?Format,

        pub fn targets(
            color_attachments: []const ColorAttachmentState,
            depth_stencil_format: ?Format,
        ) TargetState {
            var target_state = TargetState{
                .color_attachments = @splat(.noBlend(.unknown)),
                .depth_stencil_format = depth_stencil_format,
            };
            const len = @min(color_attachments.len, target_state.color_attachments.len);
            for (
                color_attachments[0..len],
                target_state.color_attachments[0..len],
            ) |attachment, *out| {
                out.* = attachment;
            }
            return target_state;
        }
    };

    pub const GraphicsDesc = struct {
        vs: []const u8,
        fs: []const u8,
        rasterization: RasterizationState,
        multisample: MultisampleState,
        depth_stencil: DepthStencilState,
        target_state: TargetState,
        primitive_topology: Primitive,
    };

    pub const ComputeDesc = struct {
        cs: []const u8,
    };
};

pub const RenderPass = struct {
    pub const Desc = struct {
        color_attachments: []const ColorAttachment,
        depth_stencil_attachment: ?DepthStencilAttachment = null,

        pub fn colorOnly(
            color_attachments: []const ColorAttachment,
        ) Desc {
            return .{
                .color_attachments = color_attachments,
                .depth_stencil_attachment = null,
            };
        }

        pub fn withDepthStencil(
            color_attachments: []const ColorAttachment,
            depth_stencil_attachment: DepthStencilAttachment,
        ) Desc {
            return .{
                .color_attachments = color_attachments,
                .depth_stencil_attachment = depth_stencil_attachment,
            };
        }
    };

    pub const ColorAttachment = struct {
        texture: Texture.Slice,
        load: LoadColor,
        store: Store,

        pub fn color(texture: Texture.Slice, load: LoadColor, store: Store) ColorAttachment {
            return .{
                .texture = texture,
                .load = load,
                .store = store,
            };
        }
    };

    pub const DepthStencilAttachment = struct {
        texture: Texture.Slice,
        depth_load: LoadDepth,
        depth_store: Store,
        stencil_load: LoadStencil,
        stencil_store: Store,

        pub fn depthStencil(
            texture: Texture.Slice,
            depth_load: LoadDepth,
            depth_store: Store,
            stencil_load: LoadStencil,
            stencil_store: Store,
        ) DepthStencilAttachment {
            return .{
                .texture = texture,
                .depth_load = depth_load,
                .depth_store = depth_store,
                .stencil_load = stencil_load,
                .stencil_store = stencil_store,
            };
        }
    };

    pub const LoadColor = union(enum) {
        load,
        clear: [4]f32,
        discard,

        pub fn loadClear(color: [4]f32) LoadColor {
            return .{ .clear = color };
        }
    };

    pub const LoadDepth = union(enum) {
        load,
        clear: f32,
        discard,

        pub fn loadClear(depth: f32) LoadDepth {
            return .{ .clear = depth };
        }
    };

    pub const LoadStencil = union(enum) {
        load,
        clear: u8,
        discard,

        pub fn loadClear(stencil: u8) LoadStencil {
            return .{ .clear = stencil };
        }
    };

    pub const Store = enum {
        store,
        discard,
    };
};

pub const Swapchain = opaque {
    pub const Backbuffer = struct {
        texture: *Texture,
        width: u32,
        height: u32,
    };

    pub const Desc = struct {
        window_handle: *const platform.Window,
        present_mode: PresentMode,
        composition: Composition,

        pub fn default(window_handle: *const platform.Window) Desc {
            return .{
                .window_handle = window_handle,
                .present_mode = .vsync,
                .composition = .sdr,
            };
        }

        pub fn withPresentMode(
            window_handle: *const platform.Window,
            present_mode: PresentMode,
        ) Desc {
            return .{
                .window_handle = window_handle,
                .present_mode = present_mode,
                .composition = .sdr,
            };
        }
    };

    pub const PresentMode = enum(u32) {
        immediate,
        vsync,
    };

    pub const Composition = enum(u32) {
        sdr,
        /// B8G8R8A8_SRGB or R8G8B8A8_SRGB swapchain, so textures stored in sRGB space but linear when sampled
        sdr_linear,
        /// R16G16B16A16_FLOAT, permits outside of 0, 1 range
        hdr_extended_linear,
        /// A2R10G10B10 or A2B10G10R10, pixels are BT.2020 ST2084 (PQ) encoding
        hdr10_st2084,
    };
};

pub const Texture = opaque {
    pub const Usage = struct {
        render_target: bool,
        depth_stencil: bool,
        shader_write: bool,

        pub const read_only: Usage = .{
            .render_target = false,
            .depth_stencil = false,
            .shader_write = false,
        };

        pub const read_write: Usage = .{
            .render_target = false,
            .depth_stencil = false,
            .shader_write = true,
        };

        pub const read_only_render_target: Usage = .{
            .render_target = true,
            .depth_stencil = false,
            .shader_write = false,
        };

        pub const read_write_render_target: Usage = .{
            .render_target = true,
            .depth_stencil = false,
            .shader_write = true,
        };

        pub const read_only_depth_stencil: Usage = .{
            .render_target = false,
            .depth_stencil = true,
            .shader_write = false,
        };

        pub const read_write_depth_stencil: Usage = .{
            .render_target = false,
            .depth_stencil = true,
            .shader_write = true,
        };
    };

    pub const Dimension = enum(u32) {
        @"2d",
        @"3d",
        cube,
    };

    pub const SampleCount = enum(u32) {
        x1,
        x2,
        x4,
        x8,

        pub fn fromInt(value: u32) SampleCount {
            return switch (value) {
                1 => .x1,
                2 => .x2,
                4 => .x4,
                8 => .x8,
                else => @panic("Invalid sample count"),
            };
        }

        pub fn toInt(self: SampleCount) u32 {
            return switch (self) {
                .x1 => 1,
                .x2 => 2,
                .x4 => 4,
                .x8 => 8,
            };
        }
    };

    pub const Desc = struct {
        dimension: Dimension = .@"2d",
        format: Format = .unknown,
        usage: Usage = .read_only,
        width: u32 = 1,
        height: u32 = 1,
        depth_or_array_layers: u32 = 1,
        mip_levels: u32 = 1,
        sample_count: SampleCount = .x1,
        location: MemoryLocation = .gpu_only,

        pub fn calcSubresource(
            self: *const Desc,
            mip_level: u32,
            array_layer: u32,
        ) u32 {
            return mip_level + array_layer * self.mip_levels;
        }

        pub fn decomposeSubresource(
            self: *const Desc,
            subresource: u32,
        ) struct {
            mip_level: u32,
            array_layer: u32,
        } {
            const mip_level = subresource % self.mip_levels;
            const array_layer = subresource / self.mip_levels;
            return .{ .mip_level = mip_level, .array_layer = array_layer };
        }
    };

    pub const Slice = struct {
        texture: *Texture,
        mip_level: u32,
        depth_or_array_layer: u32,
        mip_level_count: u32,
        depth_or_array_layer_count: u32,
        plane: u32,

        pub fn first(texture: *Texture) Slice {
            return .{
                .texture = texture,
                .mip_level = 0,
                .depth_or_array_layer = 0,
                .mip_level_count = 1,
                .depth_or_array_layer_count = 1,
                .plane = 0,
            };
        }

        pub fn mipAndDepthOrLayer(
            texture: *Texture,
            mip_level: u32,
            depth_or_array_layer: u32,
        ) Slice {
            return .{
                .texture = texture,
                .mip_level = mip_level,
                .depth_or_array_layer = depth_or_array_layer,
                .mip_level_count = 1,
                .depth_or_array_layer_count = 1,
                .plane = 0,
            };
        }

        pub fn sizedMipAndDepthOrLayersWithPlane(
            texture: *Texture,
            mip_level: u32,
            mip_level_count: u32,
            depth_or_array_layer: u32,
            depth_or_array_layer_count: u32,
            plane: u32,
        ) Slice {
            return .{
                .texture = texture,
                .mip_level = mip_level,
                .depth_or_array_layer = depth_or_array_layer,
                .mip_level_count = mip_level_count,
                .depth_or_array_layer_count = depth_or_array_layer_count,
                .plane = plane,
            };
        }
    };

    /// a location within a gpu texture
    pub const Location = struct {
        texture: *Texture,
        mip_level: u32,
        layer: u32,
        x: u32,
        y: u32,
        z: u32,
    };

    pub const Region = struct {
        texture: *Texture,
        mip_level: u32,
        layer: u32,
        x: u32,
        y: u32,
        z: u32,
        width: Size,
        height: Size,
        depth: Size,
    };
};

pub const Backend = enum {
    d3d12,
    vulkan,
    metal,
    mock,

    pub const default: Backend = switch (builtin.os.tag) {
        .windows => .d3d12,
        else => @compileError("Unsupported platform"),
    };
};

pub const Vendor = enum {
    unknown,
    amd,
    intel,
    nvidia,
    apple,
};

pub const MemoryLocation = enum(u32) {
    gpu_only,
    /// staging
    cpu_only,
    cpu_to_gpu,
    gpu_to_cpu,
};

pub const Queue = enum(u32) {
    graphics,
    compute,
    copy,
};

pub const Access = packed struct(u32) {
    common: bool = false,
    vertex_and_constant_buffer: bool = false,
    index_buffer: bool = false,
    render_target: bool = false,
    shader_write: bool = false,
    depth_stencil_write: bool = false,
    depth_stencil_read: bool = false,
    non_pixel_shader_resource: bool = false,
    pixel_shader_resource: bool = false,
    indirect_argument: bool = false,
    copy_dest: bool = false,
    copy_source: bool = false,
    present: bool = false,
    _: u19 = 0,

    pub const read: Access = .{
        .vertex_and_constant_buffer = true,
        .index_buffer = true,
        .non_pixel_shader_resource = true,
        .pixel_shader_resource = true,
        .indirect_argument = true,
        .copy_source = true,
    };

    pub fn isRead(self: Access) bool {
        return self.vertex_and_constant_buffer or
            self.index_buffer or
            self.non_pixel_shader_resource or
            self.pixel_shader_resource or
            self.indirect_argument or
            self.copy_source;
    }

    pub const all_shader_resource: Access = .{
        .non_pixel_shader_resource = true,
        .pixel_shader_resource = true,
    };

    pub fn isShaderResource(self: Access) bool {
        return self.non_pixel_shader_resource or self.pixel_shader_resource;
    }
};

pub const Size = enum(usize) {
    whole = std.math.maxInt(usize),
    _,

    pub fn fromInt(s: usize) Size {
        return @enumFromInt(s);
    }

    pub fn toInt(self: Size) ?usize {
        if (self == .whole) return null;
        return @intFromEnum(self);
    }
};

pub const BindPoint = enum(u32) {
    vertex,
    fragment,
    compute,

    pub fn toInt(self: BindPoint) u32 {
        return @intFromEnum(self);
    }
};

pub const ConstantSlot = enum(u8) {
    /// max size is 32 bytes
    root,
    buffer1,
    buffer2,
};

pub const IndexFormat = enum(u32) {
    uint16,
    uint32,
};

pub const Format = enum(u32) {
    unknown,

    rgba32f,
    rgba32ui,
    rgba32si,
    rgba16f,
    rgba16ui,
    rgba16si,
    rgba16unorm,
    rgba16snorm,
    rgba8ui,
    rgba8si,
    rgba8unorm,
    rgba8snorm,
    rgba8srgb,
    bgra8unorm,
    bgra8srgb,
    rgb10a2ui,
    rgb10a2unorm,

    rgb32f,
    rgb32ui,
    rgb32si,
    r11g11b10f,
    rgb9e5,

    rg32f,
    rg32ui,
    rg32si,
    rg16f,
    rg16ui,
    rg16si,
    rg16unorm,
    rg16snorm,
    rg8ui,
    rg8si,
    rg8unorm,
    rg8snorm,

    r32f,
    r32ui,
    r32si,
    r16f,
    r16ui,
    r16si,
    r16unorm,
    r16snorm,
    r8ui,
    r8si,
    r8unorm,
    r8snorm,

    d32f,
    d32fs8,
    d16,

    bc1unorm,
    bc1srgb,
    bc2unorm,
    bc2srgb,
    bc3unorm,
    bc3srgb,
    bc4unorm,
    bc4snorm,
    bc5unorm,
    bc5snorm,
    bc6u16f,
    bc6s16f,
    bc7unorm,
    bc7srgb,

    pub fn isStencilFormat(self: Format) bool {
        return switch (self) {
            .d32fs8 => true,
            else => false,
        };
    }

    pub fn getBlockWidth(self: Format) u32 {
        return switch (self) {
            .bc1unorm,
            .bc1srgb,
            .bc2unorm,
            .bc2srgb,
            .bc3unorm,
            .bc3srgb,
            .bc4unorm,
            .bc4snorm,
            .bc5unorm,
            .bc5snorm,
            .bc6u16f,
            .bc6s16f,
            .bc7unorm,
            .bc7srgb,
            => 4,
            else => 1,
        };
    }

    pub fn getBlockHeight(self: Format) u32 {
        return switch (self) {
            .bc1unorm,
            .bc1srgb,
            .bc2unorm,
            .bc2srgb,
            .bc3unorm,
            .bc3srgb,
            .bc4unorm,
            .bc4snorm,
            .bc5unorm,
            .bc5snorm,
            .bc6u16f,
            .bc6s16f,
            .bc7unorm,
            .bc7srgb,
            => 4,
            else => 1,
        };
    }

    pub fn getRowPitch(self: Format, width: u32) u32 {
        return switch (self) {
            .rgba32f,
            .rgba32ui,
            .rgba32si,
            => width * 16,
            .rgb32f,
            .rgb32ui,
            .rgb32si,
            => width * 12,
            .rgba16f,
            .rgba16ui,
            .rgba16si,
            .rgba16unorm,
            .rgba16snorm,
            => width * 8,
            .rgba8ui,
            .rgba8si,
            .rgba8unorm,
            .rgba8snorm,
            .rgba8srgb,
            .bgra8unorm,
            .bgra8srgb,
            .rgb10a2unorm,
            .r11g11b10f,
            .rgb9e5,
            => width * 4,
            .rg32f,
            .rg32ui,
            .rg32si,
            => width * 8,
            .rg16f,
            .rg16ui,
            .rg16si,
            .rg16unorm,
            .rg16snorm,
            => width * 4,
            .rg8ui,
            .rg8si,
            .rg8unorm,
            .rg8snorm,
            => width * 2,
            .r32f,
            .r32ui,
            .r32si,
            => width * 4,
            .r16f,
            .r16ui,
            .r16si,
            .r16unorm,
            .r16snorm,
            => width * 2,
            .r8ui,
            .r8si,
            .r8unorm,
            .r8snorm,
            => width,
            .bc1unorm,
            .bc1srgb,
            .bc4unorm,
            .bc4snorm,
            => width / 2,
            .bc2unorm,
            .bc2srgb,
            .bc3unorm,
            .bc3srgb,
            .bc5unorm,
            .bc5snorm,
            .bc6u16f,
            .bc6s16f,
            .bc7unorm,
            .bc7srgb,
            => width,
            else => @panic("unhandled format in getRowPitch"),
        };
    }
};

const std = @import("std");
const builtin = @import("builtin");

const spatial = @import("../math/spatial.zig");

const platform = @import("../platform/root.zig");

pub const utils = @import("utils.zig");
pub const OffsetAllocator = @import("OffsetAllocator.zig");
