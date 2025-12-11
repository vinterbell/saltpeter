pub fn main() !void {
    const allocator = defaultGpa();
    defer deinitGpa();

    var io_impl: std.Io.Threaded = .init(allocator);
    defer io_impl.deinit();

    const io = io_impl.io();

    const window: *sp.platform.Window = try .create(allocator, .{
        .title = "window",
        .width = 800,
        .height = 600,
        .fullscreen = false,
        .resizable = true,
    });
    defer window.destroy(allocator);

    var rctx = try sp.graphics.Context.create(
        allocator,
        .cwd(),
        io,
        .{},
    );
    defer rctx.destroy();

    var view = try sp.graphics.View.init(
        &rctx.ren,
        allocator,
        800,
        600,
    );
    defer view.deinit();

    const sky_pipeline_handle = try rctx.gres.loadRenderPipeline(allocator, .{
        .data = .fromSource(
            \\#include "core/graphics/shaders/sky.hlsl"
        , "sky"),
        .rasterization = .default,
        .multisample = .default,
        .depth_stencil = .no_depth_stencil,
        .target_state = .targets(&.{
            .noBlend(.rgba8unorm),
        }, null),
        .primitive_topology = .triangle_list,
    }, "sky_pipeline");

    const sky_pipeline = rctx.gres.getPipeline(sky_pipeline_handle) orelse @panic("missing sky pipeline");

    var renderer = try sp.graphics.Renderer.init(&rctx.ren, &view, .{
        .sky_pipeline = sky_pipeline,
    });
    defer renderer.deinit();

    const swapchain = try rctx.interface.createSwapchain(
        allocator,
        .default(window),
        "swapchain",
    );
    defer rctx.interface.destroySwapchain(swapchain);

    var bell_img = try sp.assets.Image.loadFromMemory(bell_transparent_png, 4);
    defer bell_img.deinit();

    var random_img = try sp.assets.Image.loadFromMemory(random_image_png, 4);
    defer random_img.deinit();

    const bell_texture = try rctx.gres.loadTexture(
        allocator,
        .image(&bell_img, .rgba8unorm),
        "bell_texture",
    );

    std.debug.print("Loaded bell texture with ID: {any}\n", .{@as([2]u32, @bitCast(@as(u64, @intFromEnum(bell_texture))))});

    var scene: util.Scene = .init(allocator);
    defer scene.deinit();

    var gltf_doc = sp.assets.Gltf.init(allocator);
    defer gltf_doc.deinit();

    try gltf_doc.parse(@ptrCast(@alignCast(avocado_gltf)));
    gltf_doc.assignBinaryBuffer(@ptrCast(@alignCast(avocado_bin)));

    std.debug.print("GLTF has {} meshes\n", .{gltf_doc.data.meshes.len});

    // var avocado_base_color_img = try sp.assets.Image.loadFromMemory(
    //     avocado_base_color,
    //     4,
    // );
    // defer avocado_base_color_img.deinit();
    // std.debug.print("Loaded avocado base color image: {}x{}\n", .{
    //     avocado_base_color_img.width,
    //     avocado_base_color_img.height,
    // });

    // var avocado_normal_img = try sp.assets.Image.loadFromMemory(
    //     avocado_normal,
    //     4,
    // );
    // defer avocado_normal_img.deinit();
    // std.debug.print("Loaded avocado normal image: {}x{}\n", .{
    //     avocado_normal_img.width,
    //     avocado_normal_img.height,
    // });

    // var avocado_roughness_metallic_img = try sp.assets.Image.loadFromMemory(
    //     avocado_roughness_metallic,
    //     4,
    // );
    // defer avocado_roughness_metallic_img.deinit();
    // std.debug.print("Loaded avocado roughness metallic image: {}x{}\n", .{
    //     avocado_roughness_metallic_img.width,
    //     avocado_roughness_metallic_img.height,
    // });

    var image_map: std.StringArrayHashMapUnmanaged(*const sp.assets.Image) = try .init(allocator, &.{}, &.{}
        // &.{
        //     "Avocado_baseColor.png",
        //     "Avocado_normal.png",
        //     "Avocado_roughnessMetallic.png",
        // },
        // &.{
        //     &avocado_base_color_img,
        //     &avocado_normal_img,
        //     &avocado_roughness_metallic_img,
        // },
    );
    defer image_map.deinit(allocator);

    std.debug.print("Loading GLTF into scene...\n", .{});
    try util.loadGltfIntoScene(
        &rctx.gres,
        &scene,
        allocator,
        &gltf_doc,
        &image_map,
    );
    std.debug.print("Loaded scene with {} meshes\n", .{scene.meshes.items.len});

    const blit_pipeline = rctx.gres.getPipeline(rctx.gres.blit_2d_pipeline) orelse @panic("missing blit pipeline");

    // try rctx.gres.recreateTexture(
    //     allocator,
    //     bell_texture,
    //     .image(&random_img, .rgba8unorm),
    //     "random_texture_recreated",
    // );

    defer rctx.interface.shutdown();

    var camera: sp.graphics.Camera = .initPerspective(70.0, 800, 600, 0.1, 1000.0);

    const camera_pitch_speed: f32 = 1.0;
    const camera_yaw_speed: f32 = 1.0;
    const camera_move_speed: f32 = 0.05;

    var previous_time: std.Io.Clock.Timestamp = try .now(io, .real);

    var frame_index: usize = 0;
    while (!window.should_close) {
        sp.platform.processEvents();
        window.preUpdate();
        try window.postUpdate();

        const now: std.Io.Clock.Timestamp = try .now(io, .real);
        const delta = previous_time.durationTo(now);
        previous_time = now;

        const delta_time: f32 = @as(f32, @floatFromInt(delta.raw.toNanoseconds())) / 1_000_000_000.0;

        const input_up = window.back_input.keys_held.contains(.up);
        const input_down = window.back_input.keys_held.contains(.down);
        const input_left = window.back_input.keys_held.contains(.left);
        const input_right = window.back_input.keys_held.contains(.right);

        const input_w = window.back_input.keys_held.contains(.W);
        const input_s = window.back_input.keys_held.contains(.S);
        const input_a = window.back_input.keys_held.contains(.A);
        const input_d = window.back_input.keys_held.contains(.D);
        const input_q = window.back_input.keys_held.contains(.Q);
        const input_e = window.back_input.keys_held.contains(.E);

        // do camera rotation
        const camera_yaw_delta = boolSignMap(input_right, input_left) * camera_yaw_speed * delta_time;
        const camera_pitch_delta = boolSignMap(input_up, input_down) * camera_pitch_speed * delta_time;

        const camera_move_back_front = boolSignMap(input_w, input_s) * camera_move_speed * delta_time;
        const camera_move_left_right = boolSignMap(input_d, input_a) * camera_move_speed * delta_time;
        const camera_move_up_down = boolSignMap(input_e, input_q) * camera_move_speed * delta_time;

        const old_view: linalg.Mat = camera.view;
        const rotation_mat = linalg.mul(
            linalg.rotationY(-camera_yaw_delta),
            linalg.rotationX(camera_pitch_delta),
        );
        const rotated_view = linalg.mul(old_view, rotation_mat);
        const translated_view = linalg.mul(
            rotated_view,
            linalg.translation(camera_move_left_right, camera_move_up_down, camera_move_back_front),
        );
        camera.setView(translated_view);

        // const t = linalg.util.getTranslationVec(translated_view);
        // std.debug.print("Camera position: ({}, {}, {})\n", .{ t[0], t[1], t[2] });

        // const r = linalg.util.getRotationQuat(translated_view);
        // const euler = linalg.quatToRollPitchYaw(r);
        // std.debug.print("Camera rotation (radians): ({}, {}, {})\n", .{ euler[0], euler[1], euler[2] });

        rctx.gres.clearTemporaryResources();

        const sampler = rctx.gres.getSampler(.linear);

        if (window.popResize()) |new_size| {
            _ = try rctx.interface.resizeSwapchain(swapchain, new_size.width, new_size.height);
            try view.resize(allocator, new_size.width, new_size.height);
            camera.setWidthHeight(new_size.width, new_size.height);
        }

        const descriptor_index_albedo = rctx.interface.getDescriptorIndex(view.targets.albedo_metallic.shader_resource_view);

        try rctx.ren.beginFrame();

        const cmd = rctx.ren.commandList();
        try renderer.begin(cmd, &camera);

        try renderer.end(cmd);

        const backbuffer = try rctx.ren.useSwapchain(swapchain);
        {
            rctx.interface.commandTextureBarrier(
                cmd,
                backbuffer.texture,
                0,
                .{ .present = true },
                .{ .render_target = true },
            );
            defer rctx.interface.commandTextureBarrier(
                cmd,
                backbuffer.texture,
                0,
                .{ .render_target = true },
                .{ .present = true },
            );

            try rctx.interface.commandBeginRenderPass(cmd, .colorOnly(&.{
                .color(.first(backbuffer.texture), .loadClear(.{ 0, 0, 0, 1.0 }), .store),
            }));
            {
                rctx.interface.commandBindPipeline(cmd, blit_pipeline);
                try rctx.interface.commandSetGraphicsConstants(
                    cmd,
                    .buffer1,
                    sp.graphics.gpu_structures.BlitConstants,
                    .{
                        .texture_index = descriptor_index_albedo,
                        .sampler_index = sampler,
                        .rect = .{
                            -1.0, 1.0,
                            1.0,  -1.0,
                        },
                    },
                );
                rctx.interface.commandDraw(cmd, 6, 1, 0, 0);
            }
            try rctx.interface.commandEndRenderPass(cmd);
        }

        rctx.interface.commandTextureBarrier(
            cmd,
            view.targets.albedo_metallic.texture,
            0,
            .{ .present = true },
            .{ .render_target = true },
        );

        try rctx.us.doUploads();
        rctx.us.reset();
        try rctx.ren.endFrame();

        frame_index += 1;
    }
}

