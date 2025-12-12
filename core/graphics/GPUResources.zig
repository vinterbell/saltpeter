//! stores and manages graphics resources. these should be immutable once added?
const GPUResources = @This();

arena: std.heap.ArenaAllocator,
us: *UploadStage,
sc: *ShaderCompiler,
sc_backend: ShaderCompiler.Backend,
textures: hm.HandleMap(TextureEntry),
pipelines: hm.HandleMap(PipelineEntry),
samplers: [@typeInfo(Sampler).@"enum".fields.len]*gpu.Descriptor,

mesh_set_allocator: std.mem.Allocator,
mesh_sets: std.ArrayList(MeshSet),
meshes: hm.HandleMap(Mesh),

white_texture: TextureHandle,
black_texture: TextureHandle,
debug_texture: TextureHandle,

blit_2d_pipeline: PipelineHandle,
blit_2d_array_pipeline: PipelineHandle,
blit_3d_pipeline: PipelineHandle,
blit_cube_pipeline: PipelineHandle,
blit_cube_array_pipeline: PipelineHandle,

pub const max_vertex_buffer_size_per_mesh = 1_000_000;
pub const max_index_buffer_size_per_mesh = 3_000_000;

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

pub const MeshHandle = enum(u64) {
    invalid = 0,
    _,

    fn toHm(self: MeshHandle) hm.Handle {
        return @bitCast(@intFromEnum(self));
    }

    fn fromHm(handle: hm.Handle) MeshHandle {
        return @enumFromInt(@as(u64, @bitCast(handle)));
    }
};

pub const Sampler = enum(u32) {
    linear,
    nearest,
};

pub const init_mesh_vertices_size = 1_000_000;
pub const init_mesh_indices_size = 300_000 * 4;
pub const default_mesh_vertices_growth_factor = 1.5;
pub const default_mesh_indices_growth_factor = 1.5;

