// based off of https://github.com/karl-zylinski/odin-handle-map/blob/master/handle_map_growing/handle_map.odin
// MIT License

pub fn HandleMap(comptime T: type) type {
    std.debug.assert(@hasField(T, "handle"));
    return struct {
        const HandleMapT = @This();

        allocator: std.mem.Allocator,
        items: std.ArrayList(*T),
        item_arena: std.heap.ArenaAllocator,
        unused_items: std.ArrayList(u32),

        pub fn init(allocator: std.mem.Allocator) !HandleMapT {
            var self: HandleMapT = .{
                .allocator = allocator,
                .items = try .initCapacity(allocator, 1),
                .item_arena = .init(allocator),
                .unused_items = .empty,
            };
            // add dummy
            const dummy = self.item_arena.allocator().create(T) catch {
                self.items.deinit(allocator);
                return error.OutOfMemory;
            };
            dummy.handle = .nil;
            self.items.appendAssumeCapacity(dummy);

            return self;
        }

        pub fn deinit(self: *HandleMapT) void {
            self.items.deinit(self.allocator);
            self.unused_items.deinit(self.allocator);
            self.item_arena.deinit();
        }

        pub fn clear(self: *HandleMapT) void {
            self.items.clearRetainingCapacity();
            self.unused_items.clearRetainingCapacity();
            _ = self.item_arena.reset(.retain_capacity);
        }

        pub fn add(self: *HandleMapT, item: T) !Handle {
            if (self.unused_items.pop()) |unused_index| {
                var reused_item = self.items.items[unused_index];
                const generation = reused_item.handle.generation + 1;
                reused_item.* = item;
                reused_item.handle.index = unused_index;
                reused_item.handle.generation = generation + 1;
                return reused_item.handle;
            }

            const new_item = try self.item_arena.allocator().create(T);
            new_item.* = item;
            new_item.handle.index = @intCast(self.items.items.len);
            new_item.handle.generation = 1;
            try self.items.append(self.allocator, new_item);
            return new_item.handle;
        }

        pub fn get(self: *HandleMapT, handle: Handle) ?*T {
            if (!self.valid(handle)) {
                return null;
            }
            return self.items.items[handle.index];
        }

        pub fn remove(self: *HandleMapT, handle: Handle) ?T {
            if (!self.valid(handle)) {
                return null;
            }
            const item = self.items.items[handle.index];
            const data = item.*;
            self.unused_items.append(self.allocator, handle.index) catch {};
            item.* = undefined;
            return data;
        }

        pub fn valid(self: *const HandleMapT, handle: Handle) bool {
            if (handle.index <= 0 or handle.index >= self.items.items.len) {
                return false;
            }
            const item = self.items.items[handle.index];
            return item.handle.generation == handle.generation;
        }

        pub fn len(self: *const HandleMapT) usize {
            return @max(self.items.items.len, 1) - self.unused_items.items.len - 1;
        }

        pub const Iterator = struct {
            map: *HandleMapT,
            index: usize,

            pub fn next(self: *Iterator) ?struct { *T, Handle } {
                for (self.index..self.map.items.items.len) |i| {
                    const item = self.map.items.items[i];
                    self.index = i + 1;
                    if (item.handle.index != 0) {
                        return .{ item, item.handle };
                    }
                }
                return null;
            }
        };

        pub fn iterator(self: *HandleMapT) Iterator {
            return Iterator{
                .map = self,
                .index = 0,
            };
        }
    };
}

pub const Handle = extern struct {
    index: u32,
    generation: u32,
    pub const nil: Handle = .{ .index = 0, .generation = 0 };

    pub fn isNil(self: Handle) bool {
        return self.index == 0 and self.generation == 0;
    }
};

pub fn TypedHandle(comptime T: type) type {
    return struct {
        const TypedHandleT = @This();
        const _ = T;
        index: u32,
        generation: u32,

        pub fn fromHandle(handle: Handle) TypedHandleT {
            return .{ .index = handle.index, .generation = handle.generation };
        }

        pub fn toHandle(self: TypedHandleT) Handle {
            return .{ .index = self.index, .generation = self.generation };
        }

        pub fn isNil(self: TypedHandleT) bool {
            return self.index == 0 and self.generation == 0;
        }
    };
}

const std = @import("std");
