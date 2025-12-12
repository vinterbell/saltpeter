pub const LinearAllocatedBuffer = struct {
    interface: gpu.Interface,
    buffer: *gpu.Buffer,
    shader_resource_view: *gpu.Descriptor,
    cpu_address: []u8,
    gpu_address: u64,
    allocated_size: usize,
    total_size: usize,

    pub const zero: LinearAllocatedBuffer = .{
        .interface = undefined,
        .buffer = undefined,
        .shader_resource_view = undefined,
        .cpu_address = &.{},
        .gpu_address = 0,
        .allocated_size = 0,
        .total_size = 0,
    };

    pub const Address = struct {
        cpu: []u8,
        gpu: gpu.Buffer.GpuAddress,
        offset: usize,
    };

    pub fn init(interface: gpu.Interface, allocator: std.mem.Allocator, buffer_size: usize, name: []const u8) !LinearAllocatedBuffer {
        var self: LinearAllocatedBuffer = .zero;
        self.allocated_size = 0;
        self.interface = interface;
        self.total_size = buffer_size;

        self.buffer = try interface.createBuffer(
            allocator,
            .constantBuffer(buffer_size, .cpu_to_gpu),
            name,
        );

        self.shader_resource_view = try interface.createDescriptor(
            allocator,
            .readBuffer(.whole(self.buffer)),
            name,
        );
        errdefer interface.destroyDescriptor(self.shader_resource_view);

        // should assume that there is a cpu address since it's cpu_to_gpu
        self.cpu_address = interface.getBufferCPUAddress(self.buffer).?[0..buffer_size];
        self.gpu_address = interface.getBufferGPUAddress(self.buffer).toInt();
        return self;
    }

    pub fn deinit(self: *LinearAllocatedBuffer) void {
        self.interface.destroyDescriptor(self.shader_resource_view);
        self.interface.destroyBuffer(self.buffer);
        self.cpu_address = &.{};
        self.gpu_address = 0;
        self.allocated_size = 0;
    }

    pub fn alloc(self: *LinearAllocatedBuffer, size: u32) error{OutOfMemory}!Address {
        if (self.allocated_size + size > self.total_size) {
            return error.OutOfMemory;
        }

        const cpu_address: []u8 = self.cpu_address[self.allocated_size .. self.allocated_size + size];
        const gpu_address = self.gpu_address + self.allocated_size;
        const offset = self.allocated_size;
        self.allocated_size += roundUpTo256(size);
        return .{ .cpu = cpu_address, .gpu = @enumFromInt(gpu_address), .offset = offset };
    }

    pub fn reset(self: *LinearAllocatedBuffer) void {
        self.allocated_size = 0;
    }
};

pub const StagingBufferAllocator = struct {
    pub const buffer_size = 64 * 1024 * 1024; // 64 MB
    pub const frame_delay_cleanup = 30;
    pub const retain_buffers = 0;

    interface: gpu.Interface,
    allocator: std.mem.Allocator,
    buffers: std.ArrayList(*gpu.Buffer),
    current_buffer: usize,
    allocated_size: usize,
    last_allocated_frame: usize,

    pub fn init(interface: gpu.Interface, allocator: std.mem.Allocator, preheat_buffer_count: usize) !StagingBufferAllocator {
        var buffers: std.ArrayList(*gpu.Buffer) = try .initCapacity(allocator, preheat_buffer_count);
        errdefer buffers.deinit(allocator);

        var self: StagingBufferAllocator = .{
            .interface = interface,
            .allocator = allocator,
            .buffers = buffers,
            .current_buffer = 0,
            .allocated_size = 0,
            .last_allocated_frame = 0,
        };

        errdefer {
            for (self.buffers.items) |buffer| {
                self.interface.destroyBuffer(buffer);
            }
        }
        for (0..preheat_buffer_count) |_| {
            try self.newBuffer();
        }

        return self;
    }

    pub fn deinit(self: *StagingBufferAllocator) void {
        for (self.buffers.items) |buffer| {
            self.interface.destroyBuffer(buffer);
        }
        self.buffers.deinit(self.allocator);
    }

    pub fn allocate(self: *StagingBufferAllocator, size: usize) !gpu.Buffer.Slice {
        std.debug.assert(size <= buffer_size);

        if (self.buffers.items.len == 0) {
            try self.newBuffer();
        }

        if (self.allocated_size + size > buffer_size) {
            try self.newBuffer();
            self.current_buffer += 1;
            self.allocated_size = 0;
        }

        const buf: gpu.Buffer.Slice = .sub(
            self.buffers.items[self.current_buffer],
            self.allocated_size,
            .fromInt(size),
        );

        self.allocated_size += roundUpTo512(size);
        self.last_allocated_frame = self.interface.getFrameIndex();

        return buf;
    }

    pub fn reset(self: *StagingBufferAllocator) void {
        self.current_buffer = 0;
        self.allocated_size = 0;

        if (self.buffers.items.len > retain_buffers) {
            if (self.interface.getFrameIndex() - self.last_allocated_frame >= frame_delay_cleanup) {
                const retain_count = @min(self.buffers.items.len, retain_buffers);
                const first_free_index = (self.buffers.items.len - retain_count - 1);
                const free_slice = self.buffers.items[first_free_index..];
                for (free_slice) |buffer| {
                    self.interface.destroyBuffer(buffer);
                }
                self.buffers.shrinkRetainingCapacity(retain_count);
            }
        }
    }

    fn newBuffer(self: *StagingBufferAllocator) !void {
        const buffer = try self.interface.createBuffer(
            self.allocator,
            .constantBuffer(buffer_size, .cpu_only),
            "staging buffer",
        );

        try self.buffers.append(self.allocator, buffer);
    }
};

