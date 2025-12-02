const Interface = @This();

pub fn deinit(self: Interface) void {
    self.vtable.deinit(self.data);
}

pub fn getInterfaceOptions(self: Interface) *const gpu.Options {
    return self.vtable.get_interface_options(self.data);
}

pub fn beginFrame(self: Interface) void {
    self.vtable.begin_frame(self.data);
}

pub fn endFrame(self: Interface) void {
    self.vtable.end_frame(self.data);
}

pub fn getFrameIndex(self: Interface) usize {
    return self.vtable.get_frame_index(self.data);
}

pub fn shutdown(self: Interface) void {
    self.vtable.shutdown(self.data);
}

// buffer
pub fn createBuffer(
    self: Interface,
    allocator: std.mem.Allocator,
    desc: Buffer.Desc,
    debug_name: []const u8,
) Error!*Buffer {
    return self.vtable.create_buffer(self.data, allocator, &desc, debug_name);
}

pub fn destroyBuffer(self: Interface, buffer: *Buffer) void {
    self.vtable.destroy_buffer(self.data, buffer);
}

pub fn getBufferDesc(self: Interface, buffer: *const Buffer) *const Buffer.Desc {
    return self.vtable.get_buffer_desc(self.data, buffer);
}

pub fn getBufferCPUAddress(self: Interface, buffer: *Buffer) ?[*]u8 {
    return self.vtable.get_buffer_cpu_address(self.data, buffer);
}

pub fn getBufferGPUAddress(self: Interface, buffer: *Buffer) Buffer.GpuAddress {
    return self.vtable.get_buffer_gpu_address(self.data, buffer);
}

pub fn getBufferRequiredStagingSize(self: Interface, desc: *const Buffer) usize {
    return self.vtable.get_buffer_required_staging_size(self.data, desc);
}

// command list
pub fn createCommandList(
    self: Interface,
    allocator: std.mem.Allocator,
    queue: Queue,
    debug_name: []const u8,
) Error!*CommandList {
    return self.vtable.create_command_list(self.data, allocator, queue, debug_name);
}

pub fn destroyCommandList(self: Interface, cmd_list: *CommandList) void {
    self.vtable.destroy_command_list(self.data, cmd_list);
}

pub fn resetCommandAllocator(self: Interface, cmd_list: *CommandList) void {
    self.vtable.reset_command_allocator(self.data, cmd_list);
}

pub fn beginCommandList(self: Interface, cmd_list: *CommandList) Error!void {
    try self.vtable.begin_command_list(self.data, cmd_list);
}

pub fn endCommandList(self: Interface, cmd_list: *CommandList) Error!void {
    try self.vtable.end_command_list(self.data, cmd_list);
}

pub fn commandWaitOnFence(
    self: Interface,
    cmd_list: *CommandList,
    fence: *Fence,
    fence_value: u64,
) void {
    self.vtable.command_wait_on_fence(self.data, cmd_list, fence, fence_value);
}

pub fn commandSignalFence(
    self: Interface,
    cmd_list: *CommandList,
    fence: *Fence,
    fence_value: u64,
) Error!void {
    try self.vtable.command_signal_fence(self.data, cmd_list, fence, fence_value);
}

pub fn commandPresentSwapchain(
    self: Interface,
    cmd_list: *CommandList,
    swapchain: *Swapchain,
) Error!void {
    try self.vtable.command_present_swapchain(self.data, cmd_list, swapchain);
}

pub fn submitCommandList(self: Interface, cmd_list: *CommandList) Error!void {
    try self.vtable.submit_command_list(self.data, cmd_list);
}

pub fn resetCommandList(self: Interface, cmd_list: *CommandList) void {
    self.vtable.reset_command_list(self.data, cmd_list);
}

pub fn commandTextureBarrier(
    self: Interface,
    cmd_list: *CommandList,
    texture: *Texture,
    subresource: u32,
    old_access: Access,
    new_access: Access,
) void {
    self.vtable.command_texture_barrier(
        self.data,
        cmd_list,
        texture,
        subresource,
        old_access,
        new_access,
    );
}

