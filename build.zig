const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_module = b.addModule("core", .{
        .root_source_file = b.path("core/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    core_module.addCSourceFile(.{
        .file = b.path("core/assets/stb.c"),
    });

    if (target.result.os.tag == .windows) {
        core_module.addCSourceFile(.{
            .file = b.path("core/gpu/d3d12/build.cpp"),
            .flags = &.{
                "-std=c++17",
                "-fno-sanitize=undefined",
                // does this == NULL for some reason?
                "-Wno-tautological-undefined-compare",
                // code handles all cases except for TYPE_COUNT, should fix but oh well...
                "-Wno-switch",
            },
        });
    }

    const runtime_module = b.addModule("runtime", .{
        .root_source_file = b.path("runtime/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sp", .module = core_module },
        },
    });

    const runtime_exe = b.addExecutable(.{
        .name = "runtime",
        .root_module = runtime_module,
    });
    b.installArtifact(runtime_exe);

    const run_step = b.step("run:runtime", "Run the runtime executable");

    const run_runtime = b.addRunArtifact(runtime_exe);
    run_step.dependOn(&run_runtime.step);

    run_step.dependOn(b.getInstallStep());
}
