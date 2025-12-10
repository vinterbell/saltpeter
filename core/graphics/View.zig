const View = @This();

rd: *graphics.RenderDevice,

// please don't touch
width: u32,
// please don't touch
height: u32,

targets: Targets,

const Targets = struct {
    // rgb: albedo, a: metallic, rgba byte
    albedo_metallic: Unit,
    // rgb: normal, a: roughness, rgba float
    normal_roughness: Unit,
    depth_texture: Unit,
};

pub fn init(
    rd: *graphics.RenderDevice,
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
) gpu.Error!View {
    var view: View = .{
        .rd = rd,
        .width = width,
        .height = height,
        .targets = undefined,
    };
    try view.initSizedResources(allocator);
    return view;
}

pub fn deinit(self: *View) void {
    self.deinitSizedResources();
}

pub fn resize(self: *View, allocator: std.mem.Allocator, new_width: u32, new_height: u32) gpu.Error!void {
    if (self.width == new_width and self.height == new_height) {
        return;
    }

    self.deinitSizedResources();
    self.width = new_width;
    self.height = new_height;
    try self.initSizedResources(allocator);
}

pub fn beginRenderPass(self: *View, cmd: *gpu.CommandList) !void {
    try self.rd.interface.commandBeginRenderPass(cmd, .{
        .color_attachments = &.{
            .color(.first(self.targets.albedo_metallic.texture), .loadClear(.{ 0, 0, 0, 1 }), .store),
            .color(.first(self.targets.normal_roughness.texture), .loadClear(.{ 0, 0, 0, 1 }), .store),
        },
        .depth_stencil_attachment = .depthStencil(
            .first(self.targets.depth_texture.texture),
            .loadClear(1.0),
            .store,
            .discard,
            .discard,
        ),
    });
}

fn initSizedResources(self: *View, allocator: std.mem.Allocator) gpu.Error!void {
    const interface = self.rd.interface;

    self.targets.albedo_metallic = try Unit.init(
        allocator,
        .{
            .width = self.width,
            .height = self.height,
            .format = .rgba8unorm,
            .usage = .read_only_render_target,
        },
        interface,
        "View_Targets_Albedo_Metallic",
    );
    errdefer self.targets.albedo_metallic.deinit(interface);

    self.targets.normal_roughness = try Unit.init(
        allocator,
        .{
            .width = self.width,
            .height = self.height,
            .format = .rgba16f,
            .usage = .read_only_render_target,
        },
        interface,
        "View_Targets_Normal_Roughness",
    );
    errdefer self.targets.normal_roughness.deinit(interface);

    self.targets.depth_texture = try Unit.init(
        allocator,
        .{
            .width = self.width,
            .height = self.height,
            .format = .d32f,
            .usage = .read_only_depth_stencil,
        },
        interface,
        "View_Targets_Depth_Texture",
    );
    errdefer self.targets.depth_texture.deinit(interface);
}

fn deinitSizedResources(self: *View) void {
    self.targets.depth_texture.deinit(self.rd.interface);
    self.targets.normal_roughness.deinit(self.rd.interface);
    self.targets.albedo_metallic.deinit(self.rd.interface);
}

const Unit = struct {
    texture: *gpu.Texture,
    shader_resource_view: *gpu.Descriptor,

    pub fn init(allocator: std.mem.Allocator, desc: gpu.Texture.Desc, interface: gpu.Interface, debug_name: []const u8) !Unit {
        const texture = try interface.createTexture(
            allocator,
            desc,
            debug_name,
        );
        errdefer interface.destroyTexture(texture);

        const shader_resource_view = try interface.createDescriptor(
            allocator,
            .readTexture2D(.first(texture), desc.format),
            debug_name,
        );
        errdefer interface.destroyDescriptor(shader_resource_view);

        return .{
            .texture = texture,
            .shader_resource_view = shader_resource_view,
        };
    }

    pub fn deinit(self: *Unit, interface: gpu.Interface) void {
        interface.destroyDescriptor(self.shader_resource_view);
        interface.destroyTexture(self.texture);
    }
};

const std = @import("std");
const gpu = @import("../gpu/root.zig");
const graphics = @import("root.zig");
const linalg = @import("../math/linalg.zig");