pub fn commandBufferBarrier(
    self: Interface,
    cmd_list: *CommandList,
    buffer: *Buffer,
    old_access: Access,
    new_access: Access,
) void {
    self.vtable.command_buffer_barrier(
        self.data,
        cmd_list,
        buffer,
        old_access,
        new_access,
    );
}

pub fn commandGlobalBarrier(
    self: Interface,
    cmd_list: *CommandList,
    old_access: Access,
    new_access: Access,
) void {
    self.vtable.command_global_barrier(
        self.data,
        cmd_list,
        old_access,
        new_access,
    );
}

pub fn commandFlushBarriers(self: Interface, cmd_list: *CommandList) void {
    self.vtable.command_flush_barriers(self.data, cmd_list);
}

pub fn commandBindPipeline(self: Interface, cmd_list: *CommandList, pipeline: *Pipeline) void {
    self.vtable.command_bind_pipeline(self.data, cmd_list, pipeline);
}

pub fn commandSetGraphicsConstants(
    self: Interface,
    cmd_list: *CommandList,
    slot: ConstantSlot,
    comptime T: type,
    data: T,
) Error!void {
    return self.commandSetGraphicsConstantsBytes(
        cmd_list,
        slot,
        @as([]const u8, @ptrCast(&data)),
    );
}

pub fn commandSetGraphicsConstantsBytes(
    self: Interface,
    cmd_list: *CommandList,
    slot: ConstantSlot,
    data: []const u8,
) Error!void {
    return self.vtable.command_set_graphics_constants(self.data, cmd_list, slot, data);
}

pub fn commandSetComputeConstants(
    self: Interface,
    cmd_list: *CommandList,
    slot: ConstantSlot,
    comptime T: type,
    data: T,
) Error!void {
    return self.commandSetComputeConstantsBytes(
        cmd_list,
        slot,
        @as([]const u8, &data),
    );
}

pub fn commandSetComputeConstantsBytes(
    self: Interface,
    cmd_list: *CommandList,
    slot: ConstantSlot,
    data: []const u8,
) Error!void {
    return self.vtable.command_set_compute_constants(self.data, cmd_list, slot, data);
}

pub fn commandBeginRenderPass(
    self: Interface,
    cmd_list: *CommandList,
    desc: RenderPass.Desc,
) Error!void {
    try self.vtable.command_begin_render_pass(self.data, cmd_list, &desc);
}

pub fn commandEndRenderPass(self: Interface, cmd_list: *CommandList) Error!void {
    try self.vtable.command_end_render_pass(self.data, cmd_list);
}

pub fn commandSetViewports(
    self: Interface,
    cmd_list: *CommandList,
    viewports: []const spatial.Viewport,
) void {
    self.vtable.command_set_viewports(self.data, cmd_list, viewports);
}

pub fn commandSetScissors(
    self: Interface,
    cmd_list: *CommandList,
    scissors: []const spatial.Rect,
) void {
    self.vtable.command_set_scissors(self.data, cmd_list, scissors);
}

pub fn commandSetBlendConstants(
    self: Interface,
    cmd_list: *CommandList,
    blend_constants: [4]f32,
) void {
    self.vtable.command_set_blend_constants(self.data, cmd_list, blend_constants);
}

pub fn commandSetStencilReference(
    self: Interface,
    cmd_list: *CommandList,
    reference: u32,
) void {
    self.vtable.command_set_stencil_reference(self.data, cmd_list, reference);
}

pub fn commandBindIndexBuffer(
    self: Interface,
    cmd_list: *CommandList,
    slice: Buffer.Slice,
    format: IndexFormat,
) void {
    self.vtable.command_bind_index_buffer(self.data, cmd_list, slice, format);
}

pub fn commandDraw(
    self: Interface,
    cmd_list: *CommandList,
    vertex_count: u32,
    instance_count: u32,
    start_vertex: u32,
    start_instance: u32,
) void {
    self.vtable.command_draw(
        self.data,
        cmd_list,
        vertex_count,
        instance_count,
        start_vertex,
        start_instance,
    );
}

