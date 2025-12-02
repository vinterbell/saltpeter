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

    // try rctx.gres.recreateTexture(
    //     allocator,
    //     bell_texture,
    //     .image(&random_img, .rgba8unorm),
    //     "random_texture_recreated",
    // );

    var frame_index: usize = 0;
    while (!window.should_close) {
        sp.platform.processEvents();
        window.preUpdate();
        try window.postUpdate();

        // if (frame_index == 5000) {
        //     try rctx.gres.recreateTexture(
        //         allocator,
        //         bell_texture,
        //         .image(&random_img, .rgba8unorm),
        //         "random_texture_recreated",
        //     );
        // }

        rctx.gres.clearTemporaryResources();

        const tex = rctx.gres.getTextureView(bell_texture) orelse {
            @panic("missing white texture");
        };
        const sampler = rctx.gres.getSampler(.linear);

        if (window.popResize()) |new_size| {
            _ = try rctx.interface.resizeSwapchain(swapchain, new_size.width, new_size.height);
        }

        try rctx.ren.beginFrame();
        // make sure to do any uploads here
        try rctx.ren.upload.doUploads();
        try rctx.ren.blitSwapchain(swapchain, tex, sampler);
        try rctx.ren.endFrame();

        frame_index += 1;
    }
}

const std = @import("std");
const builtin = @import("builtin");

const sp = @import("sp");

const bell_transparent_png = @embedFile("bell_transparent.png");
const random_image_png = @embedFile("random_image.png");

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
