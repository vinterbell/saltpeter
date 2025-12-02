//! stores and manages graphics resources. these should be immutable once added?
const GPUResources = @This();

arena: std.heap.ArenaAllocator,
us: *UploadStage,
sc: *ShaderCompiler,
sc_backend: ShaderCompiler.Backend,
textures: hm.HandleMap(TextureEntry),
pipelines: hm.HandleMap(PipelineEntry),
samplers: [@typeInfo(Sampler).@"enum".fields.len]*gpu.Descriptor,

white_texture: TextureHandle,
black_texture: TextureHandle,
debug_texture: TextureHandle,
blit_pipeline: PipelineHandle,

pub const TextureHandle = enum(u64) {
    invalid = 0,
    _,

    fn toHm(self: TextureHandle) hm.Handle {
        return @bitCast(@intFromEnum(self));
    }

    fn fromHm(handle: hm.Handle) TextureHandle {
        return @enumFromInt(@as(u64, @bitCast(handle)));
    }
};
pub const PipelineHandle = enum(u64) {
    invalid = 0,
    _,

    fn toHm(self: PipelineHandle) hm.Handle {
        return @bitCast(@intFromEnum(self));
    }

    fn fromHm(handle: hm.Handle) PipelineHandle {
        return @enumFromInt(@as(u64, @bitCast(handle)));
    }
};
pub const Sampler = enum(u32) {
    linear,
    nearest,
    anisotropic,
};

pub fn init(allocator: std.mem.Allocator, us: *UploadStage, sc: *ShaderCompiler) !GPUResources {
    var self: GPUResources = self: {
        const backend: ShaderCompiler.Backend = switch (us.interface.getInterfaceOptions().backend) {
            .d3d12 => .d3d12,
            else => |gpu_backend| {
                std.debug.panic("Unsupported GPU backend for ShaderCompiler: {}\n", .{gpu_backend});
            },
        };

        var textures: hm.HandleMap(TextureEntry) = try .init(allocator);
        errdefer textures.deinit();

        var pipelines: hm.HandleMap(PipelineEntry) = try .init(allocator);
        errdefer pipelines.deinit();

        const linear_sampler = try us.interface.createDescriptor(
            allocator,
            .sampler(.{ .filters = .{
                .min = .linear,
                .mag = .linear,
                .mip = .linear,
            } }),
            "Linear Sampler",
        );
        errdefer us.interface.destroyDescriptor(linear_sampler);

        const nearest_sampler = try us.interface.createDescriptor(
            allocator,
            .sampler(.{ .filters = .{
                .min = .nearest,
                .mag = .nearest,
                .mip = .nearest,
            } }),
            "Nearest Sampler",
        );
        errdefer us.interface.destroyDescriptor(nearest_sampler);

        const anisotropic_sampler = try us.interface.createDescriptor(
            allocator,
            .sampler(.{ .filters = .{
                .min = .anisotropic,
                .mag = .anisotropic,
                .mip = .linear,
            } }),
            "Anisotropic Sampler",
        );
        errdefer us.interface.destroyDescriptor(anisotropic_sampler);

        break :self .{
            .arena = .init(allocator),
            .us = us,
            .sc = sc,
            .sc_backend = backend,
            .textures = textures,
            .pipelines = pipelines,
            .samplers = .{
                linear_sampler,
                nearest_sampler,
                anisotropic_sampler,
            },
            .white_texture = .invalid,
            .black_texture = .invalid,
            .debug_texture = .invalid,
            .blit_pipeline = .invalid,
        };
    };
    errdefer self.deinit();

    self.white_texture = try self.loadTexture(
        allocator,
        .empty(1, 1, 1, .rgba8unorm),
        "White Texture",
    );

    self.black_texture = try self.loadTexture(
        allocator,
        .empty(1, 1, 1, .rgba8unorm),
        "Black Texture",
    );

    const test_texture_dim = 8;

    self.debug_texture = try self.loadTexture(
        allocator,
        .empty(test_texture_dim, test_texture_dim, 1, .rgba8unorm),
        "Debug Texture",
    );

    const white_data: [4]u8 = .{ 255, 255, 255, 255 };
    try us.uploadTexture(self.getTexture(self.white_texture).?, &white_data);
    const black_data: [4]u8 = .{ 0, 0, 0, 255 };
    try us.uploadTexture(self.getTexture(self.black_texture).?, &black_data);

    const test_texture_data: [test_texture_dim * test_texture_dim * 4]u8 = blk: {
        const black_pixel: [4]u8 = .{ 0, 0, 0, 255 };
        const magenta_pixel: [4]u8 = .{ 255, 0, 255, 255 };
        var data: [test_texture_dim * test_texture_dim * 4]u8 = undefined;
        var is_black: bool = false;
        for (0..test_texture_dim) |y| {
            for (0..test_texture_dim) |x| {
                const pixel = if (is_black) black_pixel else magenta_pixel;
                const index = (y * test_texture_dim + x) * 4;
                data[index + 0] = pixel[0];
                data[index + 1] = pixel[1];
                data[index + 2] = pixel[2];
                data[index + 3] = pixel[3];
                is_black = !is_black;
            }
            is_black = !is_black;
        }
        break :blk data;
    };
    try us.uploadTexture(self.getTexture(self.debug_texture).?, &test_texture_data);

    const blit_pipeline_desc: RenderPipelineDesc = .{
        .data = .fromSource(blit_hlsl_shader, "@embedded/blit.hlsl"),
        .rasterization = .default,
        .multisample = .default,
        .depth_stencil = .no_depth_stencil,
        .target_state = .targets(&.{
            .noBlend(.rgba8unorm),
        }, null),
        .primitive_topology = .triangle_list,
    };
    self.blit_pipeline = try self.loadRenderPipeline(
        allocator,
        blit_pipeline_desc,
        "Blit Pipeline",
    );

    return self;
}