pub fn commandDrawIndexed(
    self: Interface,
    cmd_list: *CommandList,
    index_count: u32,
    instance_count: u32,
    start_index: u32,
    base_vertex: i32,
    start_instance: u32,
) void {
    self.vtable.command_draw_indexed(
        self.data,
        cmd_list,
        index_count,
        instance_count,
        start_index,
        base_vertex,
        start_instance,
    );
}

pub fn commandDrawIndirect(
    self: Interface,
    cmd_list: *CommandList,
    slice: Buffer.Slice,
    max_draw_count: u32,
) void {
    self.vtable.command_draw_indirect(self.data, cmd_list, slice, max_draw_count);
}

pub fn commandDrawIndexedIndirect(
    self: Interface,
    cmd_list: *CommandList,
    slice: Buffer.Slice,
    max_draw_count: u32,
) void {
    self.vtable.command_draw_indexed_indirect(self.data, cmd_list, slice, max_draw_count);
}

pub fn commandMultiDrawIndirect(
    self: Interface,
    cmd_list: *CommandList,
    slice: Buffer.Slice,
    count: Buffer.Location,
) void {
    self.vtable.command_multi_draw_indirect(self.data, cmd_list, slice, count);
}

pub fn commandMultiDrawIndexedIndirect(
    self: Interface,
    cmd_list: *CommandList,
    slice: Buffer.Slice,
    count: Buffer.Location,
) void {
    self.vtable.command_multi_draw_indexed_indirect(self.data, cmd_list, slice, count);
}

pub fn commandDispatch(
    self: Interface,
    cmd_list: *CommandList,
    group_count_x: u32,
    group_count_y: u32,
    group_count_z: u32,
) void {
    self.vtable.command_dispatch(
        self.data,
        cmd_list,
        group_count_x,
        group_count_y,
        group_count_z,
    );
}

pub fn commandDispatchIndirect(
    self: Interface,
    cmd_list: *CommandList,
    slice: Buffer.Slice,
) void {
    self.vtable.command_dispatch_indirect(self.data, cmd_list, slice);
}

pub fn commandWriteIntBuffer(
    self: Interface,
    cmd_list: *CommandList,
    location: Buffer.Location,
    value: u32,
) void {
    self.vtable.command_write_int_buffer(self.data, cmd_list, location, value);
}

pub fn commandCopyBufferToTexture(
    self: Interface,
    cmd_list: *CommandList,
    src: Buffer.Location,
    dst: Texture.Slice,
) void {
    self.vtable.command_copy_buffer_to_texture(self.data, cmd_list, src, dst);
}

pub fn commandCopyTextureToBuffer(
    self: Interface,
    cmd_list: *CommandList,
    src: Texture.Slice,
    dst: Buffer.Location,
) void {
    self.vtable.command_copy_texture_to_buffer(self.data, cmd_list, src, dst);
}

pub fn commandCopyTextureToTexture(
    self: Interface,
    cmd_list: *CommandList,
    src: Texture.Slice,
    dst: Texture.Slice,
) void {
    self.vtable.command_copy_texture_to_texture(self.data, cmd_list, src, dst);
}

pub fn commandCopyBufferToBuffer(
    self: Interface,
    cmd_list: *CommandList,
    src: Buffer.Location,
    dst: Buffer.Location,
    size: Size,
) void {
    self.vtable.command_copy_buffer_to_buffer(self.data, cmd_list, src, dst, size);
}

// fence
pub fn createFence(self: Interface, allocator: std.mem.Allocator, debug_name: []const u8) Error!*Fence {
    return self.vtable.create_fence(self.data, allocator, debug_name);
}

pub fn destroyFence(self: Interface, fence: *Fence) void {
    self.vtable.destroy_fence(self.data, fence);
}

pub fn signalFence(self: Interface, fence: *Fence, value: u64) void {
    self.vtable.signal_fence(self.data, fence, value);
}

pub fn waitFence(self: Interface, fence: *Fence, value: u64) Error!void {
    try self.vtable.wait_fence(self.data, fence, value);
}

// descriptor
pub fn createDescriptor(
    self: Interface,
    allocator: std.mem.Allocator,
    desc: Descriptor.Desc,
    debug_name: []const u8,
) Error!*Descriptor {
    return self.vtable.create_descriptor(self.data, allocator, &desc, debug_name);
}

