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

    while (!window.should_close) {
        sp.platform.processEvents();
        window.preUpdate();
        try window.postUpdate();

        rctx.gres.clearTemporaryResources();

        const white_texture = rctx.gres.getTextureView(rctx.gres.debug_texture) orelse {
            @panic("missing white texture");
        };
        const sampler = rctx.gres.getSampler(.nearest);

        if (window.popResize()) |new_size| {
            _ = try rctx.interface.resizeSwapchain(swapchain, new_size.width, new_size.height);
        }

        try rctx.ren.upload.doUploads();

        try rctx.ren.beginFrame();
        try rctx.ren.blitSwapchain(swapchain, white_texture, sampler);
        try rctx.ren.endFrame();
    }
}

const std = @import("std");
const builtin = @import("builtin");

const sp = @import("sp");

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