fn roundUpTo256(value: usize) usize {
    return (value + 255) & ~@as(usize, 255);
}

fn roundUpTo512(value: usize) usize {
    return (value + 511) & ~@as(usize, 511);
}

/// A value type static buffer or a slice. Only mutable
pub fn InlineStorage(comptime T: type, comptime N: usize) type {
    return union(enum) {
        const InlineStorageTN = @This();
        fixed: struct {
            data: [N]T,
            len: usize,
        },
        buf: []T,

        pub const empty: InlineStorageTN = .{ .buf = &.{} };

        pub fn initFixed(data: []const T) error{OutOfMemory}!InlineStorageTN {
            if (data.len > N) {
                return error.OutOfMemory;
            }
            var s: InlineStorageTN = .{ .fixed = .{ .data = undefined, .len = data.len } };
            @memcpy(s.fixed.data[0..data.len], data);
            return s;
        }

        pub fn initSlice(data: []T) InlineStorageTN {
            return .{ .buf = data };
        }

        pub fn constSlice(self: *const InlineStorageTN) []const T {
            return switch (self.*) {
                .fixed => |*f| f.data[0..f.len],
                .buf => |b| b,
            };
        }

        pub fn slice(self: *InlineStorageTN) []T {
            return switch (self.*) {
                .fixed => |*f| f.data[0..f.len],
                .buf => |b| b,
            };
        }

        pub fn len(self: *const InlineStorageTN) usize {
            return switch (self.*) {
                .fixed => |f| f.len,
                .buf => |b| b.len,
            };
        }
    };
}