pub fn deinit(self: *GPUResources) void {
    for (self.samplers) |sampler| {
        self.us.interface.destroyDescriptor(sampler);
    }
    var it_textures = self.textures.iterator();
    while (it_textures.next()) |e| {
        const entry, _ = e;
        self.us.interface.destroyDescriptor(entry.gpu_view);
        self.us.interface.destroyTexture(entry.gpu_texture);
    }
    self.textures.deinit();
    var it_pipelines = self.pipelines.iterator();
    while (it_pipelines.next()) |e| {
        const entry, _ = e;
        self.us.interface.destroyPipeline(entry.gpu_pipeline);
    }
    self.pipelines.deinit();
    self.arena.deinit();
}

pub fn getSampler(self: *GPUResources, sampler: Sampler) gpu.Descriptor.Index {
    return self.us.interface.getDescriptorIndex(self.samplers[@intFromEnum(sampler)]);
}

const TextureEntry = struct {
    handle: hm.Handle,
    gpu_texture: *gpu.Texture,
    gpu_view: *gpu.Descriptor,
};

const TextureDesc = struct {
    data: Data,
    view_format: gpu.Format,

    pub const Data = union(enum) {
        empty: struct {
            width: u32,
            height: u32,
            mip_levels: u32,
            format: gpu.Format,
        },
        image: *const assets.Image,
    };

    pub fn empty(
        width: u32,
        height: u32,
        mip_levels: u32,
        format: gpu.Format,
    ) TextureDesc {
        return .{
            .data = .{
                .empty = .{
                    .width = width,
                    .height = height,
                    .mip_levels = mip_levels,
                    .format = format,
                },
            },
            .view_format = format,
        };
    }

    pub fn image(img: *const assets.Image, view_format: gpu.Format) TextureDesc {
        return .{
            .data = .{
                .image = img,
            },
            .view_format = view_format,
        };
    }
};

pub fn loadTexture(
    self: *GPUResources,
    allocator: std.mem.Allocator,
    desc: TextureDesc,
    debug_name: []const u8,
) !TextureHandle {
    const entry: TextureEntry = try self.makeTexture(
        allocator,
        desc,
        debug_name,
    );
    const handle = try self.textures.add(entry);
    return .fromHm(handle);
}

fn makeTexture(
    self: *GPUResources,
    allocator: std.mem.Allocator,
    desc: TextureDesc,
    debug_name: []const u8,
) !TextureEntry {
    const image: ?*const assets.Image = switch (desc.data) {
        .empty => null,
        .image => desc.data.image,
    };

    const gpu_desc: gpu.Texture.Desc = if (image) |img|
        .{
            .width = img.width,
            .height = img.height,
            .depth_or_array_layers = 1,
            .mip_levels = 1,
            .format = .rgba8unorm,
            .usage = .read_only,
        }
    else
        .{
            .width = desc.data.empty.width,
            .height = desc.data.empty.height,
            .depth_or_array_layers = 1,
            .mip_levels = desc.data.empty.mip_levels,
            .format = desc.data.empty.format,
            .usage = .read_only,
        };

    const gpu_texture = try self.us.interface.createTexture(
        allocator,
        gpu_desc,
        debug_name,
    );
    errdefer self.us.interface.destroyTexture(gpu_texture);

    const gpu_view = try self.us.interface.createDescriptor(
        allocator,
        .readTexture2D(.first(gpu_texture), desc.view_format),
        debug_name,
    );
    errdefer self.us.interface.destroyDescriptor(gpu_view);

    if (image) |img| {
        try self.us.uploadTexture(gpu_texture, img.data);
    }

    return .{
        .handle = .nil,
        .gpu_texture = gpu_texture,
        .gpu_view = gpu_view,
    };
}