pub fn destroyDescriptor(self: Interface, descriptor: *Descriptor) void {
    self.vtable.destroy_descriptor(self.data, descriptor);
}

pub fn getDescriptorIndex(self: Interface, descriptor: *const Descriptor) Descriptor.Index {
    return self.vtable.get_descriptor_index(self.data, descriptor);
}

// pipeline
pub fn createGraphicsPipeline(
    self: Interface,
    allocator: std.mem.Allocator,
    desc: Pipeline.GraphicsDesc,
    debug_name: []const u8,
) Error!*Pipeline {
    return self.vtable.create_graphics_pipeline(self.data, allocator, &desc, debug_name);
}

pub fn createComputePipeline(
    self: Interface,
    allocator: std.mem.Allocator,
    desc: Pipeline.ComputeDesc,
    debug_name: []const u8,
) Error!*Pipeline {
    return self.vtable.create_compute_pipeline(self.data, allocator, &desc, debug_name);
}

pub fn destroyPipeline(self: Interface, pipeline: *Pipeline) void {
    self.vtable.destroy_pipeline(self.data, pipeline);
}

pub fn getPipelineKind(self: Interface, pipeline: *const Pipeline) Pipeline.Kind {
    return self.vtable.get_pipeline_kind(self.data, pipeline);
}

// swapchain
pub fn createSwapchain(
    self: Interface,
    allocator: std.mem.Allocator,
    desc: Swapchain.Desc,
    debug_name: []const u8,
) Error!*Swapchain {
    return self.vtable.create_swapchain(self.data, allocator, &desc, debug_name);
}

pub fn destroySwapchain(self: Interface, swapchain: *Swapchain) void {
    self.vtable.destroy_swapchain(self.data, swapchain);
}

pub fn acquireNextSwapchainImage(self: Interface, swapchain: *Swapchain) Error!void {
    return self.vtable.acquire_next_swapchain_image(self.data, swapchain);
}

pub fn getSwapchainBackbuffer(
    self: Interface,
    swapchain: *Swapchain,
) Error!Swapchain.Backbuffer {
    return self.vtable.get_swapchain_backbuffer(self.data, swapchain);
}

pub fn resizeSwapchain(
    self: Interface,
    swapchain: *Swapchain,
    width: u32,
    height: u32,
) Error!bool {
    return self.vtable.resize_swapchain(self.data, swapchain, width, height);
}

// texture
pub fn createTexture(
    self: Interface,
    allocator: std.mem.Allocator,
    desc: Texture.Desc,
    debug_name: []const u8,
) Error!*Texture {
    return self.vtable.create_texture(self.data, allocator, &desc, debug_name);
}

pub fn destroyTexture(self: Interface, texture: *Texture) void {
    self.vtable.destroy_texture(self.data, texture);
}

pub fn getTextureDesc(self: Interface, texture: *const Texture) *const Texture.Desc {
    return self.vtable.get_texture_desc(self.data, texture);
}

pub fn getTextureRequiredStagingSize(self: Interface, desc: *const Texture) usize {
    return self.vtable.get_texture_required_staging_size(self.data, desc);
}

pub fn getTextureRowPitch(self: Interface, desc: *const Texture, mip_level: u32) u32 {
    return self.vtable.get_texture_row_pitch(self.data, desc, mip_level);
}

