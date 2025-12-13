const SceneRenderer = @This();

rd: *graphics.RenderDevice,
view: *graphics.View,
gres: *graphics.GPUResources,

sun_light_direction: linalg.Vec,
sun_light_color: linalg.Vec,
ambient_light_color: linalg.Vec,

sky_pipeline_handle: graphics.GPUResources.PipelineHandle,

blit_to_swapchains: [8]SwapchainBlit,
blit_to_swapchain_count: usize,

pub const Desc = struct {
    gres: *graphics.GPUResources,
    rd: *graphics.RenderDevice,
    view: *graphics.View,
};

const SwapchainBlit = struct {
    swapchain: *gpu.Swapchain,
    unit: graphics.View.UnitId,
};

pub fn init(
    allocator: std.mem.Allocator,
    desc: Desc,
) !SceneRenderer {
    const sky_pipeline_handle = try desc.gres.loadRenderPipeline(allocator, .{
        .data = .fromSource(
            \\#include "core/graphics/shaders/sky.hlsl"
        , "sky"),
        .rasterization = .default,
        .multisample = .default,
        .depth_stencil = .withDepth(
            .always,
            .no_write_depth,
        ),
        .target_state = .targets(&.{
            .noBlend(.rgba8unorm),
            .noBlend(.rgba16f),
        }, null),
        .primitive_topology = .triangle_list,
    }, "sky_pipeline");

    var self: SceneRenderer = .{
        .rd = desc.rd,
        .view = desc.view,
        .gres = desc.gres,
        .sun_light_direction = linalg.loadArr4(@splat(0)),
        .sun_light_color = linalg.loadArr4(@splat(1)),
        .ambient_light_color = linalg.loadArr4(@splat(0.1)),
        .sky_pipeline_handle = sky_pipeline_handle,

        .blit_to_swapchain_count = 0,
        .blit_to_swapchains = undefined,
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

    interface.commandSetGraphicsConstants(
        cmd,
        .root,
        gpu_structures.RootConstants,
        .{
            .scene_constants = scene_constants,
        },
    );

    // draw sky
    self.drawSky(cmd);
    self.finalComposite(cmd);
}

pub fn end(self: *SceneRenderer, cmd: *gpu.CommandList) !void {
    // tbarrier(final_composite: present -> render_target)
    const interface = self.rd.interface;
    interface.commandTextureBarrier(
        cmd,
        self.view.targets.final_composite.texture,
        0,
        .{ .fragment_shader_read = true },
        .{ .render_target = true },
    );

    self.blit_to_swapchain_count = 0;
}

/// call this BEFORE end()
pub fn useSwapchain(
    self: *SceneRenderer,
    swapchain: *gpu.Swapchain,
    unit: graphics.View.UnitId,
) void {
    if (self.blit_to_swapchain_count >= self.blit_to_swapchains.len) {
        @panic("Exceeded maximum swapchain blits");
    }
    self.blit_to_swapchains[self.blit_to_swapchain_count] = .{
        .swapchain = swapchain,
        .unit = unit,
    };
    self.blit_to_swapchain_count += 1;
}

fn drawSky(self: *SceneRenderer, cmd: *gpu.CommandList) void {
    const interface = self.rd.interface;
    const sky_pipeline = self.gres.getPipeline(self.sky_pipeline_handle) orelse {
        @panic("Sky pipeline not loaded");
    };

    interface.commandBeginRenderPass(cmd, .colorOnly(&.{
        .color(.first(self.view.targets.albedo_metallic.texture), .discard, .store),
        .color(.first(self.view.targets.normal_roughness.texture), .discard, .store),
    }));

    // interface.commandBeginRenderPass(cmd, .withDepthStencil(&.{
    //     .color(.first(self.view.targets.albedo_metallic.texture), .discard, .store),
    //     .color(.first(self.view.targets.normal_roughness.texture), .discard, .store),
    // }, .depthStencil(
    //     .first(self.view.targets.depth_texture.texture),
    //     .loadClear(1.0),
    //     .discard,
    //     .discard,
    //     .discard,
    // )));
    {
        defer interface.commandEndRenderPass(cmd);
        interface.commandBindPipeline(cmd, sky_pipeline);
        interface.commandDraw(cmd, 36, 1, 0, 0);
    }

    // tbarrier(albedo_metallic: render_target -> fs_read)
    interface.commandTextureBarrier(
        cmd,
        self.view.targets.albedo_metallic.texture,
        0,
        .{ .render_target = true },
        .{ .fragment_shader_read = true },
    );

    // tbarrier(roughness_metallic: render_target -> fs_read)
    interface.commandTextureBarrier(
        cmd,
        self.view.targets.normal_roughness.texture,
        0,
        .{ .render_target = true },
        .{ .fragment_shader_read = true },
    );

    // tbarrier(depth: depth_stencil -> fs_read)
    interface.commandTextureBarrier(
        cmd,
        self.view.targets.depth_texture.texture,
        0,
        .{ .depth_stencil = true },
        .{ .fragment_shader_read = true },
    );

    self.blitSwapchainsWithUnit(cmd, .albedo_metallic);
    self.blitSwapchainsWithUnit(cmd, .normal_roughness);
    self.blitSwapchainsWithUnit(cmd, .depth_texture);
}

fn finalComposite(self: *SceneRenderer, cmd: *gpu.CommandList) void {
    const interface = self.rd.interface;
    const blit_2d_pipeline = self.gres.getPipeline(self.gres.blit_2d_pipeline) orelse {
        @panic("Blit 2D pipeline not loaded");
    };

    const descriptor_index_albedo = interface.getDescriptorIndex(self.view.targets.albedo_metallic.shader_resource_view);
    const linear_sampler = self.gres.getSampler(.linear);

    interface.commandBeginRenderPass(cmd, .colorOnly(&.{
        .color(.first(self.view.targets.final_composite.texture), .discard, .store),
    }));
    {
        defer interface.commandEndRenderPass(cmd);
        interface.commandBindPipeline(cmd, blit_2d_pipeline);
        interface.commandSetGraphicsConstants(
            cmd,
            .buffer1,
            graphics.gpu_structures.FullscreenBlit,
            .{
                .texture_index = descriptor_index_albedo,
                .sampler_index = linear_sampler,
            },
        );
        interface.commandDraw(cmd, 3, 1, 0, 0);
    }

    // tbarrier(albedo_metallic: fs_read -> render_target)
    interface.commandTextureBarrier(
        cmd,
        self.view.targets.albedo_metallic.texture,
        0,
        .{ .fragment_shader_read = true },
        .{ .render_target = true },
    );

    // tbarrier(roughness_metallic: fs_read -> render_target)
    interface.commandTextureBarrier(
        cmd,
        self.view.targets.normal_roughness.texture,
        0,
        .{ .fragment_shader_read = true },
        .{ .render_target = true },
    );

    // tbarrier(depth: fs_read -> depth_stencil)
    interface.commandTextureBarrier(
        cmd,
        self.view.targets.depth_texture.texture,
        0,
        .{ .fragment_shader_read = true },
        .{ .depth_stencil = true },
    );

    // tbarrier(final_composite: render_target -> present)
    interface.commandTextureBarrier(
        cmd,
        self.view.targets.final_composite.texture,
        0,
        .{ .render_target = true },
        .{ .fragment_shader_read = true },
    );

    self.blitSwapchainsWithUnit(cmd, .final_composite);
}

/// the provided unit MUST be in fragment_shader_read state
fn blitSwapchainsWithUnit(
    self: *SceneRenderer,
    cmd: *gpu.CommandList,
    unit: graphics.View.UnitId,
) void {
    const interface = self.rd.interface;
    const blit_2d_pipeline = self.gres.getPipeline(self.gres.blit_2d_pipeline) orelse {
        @panic("Blit 2D pipeline not loaded");
    };

    const linear_sampler = self.gres.getSampler(.linear);

    for (self.blit_to_swapchains[0..self.blit_to_swapchain_count]) |blit| {
        if (blit.unit != unit) continue;

        // std.debug.print("Blitting unit {} to swapchain\n", .{unit});
        const backbuffer = self.rd.useSwapchain(blit.swapchain);
        const unit_texture_idx = interface.getDescriptorIndex(self.view.getUnit(unit).shader_resource_view);

        interface.commandTextureBarrier(
            cmd,
            backbuffer.texture,
            0,
            .{ .present = true },
            .{ .render_target = true },
        );
        defer interface.commandTextureBarrier(
            cmd,
            backbuffer.texture,
            0,
            .{ .render_target = true },
            .{ .present = true },
        );

        interface.commandBeginRenderPass(cmd, .colorOnly(&.{
            .color(.first(backbuffer.texture), .loadClear(.{ 0, 0, 0, 1.0 }), .store),
        }));
        {
            defer interface.commandEndRenderPass(cmd);
            interface.commandBindPipeline(cmd, blit_2d_pipeline);
            interface.commandSetGraphicsConstants(
                cmd,
                .buffer1,
                graphics.gpu_structures.FullscreenBlit,
                .{
                    .texture_index = unit_texture_idx,
                    .sampler_index = linear_sampler,
                },
            );
            interface.commandDraw(cmd, 3, 1, 0, 0);
        }
    }
}

const std = @import("std");
const gpu = @import("../gpu/root.zig");
const graphics = @import("root.zig");
const linalg = @import("../math/linalg.zig");

const gpu_structures = @import("gpu_structures.zig");