pub const UploadStage = struct {
    interface: gpu.Interface,
    allocator: std.mem.Allocator,
    texture_dst_alignment: u32,

    fence: *gpu.Fence,
    current_fence_value: u64,
    fence_values: [gpu.backbuffer_count]u64,
    command_lists: [gpu.backbuffer_count]*gpu.CommandList,
    staging_buffers: [gpu.backbuffer_count]StagingBufferAllocator,
    needs_transition: bool,

    pending_texture_uploads: std.ArrayList(TextureUpload),
    pending_buffer_uploads: std.ArrayList(BufferUpload),

    const max_texture_uploads_per_frame = 512;
    const max_buffer_uploads_per_frame = 512;

    pub const TextureUpload = struct {
        destination: gpu.Texture.Slice,
        staging_buffer: gpu.Buffer.Slice,
    };

    pub const BufferUpload = struct {
        destination: gpu.Buffer.Location,
        staging_buffer: gpu.Buffer.Slice,
    };

    pub fn init(allocator: std.mem.Allocator, interface: gpu.Interface) !UploadStage {
        const upload_fence = try interface.createFence(allocator, "upload stage fence");
        errdefer interface.destroyFence(upload_fence);

        var upload_command_lists: [gpu.backbuffer_count]*gpu.CommandList = undefined;
        var staging_buffers: [gpu.backbuffer_count]StagingBufferAllocator = undefined;
        var upload_command_lists_initialized: usize = 0;
        var staging_buffers_initialized: usize = 0;
        errdefer {
            for (upload_command_lists[0..upload_command_lists_initialized]) |cmd| {
                interface.destroyCommandList(cmd);
            }

            for (staging_buffers[0..staging_buffers_initialized]) |*a| {
                a.deinit();
            }
        }

        var buf: [256]u8 = undefined;
        for (0..gpu.backbuffer_count) |i| {
            const name = std.fmt.bufPrint(&buf, "Upload Command List {}", .{i}) catch "Upload Command List ?";
            upload_command_lists[i] = try interface.createCommandList(allocator, .copy, name);
            upload_command_lists_initialized += 1;
            staging_buffers[i] = try .init(interface, allocator, 0);
            staging_buffers_initialized += 1;
        }

        var pending_texture_uploads: std.ArrayList(TextureUpload) = try .initCapacity(allocator, max_texture_uploads_per_frame);
        errdefer pending_texture_uploads.deinit(allocator);

        var pending_buffer_uploads: std.ArrayList(BufferUpload) = try .initCapacity(allocator, max_buffer_uploads_per_frame);
        errdefer pending_buffer_uploads.deinit(allocator);

        const texture_dst_alignment: u32 = if (interface.getInterfaceOptions().backend == .d3d12) 512 else 1;

        const needs_transition = if (interface.getInterfaceOptions().backend == .vulkan) true else false;

        return .{
            .interface = interface,
            .allocator = allocator,
            .texture_dst_alignment = texture_dst_alignment,
            .fence = upload_fence,
            .current_fence_value = 0,
            .fence_values = @splat(0),
            .command_lists = upload_command_lists,
            .staging_buffers = staging_buffers,
            .pending_texture_uploads = pending_texture_uploads,
            .pending_buffer_uploads = pending_buffer_uploads,
            .needs_transition = needs_transition,
        };
    }

    pub fn deinit(self: *UploadStage) void {
        self.interface.destroyFence(self.fence);
        for (self.command_lists[0..]) |cmd| {
            self.interface.destroyCommandList(cmd);
        }
        for (self.staging_buffers[0..]) |*a| {
            a.deinit();
        }
        self.pending_texture_uploads.deinit(self.allocator);
        self.pending_buffer_uploads.deinit(self.allocator);
    }

    pub fn commandList(self: *UploadStage) *gpu.CommandList {
        const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
        return self.command_lists[frame_index];
    }

    pub fn reset(self: *UploadStage) void {
        const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
        self.staging_buffers[frame_index].reset();
    }

    pub fn doUploads(self: *UploadStage, graphics_cmd: *gpu.CommandList) gpu.Error!void {
        if (self.pending_buffer_uploads.items.len == 0 and self.pending_texture_uploads.items.len == 0) {
            return;
        }

        const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
        try self.interface.waitFence(self.fence, self.fence_values[frame_index]);

        const cmd = self.commandList();
        self.interface.resetCommandAllocator(cmd);
        try self.interface.beginCommandList(cmd);
        {
            for (self.pending_buffer_uploads.items) |upload| {
                self.interface.commandCopyBufferToBuffer(
                    cmd,
                    upload.staging_buffer.location(0),
                    upload.destination,
                    upload.staging_buffer.size,
                );
            }

            for (self.pending_texture_uploads.items) |upload| {
                self.interface.commandCopyBufferToTexture(
                    cmd,
                    upload.staging_buffer.location(0),
                    upload.destination,
                );
            }
        }
        try self.interface.endCommandList(cmd);
        self.current_fence_value += 1;
        self.fence_values[frame_index] = self.current_fence_value;

        self.interface.commandSignalFence(cmd, self.fence, self.current_fence_value);
        try self.interface.submitCommandList(cmd);

        // TODO: transition barriers for vulkan

        if (self.needs_transition) {
            for (self.pending_texture_uploads.items) |upload| {
                const desc = self.interface.getTextureDesc(upload.destination.texture);
                self.interface.commandTextureBarrier(
                    graphics_cmd,
                    upload.destination.texture,
                    desc.calcSubresource(
                        upload.destination.mip_level,
                        upload.destination.depth_or_array_layer,
                    ),
                    .{ .copy_dst = true },
                    .read,
                );
            }
        }

        self.pending_buffer_uploads.clearRetainingCapacity();
        self.pending_texture_uploads.clearRetainingCapacity();
    }

    pub fn uploadTexture(
        self: *UploadStage,
        texture: *gpu.Texture,
        data: []const u8,
    ) !void {
        const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
        const staging_buffer_allocator = &self.staging_buffers[frame_index];

        const required_size = self.interface.getTextureRequiredStagingSize(texture);
        const bufslice = try staging_buffer_allocator.allocate(required_size);

        const desc = self.interface.getTextureDesc(texture);
        const destination_data = (self.interface.getBufferCPUAddress(bufslice.buffer) orelse
            @panic("Staging buffer not CPU accessible"))[bufslice.offset..][0..required_size];

        var dst_offset: u32 = 0;
        var src_offset: u32 = 0;

        const min_width = desc.format.getBlockWidth();
        const min_height = desc.format.getBlockHeight();

        for (0..desc.depth_or_array_layers) |slice| {
            for (0..desc.mip_levels) |mip| {
                const width = @max(desc.width >> @as(u5, @intCast(mip)), min_width);
                const height = @max(desc.height >> @as(u5, @intCast(mip)), min_height);
                const depth = @max(desc.depth_or_array_layers >> @as(u5, @intCast(mip)), 1);

                const source_row_pitch = desc.format.getRowPitch(width) * desc.format.getBlockHeight();
                const destination_row_pitch = self.interface.getTextureRowPitch(
                    texture,
                    @intCast(mip),
                );

                const row_num = @divTrunc(height, desc.format.getBlockHeight());

                imageCopy(
                    destination_data[dst_offset..].ptr,
                    destination_row_pitch,
                    data[src_offset..].ptr,
                    source_row_pitch,
                    row_num,
                    depth,
                );

                try self.pending_texture_uploads.appendBounded(.{
                    .destination = .mipAndDepthOrLayer(texture, @intCast(mip), @intCast(slice)),
                    .staging_buffer = bufslice.offsetted(dst_offset),
                });

                dst_offset += roundUpPow2(
                    destination_row_pitch * row_num,
                    self.texture_dst_alignment,
                );
                src_offset += source_row_pitch * row_num;
            }
        }
    }

    pub fn uploadBuffer(
        self: *UploadStage,
        slice: gpu.Buffer.Location,
        data: []const u8,
    ) !void {
        const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
        const staging_buffer_allocator = &self.staging_buffers[frame_index];

        const bufslice = try staging_buffer_allocator.allocate(data.len);
        const destination_data = (self.interface.getBufferCPUAddress(bufslice.buffer) orelse
            @panic("Staging buffer not CPU accessible"))[bufslice.offset..][0..data.len];

        @memcpy(destination_data, data);

        try self.pending_buffer_uploads.appendBounded(.{
            .destination = slice,
            .staging_buffer = bufslice,
        });
    }

    fn roundUpPow2(value: u32, pow2: u32) u32 {
        return (value + pow2 - 1) & ~(pow2 - 1);
    }

    fn imageCopy(
        desination: [*]u8,
        destination_row_pitch: u32,
        source: [*]const u8,
        source_row_pitch: u32,
        row_num: u32,
        depth: u32,
    ) void {
        const src_slice_size = source_row_pitch * row_num;
        const dst_slice_size = destination_row_pitch * row_num;

        for (0..depth) |z| {
            const dst_slice = desination[z * dst_slice_size ..][0..dst_slice_size];
            const src_slice = source[z * src_slice_size ..][0..src_slice_size];

            for (0..row_num) |row| {
                @memcpy(
                    dst_slice[row * destination_row_pitch ..][0..source_row_pitch],
                    src_slice[row * source_row_pitch ..][0..source_row_pitch],
                );
            }
        }
    }

    pub fn removeUploadsReferencingTexture(self: *UploadStage, texture: *gpu.Texture) void {
        var i: isize = @intCast(self.pending_texture_uploads.items.len - 1);
        while (i >= 0) : (i -|= 1) {
            if (self.pending_texture_uploads.items[@intCast(i)].destination.texture == texture) {
                _ = self.pending_texture_uploads.swapRemove(@intCast(i));
            }
        }
    }

    pub fn removeUploadsReferencingBuffer(self: *UploadStage, buffer: *gpu.Buffer) void {
        var i: isize = @intCast(self.pending_buffer_uploads.items.len - 1);
        while (i >= 0) : (i -|= 1) {
            if (self.pending_buffer_uploads.items[@intCast(i)].destination.buffer == buffer) {
                _ = self.pending_buffer_uploads.swapRemove(@intCast(i));
            }
        }
    }
};