pub fn init(allocator: std.mem.Allocator, us: *UploadStage, sc: *ShaderCompiler) !GPUResources {
    var self: GPUResources = self: {
        const backend: ShaderCompiler.Backend = switch (us.interface.getInterfaceOptions().backend) {
            .d3d12 => .d3d12,
            .vulkan => .vulkan,
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

        var meshes: hm.HandleMap(Mesh) = try .init(allocator);
        errdefer meshes.deinit();

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
            },
            .mesh_set_allocator = allocator,
            .mesh_sets = .empty,
            .meshes = meshes,
            .white_texture = .invalid,
            .black_texture = .invalid,
            .debug_texture = .invalid,
            .blit_2d_pipeline = .invalid,
            .blit_2d_array_pipeline = .invalid,
            .blit_3d_pipeline = .invalid,
            .blit_cube_pipeline = .invalid,
            .blit_cube_array_pipeline = .invalid,
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

    var blit_2d_pipeline_desc: RenderPipelineDesc = .{
        .data = .fromSourceWithDefines(blit_hlsl_shader, "blit.hlsl", &.{
            "BLIT_FROM_2D_TEXTURE",
        }),
        .rasterization = .default,
        .multisample = .default,
        .depth_stencil = .no_depth_stencil,
        .target_state = .targets(&.{
            .noBlend(.rgba8unorm),
        }, null),
        .primitive_topology = .triangle_list,
    };
    self.blit_2d_pipeline = try self.loadRenderPipeline(
        allocator,
        blit_2d_pipeline_desc,
        "Blit 2D Pipeline",
    );

    blit_2d_pipeline_desc.data = .fromSourceWithDefines(
        blit_hlsl_shader,
        "blit.hlsl",
        &.{"BLIT_FROM_2D_TEXTURE_ARRAY"},
    );
    self.blit_2d_array_pipeline = try self.loadRenderPipeline(
        allocator,
        blit_2d_pipeline_desc,
        "Blit 2D Array Pipeline",
    );

    blit_2d_pipeline_desc.data = .fromSourceWithDefines(
        blit_hlsl_shader,
        "blit.hlsl",
        &.{"BLIT_FROM_3D_TEXTURE"},
    );
    self.blit_3d_pipeline = try self.loadRenderPipeline(
        allocator,
        blit_2d_pipeline_desc,
        "Blit 3D Pipeline",
    );

    blit_2d_pipeline_desc.data = .fromSourceWithDefines(
        blit_hlsl_shader,
        "blit.hlsl",
        &.{"BLIT_FROM_CUBE_TEXTURE"},
    );
    self.blit_cube_pipeline = try self.loadRenderPipeline(
        allocator,
        blit_2d_pipeline_desc,
        "Blit Cube Pipeline",
    );

    blit_2d_pipeline_desc.data = .fromSourceWithDefines(
        blit_hlsl_shader,
        "blit.hlsl",
        &.{"BLIT_FROM_CUBE_TEXTURE_ARRAY"},
    );
    self.blit_cube_array_pipeline = try self.loadRenderPipeline(
        allocator,
        blit_2d_pipeline_desc,
        "Blit Cube Array Pipeline",
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
    for (self.mesh_sets.items) |*mesh_set| {
        mesh_set.deinit();
    }
    self.mesh_sets.deinit(self.mesh_set_allocator);
    self.meshes.deinit();
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
            defines: []const []const u8,
        },
        compiled: struct {
            vs: []const u8,
            fs: []const u8,
        },

        pub fn fromSource(source: []const u8, file_path: []const u8) Data {
            return .{ .source = .{
                .data = source,
                .file_path = file_path,
                .defines = &.{},
            } };
        }

        pub fn fromSourceWithDefines(
            source: []const u8,
            file_path: []const u8,
            defines: []const []const u8,
        ) Data {
            return .{ .source = .{
                .data = source,
                .file_path = file_path,
                .defines = defines,
            } };
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

    const temp = self.arena.allocator();

    switch (desc.data) {
        .source => |source| {
            vs_blob = try self.sc.compile(temp, .{
                .source = source.data,
                .entry_point = "VSMain",
                .stage = .vertex,
                .file_path = source.file_path,
                .target_backend = self.sc_backend,
                .defines = source.defines,
            });

            fs_blob = try self.sc.compile(temp, .{
                .source = source.data,
                .entry_point = "FSMain",
                .stage = .fragment,
                .file_path = source.file_path,
                .target_backend = self.sc_backend,
                .defines = source.defines,
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

pub const Mesh = struct {
    handle: hm.Handle,
    mesh_set: *MeshSet,

    vertices_allocation: gpu.OffsetAllocator.Allocation,
    vertex_slice: gpu.Buffer.Slice,
    vertices_offset: usize,
    vertices_count: usize,

    indices_allocation: gpu.OffsetAllocator.Allocation,
    index_slice: gpu.Buffer.Slice,
    indices_offset: usize,
    indices_count: usize,
};

pub fn loadMesh(
    self: *GPUResources,
    vertex_data: []const u8,
    vertex_count: usize,
    indices: []const u32,
) !MeshHandle {
    const mesh = try self.makeMesh(
        vertex_data,
        vertex_count,
        indices,
    );
    const handle = try self.meshes.add(mesh);
    return .fromHm(handle);
}

fn makeMesh(
    self: *GPUResources,
    vertex_data: []const u8,
    vertex_count: usize,
    indices: []const u32,
) !Mesh {
    const vertex_byte_length: u32 = @intCast(vertex_data.len);
    const index_byte_length: u32 = @intCast(indices.len * @sizeOf(u32));
    const mesh_set = try self.getMeshSet(vertex_byte_length, index_byte_length);

    const vertex_allocation = mesh_set.vertex_allocator.allocate(vertex_byte_length) catch {
        return error.MeshAllocationFailed;
    };
    errdefer mesh_set.vertex_allocator.free(vertex_allocation) catch {};
    const index_allocation = mesh_set.index_allocator.allocate(index_byte_length) catch {
        return error.MeshAllocationFailed;
    };
    errdefer mesh_set.index_allocator.free(index_allocation) catch {};

    const vertex_slice: gpu.Buffer.Slice = .sub(
        mesh_set.vertex_buffer,
        vertex_allocation.offset,
        .fromInt(vertex_allocation.size),
    );
    const index_slice: gpu.Buffer.Slice = .sub(
        mesh_set.index_buffer,
        index_allocation.offset,
        .fromInt(index_allocation.size),
    );

    try self.us.uploadBuffer(vertex_slice.location(0), vertex_data);
    try self.us.uploadBuffer(index_slice.location(0), @ptrCast(indices));

    return .{
        .handle = .nil,
        .mesh_set = mesh_set,
        .vertices_allocation = vertex_allocation,
        .vertex_slice = vertex_slice,
        .vertices_offset = @intCast(vertex_allocation.offset),
        .vertices_count = vertex_count,
        .indices_allocation = index_allocation,
        .index_slice = index_slice,
        .indices_offset = @intCast(index_allocation.offset),
        .indices_count = indices.len,
    };
}

fn getMeshSet(self: *GPUResources, vertex_byte_length: u32, index_byte_length: u32) !*MeshSet {
    if (vertex_byte_length > max_vertex_buffer_size_per_mesh or
        index_byte_length > max_index_buffer_size_per_mesh)
    {
        std.debug.print(
            "Requested mesh size exceeds maximum per-mesh buffer size: vertex_byte_length={}, index_byte_length={}\n",
            .{ vertex_byte_length, index_byte_length },
        );
        return error.MeshTooLarge;
    }

    for (self.mesh_sets.items) |*mesh_set| {
        const vertex_alloc = mesh_set.vertex_allocator.allocate(vertex_byte_length) catch continue;
        defer mesh_set.vertex_allocator.free(vertex_alloc) catch {};
        const index_alloc = mesh_set.index_allocator.allocate(index_byte_length) catch continue;
        defer mesh_set.index_allocator.free(index_alloc) catch {};

        return mesh_set;
    }

    var new_mesh_set = try MeshSet.init(self.mesh_set_allocator, self.us);
    errdefer new_mesh_set.deinit();

    try self.mesh_sets.append(self.mesh_set_allocator, new_mesh_set);
    return &self.mesh_sets.items[self.mesh_sets.items.len - 1];
}

pub fn getMesh(self: *GPUResources, handle: MeshHandle) ?Mesh {
    if (handle == .invalid) return null;
    const hm_handle: hm.Handle = handle.toHm();
    const entry = self.textures.get(hm_handle) orelse return null;
    return entry;
}

pub fn removeMesh(self: *GPUResources, handle: MeshHandle) void {
    if (handle == .invalid) return;
    const hm_handle: hm.Handle = handle.toHm();
    const entry = self.meshes.remove(hm_handle) orelse return;
    entry.mesh_set.vertex_allocator.free(entry.vertices_allocation) catch @panic("failed to free vertex allocation");
    entry.mesh_set.index_allocator.free(entry.indices_allocation) catch @panic("failed to free index allocation");
}

pub fn recreateMesh(
    self: *GPUResources,
    allocator: std.mem.Allocator,
    handle: MeshHandle,
    vertex_data: []const u8,
    vertex_count: usize,
    indices: []const u32,
) !void {
    if (handle == .invalid) return;
    const hm_handle: hm.Handle = handle.toHm();
    const old_entry = self.meshes.get(hm_handle) orelse return;

    old_entry.mesh_set.vertex_allocator.free(old_entry.vertices_allocation) catch @panic("failed to free vertex allocation");
    old_entry.mesh_set.index_allocator.free(old_entry.indices_allocation) catch @panic("failed to free index allocation");

    const new_entry = try self.makeMesh(
        allocator,
        vertex_data,
        vertex_count,
        indices,
    );

    old_entry.* = new_entry;
    old_entry.handle = hm_handle;
}

const MeshSet = struct {
    allocator: std.mem.Allocator,
    us: *UploadStage,
    vertex_allocator: gpu.OffsetAllocator,
    vertex_buffer: *gpu.Buffer,
    index_allocator: gpu.OffsetAllocator,
    index_buffer: *gpu.Buffer,

    pub fn init(allocator: std.mem.Allocator, us: *UploadStage) !MeshSet {
        var vertex_allocator = try gpu.OffsetAllocator.init(
            allocator,
            max_vertex_buffer_size_per_mesh,
            null,
        );
        errdefer vertex_allocator.deinit(allocator);

        var index_allocator = try gpu.OffsetAllocator.init(
            allocator,
            max_index_buffer_size_per_mesh,
            null,
        );
        errdefer index_allocator.deinit(allocator);

        const vertex_buffer = try us.interface.createBuffer(
            allocator,
            .readonlyStorageBuffer(max_vertex_buffer_size_per_mesh, .gpu_only),
            "MeshSet Vertex Buffer",
        );
        errdefer us.interface.destroyBuffer(vertex_buffer);

        const index_buffer = try us.interface.createBuffer(
            allocator,
            .readonlyStorageBuffer(max_index_buffer_size_per_mesh, .gpu_only),
            "MeshSet Index Buffer",
        );
        errdefer us.interface.destroyBuffer(index_buffer);

        return .{
            .allocator = allocator,
            .us = us,
            .vertex_allocator = vertex_allocator,
            .vertex_buffer = vertex_buffer,
            .index_allocator = index_allocator,
            .index_buffer = index_buffer,
        };
    }

    pub fn deinit(self: *MeshSet) void {
        self.us.interface.destroyBuffer(self.vertex_buffer);
        self.vertex_allocator.deinit(self.allocator);
        self.us.interface.destroyBuffer(self.index_buffer);
        self.index_allocator.deinit(self.allocator);
    }
};

pub fn clearTemporaryResources(self: *GPUResources) void {
    _ = self.arena.reset(.retain_capacity);
}

const std = @import("std");
const hm = @import("../hm.zig");

const assets = @import("../assets/root.zig");

const ShaderCompiler = @import("ShaderCompiler.zig");

const gpu = @import("../gpu/root.zig");
const UploadStage = gpu.utils.UploadStage;

const blit_hlsl_shader = @embedFile("shaders/blit.hlsl");

const gpu_structures = @import("gpu_structures.zig");