data: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (data: *anyopaque) void,
    get_interface_options: *const fn (data: *anyopaque) *const gpu.Options,
    begin_frame: *const fn (data: *anyopaque) void,
    end_frame: *const fn (data: *anyopaque) void,
    get_frame_index: *const fn (data: *anyopaque) usize,
    shutdown: *const fn (data: *anyopaque) void,

    // buffer
    create_buffer: *const fn (data: *anyopaque, allocator: std.mem.Allocator, desc: *const Buffer.Desc, debug_name: []const u8) Error!*Buffer,
    destroy_buffer: *const fn (data: *anyopaque, buffer: *Buffer) void,
    get_buffer_desc: *const fn (data: *anyopaque, buffer: *const Buffer) *const Buffer.Desc,
    get_buffer_cpu_address: *const fn (data: *anyopaque, buffer: *Buffer) ?[*]u8,
    get_buffer_gpu_address: *const fn (data: *anyopaque, buffer: *Buffer) Buffer.GpuAddress,
    get_buffer_required_staging_size: *const fn (data: *anyopaque, desc: *const Buffer) usize,

    // command list
    create_command_list: *const fn (data: *anyopaque, allocator: std.mem.Allocator, queue: Queue, debug_name: []const u8) Error!*CommandList,
    destroy_command_list: *const fn (data: *anyopaque, cmd_list: *CommandList) void,
    reset_command_allocator: *const fn (data: *anyopaque, cmd_list: *CommandList) void,
    begin_command_list: *const fn (data: *anyopaque, cmd_list: *CommandList) Error!void,
    end_command_list: *const fn (data: *anyopaque, cmd_list: *CommandList) Error!void,
    command_wait_on_fence: *const fn (data: *anyopaque, cmd_list: *CommandList, fence: *Fence, fence_value: u64) Error!void,
    command_signal_fence: *const fn (data: *anyopaque, cmd_list: *CommandList, fence: *Fence, fence_value: u64) Error!void,
    command_present_swapchain: *const fn (data: *anyopaque, cmd_list: *CommandList, swapchain: *Swapchain) Error!void,
    submit_command_list: *const fn (data: *anyopaque, cmd_list: *CommandList) Error!void,
    reset_command_list: *const fn (data: *anyopaque, cmd_list: *CommandList) void,
    command_texture_barrier: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        texture: *Texture,
        subresource: u32,
        old_access: Access,
        new_access: Access,
    ) void,
    command_buffer_barrier: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        buffer: *Buffer,
        old_access: Access,
        new_access: Access,
    ) void,
    command_global_barrier: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        old_access: Access,
        new_access: Access,
    ) void,
    command_flush_barriers: *const fn (data: *anyopaque, cmd_list: *CommandList) void,
    command_bind_pipeline: *const fn (data: *anyopaque, cmd_list: *CommandList, pipeline: *Pipeline) void,
    command_set_graphics_constants: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        slot: ConstantSlot,
        data: []const u8,
    ) Error!void,
    command_set_compute_constants: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        slot: ConstantSlot,
        data: []const u8,
    ) Error!void,
    command_begin_render_pass: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        desc: *const RenderPass.Desc,
    ) Error!void,
    command_end_render_pass: *const fn (data: *anyopaque, cmd_list: *CommandList) Error!void,
    command_set_viewports: *const fn (data: *anyopaque, cmd_list: *CommandList, viewports: []const spatial.Viewport) void,
    command_set_scissors: *const fn (data: *anyopaque, cmd_list: *CommandList, scissors: []const spatial.Rect) void,
    command_set_blend_constants: *const fn (data: *anyopaque, cmd_list: *CommandList, blend_constants: [4]f32) void,
    command_set_stencil_reference: *const fn (data: *anyopaque, cmd_list: *CommandList, reference: u32) void,
    command_bind_index_buffer: *const fn (data: *anyopaque, cmd_list: *CommandList, slice: Buffer.Slice, format: IndexFormat) void,
    command_draw: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        vertex_count: u32,
        instance_count: u32,
        start_vertex: u32,
        start_instance: u32,
    ) void,
    command_draw_indexed: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        index_count: u32,
        instance_count: u32,
        start_index: u32,
        base_vertex: i32,
        start_instance: u32,
    ) void,
    command_draw_indirect: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        slice: Buffer.Slice,
        max_draw_count: u32,
    ) void,
    command_draw_indexed_indirect: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        slice: Buffer.Slice,
        max_draw_count: u32,
    ) void,
    command_multi_draw_indirect: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        slice: Buffer.Slice,
        count: Buffer.Location,
    ) void,
    command_multi_draw_indexed_indirect: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        slice: Buffer.Slice,
        count: Buffer.Location,
    ) void,
    command_dispatch: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        group_count_x: u32,
        group_count_y: u32,
        group_count_z: u32,
    ) void,
    command_dispatch_indirect: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        slice: Buffer.Slice,
    ) void,
    command_write_int_buffer: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        location: Buffer.Location,
        value: u32,
    ) void,
    command_copy_buffer_to_texture: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        src: Buffer.Location,
        dst: Texture.Slice,
    ) void,
    command_copy_texture_to_buffer: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        src: Texture.Slice,
        dst: Buffer.Location,
    ) void,
    command_copy_texture_to_texture: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        src: Texture.Slice,
        dst: Texture.Slice,
    ) void,
    command_copy_buffer_to_buffer: *const fn (
        data: *anyopaque,
        cmd_list: *CommandList,
        src: Buffer.Location,
        dst: Buffer.Location,
        size: Size,
    ) void,

    // fence
    create_fence: *const fn (data: *anyopaque, allocator: std.mem.Allocator, debug_name: []const u8) Error!*Fence,
    destroy_fence: *const fn (data: *anyopaque, fence: *Fence) void,
    signal_fence: *const fn (data: *anyopaque, fence: *Fence, value: u64) Error!void,
    wait_fence: *const fn (data: *anyopaque, fence: *Fence, value: u64) Error!void,

    // descriptor
    create_descriptor: *const fn (data: *anyopaque, allocator: std.mem.Allocator, desc: *const Descriptor.Desc, debug_name: []const u8) Error!*Descriptor,
    destroy_descriptor: *const fn (data: *anyopaque, descriptor: *Descriptor) void,
    get_descriptor_index: *const fn (data: *anyopaque, descriptor: *const Descriptor) Descriptor.Index,

    // pipeline
    create_graphics_pipeline: *const fn (data: *anyopaque, allocator: std.mem.Allocator, desc: *const Pipeline.GraphicsDesc, debug_name: []const u8) Error!*Pipeline,
    create_compute_pipeline: *const fn (data: *anyopaque, allocator: std.mem.Allocator, desc: *const Pipeline.ComputeDesc, debug_name: []const u8) Error!*Pipeline,
    destroy_pipeline: *const fn (data: *anyopaque, pipeline: *Pipeline) void,
    get_pipeline_kind: *const fn (data: *anyopaque, pipeline: *const Pipeline) Pipeline.Kind,

    // swapchain
    create_swapchain: *const fn (data: *anyopaque, allocator: std.mem.Allocator, desc: *const Swapchain.Desc, debug_name: []const u8) Error!*Swapchain,
    destroy_swapchain: *const fn (data: *anyopaque, swapchain: *Swapchain) void,
    acquire_next_swapchain_image: *const fn (data: *anyopaque, swapchain: *Swapchain) Error!void,
    get_swapchain_backbuffer: *const fn (data: *anyopaque, swapchain: *Swapchain) Error!Swapchain.Backbuffer,
    resize_swapchain: *const fn (data: *anyopaque, swapchain: *Swapchain, width: u32, height: u32) Error!bool, // returns if resized

    // texture
    create_texture: *const fn (data: *anyopaque, allocator: std.mem.Allocator, desc: *const Texture.Desc, debug_name: []const u8) Error!*Texture,
    destroy_texture: *const fn (data: *anyopaque, texture: *Texture) void,
    get_texture_desc: *const fn (data: *anyopaque, texture: *const Texture) *const Texture.Desc,
    get_texture_required_staging_size: *const fn (data: *anyopaque, desc: *const Texture) usize,
    get_texture_row_pitch: *const fn (data: *anyopaque, desc: *const Texture, mip_level: u32) u32,
};

const std = @import("std");

const gpu = @import("root.zig");
const Error = gpu.Error;

const spatial = @import("../math/spatial.zig");

const Buffer = gpu.Buffer;
const CommandList = gpu.CommandList;
const Descriptor = gpu.Descriptor;
const Fence = gpu.Fence;
const IndexFormat = gpu.IndexFormat;
const Pipeline = gpu.Pipeline;
const Queue = gpu.Queue;
const RenderPass = gpu.RenderPass;
const Size = gpu.Size;
const Swapchain = gpu.Swapchain;
const Texture = gpu.Texture;
const Access = gpu.Access;
const ConstantSlot = gpu.ConstantSlot;
