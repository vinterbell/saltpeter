const ShaderCompiler = @This();

pub const Stage = enum {
    vertex,
    fragment,
    compute,
};

pub const Backend = enum {
    d3d12,
    vulkan,
    metal,
};

pub const OptimizationLevel = enum {
    none,
    o1,
    o2,
    o3,
};

pub const Desc = struct {
    entry_point: []const u8,
    source: []const u8,
    file_path: []const u8,
    stage: Stage,
    defines: []const []const u8 = &.{},
    optimization_level: OptimizationLevel = .o3,
    target_backend: Backend,
};

cwd: std.Io.Dir,
arena: std.heap.ArenaAllocator,
io: std.Io,

lib: std.DynLib,
dxc_compiler: *dxc.ICompiler3,
dxc_utils: *dxc.IUtils,
include_handler: IncludeHandler,

// if mac then we need IRCompiler and IRRootSignature

pub fn init(
    temp_allocator: std.mem.Allocator,
    cwd: std.Io.Dir,
    io: std.Io,
) !ShaderCompiler {
    var dylib = std.DynLib.open(switch (builtin.os.tag) {
        .windows => "dxcompiler.dll",
        .macos => "./libdxcompiler.dylib",
        else => "./libdxcompiler.so",
    }) catch {
        return error.MissingDxcCompilerLibrary;
    };
    errdefer dylib.close();

    const create_instance_proc = dylib.lookup(
        dxc.CreateInstanceProc,
        "DxcCreateInstance",
    ) orelse {
        return error.MissingDxcCreateInstance;
    };

    var compiler: ?*dxc.ICompiler3 = null;
    _ = create_instance_proc(
        &dxc.CLSID_Compiler,
        win32.riid(dxc.ICompiler3),
        @ptrCast(&compiler),
    );
    errdefer {
        if (compiler) |c| _ = c.iunknown.Release();
    }
    var utils: ?*dxc.IUtils = null;
    _ = create_instance_proc(
        &dxc.CLSID_Utils,
        win32.riid(dxc.IUtils),
        @ptrCast(&utils),
    );
    errdefer {
        if (utils) |u| _ = u.iunknown.Release();
    }

    return .{
        .cwd = cwd,
        .arena = .init(temp_allocator),
        .io = io,
        .lib = dylib,
        .dxc_compiler = compiler.?,
        .dxc_utils = utils.?,
        .include_handler = .{
            .ref = .init(1),
        },
    };
}

pub fn deinit(self: *ShaderCompiler) void {
    _ = self.dxc_compiler.iunknown.Release();
    _ = self.dxc_utils.iunknown.Release();
    self.arena.deinit();
    _ = self.lib.close();
}

pub fn compile(self: *ShaderCompiler, allocator: std.mem.Allocator, desc: Desc) ![]u8 {
    const source_buffer: dxc.Buffer = .{
        .Ptr = @ptrCast(desc.source.ptr),
        .Size = @intCast(desc.source.len),
        .Encoding = .UTF8,
    };

    _ = self.arena.reset(.retain_capacity);

    const temp = self.arena.allocator();
    var args: std.ArrayList(win32.LPCWSTR) = try .initCapacity(temp, 16);

    const file_path_wide = try std.unicode.utf8ToUtf16LeAllocZ(
        temp,
        desc.file_path,
    );
    const entry_point_wide = try std.unicode.utf8ToUtf16LeAllocZ(
        temp,
        desc.entry_point,
    );
    const target_profile = switch (desc.stage) {
        .vertex => win32.L("vs_6_6"),
        .fragment => win32.L("ps_6_6"),
        .compute => win32.L("cs_6_6"),
        // else => return error.UnsupportedShaderStage,
    };
    try args.appendSlice(temp, &.{
        file_path_wide.ptr,
        win32.L("-E"),
        entry_point_wide.ptr,
        win32.L("-T"),
        target_profile.ptr,
    });

    for (desc.defines) |define| {
        const define_wide = try std.unicode.utf8ToUtf16LeAllocZ(
            temp,
            define,
        );
        try args.appendSlice(temp, &.{
            win32.L("-D"),
            @ptrCast(define_wide.ptr),
        });
    }

    switch (desc.target_backend) {
        .d3d12 => {
            try args.appendSlice(temp, &.{
                win32.L("-D"),
                win32.L("BACKEND_D3D12"),
            });
        },
        .vulkan => {
            try args.appendSlice(temp, &.{
                win32.L("-D"),
                win32.L("BACKEND_VULKAN"),
                win32.L("-spirv"),
            });
        },
        else => @panic("Unsupported backend"),
    }

    const optimization_level_arg: win32.LPCWSTR = switch (desc.optimization_level) {
        .none => win32.L("-O0"),
        .o1 => win32.L("-O1"),
        .o2 => win32.L("-O2"),
        .o3 => win32.L("-O3"),
    };
    try args.append(temp, optimization_level_arg);

    if (builtin.os.tag != .windows) {
        try args.appendSlice(temp, &.{
            win32.L("-Vd"),
        });
    }

    var result: ?*dxc.IResult = null;
    const hr = self.dxc_compiler.Compile(
        &source_buffer,
        @ptrCast(args.items.ptr),
        @intCast(args.items.len),
        @ptrCast(&self.include_handler),
        win32.riid(dxc.IResult),
        @ptrCast(&result),
    );
    if (win32.S_OK != hr) {
        return error.ShaderCompilationFailed;
    }
    defer {
        if (result) |r| _ = r.iunknown.Release();
    }
    const compilation_result = result.?;

    var errors_blob: ?*dxc.IBlobUtf8 = null;
    _ = compilation_result.GetOutput(
        .ERRORS,
        win32.riid(dxc.IBlobUtf8),
        @ptrCast(&errors_blob),
        null,
    );
    defer {
        if (errors_blob) |e| _ = e.iunknown.Release();
    }

    if (errors_blob) |errs| {
        const msg = errs.getSlice();
        if (msg.len != 0) {
            std.debug.print("Shader compilation errors:\n{s}\n", .{msg});
            return error.ShaderCompilationFailed;
        }
    }

    var shader_blob: ?*d3dcommon.IBlob = null;
    const hr_blob = compilation_result.GetOutput(
        .OBJECT,
        win32.riid(d3dcommon.IBlob),
        @ptrCast(&shader_blob),
        null,
    );
    if (win32.S_OK != hr_blob or shader_blob == null) {
        return error.ShaderCompilationFailed;
    }
    defer {
        if (shader_blob) |s| _ = s.iunknown.Release();
    }

    const shader_data = shader_blob.?.getSlice();
    const out_data = try allocator.dupe(u8, shader_data);
    return out_data;
}