pub fn getTexture(self: *GPUResources, handle: TextureHandle) ?*gpu.Texture {
    if (handle == .invalid) return null;
    const hm_handle: hm.Handle = handle.toHm();
    const entry = self.textures.get(hm_handle) orelse return null;
    return entry.gpu_texture;
}

pub fn getTextureView(self: *GPUResources, handle: TextureHandle) ?gpu.Descriptor.Index {
    if (handle == .invalid) return null;
    const hm_handle: hm.Handle = handle.toHm();
    const entry = self.textures.get(hm_handle) orelse return null;
    return self.us.interface.getDescriptorIndex(entry.gpu_view);
}

pub fn removeTexture(self: *GPUResources, handle: TextureHandle) void {
    if (handle == .invalid) return;
    const hm_handle: hm.Handle = handle.toHm();
    const entry = self.textures.remove(hm_handle) orelse return;
    self.us.interface.destroyDescriptor(entry.gpu_view);
    self.us.interface.destroyTexture(entry.gpu_texture);
}

pub fn recreateTexture(
    self: *GPUResources,
    allocator: std.mem.Allocator,
    handle: TextureHandle,
    desc: TextureDesc,
    debug_name: []const u8,
) !void {
    if (handle == .invalid) return;
    const hm_handle: hm.Handle = handle.toHm();
    const old_entry = self.textures.get(hm_handle) orelse return;
    self.us.removeUploadsReferencingTexture(old_entry.gpu_texture);

    self.us.interface.destroyDescriptor(old_entry.gpu_view);
    self.us.interface.destroyTexture(old_entry.gpu_texture);

    const new_entry = try self.makeTexture(allocator, desc, debug_name);
    old_entry.* = new_entry;
    old_entry.handle = hm_handle;
}

pub const PipelineEntry = struct {
    handle: hm.Handle,
    gpu_pipeline: *gpu.Pipeline,
};

pub const RenderPipelineDesc = struct {
    data: Data,
    rasterization: gpu.Pipeline.RasterizationState,
    multisample: gpu.Pipeline.MultisampleState,
    depth_stencil: gpu.Pipeline.DepthStencilState,
    target_state: gpu.Pipeline.TargetState,
    primitive_topology: gpu.Pipeline.Primitive,

    const Data = union(enum) {
        source: struct {
            data: []const u8,
            file_path: []const u8,
        },
        compiled: struct {
            vs: []const u8,
            fs: []const u8,
        },

        pub fn fromSource(source: []const u8, file_path: []const u8) Data {
            return .{ .source = .{ .data = source, .file_path = file_path } };
        }

        pub fn fromCompiled(vs: []const u8, fs: []const u8) Data {
            return .{ .compiled = .{ .vs = vs, .fs = fs } };
        }
    };
};

pub fn loadRenderPipeline(
    self: *GPUResources,
    allocator: std.mem.Allocator,
    desc: RenderPipelineDesc,
    debug_name: []const u8,
) !PipelineHandle {
    const entry: PipelineEntry = try self.makeRenderPipeline(
        allocator,
        desc,
        debug_name,
    );
    const handle = try self.pipelines.add(entry);
    return .fromHm(handle);
}

fn makeRenderPipeline(
    self: *GPUResources,
    allocator: std.mem.Allocator,
    desc: RenderPipelineDesc,
    debug_name: []const u8,
) !PipelineEntry {
    var vs_blob: []const u8 = &.{};
    var fs_blob: []const u8 = &.{};

    switch (desc.data) {
        .source => |source| {
            vs_blob = try self.sc.compile(self.arena.allocator(), .{
                .source = source.data,
                .entry_point = "VSMain",
                .stage = .vertex,
                .file_path = source.file_path,
                .target_backend = self.sc_backend,
            });

            fs_blob = try self.sc.compile(self.arena.allocator(), .{
                .source = source.data,
                .entry_point = "FSMain",
                .stage = .fragment,
                .file_path = source.file_path,
                .target_backend = self.sc_backend,
            });
        },
        .compiled => |compiled| {
            vs_blob = compiled.vs;
            fs_blob = compiled.fs;
        },
    }

    const gpu_pipeline = try self.us.interface.createGraphicsPipeline(
        allocator,
        .{
            .vs = vs_blob,
            .fs = fs_blob,
            .rasterization = desc.rasterization,
            .multisample = desc.multisample,
            .depth_stencil = desc.depth_stencil,
            .target_state = desc.target_state,
            .primitive_topology = desc.primitive_topology,
        },
        debug_name,
    );
    errdefer self.us.interface.destroyPipeline(gpu_pipeline);

    return .{
        .handle = .nil,
        .gpu_pipeline = gpu_pipeline,
    };
}

