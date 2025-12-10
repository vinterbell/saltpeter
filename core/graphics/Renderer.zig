const SceneRenderer = @This();

rd: *graphics.RenderDevice,
view: *graphics.View,

sun_light_direction: linalg.Vec,
sun_light_color: linalg.Vec,
ambient_light_color: linalg.Vec,

sky_pipeline: *gpu.Pipeline,

pub const Desc = struct {
    sky_pipeline: *gpu.Pipeline,
};

pub fn init(
    rd: *graphics.RenderDevice,
    view: *graphics.View,
    desc: Desc,
) !SceneRenderer {
    var self: SceneRenderer = .{
        .rd = rd,
        .view = view,
        .sun_light_direction = linalg.loadArr4(@splat(0)),
        .sun_light_color = linalg.loadArr4(@splat(1)),
        .ambient_light_color = linalg.loadArr4(@splat(0.1)),
        .sky_pipeline = desc.sky_pipeline,
    };
    _ = &self;

    return self;
}

pub fn deinit(self: *SceneRenderer) void {
    _ = self;
}

pub fn begin(self: *SceneRenderer, cmd: *gpu.CommandList, camera: *const graphics.Camera) !void {
    const interface = self.rd.interface;

    const scene_constants = try self.rd.allocateConstantBuffer(gpu_structures.SceneConstants, .{
        .view_matrix = camera.view_matrix,
        .projection_matrix = camera.projection_matrix,
        .view_projection_matrix = camera.view_projection_matrix,

        .sun_light_direction = self.sun_light_direction,
        .sun_light_color = self.sun_light_color,
        .ambient_light_color = self.ambient_light_color,
    });

    try interface.commandSetGraphicsConstants(
        cmd,
        .root,
        gpu_structures.RootConstants,
        .{
            .scene_constants = scene_constants,
        },
    );

    // draw sky
    try self.drawSky(cmd);
}

pub fn end(self: *SceneRenderer, cmd: *gpu.CommandList) !void {
    _ = self;
    _ = cmd;
    // try self.rd.interface.commandEndRenderPass(cmd);
}

fn drawSky(self: *SceneRenderer, cmd: *gpu.CommandList) !void {
    const interface = self.rd.interface;

    try interface.commandBeginRenderPass(cmd, .colorOnly(&.{
        .color(.first(self.view.targets.albedo_metallic.texture), .loadClear(.{ 0, 0, 0, 1.0 }), .store),
    }));
    {
        interface.commandBindPipeline(cmd, self.sky_pipeline);
        interface.commandDraw(cmd, 36, 1, 0, 0);
    }
    try interface.commandEndRenderPass(cmd);

    interface.commandTextureBarrier(
        cmd,
        self.view.targets.albedo_metallic.texture,
        0,
        .{ .render_target = true },
        .{ .present = true },
    );
}

const std = @import("std");
const gpu = @import("../gpu/root.zig");
const graphics = @import("root.zig");
const linalg = @import("../math/linalg.zig");

const gpu_structures = @import("gpu_structures.zig");