const std = @import("std");
const builtin = @import("builtin");

const sp = @import("sp");

const util = @import("util.zig");

const bell_transparent_png = @embedFile("bell_transparent.png");
const random_image_png = @embedFile("random_image.png");
const avocado_gltf = @embedFile("Avocado.gltf");
const avocado_bin = @embedFile("Avocado.bin");
const avocado_base_color = @embedFile("Avocado_baseColor.png");
const avocado_normal = @embedFile("Avocado_normal.png");
const avocado_roughness_metallic = @embedFile("Avocado_roughnessMetallic.png");

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
const is_debug_allocator = blk: {
    if (builtin.os.tag == .wasi) break :blk false;
    break :blk switch (builtin.mode) {
        .Debug, .ReleaseSafe => true,
        .ReleaseFast, .ReleaseSmall => false,
    };
};

fn defaultGpa() std.mem.Allocator {
    if (builtin.os.tag == .wasi) return std.heap.wasm_allocator;
    return switch (builtin.mode) {
        .Debug, .ReleaseSafe => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.c_allocator,
    };
}

fn deinitGpa() void {
    if (is_debug_allocator) {
        _ = debug_allocator.deinit();
    }
}

fn boolSignMap(pos: bool, neg: bool) f32 {
    if (pos and neg) return 0.0;
    if (pos) return 1.0;
    if (neg) return -1.0;
    return 0.0;
}

const linalg = @import("sp").math.linalg;
