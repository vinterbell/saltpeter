pub const Id = enum(u64) {
    invalid = std.math.maxInt(u64),
    _,

    pub fn toInt(self: Id) u64 {
        return @intFromEnum(self);
    }
};

pub const Provider = struct {
    vtable: *const VTable,

    pub const VTable = struct {
        get: *const fn (provider: *Provider, allocator: std.mem.Allocator, id: Id) ?runtime.Asset,
        exists: *const fn (provider: *Provider, id: Id) bool,
        set: *const fn (provider: *Provider, id: Id, asset: *const runtime.Asset) void,
    };
};

const std = @import("std");
const runtime = @import("runtime.zig");