pub const IncludeHandler = extern struct {
    vtable: *const dxc.IIncludeHandler.VTable = &.{
        .base = .{
            .QueryInterface = @ptrCast(&queryInterface),
            .AddRef = @ptrCast(&addRef),
            .Release = @ptrCast(&release),
        },
        .LoadSource = @ptrCast(&loadSource),
    },
    ref: std.atomic.Value(win32.ULONG),

    pub fn compiler(self: *IncludeHandler) *ShaderCompiler {
        return @fieldParentPtr("include_handler", self);
    }

    pub fn loadSource(
        self: *IncludeHandler,
        pFilename: win32.LPCWSTR,
        ppIncludeSource: *?*d3dcommon.IBlob,
    ) callconv(.winapi) win32.HRESULT {
        var filename_buf: [260]u8 = undefined;
        const len = std.unicode.utf16LeToUtf8(&filename_buf, std.mem.span(pFilename)) catch
            {
                std.debug.print("IncludeHandler: Failed to convert filename from UTF-16 to UTF-8\n", .{});
                return win32.E_OUTOFMEMORY;
            };
        const path = filename_buf[0..len];
        const c = self.compiler();
        const arena = c.arena.allocator();
        const stat = c.cwd.statPath(c.io, path, .{}) catch |err| switch (err) {
            error.FileNotFound => return win32.E_FILE_NOT_FOUND,
            // error.OutOfMemory => return win32.E_OUTOFMEMORY,
            else => return win32.E_FAIL,
        };
        const data = c.cwd.readFile(
            c.io,
            path,
            arena.alloc(u8, stat.size) catch return win32.E_OUTOFMEMORY,
        ) catch |err| switch (err) {
            error.FileNotFound => return win32.E_FILE_NOT_FOUND,
            // error.OutOfMemory => return win32.E_OUTOFMEMORY,
            else => return win32.E_FAIL,
        };
        defer arena.free(data);

        ppIncludeSource.* = null;

        return c.dxc_utils.CreateBlob(
            @ptrCast(data.ptr),
            @intCast(data.len),
            .UTF8,
            @ptrCast(ppIncludeSource),
        );
    }

    pub fn addRef(self: *IncludeHandler) callconv(.winapi) win32.ULONG {
        const value = self.ref.fetchAdd(1, .seq_cst);
        return value + 1;
    }

    pub fn release(self: *IncludeHandler) callconv(.winapi) win32.ULONG {
        const value = self.ref.fetchSub(1, .seq_cst);
        if (value == 1) {
            // we should free self but, delegate it to users of this IncludeHandler
        }
        return value - 1;
    }

    pub fn queryInterface(
        self: *IncludeHandler,
        riid: *const win32.GUID,
        ppvObject: ?*?*anyopaque,
    ) callconv(.winapi) win32.HRESULT {
        if (win32.isEqualIID(riid, win32.riid(dxc.IIncludeHandler))) {
            if (ppvObject) |out| {
                out.* = @ptrCast(self);
                _ = self.addRef();
                return win32.S_OK;
            } else {
                return win32.E_POINTER;
            }
        } else if (win32.isEqualIID(riid, win32.riid(win32.IUnknown))) {
            if (ppvObject) |out| {
                out.* = @ptrCast(self);
                _ = self.addRef();
                return win32.S_OK;
            } else {
                return win32.E_POINTER;
            }
        } else {
            if (ppvObject) |out| {
                out.* = null;
            }
            return win32.E_NOINTERFACE;
        }
    }
};

const std = @import("std");
const builtin = @import("builtin");

const windows = @import("../windows/root.zig");
const win32 = windows.win32;
const dxc = windows.dxc;
const d3dcommon = windows.d3dcommon;

// const Source = @import("../content/root.zig").Source;