pub fn getPipeline(self: *GPUResources, handle: PipelineHandle) ?*gpu.Pipeline {
    if (handle == .invalid) return null;
    const hm_handle: hm.Handle = handle.toHm();
    const entry = self.pipelines.get(hm_handle) orelse return null;
    return entry.gpu_pipeline;
}

pub fn removePipeline(self: *GPUResources, handle: PipelineHandle) void {
    if (handle == .invalid) return;
    const hm_handle: hm.Handle = handle.toHm();
    const entry = self.pipelines.remove(hm_handle) orelse return;
    self.us.interface.destroyPipeline(entry.gpu_pipeline);
}

pub fn recreatePipeline(
    self: *GPUResources,
    allocator: std.mem.Allocator,
    handle: PipelineHandle,
    desc: RenderPipelineDesc,
    debug_name: []const u8,
) !void {
    if (handle == .invalid) return;
    const hm_handle: hm.Handle = handle.toHm();
    const old_entry = self.pipelines.get(hm_handle) orelse return;

    self.us.interface.destroyPipeline(old_entry.gpu_pipeline);

    const new_entry = try self.makeRenderPipeline(allocator, desc, debug_name);

    old_entry.* = new_entry;
    old_entry.handle = hm_handle;
}

pub fn clearTemporaryResources(self: *GPUResources) void {
    _ = self.arena.reset(.retain_capacity);
}

const std = @import("std");
const hm = @import("../hm.zig");

const assets = @import("../assets/root.zig");

const ShaderCompiler = @import("ShaderCompiler.zig");

const gpu = @import("../gpu/root.zig");
const UploadStage = gpu.utils.UploadStage;

const blit_hlsl_shader =
    \\// this is set to slot 1
    \\cbuffer BlitConstants : register(b1)
    \\{
    \\    uint texture_index;
    \\    uint sampler_index;
    \\    float top_left_x;
    \\    float top_left_y;
    \\    float bottom_right_x;
    \\    float bottom_right_y;
    \\};
    \\
    \\struct FSInput
    \\{
    \\    float4 position : SV_POSITION;
    \\    float2 uv : TEXCOORD0;
    \\};
    \\
    \\FSInput VSMain(uint vertexID : SV_VertexID)
    \\{
    \\    float2 top_left = float2(top_left_x, top_left_y);
    \\    float2 top_right = float2(bottom_right_x, top_left_y);
    \\    float2 bottom_left = float2(top_left_x, bottom_right_y);
    \\    float2 bottom_right = float2(bottom_right_x, bottom_right_y);
    \\    
    \\    float4 positions[6] = {
    \\        float4(top_left.x, top_left.y, 0.0f, 1.0f),
    \\        float4(bottom_right.x, bottom_right.y, 0.0f, 1.0f),
    \\        float4(bottom_left.x, bottom_left.y, 0.0f, 1.0f),
    \\        float4(top_left.x, top_left.y, 0.0f, 1.0f),
    \\        float4(top_right.x, top_right.y, 0.0f, 1.0f),
    \\        float4(bottom_right.x, bottom_right.y, 0.0f, 1.0f),
    \\    };
    \\
    \\    float2 uvs[6] = {
    \\        float2(0.0f, 0.0f),
    \\        float2(1.0f, 1.0f),
    \\        float2(0.0f, 1.0f),
    \\        float2(0.0f, 0.0f),
    \\        float2(1.0f, 0.0f),
    \\        float2(1.0f, 1.0f),
    \\    };
    \\
    \\    FSInput output;
    \\    output.position = positions[vertexID];
    \\    output.uv = uvs[vertexID];
    \\
    \\    return output;
    \\}
    \\
    \\float4 FSMain(FSInput input) : SV_TARGET
    \\{
    \\    Texture2D tex = ResourceDescriptorHeap[texture_index];
    \\    SamplerState s = SamplerDescriptorHeap[sampler_index];
    \\    return tex.Sample(s, input.uv, 0);
    \\}
;

const gpu_structures = @import("gpu_structures.zig");