/// when `nextBuffer` is called, the buffer it moves to is returned to be processed/deleted
pub fn StaticRingBuffer(comptime T: type, comptime buffer_frames: usize, comptime max_items: usize) type {
    return struct {
        const StaticRingBufferT = @This();

        buffers: [buffer_frames + 1][max_items]T = undefined,
        buffer_lens: [buffer_frames + 1]usize = @splat(0),
        current_buffer_index: usize = 0,

        pub const empty: StaticRingBufferT = .{};

        pub fn buffer(self: *StaticRingBufferT, index: usize) []T {
            return self.buffers[index][0..self.buffer_lens[index]];
        }

        /// process the items returned in the slice to be deleted
        pub fn nextBuffer(self: *StaticRingBufferT) []const T {
            self.current_buffer_index = (self.current_buffer_index + 1) % (buffer_frames + 1);
            const slice = self.buffer(self.current_buffer_index);
            self.buffer_lens[self.current_buffer_index] = 0;
            return slice;
        }

        pub fn add(self: *StaticRingBufferT, item: T) void {
            const len = self.buffer_lens[self.current_buffer_index];
            self.buffers[self.current_buffer_index][len] = item;
            self.buffer_lens[self.current_buffer_index] += 1;
        }
    };
}

const std = @import("std");
const gpu = @import("root.zig");
