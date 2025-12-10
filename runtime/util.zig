const std = @import("std");
const builtin = @import("builtin");

const sp = @import("sp");

pub const Scene = struct {
    arena: std.heap.ArenaAllocator,
    images: std.ArrayList(sp.graphics.GPUResources.TextureHandle),
    // materials:
    primitives: std.ArrayList(sp.graphics.GPUResources.MeshHandle),
    meshes: std.ArrayList(GeometryMaterial),

    pub fn init(allocator: std.mem.Allocator) Scene {
        return Scene{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .images = .empty,
            .primitives = .empty,
            .meshes = .empty,
        };
    }

    pub fn deinit(self: *Scene) void {
        self.arena.deinit();
    }
};

const GeometryMaterial = struct {
    material_index: usize,
    primitive_index: usize,
};

pub fn loadGltfIntoScene(
    gres: *sp.graphics.GPUResources,
    scene: *Scene,
    allocator: std.mem.Allocator,
    document: *const sp.assets.Gltf,
    images: *const std.StringArrayHashMapUnmanaged(*const sp.assets.Image),
) !void {
    for (document.data.images) |img| {
        if (img.data) |data| {
            var img_asset = try sp.assets.Image.loadFromMemory(data, 4);
            defer img_asset.deinit();

            const tex_handle = try gres.loadTexture(
                allocator,
                .image(&img_asset, .rgba8unorm),
                img.name orelse "gltf_image",
            );
            try scene.images.append(scene.arena.allocator(), tex_handle);
        }
        if (img.uri) |uri| {
            const img_asset = images.get(uri) orelse return error.ImageNotFound;
            const tex_handle = try gres.loadTexture(
                allocator,
                .image(img_asset, .rgba8unorm),
                img.name orelse uri,
            );
            try scene.images.append(scene.arena.allocator(), tex_handle);
        }
    }

    // todo: mapping from gltf texture index to the gpu texture handle

    try scene.meshes.ensureUnusedCapacity(scene.arena.allocator(), document.data.meshes.len);
    for (document.data.meshes) |mesh| {
        try scene.primitives.ensureUnusedCapacity(scene.arena.allocator(), mesh.primitives.len);
        for (mesh.primitives) |primitive| {
            const num_vertices = document.data.accessors[primitive.attributes[0].index()].count;
            const num_indices = document.data.accessors[primitive.indices.?].count;
            const vertex_offset = @sizeOf(Vertex) * num_vertices;

            const mesh_handle = blk: {
                const buffer_data = try scene.arena.allocator().alloc(u8, vertex_offset + num_indices * @sizeOf(u32));
                defer scene.arena.allocator().free(buffer_data);

                const vertex_data: []align(1) Vertex = @ptrCast(buffer_data[0..vertex_offset]);
                const index_data: []align(1) u32 = @ptrCast(buffer_data[vertex_offset..]);

                const binary = document.glb_binary orelse @panic("needs binary information next to or glb");
                var min_position: [3]f32 = .{ std.math.floatMax(f32), std.math.floatMax(f32), std.math.floatMax(f32) };
                var max_position: [3]f32 = .{ -std.math.floatMax(f32), -std.math.floatMax(f32), -std.math.floatMax(f32) };
                for (primitive.attributes) |attr| {
                    switch (attr) {
                        .position => |accessor_index| {
                            const accessor = document.data.accessors[accessor_index];
                            var it = accessor.iterator(f32, document, binary);
                            while (it.next()) |v| {
                                min_position[0] = @min(min_position[0], v[0]);
                                min_position[1] = @min(min_position[1], v[1]);
                                min_position[2] = @min(min_position[2], v[2]);
                                max_position[0] = @max(max_position[0], v[0]);
                                max_position[1] = @max(max_position[1], v[1]);
                                max_position[2] = @max(max_position[2], v[2]);
                                vertex_data[it.current - 1].position = .{ v[0], v[1], v[2], 0.0 };
                            }
                        },
                        .normal => |accessor_index| {
                            const accessor = document.data.accessors[accessor_index];
                            var it = accessor.iterator(f32, document, binary);
                            while (it.next()) |v| {
                                vertex_data[it.current - 1].normal = .{ v[0], v[1], v[2], 0.0 };
                            }
                        },
                        .tangent => |accessor_index| {
                            const accessor = document.data.accessors[accessor_index];
                            var it = accessor.iterator(f32, document, binary);
                            while (it.next()) |v| {
                                vertex_data[it.current - 1].tangent = v[0..4].*;
                            }
                        },
                        .texcoord => |accessor_index| {
                            const accessor = document.data.accessors[accessor_index];
                            var it = accessor.iterator(f32, document, binary);
                            while (it.next()) |v| {
                                vertex_data[it.current - 1].uv = .{ v[0], v[1], 0.0, 0.0 };
                            }
                        },
                        else => {},
                    }
                }

                {
                    const accessor = document.data.accessors[primitive.indices.?];
                    switch (accessor.component_type) {
                        .unsigned_short => {
                            var it = accessor.iterator(u16, document, binary);
                            while (it.next()) |index| {
                                index_data[it.current - 1] = index[0];
                            }
                        },
                        .unsigned_integer => {
                            var it = accessor.iterator(u32, document, binary);
                            while (it.next()) |index| {
                                index_data[it.current - 1] = index[0];
                            }
                        },
                        else => return error.UnsupportedIndexFormat,
                    }
                }
                break :blk try gres.loadMesh(
                    @ptrCast(@alignCast(vertex_data)),
                    num_vertices,
                    @ptrCast(@alignCast(index_data)),
                );
            };

            scene.primitives.appendAssumeCapacity(mesh_handle);
        }
    }
}

pub const Vertex = extern struct {
    position: [4]f32,
    normal: [4]f32,
    tangent: [4]f32,
    uv: [4]f32,
};
