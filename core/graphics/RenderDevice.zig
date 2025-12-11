const RenderDevice = @This();

allocator: std.mem.Allocator,
interface: gpu.Interface,

swapchains: [max_blit_swapchains]*gpu.Swapchain,
swapchain_count: usize,

// frame stuff
frame_fence: *gpu.Fence,
current_frame_fence_value: u64,
frame_fence_values: [gpu.backbuffer_count]u64,
command_lists: [gpu.backbuffer_count]*gpu.CommandList,

// compute stuff
compute_fence: *gpu.Fence,
compute_fence_value: usize,
compute_command_lists: [gpu.backbuffer_count]*gpu.CommandList,

// per frame constants
constant_allocators: [gpu.backbuffer_count]gpu.utils.LinearAllocatedBuffer,

pub fn init(allocator: std.mem.Allocator, options: gpu.Options) Error!RenderDevice {
    const interface = try gpu.init(allocator, options);
    errdefer interface.deinit();

    var buf: [256]u8 = undefined;
    const frame_fence = try interface.createFence(
        allocator,
        "frame_fence",
    );
    errdefer interface.destroyFence(frame_fence);

    var command_lists: [gpu.backbuffer_count]*gpu.CommandList = undefined;
    var command_lists_initialized: usize = 0;
    errdefer for (command_lists[0..command_lists_initialized]) |cmd| {
        interface.destroyCommandList(cmd);
    };
    for (0..gpu.backbuffer_count) |i| {
        const name = std.fmt.bufPrint(&buf, "Command List {}", .{i}) catch "Command List ?";
        command_lists[i] = try interface.createCommandList(
            allocator,
            .graphics,
            name,
        );
        command_lists_initialized += 1;
    }

    const compute_fence = try interface.createFence(allocator, "compute_fence");
    errdefer interface.destroyFence(compute_fence);

    var compute_command_lists: [gpu.backbuffer_count]*gpu.CommandList = undefined;
    var compute_command_lists_initialized: usize = 0;
    errdefer for (compute_command_lists[0..compute_command_lists_initialized]) |cmd| {
        interface.destroyCommandList(cmd);
    };
    for (0..gpu.backbuffer_count) |i| {
        const name = std.fmt.bufPrint(&buf, "Compute Command List {}", .{i}) catch "Compute Command List ?";
        compute_command_lists[i] = try interface.createCommandList(allocator, .compute, name);
        compute_command_lists_initialized += 1;
    }

    var constant_allocators: [gpu.backbuffer_count]gpu.utils.LinearAllocatedBuffer = undefined;
    var constant_allocators_initialized: usize = 0;
    errdefer {
        for (constant_allocators[0..constant_allocators_initialized]) |*a| {
            a.deinit();
        }
    }

    for (0..gpu.backbuffer_count) |i| {
        constant_allocators[i] = try gpu.utils.LinearAllocatedBuffer.init(
            interface,
            allocator,
            1024 * 1024,
            "Constant Allocator",
        );
        constant_allocators_initialized += 1;
    }

    return .{
        .allocator = allocator,
        .interface = interface,
        .swapchains = @splat(undefined),
        .swapchain_count = 0,
        // frame
        .frame_fence = frame_fence,
        .current_frame_fence_value = 0,
        .frame_fence_values = @splat(0),
        .command_lists = command_lists,
        // compute
        .compute_fence = compute_fence,
        .compute_fence_value = 0,
        .compute_command_lists = compute_command_lists,
        // per frame constants
        .constant_allocators = constant_allocators,
    };
}

pub fn deinit(self: *RenderDevice) void {
    // per frame constants
    for (self.constant_allocators[0..]) |*a| {
        a.deinit();
    }

    // compute
    for (self.compute_command_lists[0..]) |cmd| {
        self.interface.destroyCommandList(cmd);
    }
    self.interface.destroyFence(self.compute_fence);

    // frame
    for (self.command_lists[0..]) |cmd| {
        self.interface.destroyCommandList(cmd);
    }
    self.interface.destroyFence(self.frame_fence);
    self.interface.deinit();
}

pub fn commandList(self: *RenderDevice) *gpu.CommandList {
    const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
    return self.command_lists[frame_index];
}

pub fn computeCommandList(self: *RenderDevice) *gpu.CommandList {
    const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
    return self.compute_command_lists[frame_index];
}

pub fn beginFrame(self: *RenderDevice) Error!void {
    const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
    {
        try self.interface.waitFence(self.frame_fence, self.frame_fence_values[frame_index]);
        self.constant_allocators[frame_index].reset();
    }
    self.interface.beginFrame();

    const cmd = self.commandList();
    self.interface.resetCommandAllocator(cmd);
    try self.interface.beginCommandList(cmd);

    const compute_cmd = self.computeCommandList();
    self.interface.resetCommandAllocator(compute_cmd);
    try self.interface.beginCommandList(compute_cmd);
}

pub fn endFrame(self: *RenderDevice) Error!void {
    const compute_cmd = self.computeCommandList();
    try self.interface.endCommandList(compute_cmd);
    self.compute_fence_value += 1;

    const cmd = self.commandList();
    try self.interface.endCommandList(cmd);

    self.current_frame_fence_value += 1;
    const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
    self.frame_fence_values[frame_index] = self.current_frame_fence_value;

    for (self.swapchains[0..self.swapchain_count]) |swapchain| {
        self.interface.commandPresentSwapchain(cmd, swapchain);
    }
    self.swapchain_count = 0;

    self.interface.commandSignalFence(cmd, self.frame_fence, self.current_frame_fence_value);
    try self.interface.submitCommandList(cmd);

    self.interface.endFrame();
}

pub fn waitGpuIdle(self: *RenderDevice) Error!void {
    try self.interface.waitFence(self.frame_fence, self.current_frame_fence_value);
}

pub fn allocateConstantBuffer(self: *RenderDevice, comptime T: type, data: T) error{OutOfMemory}!gpu_structures.BufferPtr(T) {
    const frame_index = self.interface.getFrameIndex() % gpu.backbuffer_count;
    const allocator = &self.constant_allocators[frame_index];
    const address = try allocator.alloc(@sizeOf(T));
    @memcpy(address.cpu, std.mem.asBytes(&data));
    return .{
        .buffer = self.interface.getDescriptorIndex(allocator.shader_resource_view),
        .offset = @intCast(address.offset),
    };
}

/// returns a backbuffer which is in the present state; make sure it's in present by the end of frame
pub fn useSwapchain(
    self: *RenderDevice,
    swapchain: *gpu.Swapchain,
) Error!gpu.Swapchain.Backbuffer {
    // check if it's been blitted this frame already
    for (self.swapchains[0..self.swapchain_count]) |sc| {
        // should not blit same swapchain multiple times
        if (sc == swapchain) {
            return try self.interface.getSwapchainBackbuffer(swapchain);
        }
    }
    self.swapchains[self.swapchain_count] = swapchain;
    self.swapchain_count += 1;

    try self.interface.acquireNextSwapchainImage(swapchain);
    const backbuffer = try self.interface.getSwapchainBackbuffer(swapchain);
    return backbuffer;
}

const Error = gpu.Error;
const max_blit_swapchains = 8;

const std = @import("std");
const gpu = @import("../gpu/root.zig");

const gpu_structures = @import("gpu_structures.zig");
