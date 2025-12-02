const Context = @This();

allocator: std.mem.Allocator,
sc: graphics.ShaderCompiler,
ren: graphics.RenderDevice,
interface: gpu.Interface,
gres: graphics.GPUResources,

pub fn create(allocator: std.mem.Allocator, shader_cwd: std.Io.Dir, io: std.Io, options: gpu.Options) Error!*Context {
    const rctx: *Context = try allocator.create(Context);
    errdefer allocator.destroy(rctx);
    rctx.allocator = allocator;

    rctx.sc = try graphics.ShaderCompiler.init(allocator, shader_cwd, io);
    errdefer rctx.sc.deinit();

    rctx.ren = try graphics.RenderDevice.init(allocator, options);
    errdefer rctx.ren.deinit();
    rctx.interface = rctx.ren.interface;

    rctx.gres = try graphics.GPUResources.init(allocator, &rctx.ren.upload, &rctx.sc);
    errdefer rctx.gres.deinit();

    rctx.ren.blit_pipeline = rctx.gres.getPipeline(rctx.gres.blit_pipeline);

    return rctx;
}

pub fn destroy(self: *Context) void {
    self.ren.waitGpuIdle() catch {};
    self.gres.deinit();
    self.ren.deinit();
    self.sc.deinit();
    self.allocator.destroy(self);
}

pub const Error = gpu.Error || error{
    MissingDxcCompilerLibrary,
    MissingDxcCreateInstance,
    ShaderCompilationFailed,
};

const std = @import("std");
const gpu = @import("../gpu/root.zig");
const graphics = @import("root.zig");
