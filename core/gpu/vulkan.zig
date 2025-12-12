pub const Device = struct {
    allocator: std.mem.Allocator,
    options: gpu.Options,

    frame_idx: u64,

    vkb: vk.BaseWrapper,
    instance_wrapper: vk.InstanceWrapper,
    instance: vk.InstanceProxy,
    debug_messenger: vk.DebugUtilsMessengerEXT,
    physical_device: vk.PhysicalDevice,
    device_wrapper: vk.DeviceWrapper,
    device: vk.DeviceProxy,

    graphics_queue_family_index: u32,
    graphics_queue: vk.Queue,
    compute_queue_family_index: u32,
    compute_queue: vk.Queue,
    copy_queue_family_index: u32,
    copy_queue: vk.Queue,

    vma: vk_mem_alloc.Allocator,
    constant_buffers: [gpu.backbuffer_count]utils.LinearAllocatedBuffer,
    descriptor_set_layouts: [3]vk.DescriptorSetLayout,
    pipeline_layout: vk.PipelineLayout,

    descriptor_buffer_properties: vk.PhysicalDeviceDescriptorBufferPropertiesEXT,
    resource_descriptor_heap: DescriptorHeap,
    sampler_descriptor_heap: DescriptorHeap,

    deletion_queue: StaticRingBuffer(DeletePair, gpu.backbuffer_count, 512),
    allocation_deletion_queue: StaticRingBuffer(vk_mem_alloc.Allocation, gpu.backbuffer_count, 512),
    resource_deletion_queue: StaticRingBuffer(OffsetAllocator.Allocation, gpu.backbuffer_count, 512),
    sampler_deletion_queue: StaticRingBuffer(OffsetAllocator.Allocation, gpu.backbuffer_count, 512),

    pending_texture_transitions: [256]struct { *Texture, gpu.Access },
    pending_texture_transitions_count: usize,
    pending_copy_transitions: [256]struct { *Texture, gpu.Access },
    pending_copy_transitions_count: usize,

    transition_texture_command_lists: [gpu.backbuffer_count]*gpu.CommandList,

    is_done: bool,

    const DeletePair = struct {
        resource: vk.ObjectType,
        handle: u64,
    };

    pub fn init(self: *Device, allocator: std.mem.Allocator, options: gpu.Options) !void {
        const instance_desc: CreateVulkanInstanceDesc = .{
            .out_base_wrapper = &self.vkb,
            .out_instance_wrapper = &self.instance_wrapper,
            .out_instance = &self.instance,
            .out_debug_messenger = &self.debug_messenger,
            .use_validation_layers = options.validation,
        };
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();

        try createInstance(instance_desc, arena.allocator());

        const device_desc: CreateVulkanDeviceDesc = .{
            .instance = &self.instance,
            .preference = options.power_preference,
            .out_physical_device = &self.physical_device,
            .out_device_wrapper = &self.device_wrapper,
            .out_device = &self.device,
            .out_graphics_queue = &self.graphics_queue,
            .out_compute_queue = &self.compute_queue,
            .out_copy_queue = &self.copy_queue,
            .out_graphics_queue_family_index = &self.graphics_queue_family_index,
            .out_compute_queue_family_index = &self.compute_queue_family_index,
            .out_copy_queue_family_index = &self.copy_queue_family_index,
        };
        try createDevice(device_desc, arena.allocator());

        const vma_desc: CreateVMAllocatorDesc = .{
            .base = &self.vkb,
            .instance = &self.instance,
            .physical_device = self.physical_device,
            .device = &self.device,
        };
        self.vma = try createVMAllocator(vma_desc);

        self.descriptor_buffer_properties = undefined;
        self.descriptor_buffer_properties.s_type = .physical_device_descriptor_buffer_properties_ext;
        self.descriptor_buffer_properties.p_next = null;

        var properties: vk.PhysicalDeviceProperties2 = .{
            .s_type = .physical_device_properties_2,
            .p_next = &self.descriptor_buffer_properties,
            .properties = undefined,
        };
        self.instance.getPhysicalDeviceProperties2(
            self.physical_device,
            &properties,
        );

        var resource_descriptor_size: usize = self.descriptor_buffer_properties.sampled_image_descriptor_size;
        resource_descriptor_size = @max(resource_descriptor_size, self.descriptor_buffer_properties.storage_image_descriptor_size);
        resource_descriptor_size = @max(resource_descriptor_size, self.descriptor_buffer_properties.robust_uniform_texel_buffer_descriptor_size);
        resource_descriptor_size = @max(resource_descriptor_size, self.descriptor_buffer_properties.robust_storage_texel_buffer_descriptor_size);
        resource_descriptor_size = @max(resource_descriptor_size, self.descriptor_buffer_properties.robust_uniform_buffer_descriptor_size);
        resource_descriptor_size = @max(resource_descriptor_size, self.descriptor_buffer_properties.robust_storage_buffer_descriptor_size);

        self.resource_descriptor_heap = try .init(
            self,
            allocator,
            @intCast(resource_descriptor_size),
            gpu.max_resource_descriptor_count,
            .{
                .resource_descriptor_buffer_bit_ext = true,
            },
        );
        errdefer self.resource_descriptor_heap.deinit(allocator);

        self.sampler_descriptor_heap = try .init(
            self,
            allocator,
            @intCast(self.descriptor_buffer_properties.sampler_descriptor_size),
            gpu.max_sampler_descriptor_count,
            .{
                .sampler_descriptor_buffer_bit_ext = true,
            },
        );
        errdefer self.sampler_descriptor_heap.deinit(allocator);

        var name_buf: [64]u8 = undefined;
        self.constant_buffers = @splat(.zero);
        for (self.constant_buffers[0..], 0..) |*cb, i| {
            const name = std.fmt.bufPrint(name_buf[0..], "Constant Buffer Frame {}", .{i}) catch "Constant Buffer";
            cb.* = try .init(self.interface(), allocator, 8 * 1024 * 1024, name);
        }

        const pipeline_layout_desc: PipelineLayoutDesc = .{
            .device = &self.device,
            .out_descriptor_set_layouts = &self.descriptor_set_layouts,
        };
        self.pipeline_layout = try createPipelineLayout(pipeline_layout_desc);

        var transition_texture_command_lists_initialized: usize = 0;
        errdefer for (self.transition_texture_command_lists[0..transition_texture_command_lists_initialized]) |cmd| {
            self.interface().destroyCommandList(cmd);
        };

        for (0..gpu.backbuffer_count) |i| {
            const name = std.fmt.bufPrint(name_buf[0..], "Texture Transition Command List {}", .{i}) catch "Texture Transition Command List";
            self.transition_texture_command_lists[i] = try self.interface().createCommandList(
                allocator,
                .graphics,
                name,
            );
            transition_texture_command_lists_initialized += 1;
        }

        self.* = .{
            .allocator = allocator,
            .options = options,
            .frame_idx = 0,

            .vkb = self.vkb,
            .instance_wrapper = self.instance_wrapper,
            .instance = self.instance,
            .debug_messenger = self.debug_messenger,
            .physical_device = self.physical_device,
            .device_wrapper = self.device_wrapper,
            .device = self.device,
            .graphics_queue = self.graphics_queue,
            .graphics_queue_family_index = self.graphics_queue_family_index,
            .compute_queue = self.compute_queue,
            .compute_queue_family_index = self.compute_queue_family_index,
            .copy_queue = self.copy_queue,
            .copy_queue_family_index = self.copy_queue_family_index,
            .vma = self.vma,
            .constant_buffers = self.constant_buffers,
            .descriptor_set_layouts = self.descriptor_set_layouts,
            .pipeline_layout = self.pipeline_layout,
            .descriptor_buffer_properties = self.descriptor_buffer_properties,
            .resource_descriptor_heap = self.resource_descriptor_heap,
            .sampler_descriptor_heap = self.sampler_descriptor_heap,

            .deletion_queue = .empty,
            .allocation_deletion_queue = .empty,
            .resource_deletion_queue = .empty,
            .sampler_deletion_queue = .empty,

            .pending_texture_transitions = undefined,
            .pending_texture_transitions_count = 0,
            .pending_copy_transitions = undefined,
            .pending_copy_transitions_count = 0,

            .transition_texture_command_lists = self.transition_texture_command_lists,

            .is_done = false,
        };
    }

    pub fn deinit(self: *Device) void {
        self.device.deviceWaitIdle() catch {};

        for (self.transition_texture_command_lists[0..]) |cmd| {
            self.interface().destroyCommandList(cmd);
        }

        for (self.constant_buffers[0..]) |*cb| {
            cb.deinit();
        }

        self.cleanupFully();

        self.resource_descriptor_heap.deinit(self.allocator);
        self.sampler_descriptor_heap.deinit(self.allocator);

        self.vma.destroyAllocator();

        for (self.descriptor_set_layouts) |dsl| {
            self.device.destroyDescriptorSetLayout(dsl, null);
        }
        self.device.destroyPipelineLayout(self.pipeline_layout, null);

        self.device.destroyDevice(null);
        self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger, null);
        self.instance.destroyInstance(null);
    }

    fn beginFrame(self: *Device) void {
        self.garbageCollect();

        const index = self.frame_idx % gpu.backbuffer_count;

        const transition_cmd = self.transition_texture_command_lists[index];
        self.interface().resetCommandAllocator(transition_cmd);

        const cb: *utils.LinearAllocatedBuffer = &self.constant_buffers[index];
        cb.reset();

        return;
    }

    fn endFrame(self: *Device) void {
        self.frame_idx += 1;
        // SLOW ITS AN ATOMIC DO NOT CALL THIS
        // self.vma.setCurrentFrameIndex(@intCast(self.frame_idx));

        return;
    }

    fn shutdown(self: *Device) void {
        self.device.deviceWaitIdle() catch {};
        self.is_done = true;
    }

    pub fn interface(self: *Device) gpu.Interface {
        return .{
            .data = self,
            .vtable = &vtable,
        };
    }

    fn fromData(data: *anyopaque) *Device {
        return @ptrCast(@alignCast(data));
    }

    /// DO NOT CALL DIRECTLY
    fn deleteObjectPair(self: *Device, pair: DeletePair) void {
        switch (pair.resource) {
            .buffer => {
                const buffer: vk.Buffer = @enumFromInt(pair.handle);
                self.device.destroyBuffer(buffer, null);
            },
            .image => {
                const image: vk.Image = @enumFromInt(pair.handle);
                self.device.destroyImage(image, null);
            },
            .image_view => {
                const image_view: vk.ImageView = @enumFromInt(pair.handle);
                self.device.destroyImageView(image_view, null);
            },
            .sampler => {
                const sampler: vk.Sampler = @enumFromInt(pair.handle);
                self.device.destroySampler(sampler, null);
            },
            .swapchain_khr => {
                const swapchain: vk.SwapchainKHR = @enumFromInt(pair.handle);
                self.device.destroySwapchainKHR(swapchain, null);
            },
            .surface_khr => {
                const surface: vk.SurfaceKHR = @enumFromInt(pair.handle);
                self.instance.destroySurfaceKHR(surface, null);
            },
            .semaphore => {
                const semaphore: vk.Semaphore = @enumFromInt(pair.handle);
                self.device.destroySemaphore(semaphore, null);
            },
            .command_pool => {
                const command_pool: vk.CommandPool = @enumFromInt(pair.handle);
                self.device.destroyCommandPool(command_pool, null);
            },
            .command_buffer => {
                const command_buffer: vk.CommandBuffer = @enumFromInt(pair.handle);
                // Command buffers are freed when their command pool is destroyed
                _ = command_buffer;
            },
            .pipeline => {
                const pipeline: vk.Pipeline = @enumFromInt(pair.handle);
                self.device.destroyPipeline(pipeline, null);
            },
            else => |k| log.warn("Unhandled Vulkan object type for deletion: {}", .{k}),
        }
    }

    fn deleteObject(self: *Device, object_type: vk.ObjectType, handle: u64) void {
        if (self.is_done) {
            self.deleteObjectPair(.{ .resource = object_type, .handle = handle });
            return;
        }
        self.deletion_queue.add(.{ .resource = object_type, .handle = handle });
    }

    fn deleteAllocation(self: *Device, allocation: vk_mem_alloc.Allocation) void {
        if (self.is_done) {
            self.vma.freeMemory(allocation);
            return;
        }
        self.allocation_deletion_queue.add(allocation);
    }

    fn deleteResourceDescriptor(self: *Device, handle: OffsetAllocator.Allocation) void {
        if (self.is_done) {
            self.resource_descriptor_heap.free(handle);
            return;
        }
        self.resource_deletion_queue.add(handle);
    }

    fn deleteSamplerDescriptor(self: *Device, handle: OffsetAllocator.Allocation) void {
        if (self.is_done) {
            self.sampler_descriptor_heap.free(handle);
            return;
        }
        self.sampler_deletion_queue.add(handle);
    }

    fn cleanupFully(self: *Device) void {
        self.device.deviceWaitIdle() catch {};
        for (0..gpu.backbuffer_count + 1) |_| {
            self.garbageCollect();
        }
    }

    fn garbageCollect(self: *Device) void {
        for (self.deletion_queue.nextBuffer()) |pair| {
            self.deleteObjectPair(pair);
        }

        for (self.allocation_deletion_queue.nextBuffer()) |allocation| {
            self.vma.freeMemory(allocation);
        }

        for (self.resource_deletion_queue.nextBuffer()) |handle| {
            self.resource_descriptor_heap.free(handle);
        }

        for (self.sampler_deletion_queue.nextBuffer()) |handle| {
            self.sampler_descriptor_heap.free(handle);
        }
    }

    fn enqueueDefaultTransition(self: *Device, texture: *Texture) void {
        // i.e., swapchain texture
        if (texture.allocation == .null_handle) {
            self.addDefaultTransition(texture, .{ .present = true });
        } else if (texture.desc.usage.render_target) {
            self.addDefaultTransition(texture, .{ .render_target = true });
        } else if (texture.desc.usage.depth_stencil) {
            self.addDefaultTransition(texture, .{ .depth_stencil = true });
        } else if (texture.desc.usage.shader_write) {
            self.addDefaultTransition(texture, .write);
        } else {
            self.addDefaultTransition(texture, .{ .copy_dst = true });
        }
    }

    fn cancelDefaultTransition(self: *Device, texture: *Texture) void {
        for (self.pending_texture_transitions[0..self.pending_texture_transitions_count], 0..) |entry, idx| {
            if (entry.@"0" == texture) {
                // Remove by swapping with last and decreasing count
                self.pending_texture_transitions[idx] = self.pending_texture_transitions[self.pending_texture_transitions_count - 1];
                self.pending_texture_transitions_count -= 1;
                return;
            }
        }
    }

    fn addDefaultTransition(self: *Device, texture: *Texture, new_access: gpu.Access) void {
        if (self.pending_texture_transitions_count >= self.pending_texture_transitions.len) {
            log.warn("Pending texture transitions full, flushing layout transitions", .{});
            return;
        }
        self.pending_texture_transitions[self.pending_texture_transitions_count] = .{ texture, new_access };
        self.pending_texture_transitions_count += 1;
    }

    fn flushLayoutTransition(self: *Device) void {
        const index = self.frame_idx % gpu.backbuffer_count;

        const texture_cmd = self.transition_texture_command_lists[index];
        const self_cmd: *CommandList = .fromGpuCommandList(texture_cmd);

        if (self.pending_texture_transitions_count > 0 or self.pending_copy_transitions_count > 0) {
            self_cmd.resetAllocator();
            self_cmd.begin() catch {};
            for (self.pending_texture_transitions[0..self.pending_texture_transitions_count]) |entry| {
                const self_texture: *Texture = entry.@"0";
                self_cmd.textureBarrier(
                    self_texture,
                    gpu.all_subresource,
                    .{ .discard = true },
                    entry.@"1",
                );
            }
            self.pending_texture_transitions_count = 0;

            // for (self.pending_copy_transitions[0..self.pending_copy_transitions_count]) |entry| {
            //     i.commandTextureBarrier(
            //         texture_cmd,
            //         entry.@"0",
            //         gpu.all_subresource,
            //         .{ .discard = true },
            //         entry.@"1",
            //     );
            // }
            // self.pending_copy_transitions_count = 0;

            self_cmd.end() catch {};
            self_cmd.submit() catch {};
            // i.endCommandList(texture_cmd) catch {};
            // i.submitCommandList(texture_cmd) catch {};
        }
    }

    fn debugCallback(
        message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
        message_types: vk.DebugUtilsMessageTypeFlagsEXT,
        p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
        p_user_data: ?*anyopaque,
    ) callconv(.c) vk.Bool32 {
        _ = message_types;
        _ = p_user_data;
        const callback_data = p_callback_data.?;
        if (callback_data.p_message) |msg| {
            const msg_slice = std.mem.span(msg);
            if (message_severity.error_bit_ext) {
                log.err("{s}", .{msg_slice});
            } else if (message_severity.warning_bit_ext) {
                log.warn("{s}", .{msg_slice});
            } else if (message_severity.info_bit_ext) {
                log.info("{s}", .{msg_slice});
            } else if (message_severity.verbose_bit_ext) {
                log.debug("{s}", .{msg_slice});
            }
        }
        return .false;
    }

    fn allocateConstant(self: *Device, data: []const u8) error{OutOfMemory}!gpu.utils.LinearAllocatedBuffer.Address {
        const cb: *utils.LinearAllocatedBuffer = &self.constant_buffers[self.frame_idx % gpu.backbuffer_count];
        const address = try cb.alloc(@intCast(data.len));
        const cpu_address = address.cpu;
        @memcpy(cpu_address, data);
        return address;
    }

    fn allocateConstantBufferDescriptor(
        self: *Device,
        root: []const u32,
        first: *const vk.DescriptorAddressInfoEXT,
        second: *const vk.DescriptorAddressInfoEXT,
    ) !vk.DeviceSize {
        const ub_size = self.descriptor_buffer_properties.robust_uniform_buffer_descriptor_size;
        const size = gpu.max_root_constant_size_bytes + ub_size * 2;
        const allocator = self.constantBufferAllocator();
        const address = try allocator.alloc(@intCast(size));

        @memcpy(
            address.cpu[0 .. root.len * @sizeOf(u32)],
            @as([]const u8, @ptrCast(@alignCast(root))),
        );

        var descriptor_info: vk.DescriptorGetInfoEXT = .{
            .type = .uniform_buffer,
            .data = .{
                .p_uniform_buffer = null,
            },
        };

        if (first.address != 0) {
            descriptor_info.data = .{
                .p_uniform_buffer = first,
            };
            self.device.getDescriptorEXT(
                &descriptor_info,
                ub_size,
                address.cpu[gpu.max_root_constant_size_bytes..].ptr,
            );
        }

        if (second.address != 0) {
            descriptor_info.data = .{
                .p_uniform_buffer = second,
            };
            self.device.getDescriptorEXT(
                &descriptor_info,
                ub_size,
                address.cpu[gpu.max_root_constant_size_bytes + ub_size ..].ptr,
            );
        }

        return address.gpu.toInt() - allocator.gpu_address;
    }

    const CreateVulkanInstanceDesc = struct {
        out_base_wrapper: *vk.BaseWrapper,
        out_instance_wrapper: *vk.InstanceWrapper,
        out_instance: *vk.InstanceProxy,
        out_debug_messenger: *vk.DebugUtilsMessengerEXT,

        use_validation_layers: bool,
    };

    fn createInstance(instance_desc: CreateVulkanInstanceDesc, arena: std.mem.Allocator) !void {
        const vkGetInstanceProcAddr = try loader.get();
        instance_desc.out_base_wrapper.* = .load(vkGetInstanceProcAddr);

        const layers = try instance_desc.out_base_wrapper.enumerateInstanceLayerPropertiesAlloc(
            arena,
        );

        const extensions = try instance_desc.out_base_wrapper.enumerateInstanceExtensionPropertiesAlloc(
            null,
            arena,
        );

        var required_layer_names: std.ArrayList([*:0]const u8) = try .initCapacity(arena, 1);
        defer required_layer_names.deinit(arena);

        // try required_layer_names.append(arena, "VK_LAYER_LUNARG_api_dump");

        var required_extension_names: std.ArrayList([*:0]const u8) = try .initCapacity(arena, 5);
        defer required_extension_names.deinit(arena);

        log.info("Found {d} layers and {d} extensions", .{ layers.len, extensions.len });
        for (layers) |layer| {
            log.info("Layer: {s}", .{std.mem.sliceTo(layer.layer_name[0..], 0)});
        }
        for (extensions) |ext| {
            log.info("Extension: {s}", .{std.mem.sliceTo(ext.extension_name[0..], 0)});
        }

        if (instance_desc.use_validation_layers) {
            const validation_layer_name = "VK_LAYER_KHRONOS_validation";
            if (!findLayer(layers, validation_layer_name)) {
                log.err("Validation layer requested but not available: {s}", .{validation_layer_name});
                return error.Gpu;
            }
            try required_layer_names.append(arena, validation_layer_name);
        }

        // check for swapchain
        const surface_ext = vk.extensions.khr_surface;
        try required_extension_names.append(arena, surface_ext.name);
        if (!findExtension(extensions, surface_ext.name)) {
            log.err("Required extension VK_KHR_surface not available", .{});
            return error.Gpu;
        }

        // check for platform surface extensions
        const platform_surface_extension_names: []const [*:0]const u8 = switch (builtin.os.tag) {
            .windows => &.{vk.extensions.khr_win_32_surface.name},
            // .linux => switch (builtin.abi) {
            // .android => vk.extensions.khr_android_surface,
            // else => vk.extensions.khr_xcb_surface,
            // },
            // .macos => vk.extensions.mvk_macos_surface,
            else => {
                log.err("Unsupported OS for Vulkan surface creation");
                return error.Gpu;
            },
        };
        try required_extension_names.appendSlice(arena, platform_surface_extension_names);
        try required_extension_names.append(arena, vk.extensions.ext_debug_utils.name);
        // try required_extension_names.append(arena, vk.extensions.khr_portability_enumeration.name);

        for (platform_surface_extension_names) |ext_name| {
            if (!findExtension(extensions, std.mem.span(ext_name))) {
                log.err("Required platform surface extension {s} not available", .{ext_name});
                return error.Gpu;
            }
        }

        log.info("Creating Vulkan instance with {d} layers and {d} extensions", .{
            required_layer_names.items.len,
            required_extension_names.items.len,
        });
        for (required_layer_names.items) |layer_name| {
            log.info("Enabling layer: {s}", .{layer_name});
        }

        for (required_extension_names.items) |ext_name| {
            log.info("Enabling extension: {s}", .{ext_name});
        }

        for (required_layer_names.items) |layer_name| {
            if (!findLayer(layers, std.mem.span(layer_name))) {
                log.err("Required layer {s} not available", .{layer_name});
                return error.Gpu;
            }
        }

        for (required_extension_names.items) |ext_name| {
            if (!findExtension(extensions, std.mem.span(ext_name))) {
                log.err("Required extension {s} not available", .{ext_name});
                return error.Gpu;
            }
        }

        const instance = try instance_desc.out_base_wrapper.createInstance(&.{
            // .flags = .{ .enumerate_portability_bit_khr = true },
            .flags = .{},
            .p_application_info = &.{
                .p_application_name = "saltpeter",
                .application_version = @bitCast(vk.makeApiVersion(0, 0, 1, 0)),
                .p_engine_name = "saltpeter_engine",
                .engine_version = @bitCast(vk.makeApiVersion(0, 0, 1, 0)),
                .api_version = @bitCast(vk.API_VERSION_1_3),
            },
            .enabled_layer_count = @intCast(required_layer_names.items.len),
            .pp_enabled_layer_names = required_layer_names.items.ptr,
            .enabled_extension_count = @intCast(required_extension_names.items.len),
            .pp_enabled_extension_names = required_extension_names.items.ptr,
        }, null);

        instance_desc.out_instance_wrapper.* = .load(instance, instance_desc.out_base_wrapper.dispatch.vkGetInstanceProcAddr.?);
        instance_desc.out_instance.* = .init(instance, instance_desc.out_instance_wrapper);
        errdefer {
            _ = instance_desc.out_instance_wrapper.destroyInstance(instance, null);
        }

        const debug_messenger_create_info: vk.DebugUtilsMessengerCreateInfoEXT = .{
            .message_severity = .{
                .error_bit_ext = true,
                .warning_bit_ext = true,
                .info_bit_ext = true,
                .verbose_bit_ext = true,
            },
            .message_type = .{
                .general_bit_ext = true,
                .validation_bit_ext = true,
                .performance_bit_ext = true,
                .device_address_binding_bit_ext = true,
            },
            .pfn_user_callback = debugCallback,
        };
        instance_desc.out_debug_messenger.* = try instance_desc.out_instance.createDebugUtilsMessengerEXT(
            &debug_messenger_create_info,
            null,
        );

        log.info("Vulkan instance created successfully", .{});
    }

    const CreateVulkanDeviceDesc = struct {
        instance: *vk.InstanceProxy,
        preference: gpu.Options.PowerPreference,

        out_physical_device: *vk.PhysicalDevice,
        out_device_wrapper: *vk.DeviceWrapper,
        out_device: *vk.DeviceProxy,
        out_graphics_queue: *vk.Queue,
        out_graphics_queue_family_index: *u32,
        out_compute_queue: *vk.Queue,
        out_compute_queue_family_index: *u32,
        out_copy_queue: *vk.Queue,
        out_copy_queue_family_index: *u32,
    };

    fn createDevice(device_desc: CreateVulkanDeviceDesc, arena: std.mem.Allocator) !void {
        const instance = device_desc.instance;
        const physical_devices = try instance.enumeratePhysicalDevicesAlloc(arena);
        if (physical_devices.len == 0) {
            log.err("No Vulkan physical devices found", .{});
            return error.Gpu;
        }
        var chosen_device: ?vk.PhysicalDevice = null;
        log.info("Found {d} physical devices", .{physical_devices.len});
        for (physical_devices) |pd| {
            const props = instance.getPhysicalDeviceProperties(pd);
            const device_name = std.mem.sliceTo(props.device_name[0..], 0);
            log.info("Physical Device: {s}", .{device_name});
            const api_version: vk.Version = @bitCast(props.api_version);
            log.info("  API Version: {d}.{d}.{d}", .{ api_version.major, api_version.minor, api_version.patch });
            const memory_props = instance.getPhysicalDeviceMemoryProperties(pd);
            log.info("  Memory Heaps: {d}", .{memory_props.memory_heap_count});
            for (memory_props.memory_heaps[0..memory_props.memory_heap_count], 0..) |heap, i| {
                log.info("    Heap {d}: {d} MB", .{ i, @divTrunc(heap.size, (1024 * 1024)) });
            }
            const vendor_id = props.vendor_id;
            const device_id = props.device_id;
            log.info("  Vendor ID: {x}, Device ID: {x}", .{ vendor_id, device_id });
            const vendor: gpu.Vendor = switch (vendor_id) {
                0x10DE => .nvidia,
                0x1002, 0x1022 => .amd,
                0x8086 => .intel,
                0x106b => .apple,
                else => .unknown,
            };
            log.info("  Vendor: {s}", .{@tagName(vendor)});

            if (chosen_device == null) {
                if (device_desc.preference == .high_performance and props.device_type == .discrete_gpu) {
                    chosen_device = pd;
                } else if (device_desc.preference == .low_power and props.device_type == .integrated_gpu) {
                    chosen_device = pd;
                }
            }
        }

        if (chosen_device == null) {
            chosen_device = physical_devices[0];
        }
        device_desc.out_physical_device.* = chosen_device.?;
        log.info("Chosen physical device selected: {s}", .{
            std.mem.sliceTo(instance.getPhysicalDeviceProperties(device_desc.out_physical_device.*).device_name[0..], 0),
        });

        const extensions = try instance.enumerateDeviceExtensionPropertiesAlloc(
            device_desc.out_physical_device.*,
            null,
            arena,
        );
        for (extensions) |ext| {
            log.info("Device Extension: {s}", .{std.mem.sliceTo(ext.extension_name[0..], 0)});
        }

        var required_device_extension_names: std.ArrayList([*:0]const u8) = try .initCapacity(arena, 10);
        defer required_device_extension_names.deinit(arena);

        try required_device_extension_names.appendSlice(arena, &.{
            vk.extensions.khr_swapchain.name,
            vk.extensions.khr_dynamic_rendering.name,
            vk.extensions.khr_synchronization_2.name,
            vk.extensions.khr_timeline_semaphore.name,
            vk.extensions.ext_mutable_descriptor_type.name,
            vk.extensions.ext_scalar_block_layout.name,
            vk.extensions.ext_descriptor_indexing.name,
            vk.extensions.ext_descriptor_buffer.name,
            vk.extensions.khr_buffer_device_address.name,
        });

        log.info("Creating Vulkan device with {d} extensions", .{required_device_extension_names.items.len});
        for (required_device_extension_names.items) |ext_name| {
            log.info("Enabling device extension: {s}", .{ext_name});
        }

        for (required_device_extension_names.items) |ext_name| {
            if (!findExtension(extensions, std.mem.span(ext_name))) {
                log.err("Required device extension {s} not available", .{ext_name});
                return error.Gpu;
            }
        }

        const families = try findQueueFamilies(
            device_desc.out_physical_device.*,
            instance,
            arena,
        );
        const has_required_queues = families.graphics_family_index != null and
            families.compute_family_index != null and
            families.copy_family_index != null;
        if (!has_required_queues) {
            log.err("Physical device does not have required queue families", .{});
            return error.Gpu;
        }

        const queue_priorities: [1]f32 = .{0.0};
        const queue_create_infos: [3]vk.DeviceQueueCreateInfo = .{
            .{
                .queue_family_index = families.graphics_family_index.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priorities,
            },
            .{
                .queue_family_index = families.compute_family_index.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priorities,
            },
            .{
                .queue_family_index = families.copy_family_index.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priorities,
            },
        };

        const features = instance.getPhysicalDeviceFeatures(device_desc.out_physical_device.*);
        var vulkan_12_features: vk.PhysicalDeviceVulkan12Features = .{
            .descriptor_indexing = .true,
            .buffer_device_address = .true,
            .shader_uniform_texel_buffer_array_dynamic_indexing = .true,
            .shader_storage_texel_buffer_array_dynamic_indexing = .true,
            .shader_uniform_buffer_array_non_uniform_indexing = .true,
            .shader_sampled_image_array_non_uniform_indexing = .true,
            .shader_storage_buffer_array_non_uniform_indexing = .true,
            .shader_storage_image_array_non_uniform_indexing = .true,
            .shader_uniform_texel_buffer_array_non_uniform_indexing = .true,
            .shader_storage_texel_buffer_array_non_uniform_indexing = .true,
            .scalar_block_layout = .true,
            .runtime_descriptor_array = .true,
            .descriptor_binding_partially_bound = .true,
            .timeline_semaphore = .true,
        };

        var vulkan_13_features: vk.PhysicalDeviceVulkan13Features = .{
            .p_next = &vulkan_12_features,
            .synchronization_2 = .true,
            .inline_uniform_block = .true,
            .dynamic_rendering = .true,
        };

        var mutable_descriptor_features: vk.PhysicalDeviceMutableDescriptorTypeFeaturesEXT = .{
            .p_next = &vulkan_13_features,
            .mutable_descriptor_type = .true,
        };

        var descriptor_buffer_features: vk.PhysicalDeviceDescriptorBufferFeaturesEXT = .{
            .p_next = &mutable_descriptor_features,
            .descriptor_buffer = .true,
        };

        const logical_device = try instance.createDevice(device_desc.out_physical_device.*, &.{
            .p_queue_create_infos = &queue_create_infos,
            .queue_create_info_count = @intCast(queue_create_infos.len),
            .p_enabled_features = &features,
            .p_next = &descriptor_buffer_features,
            .enabled_extension_count = @intCast(required_device_extension_names.items.len),
            .pp_enabled_extension_names = required_device_extension_names.items.ptr,
        }, null);

        device_desc.out_device_wrapper.* = .load(logical_device, instance.wrapper.dispatch.vkGetDeviceProcAddr.?);
        device_desc.out_device.* = .init(logical_device, device_desc.out_device_wrapper);

        device_desc.out_graphics_queue.* = device_desc.out_device.getDeviceQueue(
            families.graphics_family_index.?,
            0,
        );
        device_desc.out_graphics_queue_family_index.* = families.graphics_family_index.?;
        device_desc.out_compute_queue.* = device_desc.out_device.getDeviceQueue(
            families.compute_family_index.?,
            0,
        );
        device_desc.out_compute_queue_family_index.* = families.compute_family_index.?;
        device_desc.out_copy_queue.* = device_desc.out_device.getDeviceQueue(
            families.copy_family_index.?,
            0,
        );
        device_desc.out_copy_queue_family_index.* = families.copy_family_index.?;
    }

    const FindQueueFamilyResult = struct {
        graphics_family_index: ?u32,
        copy_family_index: ?u32,
        compute_family_index: ?u32,
    };

    fn findQueueFamilies(physical_device: vk.PhysicalDevice, instance: *vk.InstanceProxy, arena: std.mem.Allocator) !FindQueueFamilyResult {
        const queue_families = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(
            physical_device,
            arena,
        );

        var result: FindQueueFamilyResult = .{
            .graphics_family_index = null,
            .copy_family_index = null,
            .compute_family_index = null,
        };

        for (queue_families, 0..) |family, index| {
            if (family.queue_flags.graphics_bit and result.graphics_family_index == null) {
                result.graphics_family_index = @intCast(index);
                continue;
            }
            if (family.queue_flags.compute_bit and result.compute_family_index == null) {
                result.compute_family_index = @intCast(index);
                continue;
            }
            if (family.queue_flags.transfer_bit and result.copy_family_index == null) {
                result.copy_family_index = @intCast(index);
                continue;
            }
        }

        return result;
    }

    const CreateVMAllocatorDesc = struct {
        base: *vk.BaseWrapper,
        instance: *vk.InstanceProxy,
        physical_device: vk.PhysicalDevice,
        device: *vk.DeviceProxy,
    };

    fn createVMAllocator(desc: CreateVMAllocatorDesc) !vk_mem_alloc.Allocator {
        const functions: vk_mem_alloc.VulkanFunctions = .{
            .vkGetInstanceProcAddr = desc.base.dispatch.vkGetInstanceProcAddr,
            .vkGetDeviceProcAddr = desc.instance.wrapper.dispatch.vkGetDeviceProcAddr,
        };

        const create_info: vk_mem_alloc.AllocatorCreateInfo = .{
            .flags = .{
                .khr_bind_memory_2_bit = true,
                .buffer_device_address_bit = true,
            },
            .physicalDevice = desc.physical_device,
            .device = desc.device.handle,
            .instance = desc.instance.handle,
            .pVulkanFunctions = &functions,
            .vulkanApiVersion = @bitCast(vk.API_VERSION_1_3),
        };

        var allocator: vk_mem_alloc.Allocator = undefined;
        const result = vk_mem_alloc.vmaCreateAllocator(&create_info, &allocator);
        if (result != .success) {
            log.err("Failed to create VMA allocator: {d}", .{result});
            return error.Gpu;
        }

        return allocator;
    }

    const PipelineLayoutDesc = struct {
        device: *vk.DeviceProxy,
        out_descriptor_set_layouts: *[3]vk.DescriptorSetLayout,
    };

    fn createPipelineLayout(desc: PipelineLayoutDesc) !vk.PipelineLayout {
        const mutable_descriptor_types: [6]vk.DescriptorType = .{
            .sampled_image,
            .storage_image,
            .uniform_texel_buffer,
            .storage_texel_buffer,
            .uniform_buffer,
            .storage_buffer,
            // .acceleration_structure_khr,
        };

        const type_list: vk.MutableDescriptorTypeListEXT = .{
            .descriptor_type_count = @intCast(mutable_descriptor_types.len),
            .p_descriptor_types = &mutable_descriptor_types,
        };

        const mutable_descriptor_info: vk.MutableDescriptorTypeCreateInfoEXT = .{
            .mutable_descriptor_type_list_count = 1,
            .p_mutable_descriptor_type_lists = &.{type_list},
        };

        const all_shader_stage_flags: vk.ShaderStageFlags = .{
            .vertex_bit = true,
            .fragment_bit = true,
            .compute_bit = true,
        };

        const num_constants = @typeInfo(gpu.ConstantSlot).@"enum".fields.len;
        var constant_buffers: [num_constants]vk.DescriptorSetLayoutBinding = undefined;
        constant_buffers[0] = .{
            .binding = 0,
            .descriptor_type = .inline_uniform_block,
            .descriptor_count = gpu.max_root_constant_size_bytes,
            .stage_flags = all_shader_stage_flags,
        };

        for (1..num_constants) |i| {
            constant_buffers[i] = .{
                .binding = @intCast(i),
                .descriptor_type = .uniform_buffer,
                .descriptor_count = 1,
                .stage_flags = all_shader_stage_flags,
            };
        }

        const resource_descriptor_heap: vk.DescriptorSetLayoutBinding = .{
            .binding = 0,
            .descriptor_type = .mutable_ext,
            .descriptor_count = gpu.max_resource_descriptor_count,
            .stage_flags = all_shader_stage_flags,
        };

        const sampler_descriptor_heap: vk.DescriptorSetLayoutBinding = .{
            .binding = 0,
            .descriptor_type = .sampler,
            .descriptor_count = gpu.max_sampler_descriptor_count,
            .stage_flags = all_shader_stage_flags,
        };

        const constants_set: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = @intCast(constant_buffers.len),
            .flags = .{ .descriptor_buffer_bit_ext = true },
            .p_bindings = &constant_buffers,
        };

        const resource_heap_set: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = 1,
            .flags = .{ .descriptor_buffer_bit_ext = true },
            .p_bindings = &.{resource_descriptor_heap},
            .p_next = &mutable_descriptor_info,
        };

        const sampler_heap_set: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = 1,
            .flags = .{ .descriptor_buffer_bit_ext = true },
            .p_bindings = &.{sampler_descriptor_heap},
        };

        desc.out_descriptor_set_layouts.* = .{
            try desc.device.createDescriptorSetLayout(&constants_set, null),
            try desc.device.createDescriptorSetLayout(&resource_heap_set, null),
            try desc.device.createDescriptorSetLayout(&sampler_heap_set, null),
        };

        const pipeline_layout_info: vk.PipelineLayoutCreateInfo = .{
            .p_next = &mutable_descriptor_info,
            .set_layout_count = @intCast(desc.out_descriptor_set_layouts.*.len),
            .p_set_layouts = desc.out_descriptor_set_layouts,
        };

        return desc.device.createPipelineLayout(&pipeline_layout_info, null);
    }

    fn findLayer(
        layers: []const vk.LayerProperties,
        name: []const u8,
    ) bool {
        for (layers) |layer| {
            const layer_name = std.mem.sliceTo(layer.layer_name[0..], 0);
            if (std.mem.eql(u8, layer_name, name)) {
                return true;
            }
        }
        return false;
    }

    fn findExtension(
        extensions: []const vk.ExtensionProperties,
        name: []const u8,
    ) bool {
        for (extensions) |ext| {
            const ext_name = std.mem.sliceTo(ext.extension_name[0..], 0);
            if (std.mem.eql(u8, ext_name, name)) {
                return true;
            }
        }
        return false;
    }

    fn constantBufferAllocator(self: *Device) *utils.LinearAllocatedBuffer {
        const index = self.frame_idx % gpu.backbuffer_count;
        return &self.constant_buffers[index];
    }
};

// gpu visible buffer which has descriptor buffer
const DescriptorHeap = struct {
    device: *Device,

    buffer: vk.Buffer,
    allocation: vk_mem_alloc.Allocation,
    offset_allocator: OffsetAllocator,
    gpu_address: vk.DeviceAddress,
    cpu_address: [*]u8,
    descriptor_size: u32,
    descriptor_count: u32,

    fn init(
        device: *Device,
        allocator: std.mem.Allocator,
        descriptor_size: u32,
        descriptor_count: u32,
        usage: vk.BufferUsageFlags,
    ) !DescriptorHeap {
        const create_info: vk.BufferCreateInfo = .{
            .size = descriptor_size * descriptor_count,
            .usage = usage.merge(.{ .shader_device_address_bit = true }),
            .sharing_mode = .exclusive,
        };

        const allocation_create_info: vk_mem_alloc.AllocationCreateInfo = .{
            .usage = .cpu_to_gpu,
            .flags = .{ .dedicated_memory_bit = true, .mapped_bit = true },
        };

        var buffer: vk.Buffer = .null_handle;
        var allocation: vk_mem_alloc.Allocation = undefined;

        var allocation_info: vk_mem_alloc.AllocationInfo = undefined;
        const result = device.vma.createBuffer(
            &create_info,
            &allocation_create_info,
            &buffer,
            &allocation,
            &allocation_info,
        );
        if (result != .success) {
            log.err("Failed to create descriptor heap buffer: {d}", .{result});
            return error.Gpu;
        }
        errdefer {
            device.vma.destroyBuffer(buffer, allocation);
        }

        const cpu_address: [*]u8 = @ptrCast(allocation_info.pMappedData.?);
        const gpu_address = device.device.getBufferDeviceAddress(&.{
            .buffer = buffer,
        });

        const offset_allocator: OffsetAllocator = try .init(allocator, descriptor_count, descriptor_count);
        errdefer offset_allocator.deinit(allocator);

        return .{
            .device = device,
            .buffer = buffer,
            .allocation = allocation,
            .offset_allocator = offset_allocator,
            .gpu_address = gpu_address,
            .cpu_address = cpu_address,
            .descriptor_size = descriptor_size,
            .descriptor_count = descriptor_count,
        };
    }

    fn deinit(heap: *DescriptorHeap, allocator: std.mem.Allocator) void {
        heap.device.vma.destroyBuffer(heap.buffer, heap.allocation);
        heap.offset_allocator.deinit(allocator);
    }

    fn alloc(heap: *DescriptorHeap) !struct { OffsetAllocator.Allocation, []u8 } {
        const allocation = try heap.offset_allocator.allocate(1);
        return .{
            allocation,
            heap.cpu_address[allocation.offset * heap.descriptor_size ..][0..heap.descriptor_size],
        };
    }

    fn free(heap: *DescriptorHeap, allocation: OffsetAllocator.Allocation) void {
        heap.offset_allocator.free(allocation) catch unreachable;
    }
};

const Buffer = struct {
    device: *Device,
    allocator: std.mem.Allocator,
    buffer: vk.Buffer,
    allocation: vk_mem_alloc.Allocation,
    cpu_address: ?[*]u8,

    desc: gpu.Buffer.Desc,

    fn init(self: *Buffer, device: *Device, allocator: std.mem.Allocator, desc: gpu.Buffer.Desc, name: []const u8) !void {
        self.* = .{
            .device = device,
            .allocator = allocator,
            .buffer = .null_handle,
            .allocation = .null_handle,
            .cpu_address = null,
            .desc = desc,
        };

        const create_info: vk.BufferCreateInfo = .{
            .size = desc.size,
            .usage = .{
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
                .index_buffer_bit = true,
                .indirect_buffer_bit = true,
                .shader_device_address_bit = true,
                .storage_buffer_bit = desc.usage.shader_write,
                .uniform_buffer_bit = desc.usage.constant_buffer,
                .resource_descriptor_buffer_bit_ext = desc.usage.constant_buffer,
                // .acceleration_structure_build_input_read_only_bit_khr = desc.usage.acceleration_structure,
            },
            .sharing_mode = .exclusive,
        };

        const allocation_create_info: vk_mem_alloc.AllocationCreateInfo = .{
            .usage = conv.locationToMemoryUsage(desc.location),
            .flags = .{
                .dedicated_memory_bit = true,
                .mapped_bit = desc.location != .gpu_only,
            },
        };

        var allocation_info: vk_mem_alloc.AllocationInfo = undefined;
        const result = device.vma.createBuffer(
            &create_info,
            &allocation_create_info,
            &self.buffer,
            &self.allocation,
            &allocation_info,
        );
        if (result != .success) {
            log.err("Failed to create buffer: {}", .{result});
            return error.Gpu;
        }

        self.cpu_address = @ptrCast(allocation_info.pMappedData);

        setDebugName(&self.device.device, .buffer, vk.Buffer, self.buffer, name);

        if (self.allocation != .null_handle) {
            setAllocationName(device.vma, self.allocation, name);
        }
    }

    fn deinit(self: *Buffer) void {
        self.device.deleteAllocation(self.allocation);
        self.device.deleteObject(.buffer, @intFromEnum(self.buffer));
    }

    fn fromGpuBuffer(buffer: *gpu.Buffer) *Buffer {
        return @ptrCast(@alignCast(buffer));
    }

    fn fromGpuBufferConst(buffer: *const gpu.Buffer) *const Buffer {
        return @ptrCast(@alignCast(buffer));
    }

    fn toGpuBuffer(buffer: *Buffer) *gpu.Buffer {
        return @ptrCast(@alignCast(buffer));
    }

    fn cpuAddress(self: *const Buffer) ?[*]u8 {
        return self.cpu_address;
    }

    fn gpuAddress(self: *const Buffer) gpu.Buffer.GpuAddress {
        const get_gpu_address_info: vk.BufferDeviceAddressInfo = .{
            .buffer = self.buffer,
        };
        const addr = self.device.device.getBufferDeviceAddress(&get_gpu_address_info);
        return @enumFromInt(addr);
    }

    fn requiredStagingSize(self: *const Buffer) usize {
        const requirements = self.device.device.getBufferMemoryRequirements(self.buffer);
        return @intCast(requirements.size);
    }
};

const CommandList = struct {
    const max_barriers_store = 32;
    const max_fence_operations = 32;
    const max_present_swapchains = 8;

    const FenceValue = struct {
        fence: *Fence,
        value: u64,
    };

    allocator: std.mem.Allocator,
    device: *Device = undefined,
    vk_queue: vk.Queue = .null_handle,
    command_pool: vk.CommandPool = .null_handle,
    command_buffer: vk.CommandBuffer = .null_handle,

    current_pipeline_state: vk.Pipeline = .null_handle,

    texture_barriers: [max_barriers_store]vk.ImageMemoryBarrier2 = undefined,
    texture_barriers_count: usize = 0,

    buffer_barriers: [max_barriers_store]vk.BufferMemoryBarrier2 = undefined,
    buffer_barriers_count: usize = 0,

    memory_barriers: [max_barriers_store]vk.MemoryBarrier2 = undefined,
    memory_barriers_count: usize = 0,

    pending_waits: [max_fence_operations]FenceValue = undefined,
    pending_waits_count: usize = 0,

    pending_signals: [max_fence_operations]FenceValue = undefined,
    pending_signals_count: usize = 0,

    pending_swapchains: [max_present_swapchains]*Swapchain = undefined,
    pending_swapchains_count: usize = 0,

    graphics_constants: Constants = undefined,
    compute_constants: Constants = undefined,

    // render_pass_render_targets: [8]d3d12.RENDER_PASS_RENDER_TARGET_DESC = undefined,
    // render_pass_render_target_count: usize = 0,
    // render_pass_depth_stencil: ?d3d12.RENDER_PASS_DEPTH_STENCIL_DESC = null,
    is_in_render_pass: bool = false,
    command_count: u64 = 0,

    is_open: bool = false,

    queue: gpu.Queue,

    const Constants = struct {
        root: [@divExact(gpu.max_root_constant_size_bytes, 4)]u32,
        first: vk.DescriptorAddressInfoEXT,
        second: vk.DescriptorAddressInfoEXT,
        dirty: bool,
    };

    fn init(self: *CommandList, device: *Device, allocator: std.mem.Allocator, command_queue: gpu.Queue, name: []const u8) Error!void {
        self.* = .{
            .allocator = allocator,
            .device = device,
            .vk_queue = switch (command_queue) {
                .graphics => device.graphics_queue,
                .compute => device.compute_queue,
                .copy => device.copy_queue,
            },
            .queue = command_queue,
        };

        const command_pool_info: vk.CommandPoolCreateInfo = .{
            .flags = .{
                .reset_command_buffer_bit = true,
            },
            .queue_family_index = switch (command_queue) {
                .graphics => device.graphics_queue_family_index,
                .compute => device.compute_queue_family_index,
                .copy => device.copy_queue_family_index,
            },
        };

        const command_pool = device.device.createCommandPool(&command_pool_info, null) catch |err| {
            log.err("Failed to create command pool: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        self.command_pool = command_pool;

        setDebugName(&device.device, .command_pool, vk.CommandPool, self.command_pool, name);

        const command_buffer_allocate_info: vk.CommandBufferAllocateInfo = .{
            .command_pool = self.command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        };

        var out_command_buffers: [1]vk.CommandBuffer = undefined;
        device.device.allocateCommandBuffers(
            &command_buffer_allocate_info,
            &out_command_buffers,
        ) catch |err| {
            log.err("Failed to allocate command buffer: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        self.command_buffer = out_command_buffers[0];

        setDebugName(&device.device, .command_buffer, vk.CommandBuffer, self.command_buffer, name);

        self.graphics_constants = .{
            .root = undefined,
            .first = .{
                .address = 0,
                .range = 0,
                .format = .undefined,
            },
            .second = .{
                .address = 0,
                .range = 0,
                .format = .undefined,
            },
            .dirty = false,
        };

        self.compute_constants = .{
            .root = undefined,
            .first = .{
                .address = 0,
                .range = 0,
                .format = .undefined,
            },
            .second = .{
                .address = 0,
                .range = 0,
                .format = .undefined,
            },
            .dirty = false,
        };
    }

    fn deinit(self: *CommandList) void {
        self.device.deleteObject(.command_buffer, @intFromEnum(self.command_buffer));
        self.device.deleteObject(.command_pool, @intFromEnum(self.command_pool));
    }

    fn fromGpuCommandList(command_list: *gpu.CommandList) *CommandList {
        return @ptrCast(@alignCast(command_list));
    }

    fn toGpuCommandList(command_list: *CommandList) *gpu.CommandList {
        return @ptrCast(@alignCast(command_list));
    }

    fn resetAllocator(self: *CommandList) void {
        if (self.is_open) {
            log.err("Cannot reset command allocator while command list is open", .{});
            self.end() catch {};
        }

        // self.device.device.resetCommandBuffer(self.command_buffer, .{
        //     .release_resources_bit = true,
        // }) catch |err| {
        //     log.err("Failed to reset command buffer: {s}", .{@errorName(err)});
        //     @panic("Failed to reset command buffer");
        // };

        self.device.device.resetCommandPool(self.command_pool, .{
            .release_resources_bit = true,
        }) catch |err| {
            log.err("Failed to reset command pool: {s}", .{@errorName(err)});
            @panic("Failed to reset command pool");
        };
    }

    fn begin(self: *CommandList) Error!void {
        const begin_info: vk.CommandBufferBeginInfo = .{
            .flags = .{
                .one_time_submit_bit = true,
            },
        };
        self.device.device.beginCommandBuffer(self.command_buffer, &begin_info) catch |err| {
            log.err("Failed to begin command buffer: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        self.is_open = true;

        self.resetState();
        return;
    }

    fn end(self: *CommandList) Error!void {
        self.flushBarriers();

        self.device.device.endCommandBuffer(self.command_buffer) catch |err| {
            log.err("Failed to end command buffer: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        self.is_open = false;
        return;
    }

    fn wait(self: *CommandList, fence: *Fence, value: u64) void {
        if (self.pending_waits_count >= max_fence_operations) {
            log.err("Exceeded maximum pending fence waits in command list", .{});
            return;
        }
        self.pending_waits[self.pending_waits_count] = .{
            .fence = fence,
            .value = value,
        };
        self.pending_waits_count += 1;
        return;
    }

    fn signal(self: *CommandList, fence: *Fence, value: u64) void {
        if (self.pending_signals_count >= max_fence_operations) {
            log.err("Exceeded maximum pending fence signals in command list", .{});
            return;
        }
        self.pending_signals[self.pending_signals_count] = .{
            .fence = fence,
            .value = value,
        };
        self.pending_signals_count += 1;
        return;
    }

    fn present(self: *CommandList, swapchain: *Swapchain) void {
        if (self.pending_swapchains_count >= max_present_swapchains) {
            log.err("Exceeded maximum pending swapchains in command list", .{});
            return;
        }
        self.pending_swapchains[self.pending_swapchains_count] = swapchain;
        self.pending_swapchains_count += 1;
        return;
    }

    fn submit(self: *CommandList) Error!void {
        self.device.flushLayoutTransition();

        var wait_semaphores: [64]vk.Semaphore = undefined;
        var wait_values: [64]u64 = undefined;
        var signal_semaphores: [64]vk.Semaphore = undefined;
        var signal_values: [64]u64 = undefined;

        var wait_stages: [64]vk.PipelineStageFlags = undefined;

        var timeline_info: vk.TimelineSemaphoreSubmitInfo = .{
            .wait_semaphore_value_count = 0,
            .p_wait_semaphore_values = &wait_values,
            .signal_semaphore_value_count = 0,
            .p_signal_semaphore_values = &signal_values,
        };

        for (
            self.pending_waits[0..self.pending_waits_count],
            wait_semaphores[0..self.pending_waits_count],
            wait_values[0..self.pending_waits_count],
            wait_stages[0..self.pending_waits_count],
        ) |fence_value, *ws, *w, *stage| {
            ws.* = fence_value.fence.semaphore;
            w.* = fence_value.value;
            stage.* = .{ .top_of_pipe_bit = true };
        }
        timeline_info.wait_semaphore_value_count = @intCast(self.pending_waits_count);
        self.pending_waits_count = 0;

        for (
            self.pending_signals[0..self.pending_signals_count],
            signal_semaphores[0..self.pending_signals_count],
            signal_values[0..self.pending_signals_count],
        ) |fence_value, *ss, *s| {
            ss.* = fence_value.fence.semaphore;
            s.* = fence_value.value;
        }
        timeline_info.signal_semaphore_value_count = @intCast(self.pending_signals_count);
        self.pending_signals_count = 0;

        self.command_count = 0;

        for (
            self.pending_swapchains[0..self.pending_swapchains_count],
            wait_semaphores[timeline_info.wait_semaphore_value_count..][0..self.pending_swapchains_count],
            wait_values[timeline_info.wait_semaphore_value_count..][0..self.pending_swapchains_count],
            wait_stages[timeline_info.wait_semaphore_value_count..][0..self.pending_swapchains_count],
            signal_semaphores[timeline_info.signal_semaphore_value_count..][0..self.pending_swapchains_count],
            signal_values[timeline_info.signal_semaphore_value_count..][0..self.pending_swapchains_count],
        ) |
            swapchain,
            *ws,
            *w,
            *stage,
            *ss,
            *s,
        | {
            ws.* = swapchain.getAcquireSemaphore();
            // binary semaphore
            w.* = 0;
            stage.* = .{ .top_of_pipe_bit = true };

            ss.* = swapchain.getPresentSemaphore();
            // binary semaphore
            s.* = 0;

            timeline_info.wait_semaphore_value_count += 1;
            timeline_info.signal_semaphore_value_count += 1;
        }

        const submit_info: vk.SubmitInfo = .{
            .p_next = &timeline_info,
            .wait_semaphore_count = timeline_info.wait_semaphore_value_count,
            .p_wait_semaphores = &wait_semaphores,
            .p_wait_dst_stage_mask = &wait_stages,
            .command_buffer_count = 1,
            .p_command_buffers = &.{self.command_buffer},
            .signal_semaphore_count = timeline_info.signal_semaphore_value_count,
            .p_signal_semaphores = &signal_semaphores,
        };
        self.device.device.queueSubmit(
            self.vk_queue,
            1,
            &.{submit_info},
            .null_handle,
        ) catch |err| {
            log.err("Failed to submit command buffer: {s}", .{@errorName(err)});
            return error.Gpu;
        };

        for (self.pending_swapchains[0..self.pending_swapchains_count]) |swapchain| {
            swapchain.present() catch |err| {
                log.err("Failed to present swapchain: {s}", .{@errorName(err)});
                return error.Gpu;
            };
        }
        self.pending_swapchains_count = 0;
    }

    fn resetState(self: *CommandList) void {
        self.texture_barriers_count = 0;
        self.buffer_barriers_count = 0;
        self.memory_barriers_count = 0;
        self.pending_waits_count = 0;
        self.pending_signals_count = 0;
        self.pending_swapchains_count = 0;
        self.is_in_render_pass = false;
        self.command_count = 0;
        self.current_pipeline_state = .null_handle;

        self.graphics_constants = .{
            .root = undefined,
            .first = .{
                .address = 0,
                .range = 0,
                .format = .undefined,
            },
            .second = .{
                .address = 0,
                .range = 0,
                .format = .undefined,
            },
            .dirty = false,
        };

        self.compute_constants = .{
            .root = undefined,
            .first = .{
                .address = 0,
                .range = 0,
                .format = .undefined,
            },
            .second = .{
                .address = 0,
                .range = 0,
                .format = .undefined,
            },
            .dirty = false,
        };

        if (self.queue == .graphics or self.queue == .compute) {
            const cbuffer = self.device.constantBufferAllocator().buffer;

            const cbuffer_gpu_address = impl.getBufferGpuAddress(self.device, cbuffer);

            const root_binding: vk.DescriptorBufferBindingInfoEXT = .{
                .address = cbuffer_gpu_address.toInt(),
                .usage = .{ .resource_descriptor_buffer_bit_ext = true },
            };

            const first_heap_binding: vk.DescriptorBufferBindingInfoEXT = .{
                .address = self.device.resource_descriptor_heap.gpu_address,
                .usage = .{ .resource_descriptor_buffer_bit_ext = true },
            };

            const second_heap_binding: vk.DescriptorBufferBindingInfoEXT = .{
                .address = self.device.sampler_descriptor_heap.gpu_address,
                .usage = .{ .sampler_descriptor_buffer_bit_ext = true },
            };

            const descriptor_buffers: [3]vk.DescriptorBufferBindingInfoEXT = .{
                root_binding,
                first_heap_binding,
                second_heap_binding,
            };

            self.device.device.cmdBindDescriptorBuffersEXT(
                self.command_buffer,
                3,
                &descriptor_buffers,
            );

            const buffer_indices: [2]u32 = .{ 1, 2 };
            const offsets: [2]vk.DeviceSize = .{ 0, 0 };

            self.device.device.cmdSetDescriptorBufferOffsetsEXT(
                self.command_buffer,
                .compute,
                self.device.pipeline_layout,
                1,
                2,
                &buffer_indices,
                &offsets,
            );

            if (self.queue == .graphics) {
                self.device.device.cmdSetDescriptorBufferOffsetsEXT(
                    self.command_buffer,
                    .graphics,
                    self.device.pipeline_layout,
                    1,
                    2,
                    &buffer_indices,
                    &offsets,
                );
            }
        }
    }

    fn textureBarrier(
        self: *CommandList,
        texture: *Texture,
        subresource: u32,
        before: gpu.Access,
        after: gpu.Access,
    ) void {
        if (self.texture_barriers_count >= max_barriers_store) {
            log.err("Exceeded maximum texture barriers in command list", .{});
            return;
        }

        var subresource_range: vk.ImageSubresourceRange = .{
            .aspect_mask = conv.formatToAspectMask(texture.desc.format),
            .base_mip_level = 0,
            .level_count = texture.desc.mip_levels,
            .base_array_layer = subresource,
            .layer_count = 1,
        };

        if (subresource == gpu.all_subresource) {
            subresource_range.base_array_layer = 0;
            subresource_range.layer_count = vk.REMAINING_ARRAY_LAYERS;
            subresource_range.level_count = vk.REMAINING_MIP_LEVELS;
            subresource_range.base_mip_level = 0;
        }

        const barrier: vk.ImageMemoryBarrier2 = .{
            .image = texture.image,
            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .src_stage_mask = conv.stageMask(before),
            .dst_stage_mask = conv.stageMask(after),
            .src_access_mask = conv.accessMask(before),
            .dst_access_mask = conv.accessMask(after),
            .old_layout = conv.imageLayoutFromAccess(before),
            .new_layout = conv.imageLayoutFromAccess(if (after.discard) before else after),
            .subresource_range = subresource_range,
        };

        self.texture_barriers[self.texture_barriers_count] = barrier;
        self.texture_barriers_count += 1;
    }

    fn bufferBarrier(
        self: *CommandList,
        buffer: *Buffer,
        before: gpu.Access,
        after: gpu.Access,
    ) void {
        if (self.buffer_barriers_count >= max_barriers_store) {
            log.err("Exceeded maximum buffer barriers in command list", .{});
            return;
        }

        const barrier: vk.BufferMemoryBarrier2 = .{
            .buffer = buffer.buffer,
            .offset = 0,
            .size = buffer.desc.size,
            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .src_stage_mask = conv.stageMask(before),
            .dst_stage_mask = conv.stageMask(after),
            .src_access_mask = conv.accessMask(before),
            .dst_access_mask = conv.accessMask(after),
        };

        self.buffer_barriers[self.buffer_barriers_count] = barrier;
        self.buffer_barriers_count += 1;
    }

    fn globalBarrier(
        self: *CommandList,
        before: gpu.Access,
        after: gpu.Access,
    ) void {
        if (self.memory_barriers_count >= max_barriers_store) {
            log.err("Exceeded maximum global barriers in command list", .{});
            return;
        }

        const barrier: vk.MemoryBarrier2 = .{
            .src_stage_mask = conv.stageMask(before),
            .dst_stage_mask = conv.stageMask(after),
            .src_access_mask = conv.accessMask(before),
            .dst_access_mask = conv.accessMask(after),
        };

        self.memory_barriers[self.memory_barriers_count] = barrier;
        self.memory_barriers_count += 1;
    }

    fn flushBarriers(self: *CommandList) void {
        if (self.texture_barriers_count == 0 and
            self.buffer_barriers_count == 0 and
            self.memory_barriers_count == 0)
        {
            return;
        }

        var info: vk.DependencyInfo = .{
            .memory_barrier_count = @intCast(self.memory_barriers_count),
            .p_memory_barriers = self.memory_barriers[0..],
            .buffer_memory_barrier_count = @intCast(self.buffer_barriers_count),
            .p_buffer_memory_barriers = self.buffer_barriers[0..],
            .image_memory_barrier_count = @intCast(self.texture_barriers_count),
            .p_image_memory_barriers = self.texture_barriers[0..],
        };

        self.device.device.cmdPipelineBarrier2(
            self.command_buffer,
            &info,
        );

        self.texture_barriers_count = 0;
        self.buffer_barriers_count = 0;
        self.memory_barriers_count = 0;
    }

    // shared stuff
    fn bindPipeline(self: *CommandList, pipeline: *Pipeline) void {
        if (self.current_pipeline_state == pipeline.pipeline) {
            return;
        }
        self.current_pipeline_state = pipeline.pipeline;
        self.device.device.cmdBindPipeline(
            self.command_buffer,
            switch (pipeline.kind) {
                .graphics => .graphics,
                .compute => .compute,
            },
            pipeline.pipeline,
        );
    }

    fn setComputeConstants(self: *CommandList, slot: gpu.ConstantSlot, data: []const u8) void {
        const buffer_slot: u32 = switch (slot) {
            .root => {
                std.debug.assert(data.len <= gpu.max_root_constant_size_bytes);
                @memcpy(
                    @as([]u8, @ptrCast(self.compute_constants.root[0..]))[0..data.len],
                    data,
                );
                return;
            },
            .buffer1 => 1,
            .buffer2 => 2,
        };

        const address = self.device.allocateConstant(data) catch {
            log.err("Failed to allocate constant buffer for compute root constants", .{});
            return;
        };
        switch (buffer_slot) {
            1 => {
                self.compute_constants.first = .{
                    .address = address.gpu.toInt(),
                    .range = data.len,
                    .format = .undefined,
                };
            },
            2 => {
                self.compute_constants.second = .{
                    .address = address.gpu.toInt(),
                    .range = data.len,
                    .format = .undefined,
                };
            },
            else => unreachable,
        }

        self.compute_constants.dirty = true;
    }

    fn setGraphicsConstants(self: *CommandList, slot: gpu.ConstantSlot, data: []const u8) void {
        const buffer_slot: u32 = switch (slot) {
            .root => {
                std.debug.assert(data.len <= gpu.max_root_constant_size_bytes);
                @memcpy(
                    @as([]u8, @ptrCast(self.graphics_constants.root[0..]))[0..data.len],
                    data,
                );
                return;
            },
            .buffer1 => 1,
            .buffer2 => 2,
        };

        const address = self.device.allocateConstant(data) catch {
            log.err("Failed to allocate constant buffer for compute root constants", .{});
            return;
        };
        switch (buffer_slot) {
            1 => {
                self.graphics_constants.first = .{
                    .address = address.gpu.toInt(),
                    .range = data.len,
                    .format = .undefined,
                };
            },
            2 => {
                self.graphics_constants.second = .{
                    .address = address.gpu.toInt(),
                    .range = data.len,
                    .format = .undefined,
                };
            },
            else => unreachable,
        }

        self.graphics_constants.dirty = true;
    }

    // render pass
    fn beginRenderPass(self: *CommandList, desc: gpu.RenderPass.Desc) void {
        self.flushBarriers();
        var rt_descs: [8]vk.RenderingAttachmentInfo = @splat(undefined);
        var d_desc: ?vk.RenderingAttachmentInfo = null;
        var s_desc: ?vk.RenderingAttachmentInfo = null;

        var width: u32 = 0;
        var height: u32 = 0;

        for (desc.color_attachments, 0..) |attachment, i| {
            const texture: *Texture = .fromGpuTexture(attachment.texture.texture);
            if (width == 0) {
                width = texture.desc.width;
            }

            if (height == 0) {
                height = texture.desc.height;
            }

            std.debug.assert(width == texture.desc.width);
            std.debug.assert(height == texture.desc.height);

            rt_descs[i] = .{
                .image_view = texture.getImageView(
                    attachment.texture.mip_level,
                    attachment.texture.depth_or_array_layer,
                ),
                .image_layout = .color_attachment_optimal,
                .resolve_mode = .{},
                .resolve_image_layout = .undefined,
                .load_op = conv.renderPassLoadColorOp(attachment.load),
                .store_op = conv.renderPassStoreOp(attachment.store),
                .clear_value = .{
                    .color = switch (attachment.load) {
                        .clear => |c| .{
                            .float_32 = c,
                        },
                        else => .{ .float_32 = .{ 0.0, 0.0, 0.0, 0.0 } },
                    },
                },
            };
        }
        const rt_count = desc.color_attachments.len;

        if (desc.depth_stencil_attachment) |ds_attachment| {
            const texture: *Texture = .fromGpuTexture(ds_attachment.texture.texture);
            if (width == 0) {
                width = texture.desc.width;
            }

            if (height == 0) {
                height = texture.desc.height;
            }

            std.debug.assert(width == texture.desc.width);
            std.debug.assert(height == texture.desc.height);

            d_desc = .{
                .image_view = texture.getImageView(
                    ds_attachment.texture.mip_level,
                    ds_attachment.texture.depth_or_array_layer,
                ),
                .image_layout = if (ds_attachment.depth_store == .discard)
                    .depth_stencil_read_only_optimal
                else
                    .depth_stencil_attachment_optimal,
                .resolve_mode = .{},
                .resolve_image_layout = .undefined,
                .load_op = conv.renderPassLoadDepthOp(ds_attachment.depth_load),
                .store_op = conv.renderPassStoreOp(ds_attachment.depth_store),
                .clear_value = .{
                    .depth_stencil = switch (ds_attachment.depth_load) {
                        .clear => |c| .{
                            .depth = c,
                            .stencil = 0,
                        },
                        else => .{ .depth = 0.0, .stencil = 0 },
                    },
                },
            };

            if (texture.desc.format.isStencilFormat()) {
                s_desc = .{
                    .image_view = texture.getImageView(
                        ds_attachment.texture.mip_level,
                        ds_attachment.texture.depth_or_array_layer,
                    ),
                    .image_layout = if (ds_attachment.stencil_store == .discard)
                        .depth_stencil_read_only_optimal
                    else
                        .depth_stencil_attachment_optimal,
                    .resolve_mode = .{},
                    .resolve_image_layout = .undefined,
                    .load_op = conv.renderPassLoadStencilOp(ds_attachment.stencil_load),
                    .store_op = conv.renderPassStoreOp(ds_attachment.stencil_store),
                    .clear_value = .{
                        .depth_stencil = switch (ds_attachment.stencil_load) {
                            .clear => |c| .{
                                .depth = 0.0,
                                .stencil = c,
                            },
                            else => .{ .depth = 0.0, .stencil = 0 },
                        },
                    },
                };
            }
        }

        const info: vk.RenderingInfo = .{
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = width, .height = height },
            },
            .layer_count = 1,
            .view_mask = 0,
            .color_attachment_count = @intCast(rt_count),
            .p_color_attachments = &rt_descs,
            .p_depth_attachment = if (d_desc) |attachment_desc| &attachment_desc else null,
            .p_stencil_attachment = if (s_desc) |attachment_desc| &attachment_desc else null,
        };

        self.device.device.cmdBeginRendering(
            self.command_buffer,
            &info,
        );

        self.is_in_render_pass = true;

        self.command_count += 1;

        self.setViewports(&.{.{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
        }});
        self.setScissors(&.{
            .{
                .x = 0,
                .y = 0,
                .width = width,
                .height = height,
            },
        });
        self.setStencilReference(0);
        self.setBlendConstants(@splat(1.0));
    }

    fn endRenderPass(self: *CommandList) void {
        if (!self.is_in_render_pass) {
            log.err("Cannot end render pass when not in a render pass", .{});
            return;
        }

        self.device.device.cmdEndRendering(self.command_buffer);

        self.is_in_render_pass = false;

        self.command_count += 1;
        return;
    }

    fn setViewports(self: *CommandList, viewports: []const spatial.Viewport) void {
        var vk_viewports: [16]vk.Viewport = undefined;
        const count = @min(viewports.len, vk_viewports.len);

        for (viewports[0..count], 0..) |viewport, i| {
            vk_viewports[i] = .{
                .x = viewport.x,
                .y = viewport.y,
                .width = viewport.width,
                .height = viewport.height,
                .min_depth = viewport.min_depth,
                .max_depth = viewport.max_depth,
            };
        }

        self.device.device.cmdSetViewport(
            self.command_buffer,
            0,
            @intCast(count),
            &vk_viewports,
        );
    }

    fn setScissors(self: *CommandList, rects: []const spatial.Rect) void {
        var vk_rects: [16]vk.Rect2D = undefined;
        const count = @min(rects.len, vk_rects.len);

        for (rects[0..count], 0..) |rect, i| {
            vk_rects[i] = .{
                .offset = .{
                    .x = @intCast(rect.x),
                    .y = @intCast(rect.y),
                },
                .extent = .{
                    .width = @intCast(rect.width),
                    .height = @intCast(rect.height),
                },
            };
        }
        self.device.device.cmdSetScissor(
            self.command_buffer,
            0,
            @intCast(count),
            &vk_rects,
        );
    }

    fn setBlendConstants(self: *CommandList, constants: [4]f32) void {
        self.device.device.cmdSetBlendConstants(
            self.command_buffer,
            &constants,
        );
    }

    fn setStencilReference(self: *CommandList, reference: u32) void {
        self.device.device.cmdSetStencilReference(
            self.command_buffer,
            .{ .front_bit = true, .back_bit = true },
            reference,
        );
    }

    fn bindIndexBuffer(self: *CommandList, region: gpu.Buffer.Slice, index_element: gpu.IndexFormat) void {
        const buffer: *Buffer = .fromGpuBuffer(region.buffer);
        self.device.device.cmdBindIndexBuffer(
            self.command_buffer,
            buffer.buffer,
            region.offset,
            switch (index_element) {
                .uint16 => .uint16,
                .uint32 => .uint32,
            },
        );
    }

    fn draw(self: *CommandList, vertex_count: u32, instance_count: u32, start_vertex: u32, start_instance: u32) void {
        self.updateGraphicsDescriptorBuffer();
        self.device.device.cmdDraw(
            self.command_buffer,
            vertex_count,
            instance_count,
            start_vertex,
            start_instance,
        );
        self.command_count += 1;
    }

    fn drawIndexed(
        self: *CommandList,
        index_count: u32,
        instance_count: u32,
        start_index: u32,
        base_vertex: i32,
        start_instance: u32,
    ) void {
        self.updateGraphicsDescriptorBuffer();
        self.device.device.cmdDrawIndexed(
            self.command_buffer,
            index_count,
            instance_count,
            start_index,
            base_vertex,
            start_instance,
        );
        self.command_count += 1;
    }

    fn drawIndirect(self: *CommandList, buffer: gpu.Buffer.Slice, draw_count: u32) void {
        const gpu_buffer: *Buffer = .fromGpuBuffer(buffer.buffer);
        self.updateGraphicsDescriptorBuffer();
        self.device.device.cmdDrawIndirect(
            self.command_buffer,
            gpu_buffer.buffer,
            buffer.offset,
            draw_count,
            0,
        );
    }

    fn drawIndexedIndirect(self: *CommandList, buffer: gpu.Buffer.Slice, draw_count: u32) void {
        const gpu_buffer: *Buffer = .fromGpuBuffer(buffer.buffer);
        self.updateGraphicsDescriptorBuffer();
        self.device.device.cmdDrawIndexedIndirect(
            self.command_buffer,
            gpu_buffer.buffer,
            buffer.offset,
            draw_count,
            0,
        );
    }

    fn multiDrawIndirect(self: *CommandList, buffer: gpu.Buffer.Slice, count: gpu.Buffer.Location) void {
        _ = self;
        _ = buffer;
        _ = count;
        @panic("TODO: Not implemented yet, implement multi draw signature");
        // self.updateGraphicsDescriptorBuffer();
        // self.device.device.cmdDrawIndirectCount(
        //     self.command_buffer,
        //     .fromGpuBuffer(buffer.buffer).buffer,
        //     buffer.offset,
        //     .fromGpuBuffer(count.buffer).buffer,
        //     count.offset,
        //     @intCast(count.size / @sizeOf(gpu.IndirectDrawCommand)),
        //     0,
        // );
    }

    fn multiDrawIndexedIndirect(self: *CommandList, buffer: gpu.Buffer.Slice, count: gpu.Buffer.Location) void {
        _ = self;
        _ = buffer;
        _ = count;
        @panic("TODO: Not implemented yet, implement multi draw indexed signature");
    }

    // compute stuff
    fn dispatch(self: *CommandList, workgroup_x: u32, workgroup_y: u32, workgroup_z: u32) void {
        self.flushBarriers();
        self.updateComputeDescriptorBuffer();

        self.device.device.cmdDispatch(
            self.command_buffer,
            workgroup_x,
            workgroup_y,
            workgroup_z,
        );
        self.command_count += 1;
    }

    fn dispatchIndirect(self: *CommandList, buffer: gpu.Buffer.Slice) void {
        self.flushBarriers();
        self.updateComputeDescriptorBuffer();

        const gpu_buffer: *Buffer = .fromGpuBuffer(buffer.buffer);
        self.device.device.cmdDispatchIndirect(
            self.command_buffer,
            gpu_buffer.buffer,
            buffer.offset,
        );
        self.command_count += 1;
    }

    // copy
    fn writeBuffer(self: *CommandList, buffer: *Buffer, offset: u32, data: u32) void {
        self.flushBarriers();

        self.device.device.cmdUpdateBuffer(
            self.command_buffer,
            buffer.buffer,
            offset,
            @sizeOf(u32),
            @ptrCast(&data),
        );
        self.command_count += 1;
    }

    fn copyBufferToTexture(self: *CommandList, source: gpu.Buffer.Location, destination: gpu.Texture.Slice) void {
        self.flushBarriers();

        const dst_texture: *Texture = .fromGpuTexture(destination.texture);
        const src_buffer: *Buffer = .fromGpuBuffer(source.buffer);
        const desc = dst_texture.desc;

        const width = @max(desc.width >> @as(u5, @intCast(destination.mip_level)), 1);
        const height = @max(desc.height >> @as(u5, @intCast(destination.mip_level)), 1);
        const depth = @max(desc.depth_or_array_layers >> @as(u5, @intCast(destination.mip_level)), 1);

        const copy: vk.BufferImageCopy2 = .{
            .buffer_offset = source.offset,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = conv.formatToAspectMask(desc.format),
                .mip_level = destination.mip_level,
                .base_array_layer = destination.depth_or_array_layer,
                .layer_count = 1,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{ .width = width, .height = height, .depth = depth },
        };

        const info: vk.CopyBufferToImageInfo2 = .{
            .src_buffer = src_buffer.buffer,
            .dst_image = dst_texture.image,
            .dst_image_layout = .transfer_dst_optimal,
            .region_count = 1,
            .p_regions = &.{copy},
        };
        self.device.device.cmdCopyBufferToImage2(
            self.command_buffer,
            &info,
        );

        self.command_count += 1;
    }

    fn copyTextureToBuffer(self: *CommandList, source: gpu.Texture.Slice, destination: gpu.Buffer.Location) void {
        self.flushBarriers();

        const src_texture: *Texture = .fromGpuTexture(source.texture);
        const dst_buffer: *Buffer = .fromGpuBuffer(destination.buffer);
        const desc = src_texture.desc;

        const width = @max(desc.width >> @as(u5, @intCast(source.mip_level)), 1);
        const height = @max(desc.height >> @as(u5, @intCast(source.mip_level)), 1);
        const depth = @max(desc.depth_or_array_layers >> @as(u5, @intCast(source.mip_level)), 1);

        const copy: vk.BufferImageCopy2 = .{
            .buffer_offset = destination.offset,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = conv.formatToAspectMask(desc.format),
                .mip_level = source.mip_level,
                .base_array_layer = source.depth_or_array_layer,
                .layer_count = 1,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{ .width = width, .height = height, .depth = depth },
        };

        const info: vk.CopyImageToBufferInfo2 = .{
            .src_image = src_texture.image,
            .src_image_layout = .transfer_src_optimal,
            .dst_buffer = dst_buffer.buffer,
            .region_count = 1,
            .p_regions = &.{copy},
        };

        self.device.device.cmdCopyImageToBuffer2(
            self.command_buffer,
            &info,
        );

        self.command_count += 1;
    }

    fn copyTextureToTexture(self: *CommandList, source: gpu.Texture.Slice, destination: gpu.Texture.Slice) void {
        self.flushBarriers();

        const src_texture: *Texture = .fromGpuTexture(source.texture);
        const dst_texture: *Texture = .fromGpuTexture(destination.texture);

        const copy: vk.ImageCopy2 = .{
            .src_subresource = .{
                .aspect_mask = conv.formatToAspectMask(src_texture.desc.format),
                .mip_level = source.mip_level,
                .base_array_layer = source.depth_or_array_layer,
                .layer_count = 1,
            },
            .src_offset = .{ .x = 0, .y = 0, .z = 0 },
            .dst_subresource = .{
                .aspect_mask = conv.formatToAspectMask(dst_texture.desc.format),
                .mip_level = destination.mip_level,
                .base_array_layer = destination.depth_or_array_layer,
                .layer_count = 1,
            },
            .dst_offset = .{ .x = 0, .y = 0, .z = 0 },
            .extent = .{
                .width = @max(src_texture.desc.width >> @as(u5, @intCast(source.mip_level)), 1),
                .height = @max(src_texture.desc.height >> @as(u5, @intCast(source.mip_level)), 1),
                .depth = @max(src_texture.desc.depth_or_array_layers >> @as(u5, @intCast(source.mip_level)), 1),
            },
        };

        const info: vk.CopyImageInfo2 = .{
            .src_image = src_texture.image,
            .src_image_layout = .transfer_src_optimal,
            .dst_image = dst_texture.image,
            .dst_image_layout = .transfer_dst_optimal,
            .region_count = 1,
            .p_regions = &.{copy},
        };

        self.device.device.cmdCopyImage2(
            self.command_buffer,
            &info,
        );

        self.command_count += 1;
    }

    fn copyBufferToBuffer(
        self: *CommandList,
        source: gpu.Buffer.Location,
        destination: gpu.Buffer.Location,
        size: gpu.Size,
    ) void {
        self.flushBarriers();

        const src_buffer: *Buffer = .fromGpuBuffer(source.buffer);
        const dst_buffer: *Buffer = .fromGpuBuffer(destination.buffer);

        const copy_size = size.toInt() orelse (src_buffer.desc.size - source.offset);

        const copy: vk.BufferCopy2 = .{
            .src_offset = source.offset,
            .dst_offset = destination.offset,
            .size = copy_size,
        };

        const info: vk.CopyBufferInfo2 = .{
            .src_buffer = src_buffer.buffer,
            .dst_buffer = dst_buffer.buffer,
            .region_count = 1,
            .p_regions = &.{copy},
        };

        self.device.device.cmdCopyBuffer2(
            self.command_buffer,
            &info,
        );

        self.command_count += 1;
    }

    fn updateGraphicsDescriptorBuffer(self: *CommandList) void {
        if (!self.graphics_constants.dirty) {
            return;
        }

        const buffer_offset = self.device.allocateConstantBufferDescriptor(
            &self.graphics_constants.root,
            &self.graphics_constants.first,
            &self.graphics_constants.second,
        ) catch |err| {
            log.err("Failed to allocate constant buffer for graphics root constants ({s})", .{@errorName(err)});
            return;
        };

        const buffer_indices: [1]u32 = .{0};
        const offsets: [1]vk.DeviceSize = .{buffer_offset};

        self.device.device.cmdSetDescriptorBufferOffsetsEXT(
            self.command_buffer,
            .graphics,
            self.device.pipeline_layout,
            0,
            1,
            &buffer_indices,
            &offsets,
        );

        self.graphics_constants.dirty = false;
    }

    fn updateComputeDescriptorBuffer(self: *CommandList) void {
        if (!self.compute_constants.dirty) {
            return;
        }

        const buffer_offset = self.device.allocateConstantBufferDescriptor(
            &self.compute_constants.root,
            &self.compute_constants.first,
            &self.compute_constants.second,
        ) catch |err| {
            log.err("Failed to allocate constant buffer for compute root constants ({s})", .{@errorName(err)});
            return;
        };

        const buffer_indices: [1]u32 = .{0};
        const offsets: [1]vk.DeviceSize = .{buffer_offset};

        self.device.device.cmdSetDescriptorBufferOffsetsEXT(
            self.command_buffer,
            .compute,
            self.device.pipeline_layout,
            0,
            1,
            &buffer_indices,
            &offsets,
        );

        self.compute_constants.dirty = false;
    }
};

const Descriptor = struct {
    device: *Device,
    allocator: std.mem.Allocator = undefined,
    resource: ?Resource = null,
    descriptor: OffsetAllocator.Allocation = .invalid,
    descriptor_size: usize = 0,
    kind: gpu.Descriptor.Kind,

    const Resource = union(enum) {
        buffer: *Buffer,
        texture: struct {
            texture: *Texture,
            view: vk.ImageView,
        },
        sampler: vk.Sampler,
    };

    fn init(self: *Descriptor, device: *Device, desc: gpu.Descriptor.Desc, name: []const u8) !void {
        _ = name;

        self.* = .{
            .device = device,
            .kind = desc.kind,
        };

        const descriptor_buffer_properties = device.descriptor_buffer_properties;

        var descriptor_info: vk.DescriptorGetInfoEXT = .{
            .type = undefined,
            .data = undefined,
        };
        var buffer_info: vk.DescriptorAddressInfoEXT = .{
            .address = 0,
            .range = 0,
            .format = .undefined,
        };
        var image_info: vk.DescriptorImageInfo = .{
            .sampler = .null_handle,
            .image_view = .null_handle,
            .image_layout = if (desc.kind.isRead()) .shader_read_only_optimal else .general,
        };
        var image_view_usage_create_info: vk.ImageViewUsageCreateInfo = .{
            .usage = .{
                .sampled_bit = desc.kind.isRead(),
                .storage_bit = desc.kind.isWrite(),
            },
        };
        var image_view_create_info: vk.ImageViewCreateInfo = .{
            .flags = .{},
            .image = .null_handle,
            .view_type = .@"2d",
            .format = .undefined,
            .components = .{
                .r = .identity,
                .g = .identity,
                .b = .identity,
                .a = .identity,
            },
            .subresource_range = undefined,
        };
        image_view_create_info.s_type = .image_view_create_info;
        image_view_create_info.p_next = null;

        var image_view: vk.ImageView = .null_handle;
        switch (desc.resource) {
            .texture => |t| {
                const texture: *Texture = .fromGpuTexture(t.texture);
                image_view_create_info.p_next = &image_view_usage_create_info;
                image_view_create_info.image = texture.image;
                image_view_create_info.format = conv.vkFormat(desc.format, true);
                image_view_create_info.subresource_range = .{
                    .aspect_mask = conv.formatToAspectMask(desc.format),
                    .base_mip_level = t.mip_level,
                    .level_count = if (desc.kind.isRead()) t.mip_level_count else 1,
                    .base_array_layer = t.depth_or_array_layer,
                    .layer_count = t.depth_or_array_layer_count,
                };

                descriptor_info.type = if (desc.kind.isRead()) .sampled_image else .storage_image;
                descriptor_info.data = .{
                    // same data for sampled and storage images
                    .p_storage_image = &image_info,
                };
                self.descriptor_size = descriptor_buffer_properties.sampled_image_descriptor_size;
            },
            else => {},
        }

        var sampler: vk.Sampler = .null_handle;
        switch (desc.kind) {
            .shader_read_texture_2d => {
                image_view_create_info.view_type = .@"2d";
                image_view = try device.device.createImageView(
                    &image_view_create_info,
                    null,
                );
                image_info.image_view = image_view;
            },
            .shader_read_texture_2d_array => {
                image_view_create_info.view_type = .@"2d_array";
                image_view = try device.device.createImageView(
                    &image_view_create_info,
                    null,
                );
                image_info.image_view = image_view;
            },
            .shader_read_texture_cube => {
                image_view_create_info.view_type = .cube;
                image_view = try device.device.createImageView(
                    &image_view_create_info,
                    null,
                );
                image_info.image_view = image_view;
            },
            .shader_read_texture_3d => {
                image_view_create_info.view_type = .@"3d";
                image_view = try device.device.createImageView(
                    &image_view_create_info,
                    null,
                );
                image_info.image_view = image_view;
            },
            .shader_read_buffer => {
                const buffer: *Buffer = .fromGpuBuffer(desc.resource.buffer.buffer);

                const buffer_desc = buffer.desc;

                const computed_size = desc.resource.buffer.size.toInt() orelse
                    buffer_desc.size - desc.resource.buffer.offset;

                // std.debug.assert(desc.format == .unknown);
                std.debug.assert(desc.resource.buffer.offset % 4 == 0);
                std.debug.assert(computed_size % 4 == 0);

                buffer_info.address = buffer.gpuAddress().toInt() + desc.resource.buffer.offset;
                buffer_info.range = @intCast(computed_size);

                descriptor_info.type = .storage_buffer;
                descriptor_info.data = .{
                    .p_storage_buffer = &buffer_info,
                };

                self.descriptor_size = descriptor_buffer_properties.storage_buffer_descriptor_size;
            },
            .shader_read_top_level_acceleration_structure => {
                // kind = .SRV;
                @panic("TODO");
            },

            .shader_write_texture_2d => {
                image_view_create_info.view_type = .@"2d";
                image_view = try device.device.createImageView(
                    &image_view_create_info,
                    null,
                );
                image_info.image_view = image_view;
            },
            .shader_write_texture_2d_array => {
                image_view_create_info.view_type = .@"2d_array";
                image_view = try device.device.createImageView(
                    &image_view_create_info,
                    null,
                );
                image_info.image_view = image_view;
            },
            .shader_write_texture_3d => {
                image_view_create_info.view_type = .@"3d";
                image_view = try device.device.createImageView(
                    &image_view_create_info,
                    null,
                );
                image_info.image_view = image_view;
            },
            .shader_write_buffer => {
                const buffer: *Buffer = .fromGpuBuffer(desc.resource.buffer.buffer);

                const buffer_desc = buffer.desc;

                std.debug.assert(buffer_desc.usage.shader_write);

                const computed_size = desc.resource.buffer.size.toInt() orelse
                    buffer_desc.size - desc.resource.buffer.offset;

                // std.debug.assert(desc.format == .unknown);
                std.debug.assert(desc.resource.buffer.offset % 4 == 0);
                std.debug.assert(computed_size % 4 == 0);

                buffer_info.address = buffer.gpuAddress().toInt() + desc.resource.buffer.offset;
                buffer_info.range = @intCast(computed_size);

                descriptor_info.type = .storage_buffer;
                descriptor_info.data = .{
                    .p_storage_buffer = &buffer_info,
                };
                self.descriptor_size = descriptor_buffer_properties.storage_buffer_descriptor_size;
            },

            .constant_buffer => {
                const buffer: *Buffer = .fromGpuBuffer(desc.resource.buffer.buffer);

                const buffer_desc = buffer.desc;

                const computed_size = desc.resource.buffer.size.toInt() orelse
                    buffer_desc.size - desc.resource.buffer.offset;

                std.debug.assert(desc.format == .unknown);
                std.debug.assert(computed_size % 256 == 0);

                buffer_info.address = buffer.gpuAddress().toInt() + desc.resource.buffer.offset;
                buffer_info.range = @intCast(computed_size);

                descriptor_info.type = .uniform_buffer;
                descriptor_info.data = .{
                    .p_uniform_buffer = &buffer_info,
                };
                self.descriptor_size = descriptor_buffer_properties.uniform_buffer_descriptor_size;
            },
            .sampler => {
                const sampler_info = desc.resource.sampler;
                const use_anisotropy = sampler_info.anisotropy > 1;
                const use_comparison = sampler_info.compare_op != .never;

                const create_info: vk.SamplerCreateInfo = .{
                    .s_type = .sampler_create_info,
                    .p_next = null,
                    .flags = .{},
                    .mag_filter = conv.filter(desc.resource.sampler.filters.mag),
                    .min_filter = conv.filter(desc.resource.sampler.filters.min),
                    .mipmap_mode = conv.mipmapMode(desc.resource.sampler.filters.mip),
                    .address_mode_u = conv.addressMode(sampler_info.address_modes.u),
                    .address_mode_v = conv.addressMode(sampler_info.address_modes.v),
                    .address_mode_w = conv.addressMode(sampler_info.address_modes.w),
                    .mip_lod_bias = sampler_info.mip_bias,
                    .anisotropy_enable = if (use_anisotropy) .true else .false,
                    .max_anisotropy = if (use_anisotropy) @floatFromInt(sampler_info.anisotropy) else 1.0,
                    .compare_enable = if (use_comparison) .true else .false,
                    .compare_op = conv.compareOp(sampler_info.compare_op),
                    .min_lod = sampler_info.mip_min,
                    .max_lod = sampler_info.mip_max,
                    .border_color = .float_transparent_black,
                    .unnormalized_coordinates = .false,
                };

                sampler = try device.device.createSampler(
                    &create_info,
                    null,
                );

                descriptor_info.type = .sampler;
                descriptor_info.data = .{
                    .p_sampler = &sampler,
                };
                self.descriptor_size = descriptor_buffer_properties.sampler_descriptor_size;
            },
        }

        const allocation, const descriptor = if (sampler != .null_handle)
            try device.sampler_descriptor_heap.alloc()
        else
            try device.resource_descriptor_heap.alloc();
        self.descriptor = allocation;

        device.device.getDescriptorEXT(
            &descriptor_info,
            self.descriptor_size,
            descriptor.ptr,
        );

        if (sampler != .null_handle) {
            self.resource = .{ .sampler = sampler };
        } else if (image_view != .null_handle) {
            self.resource = .{ .texture = .{
                .texture = switch (desc.resource) {
                    .texture => |t| .fromGpuTexture(t.texture),
                    else => unreachable,
                },
                .view = image_view,
            } };
        } else {
            self.resource = switch (desc.resource) {
                .buffer => |b| .{ .buffer = .fromGpuBuffer(b.buffer) },
                else => unreachable,
            };
        }
    }

    fn deinit(self: *Descriptor) void {
        switch (self.resource.?) {
            .texture => |t| {
                self.device.deleteObject(.image_view, @intFromEnum(t.view));
            },
            .sampler => |s| {
                self.device.deleteObject(.sampler, @intFromEnum(s));
            },
            else => {},
        }

        switch (self.kind) {
            .sampler => {
                self.device.deleteSamplerDescriptor(self.descriptor);
            },
            else => {
                self.device.deleteResourceDescriptor(self.descriptor);
            },
        }
    }

    fn fromGpuDescriptor(gpu_descriptor: *gpu.Descriptor) *Descriptor {
        return @ptrCast(@alignCast(gpu_descriptor));
    }

    fn fromGpuDescriptorConst(gpu_descriptor: *const gpu.Descriptor) *const Descriptor {
        return @ptrCast(@alignCast(gpu_descriptor));
    }

    fn toGpuDescriptor(self: *Descriptor) *gpu.Descriptor {
        return @ptrCast(@alignCast(self));
    }

    fn descriptorIndex(self: *const Descriptor) usize {
        return self.descriptor.offset;
    }
};

const Fence = struct {
    device: *Device,
    allocator: std.mem.Allocator,
    semaphore: vk.Semaphore,

    fn init(self: *Fence, device: *Device, name: []const u8) !void {
        self.* = .{
            .semaphore = .null_handle,
            .device = device,
            .allocator = self.allocator,
        };

        const semaphore_info: vk.SemaphoreTypeCreateInfo = .{
            .initial_value = 0,
            .semaphore_type = .timeline,
        };

        const create_info: vk.SemaphoreCreateInfo = .{
            .p_next = &semaphore_info,
        };

        const result = try self.device.device.createSemaphore(&create_info, null);
        self.semaphore = result;

        setDebugName(&self.device.device, .semaphore, vk.Semaphore, self.semaphore, name);
    }

    fn deinit(self: *Fence) void {
        self.device.deleteObject(.semaphore, @intFromEnum(self.semaphore));
    }

    fn fromGpuFence(fence: *gpu.Fence) *Fence {
        return @ptrCast(@alignCast(fence));
    }

    fn toGpuFence(fence: *Fence) *gpu.Fence {
        return @ptrCast(@alignCast(fence));
    }

    fn wait(self: *Fence, value: u64) Error!void {
        const wait_info: vk.SemaphoreWaitInfo = .{
            .semaphore_count = 1,
            .p_semaphores = &.{self.semaphore},
            .p_values = &.{value},
        };
        _ = self.device.device.waitSemaphores(&wait_info, std.math.maxInt(u64)) catch |err| {
            log.err("Failed to wait on fence: {s}", .{@errorName(err)});
            return error.Gpu;
        };
    }

    fn signal(self: *Fence, value: u64) Error!void {
        const signal_info: vk.SemaphoreSignalInfo = .{
            .semaphore = self.semaphore,
            .value = value,
        };
        self.device.device.signalSemaphore(&signal_info) catch |err| {
            log.err("Failed to signal fence: {s}", .{@errorName(err)});
            return error.Gpu;
        };
    }
};

const Pipeline = struct {
    device: *Device,
    allocator: std.mem.Allocator = undefined,
    pipeline: vk.Pipeline = .null_handle,

    kind: gpu.Pipeline.Kind,

    fn initGraphics(self: *Pipeline, device: *Device, desc: gpu.Pipeline.GraphicsDesc, name: []const u8) Error!void {
        self.* = .{
            .device = device,
            .pipeline = .null_handle,
            .kind = .graphics,
        };

        const pipeline_layout = device.pipeline_layout;

        const vs_shader_module_create_info: vk.ShaderModuleCreateInfo = .{
            .code_size = desc.vs.len,
            .p_code = @ptrCast(@alignCast(desc.vs.ptr)),
        };
        const vs_shader_module: vk.ShaderModule = device.device.createShaderModule(
            &vs_shader_module_create_info,
            null,
        ) catch |err| {
            log.err("Failed to create vertex shader module for graphics pipeline ({s}): {s}", .{ name, @errorName(err) });
            return error.Gpu;
        };
        defer device.device.destroyShaderModule(vs_shader_module, null);

        const fs_shader_module_create_info: vk.ShaderModuleCreateInfo = .{
            .code_size = desc.fs.len,
            .p_code = @ptrCast(@alignCast(desc.fs.ptr)),
        };
        const fs_shader_module: vk.ShaderModule = device.device.createShaderModule(
            &fs_shader_module_create_info,
            null,
        ) catch |err| {
            log.err("Failed to create fragment shader module for graphics pipeline ({s}): {s}", .{ name, @errorName(err) });
            return error.Gpu;
        };
        defer device.device.destroyShaderModule(fs_shader_module, null);

        const shader_stages: [2]vk.PipelineShaderStageCreateInfo = .{
            .{
                .stage = .{ .vertex_bit = true },
                .module = vs_shader_module,
                .p_name = "VSMain",
            },
            .{
                .stage = .{ .fragment_bit = true },
                .module = fs_shader_module,
                .p_name = "FSMain",
            },
        };

        const vertex_input: vk.PipelineVertexInputStateCreateInfo = .{};

        const input_assembly: vk.PipelineInputAssemblyStateCreateInfo = .{
            .topology = conv.primitiveTopology(desc.primitive_topology),
            .primitive_restart_enable = .false,
        };

        const multisample_state: vk.PipelineMultisampleStateCreateInfo = .{
            .rasterization_samples = switch (desc.multisample.sample_count) {
                .x1 => .{ .@"1_bit" = true },
                .x2 => .{ .@"2_bit" = true },
                .x4 => .{ .@"4_bit" = true },
                .x8 => .{ .@"8_bit" = true },
            },
            .min_sample_shading = 1.0,
            .p_sample_mask = if (desc.multisample.sample_mask) |mask| &.{mask} else null,
            .alpha_to_coverage_enable = if (desc.multisample.enable_alpha_to_coverage) .true else .false,
            .alpha_to_one_enable = .false,
            .sample_shading_enable = if (desc.multisample.sample_mask) |_| .true else .false,
        };

        const dynamic_states: [4]vk.DynamicState = .{
            .viewport,
            .scissor,
            .blend_constants,
            .stencil_reference,
        };

        const dynamic_state_info: vk.PipelineDynamicStateCreateInfo = .{
            .dynamic_state_count = @intCast(dynamic_states.len),
            .p_dynamic_states = &dynamic_states,
        };

        const viewport_info: vk.PipelineViewportStateCreateInfo = .{
            .viewport_count = 1,
            .scissor_count = 1,
        };

        const rasterization_info: vk.PipelineRasterizationStateCreateInfo = .{
            .depth_clamp_enable = if (desc.rasterization.enable_depth_clipping) .true else .false,
            .polygon_mode = if (desc.rasterization.fill_mode == .wireframe) .line else .fill,
            .cull_mode = .{
                .back_bit = desc.rasterization.cull_mode == .back,
                .front_bit = desc.rasterization.cull_mode == .front,
            },
            .front_face = if (desc.rasterization.front_face == .clockwise) .clockwise else .counter_clockwise,
            .depth_bias_enable = if (desc.rasterization.depth_bias) |_| .true else .false,
            .depth_bias_constant_factor = if (desc.rasterization.depth_bias) |bias| bias.constant_factor else 0.0,
            .depth_bias_clamp = if (desc.rasterization.depth_bias) |bias| bias.clamp else 0.0,
            .depth_bias_slope_factor = if (desc.rasterization.depth_bias) |bias| bias.slope_factor else 0.0,
            .line_width = 1.0,
            .rasterizer_discard_enable = .false,
        };

        const depth_stencil_info: vk.PipelineDepthStencilStateCreateInfo = .{
            .depth_test_enable = if (desc.depth_stencil.depth_test) |_| .true else .false,
            .depth_write_enable = if (desc.depth_stencil.depth_write) .true else .false,
            .depth_compare_op = if (desc.depth_stencil.depth_test) |t| conv.compareOp(t.op) else .never,
            .depth_bounds_test_enable = .false,
            .stencil_test_enable = if (desc.depth_stencil.stencil_test) |_| .true else .false,
            .front = if (desc.depth_stencil.stencil_test) |t|
                conv.stencilOpState(
                    &t.front,
                    t.compare_mask,
                    t.write_mask,
                )
            else
                undefined,
            .back = if (desc.depth_stencil.stencil_test) |t|
                conv.stencilOpState(
                    &t.back,
                    t.compare_mask,
                    t.write_mask,
                )
            else
                undefined,
            .min_depth_bounds = 0.0,
            .max_depth_bounds = 1.0,
        };

        var blend_states: [8]vk.PipelineColorBlendAttachmentState = undefined;
        for (desc.target_state.color_attachments[0..], blend_states[0..]) |attachment, *bs| {
            bs.* = if (attachment.blend) |blend| .{
                .blend_enable = .true,
                .src_color_blend_factor = conv.blendFactor(blend.color.src),
                .dst_color_blend_factor = conv.blendFactor(blend.color.dst),
                .color_blend_op = conv.blendOp(blend.color.op),
                .src_alpha_blend_factor = conv.blendFactor(blend.alpha.src),
                .dst_alpha_blend_factor = conv.blendFactor(blend.alpha.dst),
                .alpha_blend_op = conv.blendOp(blend.alpha.op),
                .color_write_mask = .{
                    .r_bit = blend.mask.r,
                    .g_bit = blend.mask.g,
                    .b_bit = blend.mask.b,
                    .a_bit = blend.mask.a,
                },
            } else .{
                .blend_enable = .false,
                .src_color_blend_factor = .one,
                .dst_color_blend_factor = .zero,
                .color_blend_op = .add,
                .src_alpha_blend_factor = .one,
                .dst_alpha_blend_factor = .zero,
                .alpha_blend_op = .add,
                .color_write_mask = .{},
            };
        }

        const blend_state_create_info: vk.PipelineColorBlendStateCreateInfo = .{
            .blend_constants = .{ 0.0, 0.0, 0.0, 0.0 },
            .logic_op = .copy,
            .logic_op_enable = .false,
            .attachment_count = @intCast(desc.target_state.color_attachment_count),
            .p_attachments = &blend_states,
        };

        var color_formats: [8]vk.Format = undefined;
        for (desc.target_state.color_attachments[0..], color_formats[0..]) |attachment, *fmt| {
            fmt.* = conv.vkFormat(attachment.format, true);
        }

        const depth_stencil_format: vk.Format = if (desc.target_state.depth_stencil_format) |fmt|
            conv.vkFormat(fmt, false)
        else
            .undefined;

        const rendering_create_info: vk.PipelineRenderingCreateInfo = .{
            .color_attachment_count = @intCast(desc.target_state.color_attachment_count),
            .p_color_attachment_formats = &color_formats,
            .depth_attachment_format = depth_stencil_format,
            .stencil_attachment_format = if (desc.target_state.depth_stencil_format) |fmt| if (fmt.isStencilFormat())
                depth_stencil_format
            else
                .undefined else .undefined,
            .view_mask = 0,
        };

        const pipeline_create_info: vk.GraphicsPipelineCreateInfo = .{
            .stage_count = @intCast(shader_stages.len),
            .base_pipeline_index = 0,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input,
            .p_input_assembly_state = &input_assembly,
            .p_viewport_state = &viewport_info,
            .p_rasterization_state = &rasterization_info,
            .p_multisample_state = &multisample_state,
            .p_depth_stencil_state = &depth_stencil_info,
            .p_color_blend_state = &blend_state_create_info,
            .p_dynamic_state = &dynamic_state_info,
            .layout = pipeline_layout,
            .render_pass = .null_handle,
            .subpass = 0,
            .p_next = &rendering_create_info,
            .flags = .{ .descriptor_buffer_bit_ext = true },
        };

        var result_pipeline: [1]vk.Pipeline = .{.null_handle};
        const pipeline_result = device.device.createGraphicsPipelines(
            .null_handle,
            1,
            &.{pipeline_create_info},
            null,
            &result_pipeline,
        ) catch |err| {
            log.err("Failed to create graphics pipeline ({s}): {s}", .{
                name,
                @errorName(err),
            });
            return error.Gpu;
        };
        if (pipeline_result != .success) {
            log.err("Failed to create graphics pipeline ({s}): {s}", .{
                name,
                @tagName(pipeline_result),
            });
            return error.Gpu;
        }
        self.pipeline = result_pipeline[0];

        setDebugName(&self.device.device, .pipeline, vk.Pipeline, self.pipeline, name);
    }

    fn initCompute(self: *Pipeline, device: *Device, desc: gpu.Pipeline.ComputeDesc, name: []const u8) Error!void {
        _ = self;
        _ = device;
        _ = desc;
        _ = name;
        @panic("TODO: Not implemented yet");
        // self.* = .{
        //     .device = device,
        //     .topology = null,
        //     .handle = undefined,
        //     .kind = .compute,
        // };

        // const root_signature = device.root_signature;

        // var cpdesc: d3d12.COMPUTE_PIPELINE_STATE_DESC = .initDefault();
        // cpdesc.pRootSignature = root_signature;
        // cpdesc.CS = conv.shaderBytecode(desc.cs);

        // var pipeline_state: ?*d3d12.IPipelineState = null;
        // const hr_create_pipeline = device.device.idevice.CreateComputePipelineState(
        //     &cpdesc,
        //     win32.riid(d3d12.IPipelineState),
        //     @ptrCast(&pipeline_state),
        // );
        // if (hr_create_pipeline != win32.S_OK) {
        //     log.err("Failed to create D3D12 compute pipeline state ({s}): {f}", .{
        //         name,
        //         win32.fmtHresult(hr_create_pipeline, .code_message),
        //     });
        //     return error.Gpu;
        // }
        // self.handle = pipeline_state.?;

        // const hr_set_name = try self.handle.iobject.setNameUtf8(name);
        // if (hr_set_name != win32.S_OK) {
        //     log.err("Failed to set pipeline name: {f}", .{win32.fmtHresult(hr_set_name, .code_message)});
        //     return error.Gpu;
        // }
    }

    fn deinit(self: *Pipeline) void {
        self.device.deleteObject(.pipeline, @intFromEnum(self.pipeline));
        // self.device.deleteIUnknown(&self.handle.iunknown);
    }

    fn fromGpuPipeline(pipeline: *gpu.Pipeline) *Pipeline {
        return @ptrCast(@alignCast(pipeline));
    }

    fn fromGpuPipelineConst(pipeline: *const gpu.Pipeline) *const Pipeline {
        return @ptrCast(@alignCast(pipeline));
    }

    fn toGpuPipeline(pipeline: *Pipeline) *gpu.Pipeline {
        return @ptrCast(@alignCast(pipeline));
    }
};

const Swapchain = struct {
    device: *Device = undefined,
    allocator: std.mem.Allocator = undefined,
    surface: vk.SurfaceKHR = .null_handle,
    swapchain: vk.SwapchainKHR = .null_handle,

    present_mode: gpu.Swapchain.PresentMode = .vsync,
    composition: gpu.Swapchain.Composition = .sdr,

    supports_mailbox: bool = false,

    width: u32 = 0,
    height: u32 = 0,

    backbuffer_index: u32 = 0,
    textures: [gpu.backbuffer_count]Texture = undefined,

    frame_semaphore_index: i32 = -1,
    acquire_semaphores: [gpu.backbuffer_count]vk.Semaphore = @splat(.null_handle),
    present_semaphores: [gpu.backbuffer_count]vk.Semaphore = @splat(.null_handle),

    name_buffer: [256]u8 = undefined,
    name: []const u8 = &.{},

    desc: gpu.Swapchain.Desc = undefined,

    fn init(
        self: *Swapchain,
        device: *Device,
        desc: gpu.Swapchain.Desc,
        name: []const u8,
    ) Error!void {
        self.* = .{};

        const name_len = @min(name.len, self.name_buffer.len);
        @memcpy(self.name_buffer[0..name_len], name[0..name_len]);
        self.name = self.name_buffer[0..name_len];
        self.desc = desc;
        self.device = device;
        self.present_mode = self.desc.present_mode;
        self.composition = self.desc.composition;

        const surface_result, const supports_mailbox = createSurface(
            &device.instance,
            &device.device,
            device.physical_device,
            desc.window_handle.window_handle,
            self.name,
        ) catch |err| {
            log.err("Failed to create surface: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        self.surface = surface_result;
        self.supports_mailbox = supports_mailbox;

        const caps = device.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(
            device.physical_device,
            self.surface,
        ) catch |err| {
            log.err("Failed to get surface capabilities: {s}", .{@errorName(err)});
            return error.Gpu;
        };

        self.width = @intCast(caps.current_extent.width);
        self.height = @intCast(caps.current_extent.height);

        const swapchain_result = createSwapchain(
            &device.device,
            self.surface,
            .null_handle,
            self.supports_mailbox,
            self.present_mode,
            self.composition,
            self.width,
            self.height,
            self.name,
        ) catch |err| {
            log.err("Failed to create swapchain: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        self.swapchain = swapchain_result;

        createTextures(
            device,
            self.swapchain,
            self.width,
            self.height,
            self.composition,
            &self.textures,
        ) catch |err| {
            log.err("Failed to create swapchain textures: {s}", .{@errorName(err)});
            return error.Gpu;
        };

        createSemaphores(
            &device.device,
            &self.acquire_semaphores,
            &self.present_semaphores,
        ) catch |err| {
            log.err("Failed to create swapchain semaphores: {s}", .{@errorName(err)});
            return error.Gpu;
        };
    }

    fn deinit(swapchain: *Swapchain) void {
        for (swapchain.textures[0..]) |*texture| {
            texture.deinit();
        }

        swapchain.device.deleteObject(.swapchain_khr, @intFromEnum(swapchain.swapchain));
        swapchain.device.deleteObject(.surface_khr, @intFromEnum(swapchain.surface));
        for (swapchain.acquire_semaphores[0..]) |semaphore| {
            swapchain.device.deleteObject(.semaphore, @intFromEnum(semaphore));
        }
        for (swapchain.present_semaphores[0..]) |semaphore| {
            swapchain.device.deleteObject(.semaphore, @intFromEnum(semaphore));
        }
    }

    fn fromGpuSwapchain(
        gpu_swapchain: *gpu.Swapchain,
    ) *Swapchain {
        return @ptrCast(@alignCast(gpu_swapchain));
    }

    fn toGpuSwapchain(
        swapchain: *Swapchain,
    ) *gpu.Swapchain {
        return @ptrCast(@alignCast(swapchain));
    }

    fn getPresentSemaphore(self: *Swapchain) vk.Semaphore {
        return self.present_semaphores[@intCast(self.frame_semaphore_index)];
    }

    fn getAcquireSemaphore(self: *Swapchain) vk.Semaphore {
        return self.acquire_semaphores[@intCast(self.frame_semaphore_index)];
    }

    fn createSurface(
        instance: *vk.InstanceProxy,
        device: *vk.DeviceProxy,
        physical_device: vk.PhysicalDevice,
        window_handle: ?*anyopaque,
        name: []const u8,
    ) !struct { vk.SurfaceKHR, bool } {
        const created_surface: vk.SurfaceKHR = surface: switch (builtin.os.tag) {
            .windows => {
                const windows = @import("../vendor/windows/root.zig");
                const create_info: vk.Win32SurfaceCreateInfoKHR = .{
                    .hinstance = @ptrCast(windows.win32.GetModuleHandleW(null).?),
                    .hwnd = @ptrCast(window_handle.?),
                };
                const surface = instance.createWin32SurfaceKHR(
                    &create_info,
                    null,
                ) catch |err| {
                    log.err("Failed to create Win32 surface: {s}", .{@errorName(err)});
                    return error.Gpu;
                };
                break :surface surface;
            },
            else => {
                @compileError("Unsupported platform");
            },
        };
        errdefer instance.destroySurfaceKHR(created_surface, null);

        setDebugName(
            device,
            .surface_khr,
            vk.SurfaceKHR,
            created_surface,
            name,
        );

        var present_mode_count: u32 = 0;
        const result_query_count = try instance.getPhysicalDeviceSurfacePresentModesKHR(
            physical_device,
            created_surface,
            &present_mode_count,
            null,
        );
        if (result_query_count != .success) {
            log.err("Failed to query surface present mode count: {}", .{result_query_count});
            return error.Gpu;
        }
        std.debug.print("Surface supports {} present modes\n", .{present_mode_count});

        var present_mode_buf: [8]vk.PresentModeKHR = undefined;
        const result = try instance.getPhysicalDeviceSurfacePresentModesKHR(
            physical_device,
            created_surface,
            &present_mode_count,
            &present_mode_buf,
        );

        if (result != .success) {
            log.err("Failed to get surface present modes: {}", .{result});
            return error.Gpu;
        }

        for (present_mode_buf[0..present_mode_count]) |mode| {
            log.info("Supported present mode: {}", .{mode});
        }

        const supports_mailbox = std.mem.indexOfScalar(
            vk.PresentModeKHR,
            present_mode_buf[0..present_mode_count],
            .mailbox_khr,
        ) != null;
        return .{ created_surface, supports_mailbox };
    }

    fn createSwapchain(
        device: *vk.DeviceProxy,
        surface: vk.SurfaceKHR,
        old_swapchain: vk.SwapchainKHR,
        supports_mailbox: bool,
        present_mode: gpu.Swapchain.PresentMode,
        format: gpu.Swapchain.Composition,
        width: u32,
        height: u32,
        name: []const u8,
    ) !vk.SwapchainKHR {
        // const format_up = conv.vkFormat(compositionToTextureFormat(format), true);
        const format_down = compositionToTextureFormat(format);
        // const view_formats: [2]vk.Format = .{
        //     format_up,
        //     format_down,
        // };

        // const format_info: vk.ImageFormatListCreateInfo = .{
        //     .view_format_count = @intCast(view_formats.len),
        //     .p_view_formats = &view_formats,
        // };

        var create_info: vk.SwapchainCreateInfoKHR = .{
            .surface = surface,
            .min_image_count = gpu.backbuffer_count,
            .image_format = format_down,
            .image_color_space = compositionToColorSpace(format),
            .image_extent = .{
                .width = width,
                .height = height,
            },
            .image_array_layers = 1,
            .image_usage = .{ .color_attachment_bit = true },
            .image_sharing_mode = .exclusive,
            .pre_transform = .{ .identity_bit_khr = true },
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = switch (present_mode) {
                .vsync => .fifo_khr,
                .immediate => if (supports_mailbox) .mailbox_khr else .immediate_khr,
            },
            .clipped = .true,
            .old_swapchain = old_swapchain,
        };
        create_info.present_mode = .immediate_khr;

        const result = try device.createSwapchainKHR(&create_info, null);

        setDebugName(
            device,
            .swapchain_khr,
            vk.SwapchainKHR,
            result,
            name,
        );

        if (old_swapchain != .null_handle) {
            device.destroySwapchainKHR(old_swapchain, null);
        }

        return result;
    }

    fn createTextures(
        device: *Device,
        swapchain: vk.SwapchainKHR,
        width: u32,
        height: u32,
        format: gpu.Swapchain.Composition,
        out_textures: *[gpu.backbuffer_count]Texture,
    ) !void {
        var image_count: u32 = 0;
        const result_query_count = try device.device.getSwapchainImagesKHR(
            swapchain,
            &image_count,
            null,
        );
        if (result_query_count != .success) {
            log.err("Failed to query swapchain image count: {}", .{result_query_count});
            return error.Gpu;
        }
        std.debug.print("Swapchain has {} images\n", .{image_count});

        var image_handles: [gpu.backbuffer_count]vk.Image = undefined;

        const result = try device.device.getSwapchainImagesKHR(
            swapchain,
            &image_count,
            &image_handles,
        );
        if (result != .success and result != .incomplete) {
            log.err("Failed to get swapchain images: {}", .{result});
            return error.Gpu;
        }
        std.debug.assert(image_count == gpu.backbuffer_count);

        const desc: gpu.Texture.Desc = .{
            .format = compositionToApiTextureFormat(format),
            .width = width,
            .height = height,
            .usage = .read_only_render_target,
        };

        var fmt_buf: [512]u8 = undefined;
        for (image_handles[0..image_count], out_textures.*[0..image_count], 0..) |image_handle, *texture, i| {
            const name = std.fmt.bufPrint(&fmt_buf, "swapchain texture {}", .{i}) catch unreachable;
            texture.* = undefined;
            try texture.initSwapchain(
                device,
                image_handle,
                desc,
                name,
            );
        }
    }

    fn createSemaphores(
        device: *vk.DeviceProxy,
        out_acquire_semaphores: *[gpu.backbuffer_count]vk.Semaphore,
        out_present_semaphores: *[gpu.backbuffer_count]vk.Semaphore,
    ) !void {
        const create_info: vk.SemaphoreCreateInfo = .{};

        var name_buf: [256]u8 = undefined;

        for (out_acquire_semaphores.*[0..], 0..) |*s, i| {
            s.* = try device.createSemaphore(&create_info, null);
            const name = std.fmt.bufPrint(&name_buf, "swapchain acquire semaphore {}", .{i}) catch unreachable;
            setDebugName(
                device,
                .semaphore,
                vk.Semaphore,
                s.*,
                name,
            );
        }

        for (out_present_semaphores.*[0..], 0..) |*s, i| {
            s.* = try device.createSemaphore(&create_info, null);
            const name = std.fmt.bufPrint(&name_buf, "swapchain present semaphore {}", .{i}) catch unreachable;
            setDebugName(
                device,
                .semaphore,
                vk.Semaphore,
                s.*,
                name,
            );
        }
    }

    fn recreateSwapchain(
        self: *Swapchain,
    ) !void {
        try self.device.device.deviceWaitIdle();

        // need to call this to update surface capabilities
        _ = self.device.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(
            self.device.physical_device,
            self.surface,
        ) catch |err| {
            log.err("Failed to get surface capabilities: {s}", .{@errorName(err)});
            return error.Gpu;
        };

        for (self.textures[0..]) |*tex| {
            tex.deinit();
        }

        for (self.acquire_semaphores) |s| {
            if (s != .null_handle) {
                // self.device.device.destroySemaphore(s, null);
                self.device.deleteObject(.semaphore, @intFromEnum(s));
            }
        }

        for (self.present_semaphores) |s| {
            if (s != .null_handle) {
                self.device.deleteObject(.semaphore, @intFromEnum(s));
            }
        }

        const swapchain = try createSwapchain(
            &self.device.device,
            self.surface,
            self.swapchain,
            self.supports_mailbox,
            self.present_mode,
            self.composition,
            self.width,
            self.height,
            self.name,
        );
        self.swapchain = swapchain;

        try createTextures(
            self.device,
            self.swapchain,
            self.width,
            self.height,
            self.composition,
            &self.textures,
        );

        try createSemaphores(
            &self.device.device,
            &self.acquire_semaphores,
            &self.present_semaphores,
        );
    }

    fn present(swapchain: *Swapchain) Error!void {
        const wait_semaphore = swapchain.getPresentSemaphore();
        var present_info: vk.PresentInfoKHR = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = &.{wait_semaphore},
            .swapchain_count = 1,
            .p_swapchains = &.{swapchain.swapchain},
            .p_image_indices = &.{swapchain.backbuffer_index},
        };

        const result = swapchain.device.device.queuePresentKHR(
            swapchain.device.graphics_queue,
            &present_info,
        ) catch |err| {
            log.err("Failed to present swapchain image: {s}", .{@errorName(err)});
            return error.Gpu;
        };

        if (result == .suboptimal_khr or result == .error_out_of_date_khr) {
            swapchain.recreateSwapchain() catch |err| {
                log.err("Failed to recreate swapchain after present: {s}", .{@errorName(err)});
                return error.Gpu;
            };
        }
    }

    fn acquireNext(
        swapchain: *Swapchain,
    ) Error!void {
        swapchain.frame_semaphore_index = @intCast(@mod((swapchain.frame_semaphore_index + 1), gpu.backbuffer_count));

        const signal_semaphore = swapchain.getAcquireSemaphore();
        var result = swapchain.device.device.acquireNextImageKHR(
            swapchain.swapchain,
            std.math.maxInt(u64),
            signal_semaphore,
            .null_handle,
        ) catch |err| {
            log.err("Failed to acquire next swapchain image: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        swapchain.backbuffer_index = result.image_index;

        if (result.result == .suboptimal_khr or result.result == .error_out_of_date_khr) {
            swapchain.recreateSwapchain() catch |err| {
                log.err("Failed to recreate swapchain after acquire next image: {s}", .{@errorName(err)});
                return error.Gpu;
            };

            result = swapchain.device.device.acquireNextImageKHR(
                swapchain.swapchain,
                std.math.maxInt(u64),
                signal_semaphore,
                .null_handle,
            ) catch |err| {
                log.err("Failed to acquire next swapchain image after recreation: {s}", .{@errorName(err)});
                return error.Gpu;
            };
            swapchain.backbuffer_index = result.image_index;
            std.debug.assert(result.result == .success);
        }
    }

    fn getBackbuffer(
        swapchain: *Swapchain,
    ) gpu.Swapchain.Backbuffer {
        return .{
            .texture = swapchain.textures[swapchain.backbuffer_index].toGpuTexture(),
            .width = swapchain.width,
            .height = swapchain.height,
        };
    }

    fn resize(
        swapchain: *Swapchain,
        width: u32,
        height: u32,
    ) Error!bool {
        if (swapchain.width == width and swapchain.height == height) {
            return false;
        }

        swapchain.width = width;
        swapchain.height = height;
        swapchain.backbuffer_index = 0;
        swapchain.recreateSwapchain() catch |err| {
            log.err("Failed to recreate swapchain after resize: {s}", .{@errorName(err)});
            return error.Gpu;
        };

        return true;
    }

    fn setPresentationMode(
        self: *Swapchain,
        mode: gpu.Swapchain.PresentMode,
    ) Error!void {
        if (self.present_mode == mode) {
            return;
        }
        self.present_mode = mode;
        self.recreateSwapchain() catch |err| {
            log.err("Failed to recreate swapchain after setting presentation mode: {s}", .{@errorName(err)});
            return error.Gpu;
        };
    }

    fn isCompositionModeSupported(
        self: *Swapchain,
        composition: gpu.Swapchain.Composition,
    ) Error!bool {
        // TODO: actually check support
        _ = self;
        _ = composition;
        return true;
    }

    fn setCompositionMode(
        self: *Swapchain,
        composition: gpu.Swapchain.Composition,
    ) Error!void {
        if (self.composition == composition) {
            return;
        }
        if (!try self.isCompositionModeSupported(composition)) {
            return error.InvalidOperation;
        }
        self.composition = composition;
        self.recreateSwapchain() catch |err| {
            log.err("Failed to recreate swapchain after setting composition mode: {s}", .{@errorName(err)});
            return error.Gpu;
        };
    }

    fn compositionToApiTextureFormat(composition: gpu.Swapchain.Composition) gpu.Format {
        return switch (composition) {
            .sdr => .rgba8unorm,
            .sdr_linear => .rgba8srgb,
            .hdr_extended_linear => .rgba16f,
            .hdr10_st2084 => .rgb10a2unorm,
        };
    }

    fn compositionToTextureFormat(composition: gpu.Swapchain.Composition) vk.Format {
        return switch (composition) {
            .sdr => .r8g8b8a8_unorm,
            .sdr_linear => .r8g8b8a8_unorm,
            .hdr_extended_linear => .r16g16b16a16_sfloat,
            .hdr10_st2084 => .a2b10g10r10_unorm_pack32,
        };
    }

    fn compositionToColorSpace(composition: gpu.Swapchain.Composition) vk.ColorSpaceKHR {
        return switch (composition) {
            .sdr => .srgb_nonlinear_khr,
            .sdr_linear => .extended_srgb_linear_ext,
            .hdr_extended_linear => .bt2020_linear_ext,
            .hdr10_st2084 => .hdr10_st2084_ext,
        };
    }
};

const Texture = struct {
    device: *Device,
    allocator: ?std.mem.Allocator = null,
    image: vk.Image = .null_handle,
    allocation: vk_mem_alloc.Allocation = .null_handle,
    image_views: InlineStorage(vk.ImageView, 1) = .empty,

    desc: gpu.Texture.Desc,

    fn init(self: *Texture, device: *Device, allocator: std.mem.Allocator, desc: gpu.Texture.Desc, name: []const u8) Error!void {
        self.* = .{
            .device = device,
            .allocator = allocator,
            .allocation = self.allocation,
            .desc = desc,
        };

        const image_desc = conv.imageCreateInfo(&desc);

        var allocation_create_info: vk_mem_alloc.AllocationCreateInfo = .{
            .usage = conv.locationToMemoryUsage(desc.location),
            .flags = .{
                .dedicated_memory_bit = true,
            },
        };

        var allocation_info: vk_mem_alloc.AllocationInfo = undefined;
        const result = device.vma.createImage(
            &image_desc,
            &allocation_create_info,
            &self.image,
            &self.allocation,
            &allocation_info,
        );

        if (result != .success) {
            log.err("Failed to create texture image: {}", .{result});
            return error.Gpu;
        }

        setDebugName(&device.device, .image, vk.Image, self.image, name);
        if (self.allocation != .null_handle) {
            setAllocationName(device.vma, self.allocation, name);
        }

        self.image_views = .initSlice(try allocator.alloc(vk.ImageView, desc.mip_levels * desc.depth_or_array_layers));
        @memset(self.image_views.slice(), .null_handle);

        // log.info("create texture: desc={}", .{desc});
        self.device.enqueueDefaultTransition(self);
    }

    fn initSwapchain(
        self: *Texture,
        device: *Device,
        image: vk.Image,
        desc: gpu.Texture.Desc,
        name: []const u8,
    ) Error!void {
        self.* = .{
            .device = device,
            .allocator = null,
            .image = image,
            .allocation = .null_handle,
            .desc = desc,
        };

        setDebugName(&device.device, .image, vk.Image, self.image, name);

        self.image_views = InlineStorage(vk.ImageView, 1).initFixed(&.{.null_handle}) catch unreachable;

        // log.info("swapchain texture: desc={}", .{self.desc});
        self.device.enqueueDefaultTransition(self);
    }

    fn deinit(self: *Texture) void {
        self.device.cancelDefaultTransition(self);
        if (self.allocation != .null_handle) {
            self.device.deleteAllocation(self.allocation);
            self.allocation = .null_handle;

            if (self.image != .null_handle) {
                self.device.deleteObject(.image, @intFromEnum(self.image));
                self.image = .null_handle;
            }
        }
        for (self.image_views.constSlice()) |image_view| {
            self.device.deleteObject(.image_view, @intFromEnum(image_view));
        }
        switch (self.image_views) {
            .buf => |b| self.allocator.?.free(b),
            else => {},
        }
    }

    fn fromGpuTexture(texture: *gpu.Texture) *Texture {
        return @ptrCast(@alignCast(texture));
    }

    fn fromGpuTextureConst(texture: *const gpu.Texture) *const Texture {
        return @ptrCast(@alignCast(texture));
    }

    fn toGpuTexture(texture: *Texture) *gpu.Texture {
        return @ptrCast(@alignCast(texture));
    }

    fn getImageView(self: *Texture, mip_slice: u32, array_slice: u32) vk.ImageView {
        const index = mip_slice * self.desc.depth_or_array_layers + array_slice;
        const image_view_slice = self.image_views.slice();
        const image_view = image_view_slice[index];
        if (image_view == .null_handle) {
            const create_info: vk.ImageViewCreateInfo = .{
                .image = self.image,
                .view_type = switch (self.desc.dimension) {
                    .cube => .cube,
                    else => .@"2d",
                },
                .format = conv.vkFormat(self.desc.format, true),
                .components = .{
                    .r = .identity,
                    .g = .identity,
                    .b = .identity,
                    .a = .identity,
                },
                .subresource_range = .{
                    .aspect_mask = conv.formatToAspectMask(self.desc.format),
                    .base_mip_level = mip_slice,
                    .level_count = 1,
                    .base_array_layer = array_slice,
                    .layer_count = 1,
                },
            };

            const result = self.device.device.createImageView(&create_info, null) catch {
                log.err("Failed to create image view for texture", .{});
                return .null_handle;
            };
            image_view_slice[index] = result;

            return result;
        }

        return image_view;
    }

    fn requiredStagingSize(self: *const Texture) usize {
        const requirements = self.device.device.getImageMemoryRequirements(self.image);
        return @intCast(requirements.size);
    }

    fn getRowPitch(self: *const Texture, mip_level: u32) u32 {
        const min_width = self.desc.format.getBlockWidth();
        const width: u32 = @max(self.desc.width >> @as(u5, @intCast(mip_level)), min_width);
        return self.desc.format.getRowPitch(width) * self.desc.format.getBlockHeight();
    }
};

const impl = struct {
    // device stuff
    fn deinit(data: *anyopaque) void {
        const device: *Device = .fromData(data);
        const allocator = device.allocator;
        device.deinit();
        allocator.destroy(device);
    }

    fn getInterfaceOptions(
        data: *anyopaque,
    ) *const gpu.Options {
        const device: *Device = .fromData(data);
        return &device.options;
    }

    fn beginFrame(
        data: *anyopaque,
    ) void {
        const device: *Device = .fromData(data);
        device.beginFrame();
    }

    fn endFrame(
        data: *anyopaque,
    ) void {
        const device: *Device = .fromData(data);
        device.endFrame();
    }

    fn getFrameIndex(
        data: *anyopaque,
    ) u64 {
        const device: *Device = .fromData(data);
        return device.frame_idx;
    }

    fn shutdown(
        data: *anyopaque,
    ) void {
        const device: *Device = .fromData(data);
        device.shutdown();
    }

    // buffer stuff
    fn createBuffer(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Buffer.Desc,
        name: []const u8,
    ) Error!*gpu.Buffer {
        const device: *Device = .fromData(data);
        var buffer = allocator.create(Buffer) catch {
            return error.OutOfMemory;
        };
        errdefer allocator.destroy(buffer);
        buffer.init(device, allocator, desc.*, name) catch |err| {
            log.err("Failed to create buffer: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        return buffer.toGpuBuffer();
    }

    fn destroyBuffer(
        data: *anyopaque,
        buffer: *gpu.Buffer,
    ) void {
        _ = data;
        const vk_buffer = Buffer.fromGpuBuffer(buffer);
        const allocator = vk_buffer.allocator;
        vk_buffer.deinit();
        allocator.destroy(vk_buffer);
    }

    fn getBufferDesc(
        data: *anyopaque,
        buffer: *const gpu.Buffer,
    ) *const gpu.Buffer.Desc {
        _ = data;
        const vk_buffer = Buffer.fromGpuBufferConst(buffer);
        return &vk_buffer.desc;
    }

    fn getBufferCpuAddress(
        data: *anyopaque,
        buffer: *const gpu.Buffer,
    ) ?[*]u8 {
        _ = data;
        const vk_buffer = Buffer.fromGpuBufferConst(buffer);
        return vk_buffer.cpuAddress();
    }

    fn getBufferGpuAddress(
        data: *anyopaque,
        buffer: *const gpu.Buffer,
    ) gpu.Buffer.GpuAddress {
        _ = data;
        const vk_buffer = Buffer.fromGpuBufferConst(buffer);
        return vk_buffer.gpuAddress();
    }

    fn getBufferRequiredStagingSize(
        data: *anyopaque,
        buffer: *const gpu.Buffer,
    ) usize {
        _ = data;
        const vk_buffer = Buffer.fromGpuBufferConst(buffer);
        return vk_buffer.requiredStagingSize();
    }

    // command list stuff
    fn createCommandList(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        queue: gpu.Queue,
        debug_name: []const u8,
    ) Error!*gpu.CommandList {
        const device: *Device = .fromData(data);
        var cmd_list = try allocator.create(CommandList);
        errdefer allocator.destroy(cmd_list);
        try cmd_list.init(device, allocator, queue, debug_name);
        return cmd_list.toGpuCommandList();
    }

    fn destroyCommandList(_: *anyopaque, cmd_list: *gpu.CommandList) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.deinit();
        cl.allocator.destroy(cl);
    }

    fn resetCommandAllocator(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.resetAllocator();
    }

    fn beginCommandList(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
    ) Error!void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        try cl.begin();
    }

    fn endCommandList(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
    ) Error!void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        try cl.end();
    }

    fn commandWaitOnFence(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        fence: *gpu.Fence,
        fence_value: u64,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        const f: *Fence = .fromGpuFence(fence);
        cl.wait(f, fence_value);
    }

    fn commandSignalFence(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        fence: *gpu.Fence,
        fence_value: u64,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        const f: *Fence = .fromGpuFence(fence);
        cl.signal(f, fence_value);
    }

    fn commandPresentSwapchain(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        swapchain: *gpu.Swapchain,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        const sc: *Swapchain = .fromGpuSwapchain(swapchain);
        cl.present(sc);
    }

    fn submitCommandList(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
    ) Error!void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        try cl.submit();
    }

    fn resetCommandList(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.resetState();
    }

    fn commandTextureBarrier(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        texture: *gpu.Texture,
        subresource: u32,
        old_access: gpu.Access,
        new_access: gpu.Access,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        const tex: *Texture = .fromGpuTexture(texture);
        cl.textureBarrier(tex, subresource, old_access, new_access);
    }

    fn commandBufferBarrier(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        buffer: *gpu.Buffer,
        old_access: gpu.Access,
        new_access: gpu.Access,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        const buf: *Buffer = .fromGpuBuffer(buffer);
        cl.bufferBarrier(buf, old_access, new_access);
    }

    fn commandGlobalBarrier(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        old_access: gpu.Access,
        new_access: gpu.Access,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.globalBarrier(old_access, new_access);
    }

    fn commandFlushBarriers(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.flushBarriers();
    }

    fn commandBindPipeline(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        pipeline: *gpu.Pipeline,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        const pl: *Pipeline = .fromGpuPipeline(pipeline);
        cl.bindPipeline(pl);
    }

    fn commandSetGraphicsConstants(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        slot: gpu.ConstantSlot,
        data: []const u8,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.setGraphicsConstants(slot, data);
    }

    fn commandSetComputeConstants(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        slot: gpu.ConstantSlot,
        data: []const u8,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.setComputeConstants(slot, data);
    }

    fn commandBeginRenderPass(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        desc: *const gpu.RenderPass.Desc,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.beginRenderPass(desc.*);
    }

    fn commandEndRenderPass(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.endRenderPass();
    }

    fn commandSetViewports(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        viewports: []const spatial.Viewport,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.setViewports(viewports);
    }

    fn commandSetScissors(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        scissors: []const spatial.Rect,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.setScissors(scissors);
    }

    fn commandSetBlendConstants(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        blend_constants: [4]f32,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.setBlendConstants(blend_constants);
    }

    fn commandSetStencilReference(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        reference: u32,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.setStencilReference(reference);
    }

    fn commandBindIndexBuffer(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        buffer: gpu.Buffer.Slice,
        format: gpu.IndexFormat,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.bindIndexBuffer(buffer, format);
    }

    fn commandDraw(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        vertex_count: u32,
        instance_count: u32,
        start_vertex: u32,
        start_instance: u32,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.draw(
            vertex_count,
            instance_count,
            start_vertex,
            start_instance,
        );
    }

    fn commandDrawIndexed(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        index_count: u32,
        instance_count: u32,
        start_index: u32,
        base_vertex: i32,
        start_instance: u32,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.drawIndexed(
            index_count,
            instance_count,
            start_index,
            base_vertex,
            start_instance,
        );
    }

    fn commandDrawIndirect(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        slice: gpu.Buffer.Slice,
        max_draw_count: u32,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.drawIndirect(slice, max_draw_count);
    }

    fn commandDrawIndexedIndirect(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        slice: gpu.Buffer.Slice,
        max_draw_count: u32,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.drawIndexedIndirect(slice, max_draw_count);
    }

    fn commandMultiDrawIndirect(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        slice: gpu.Buffer.Slice,
        count: gpu.Buffer.Location,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.multiDrawIndirect(slice, count);
    }

    fn commandMultiDrawIndexedIndirect(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        slice: gpu.Buffer.Slice,
        count: gpu.Buffer.Location,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.multiDrawIndexedIndirect(slice, count);
    }

    fn commandDispatch(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        group_count_x: u32,
        group_count_y: u32,
        group_count_z: u32,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.dispatch(group_count_x, group_count_y, group_count_z);
    }

    fn commandDispatchIndirect(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        slice: gpu.Buffer.Slice,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.dispatchIndirect(slice);
    }

    fn commandWriteIntBuffer(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        location: gpu.Buffer.Location,
        value: u32,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        const buf: *Buffer = .fromGpuBuffer(location.buffer);
        cl.writeBuffer(buf, @intCast(location.offset), value);
    }

    fn commandCopyBufferToTexture(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        src: gpu.Buffer.Location,
        dst: gpu.Texture.Slice,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.copyBufferToTexture(src, dst);
    }

    fn commandCopyTextureToBuffer(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        src: gpu.Texture.Slice,
        dst: gpu.Buffer.Location,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.copyTextureToBuffer(src, dst);
    }

    fn commandCopyTextureToTexture(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        src: gpu.Texture.Slice,
        dst: gpu.Texture.Slice,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.copyTextureToTexture(src, dst);
    }

    fn commandCopyBufferToBuffer(
        _: *anyopaque,
        cmd_list: *gpu.CommandList,
        src: gpu.Buffer.Location,
        dst: gpu.Buffer.Location,
        size: gpu.Size,
    ) void {
        const cl: *CommandList = .fromGpuCommandList(cmd_list);
        cl.copyBufferToBuffer(src, dst, size);
    }

    // fence stuff
    fn createFence(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) Error!*gpu.Fence {
        const device: *Device = .fromData(data);
        var fence = allocator.create(Fence) catch {
            return error.OutOfMemory;
        };
        errdefer allocator.destroy(fence);
        fence.init(device, name) catch |err| {
            log.err("Failed to create fence: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        return fence.toGpuFence();
    }

    fn destroyFence(
        data: *anyopaque,
        fence: *gpu.Fence,
    ) void {
        const device: *Device = .fromData(data);
        const vk_fence = Fence.fromGpuFence(fence);
        vk_fence.deinit();
        device.allocator.destroy(vk_fence);
    }

    fn signalFence(
        data: *anyopaque,
        fence: *gpu.Fence,
        value: u64,
    ) Error!void {
        _ = data;
        const vk_fence = Fence.fromGpuFence(fence);
        return vk_fence.signal(value);
    }

    fn waitFence(
        data: *anyopaque,
        fence: *gpu.Fence,
        value: u64,
    ) Error!void {
        _ = data;
        const vk_fence = Fence.fromGpuFence(fence);
        return vk_fence.wait(value);
    }

    // descriptor stuff here
    fn createDescriptor(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Descriptor.Desc,
        debug_name: []const u8,
    ) Error!*gpu.Descriptor {
        const device: *Device = .fromData(data);
        var descriptor = try allocator.create(Descriptor);
        errdefer allocator.destroy(descriptor);
        descriptor.init(device, desc.*, debug_name) catch |err| {
            log.err("Failed to create descriptor: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        descriptor.allocator = allocator;
        return descriptor.toGpuDescriptor();
    }

    fn destroyDescriptor(
        _: *anyopaque,
        descriptor: *gpu.Descriptor,
    ) void {
        const d: *Descriptor = .fromGpuDescriptor(descriptor);
        d.deinit();
        d.allocator.destroy(d);
    }

    fn getDescriptorIndex(
        _: *anyopaque,
        descriptor: *const gpu.Descriptor,
    ) gpu.Descriptor.Index {
        const d: *const Descriptor = .fromGpuDescriptorConst(descriptor);
        return @enumFromInt(d.descriptorIndex());
    }

    // pipeline stuff
    fn createGraphicsPipeline(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Pipeline.GraphicsDesc,
        name: []const u8,
    ) Error!*gpu.Pipeline {
        const device: *Device = .fromData(data);
        var pipeline = allocator.create(Pipeline) catch {
            return error.OutOfMemory;
        };
        errdefer allocator.destroy(pipeline);
        pipeline.initGraphics(device, desc.*, name) catch |err| {
            log.err("Failed to create graphics pipeline: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        pipeline.allocator = allocator;
        return pipeline.toGpuPipeline();
    }

    fn createComputePipeline(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Pipeline.ComputeDesc,
        name: []const u8,
    ) Error!*gpu.Pipeline {
        const device: *Device = .fromData(data);
        var pipeline = allocator.create(Pipeline) catch {
            return error.OutOfMemory;
        };
        errdefer allocator.destroy(pipeline);
        pipeline.initCompute(device, desc.*, name) catch |err| {
            log.err("Failed to create compute pipeline: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        pipeline.allocator = allocator;
        return pipeline.toGpuPipeline();
    }

    fn destroyPipeline(
        data: *anyopaque,
        pipeline: *gpu.Pipeline,
    ) void {
        _ = data;
        const vk_pipeline = Pipeline.fromGpuPipeline(pipeline);
        const allocator = vk_pipeline.allocator;
        vk_pipeline.deinit();
        allocator.destroy(vk_pipeline);
    }

    fn getPipelineDesc(
        data: *anyopaque,
        pipeline: *const gpu.Pipeline,
    ) *const gpu.Pipeline.Desc {
        _ = data;
        const vk_pipeline = Pipeline.fromGpuPipelineConst(pipeline);
        return &vk_pipeline.desc;
    }

    fn getPipelineKind(
        data: *anyopaque,
        pipeline: *const gpu.Pipeline,
    ) gpu.Pipeline.Kind {
        _ = data;
        const vk_pipeline = Pipeline.fromGpuPipelineConst(pipeline);
        return vk_pipeline.kind;
    }

    // swapchain stuff
    fn createSwapchain(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Swapchain.Desc,
        name: []const u8,
    ) Error!*gpu.Swapchain {
        const device: *Device = .fromData(data);
        var swapchain = allocator.create(Swapchain) catch {
            return error.OutOfMemory;
        };
        errdefer allocator.destroy(swapchain);
        swapchain.init(device, desc.*, name) catch |err| {
            log.err("Failed to create swapchain: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        return swapchain.toGpuSwapchain();
    }

    fn destroySwapchain(
        data: *anyopaque,
        swapchain: *gpu.Swapchain,
    ) void {
        _ = data;
        const vk_swapchain = Swapchain.fromGpuSwapchain(swapchain);
        const allocator = vk_swapchain.device.allocator;
        vk_swapchain.deinit();
        allocator.destroy(vk_swapchain);
    }

    fn getSwapchainDesc(
        data: *anyopaque,
        swapchain: *gpu.Swapchain,
    ) *const gpu.Swapchain.Desc {
        _ = data;
        const vk_swapchain = Swapchain.fromGpuSwapchain(swapchain);
        return &vk_swapchain.desc;
    }

    fn acquireNextSwapchainImage(
        data: *anyopaque,
        swapchain: *gpu.Swapchain,
    ) Error!void {
        _ = data;
        const vk_swapchain = Swapchain.fromGpuSwapchain(swapchain);
        return vk_swapchain.acquireNext();
    }

    fn getSwapchainBackbuffer(
        data: *anyopaque,
        swapchain: *gpu.Swapchain,
    ) gpu.Swapchain.Backbuffer {
        _ = data;
        const vk_swapchain = Swapchain.fromGpuSwapchain(swapchain);
        return vk_swapchain.getBackbuffer();
    }

    fn resizeSwapchain(
        data: *anyopaque,
        swapchain: *gpu.Swapchain,
        width: u32,
        height: u32,
    ) Error!bool {
        _ = data;
        const vk_swapchain = Swapchain.fromGpuSwapchain(swapchain);
        return vk_swapchain.resize(width, height);
    }

    // texture stuff
    fn createTexture(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Texture.Desc,
        name: []const u8,
    ) Error!*gpu.Texture {
        const device: *Device = .fromData(data);
        var texture = allocator.create(Texture) catch {
            return error.OutOfMemory;
        };
        errdefer allocator.destroy(texture);
        texture.init(device, allocator, desc.*, name) catch |err| {
            log.err("Failed to create texture: {s}", .{@errorName(err)});
            return error.Gpu;
        };
        return texture.toGpuTexture();
    }

    fn destroyTexture(
        data: *anyopaque,
        texture: *gpu.Texture,
    ) void {
        _ = data;
        const vk_texture = Texture.fromGpuTexture(texture);
        const allocator = vk_texture.allocator;
        vk_texture.deinit();
        if (allocator) |alloc| {
            alloc.destroy(vk_texture);
        }
    }

    fn getTextureDesc(
        data: *anyopaque,
        texture: *const gpu.Texture,
    ) *const gpu.Texture.Desc {
        _ = data;
        const vk_texture = Texture.fromGpuTextureConst(texture);
        return &vk_texture.desc;
    }

    fn getTextureRequiredStagingSize(
        data: *anyopaque,
        texture: *const gpu.Texture,
    ) usize {
        _ = data;
        const vk_texture = Texture.fromGpuTextureConst(texture);
        return vk_texture.requiredStagingSize();
    }

    fn getTextureRowPitch(
        data: *anyopaque,
        texture: *const gpu.Texture,
        mip_level: u32,
    ) u32 {
        _ = data;
        const vk_texture = Texture.fromGpuTextureConst(texture);
        return vk_texture.getRowPitch(mip_level);
    }
};

const vtable: gpu.Interface.VTable = .{
    .deinit = impl.deinit, // impl.deinit,
    .get_interface_options = impl.getInterfaceOptions, // impl.getInterfaceOptions,
    .begin_frame = impl.beginFrame,
    .end_frame = impl.endFrame,
    .get_frame_index = impl.getFrameIndex,
    .shutdown = impl.shutdown,

    // buffer
    .create_buffer = impl.createBuffer,
    .destroy_buffer = impl.destroyBuffer,
    .get_buffer_desc = impl.getBufferDesc,
    .get_buffer_cpu_address = impl.getBufferCpuAddress,
    .get_buffer_gpu_address = impl.getBufferGpuAddress,
    .get_buffer_required_staging_size = impl.getBufferRequiredStagingSize,

    // command list
    .create_command_list = impl.createCommandList,
    .destroy_command_list = impl.destroyCommandList,
    .reset_command_allocator = impl.resetCommandAllocator,
    .begin_command_list = impl.beginCommandList,
    .end_command_list = impl.endCommandList,
    .command_wait_on_fence = impl.commandWaitOnFence,
    .command_signal_fence = impl.commandSignalFence,
    .command_present_swapchain = impl.commandPresentSwapchain,
    .submit_command_list = impl.submitCommandList,
    .reset_command_list = impl.resetCommandList,
    .command_texture_barrier = impl.commandTextureBarrier,
    .command_buffer_barrier = impl.commandBufferBarrier,
    .command_global_barrier = impl.commandGlobalBarrier,
    .command_flush_barriers = impl.commandFlushBarriers,
    .command_bind_pipeline = impl.commandBindPipeline,
    .command_set_graphics_constants = impl.commandSetGraphicsConstants,
    .command_set_compute_constants = impl.commandSetComputeConstants,
    .command_begin_render_pass = impl.commandBeginRenderPass,
    .command_end_render_pass = impl.commandEndRenderPass,
    .command_set_viewports = impl.commandSetViewports,
    .command_set_scissors = impl.commandSetScissors,
    .command_set_blend_constants = impl.commandSetBlendConstants,
    .command_set_stencil_reference = impl.commandSetStencilReference,
    .command_bind_index_buffer = impl.commandBindIndexBuffer,
    .command_draw = impl.commandDraw,
    .command_draw_indexed = impl.commandDrawIndexed,
    .command_draw_indirect = impl.commandDrawIndirect,
    .command_draw_indexed_indirect = impl.commandDrawIndexedIndirect,
    .command_multi_draw_indirect = impl.commandMultiDrawIndirect,
    .command_multi_draw_indexed_indirect = impl.commandMultiDrawIndexedIndirect,
    .command_dispatch = impl.commandDispatch,
    .command_dispatch_indirect = impl.commandDispatchIndirect,
    .command_write_int_buffer = impl.commandWriteIntBuffer,
    .command_copy_buffer_to_texture = impl.commandCopyBufferToTexture,
    .command_copy_texture_to_buffer = impl.commandCopyTextureToBuffer,
    .command_copy_texture_to_texture = impl.commandCopyTextureToTexture,
    .command_copy_buffer_to_buffer = impl.commandCopyBufferToBuffer,

    // fence
    .create_fence = impl.createFence,
    .destroy_fence = impl.destroyFence,
    .signal_fence = impl.signalFence,
    .wait_fence = impl.waitFence,

    // descriptor
    .create_descriptor = impl.createDescriptor,
    .destroy_descriptor = impl.destroyDescriptor,
    .get_descriptor_index = impl.getDescriptorIndex,

    // pipeline
    .create_graphics_pipeline = impl.createGraphicsPipeline,
    .create_compute_pipeline = undefined, // impl.createComputePipeline,
    .destroy_pipeline = impl.destroyPipeline,
    .get_pipeline_kind = impl.getPipelineKind,

    // swapchain
    .create_swapchain = impl.createSwapchain,
    .destroy_swapchain = impl.destroySwapchain,
    .acquire_next_swapchain_image = impl.acquireNextSwapchainImage,
    .get_swapchain_backbuffer = impl.getSwapchainBackbuffer,
    .resize_swapchain = impl.resizeSwapchain,

    // texture
    .create_texture = impl.createTexture,
    .destroy_texture = impl.destroyTexture,
    .get_texture_desc = impl.getTextureDesc,
    .get_texture_required_staging_size = impl.getTextureRequiredStagingSize,
    .get_texture_row_pitch = impl.getTextureRowPitch,
};

const loader = struct {
    var lib: ?std.DynLib = null;
    var vkGetInstanceProcAddr: ?vk.PfnGetInstanceProcAddr = null;

    pub fn get() !vk.PfnGetInstanceProcAddr {
        if (vkGetInstanceProcAddr) |func| {
            return func;
        }

        var local_lib = blk: {
            const load_names: []const []const u8 = switch (builtin.os.tag) {
                .windows => &.{"vulkan-1.dll"},
                .macos => &.{ "libvulkan.dylib", "libvulkan.1.dylib", "libMoltenVK.dylib", "vulkan.framework/vulkan", "MoltenVK.framework/MoltenVK" },
                else => &.{ "libvulkan.so.1", "libvulkan.so" },
            };
            var loaded_lib: ?std.DynLib = null;
            for (load_names) |name| {
                loaded_lib = std.DynLib.open(name) catch continue;
                break :blk loaded_lib.?;
            }
            @panic("Failed to load Vulkan library");
        };
        lib = local_lib;

        const func = local_lib.lookup(
            vk.PfnGetInstanceProcAddr,
            "vkGetInstanceProcAddr",
        ) orelse {
            @panic("Failed to load vkGetInstanceProcAddr");
        };
        vkGetInstanceProcAddr = func;
        return func;
    }
};

const conv = struct {
    // default false
    fn vkFormat(format: gpu.Format, srv_or_rtv: bool) vk.Format {
        return switch (format) {
            .unknown => .undefined,
            .rgba32f => .r32g32b32a32_sfloat,
            .rgba32ui => .r32g32b32a32_uint,
            .rgba32si => .r32g32b32a32_sint,
            .rgba16f => .r16g16b16a16_sfloat,
            .rgba16ui => .r16g16b16a16_uint,
            .rgba16si => .r16g16b16a16_sint,
            .rgba16unorm => .r16g16b16a16_unorm,
            .rgba16snorm => .r16g16b16a16_snorm,
            .rgba8ui => .r8g8b8a8_uint,
            .rgba8si => .r8g8b8a8_sint,
            .rgba8unorm => .r8g8b8a8_unorm,
            .rgba8snorm => .r8g8b8a8_snorm,
            .rgba8srgb => if (srv_or_rtv) .r8g8b8a8_srgb else .r8g8b8a8_unorm,
            .bgra8unorm => .b8g8r8a8_unorm,
            .bgra8srgb => if (srv_or_rtv) .b8g8r8a8_srgb else .b8g8r8a8_unorm,
            .rgb10a2ui => .a2r10g10b10_uint_pack32,
            .rgb10a2unorm => .a2r10g10b10_unorm_pack32,
            .rgb32f => .r32g32b32_sfloat,
            .rgb32ui => .r32g32b32_uint,
            .rgb32si => .r32g32b32_sint,
            .r11g11b10f => .b10g11r11_ufloat_pack32,
            .rgb9e5 => .e5b9g9r9_ufloat_pack32,
            .rg32f => .r32g32_sfloat,
            .rg32ui => .r32g32_uint,
            .rg32si => .r32g32_sint,
            .rg16f => .r16g16_sfloat,
            .rg16ui => .r16g16_uint,
            .rg16si => .r16g16_sint,
            .rg16unorm => .r16g16_unorm,
            .rg16snorm => .r16g16_snorm,
            .rg8ui => .r8g8_uint,
            .rg8si => .r8g8_sint,
            .rg8unorm => .r8g8_unorm,
            .rg8snorm => .r8g8_snorm,
            .r32f => .r32_sfloat,
            .r32ui => .r32_uint,
            .r32si => .r32_sint,
            .r16f => .r16_sfloat,
            .r16ui => .r16_uint,
            .r16si => .r16_sint,
            .r16unorm => .r16_unorm,
            .r16snorm => .r16_snorm,
            .r8ui => .r8_uint,
            .r8si => .r8_sint,
            .r8unorm => .r8_unorm,
            .r8snorm => .r8_snorm,
            .d32f => .d32_sfloat,
            .d32fs8 => .d32_sfloat_s8_uint,
            .d16 => .d16_unorm,
            .bc1unorm => .bc1_rgb_unorm_block,
            .bc1srgb => .bc1_rgb_srgb_block,
            .bc2unorm => .bc2_unorm_block,
            .bc2srgb => .bc2_srgb_block,
            .bc3unorm => .bc3_unorm_block,
            .bc3srgb => .bc3_srgb_block,
            .bc4unorm => .bc4_unorm_block,
            .bc4snorm => .bc4_snorm_block,
            .bc5unorm => .bc5_unorm_block,
            .bc5snorm => .bc5_snorm_block,
            .bc6u16f => .bc6h_ufloat_block,
            .bc6s16f => .bc6h_sfloat_block,
            .bc7unorm => .bc7_unorm_block,
            .bc7srgb => .bc7_srgb_block,
            // else => .undefined,
        };
    }

    fn formatToAspectMask(format: gpu.Format) vk.ImageAspectFlags {
        return switch (format) {
            .d32fs8 => .{
                .depth_bit = true,
                .stencil_bit = true,
            },
            .d32f, .d16 => .{
                .depth_bit = true,
            },
            else => .{
                .color_bit = true,
            },
        };
    }

    fn locationToMemoryUsage(location: gpu.MemoryLocation) vk_mem_alloc.MemoryUsage {
        return switch (location) {
            .gpu_only => .gpu_only,
            .cpu_only => .cpu_only,
            .cpu_to_gpu => .cpu_to_gpu,
            .gpu_to_cpu => .gpu_to_cpu,
        };
    }

    fn imageCreateInfo(desc: *const gpu.Texture.Desc) vk.ImageCreateInfo {
        const usage: vk.ImageUsageFlags = .{
            .transfer_src_bit = true,
            .transfer_dst_bit = true,
            .sampled_bit = true,
            .storage_bit = desc.usage.shader_write,
            .color_attachment_bit = desc.usage.render_target,
            .depth_stencil_attachment_bit = desc.usage.depth_stencil,
        };
        const flags: vk.ImageCreateFlags = .{
            .cube_compatible_bit = desc.dimension == .cube,
            .mutable_format_bit = true,
        };

        return .{
            .image_type = switch (desc.dimension) {
                .@"2d" => .@"2d",
                .@"3d" => .@"3d",
                .cube => .@"2d",
            },
            .format = vkFormat(desc.format, false),
            .extent = .{
                .width = desc.width,
                .height = desc.height,
                .depth = if (desc.dimension == .@"3d") desc.depth_or_array_layers else 1,
            },
            .mip_levels = desc.mip_levels,
            .array_layers = switch (desc.dimension) {
                .@"2d" => desc.depth_or_array_layers,
                .@"3d" => 1,
                .cube => desc.depth_or_array_layers * 6,
            },
            .samples = .{
                .@"1_bit" = desc.sample_count == .x1,
                .@"2_bit" = desc.sample_count == .x2,
                .@"4_bit" = desc.sample_count == .x4,
                .@"8_bit" = desc.sample_count == .x8,
            },
            .tiling = .optimal,
            .usage = usage,
            .sharing_mode = .exclusive,
            .initial_layout = .undefined,
            .flags = flags,
        };
    }

    fn stageMask(access: gpu.Access) vk.PipelineStageFlags2 {
        // VkPipelineStageFlags2 stage = VK_PIPELINE_STAGE_2_NONE;
        var stage: vk.PipelineStageFlags2 = .{};

        if (access.present) stage.bottom_of_pipe_bit = true;
        if (access.render_target) stage.color_attachment_output_bit = true;
        if (access.isDSV()) {
            stage.early_fragment_tests_bit = true;
            stage.late_fragment_tests_bit = true;
        }
        if (access.isVertex()) {
            // stage.task_shader_bit_ext = true;
            // stage.mesh_shader_bit_ext = true;
            stage.vertex_shader_bit = true;
        }
        if (access.isFragment()) stage.fragment_shader_bit = true;
        if (access.isCompute()) stage.compute_shader_bit = true;
        if (access.isCopy()) stage.copy_bit = true;
        if (access.isWrite()) stage.compute_shader_bit = true;
        if (access.index_buffer) stage.index_input_bit = true;
        if (access.indirect_argument) stage.draw_indirect_bit = true;
        // TODO: acceleration structure support

        return stage;
    }

    fn accessMask(access: gpu.Access) vk.AccessFlags2 {
        var access_mask: vk.AccessFlags2 = .{};

        if (access.discard) return access_mask;

        if (access.render_target) {
            access_mask.color_attachment_read_bit = true;
            access_mask.color_attachment_write_bit = true;
        }
        if (access.depth_stencil) {
            access_mask.depth_stencil_attachment_write_bit = true;
        }
        if (access.depth_stencil_read_only) {
            access_mask.depth_stencil_attachment_read_bit = true;
        }
        if (access.isRead()) {
            access_mask.shader_sampled_read_bit = true;
            access_mask.shader_storage_read_bit = true;
        }
        if (access.isWrite()) {
            access_mask.shader_storage_write_bit = true;
        }
        if (access.copy_dst) {
            access_mask.transfer_write_bit = true;
        }
        if (access.copy_src) {
            access_mask.transfer_read_bit = true;
        }
        if (access.index_buffer) {
            access_mask.index_read_bit = true;
        }
        if (access.indirect_argument) {
            access_mask.indirect_command_read_bit = true;
        }
        // TODO: shading rate and acceleration structure support

        return access_mask;
    }

    fn imageLayoutFromAccess(access: gpu.Access) vk.ImageLayout {
        if (access.discard) return .undefined;
        if (access.present) return .present_src_khr;
        if (access.render_target) return .color_attachment_optimal;
        if (access.depth_stencil) return .depth_stencil_attachment_optimal;
        if (access.depth_stencil_read_only) return .depth_stencil_read_only_optimal;
        if (access.isRead()) return .shader_read_only_optimal;
        if (access.isWrite()) return .general;
        if (access.copy_dst) return .transfer_dst_optimal;
        if (access.copy_src) return .transfer_src_optimal;

        @panic("Unsupported access flags for image layout");
    }

    fn renderPassLoadColorOp(load_op: gpu.RenderPass.LoadColor) vk.AttachmentLoadOp {
        return switch (load_op) {
            .load => .load,
            .clear => .clear,
            .discard => .dont_care,
        };
    }

    fn renderPassLoadDepthOp(load_op: gpu.RenderPass.LoadDepth) vk.AttachmentLoadOp {
        return switch (load_op) {
            .load => .load,
            .clear => .clear,
            .discard => .dont_care,
        };
    }

    fn renderPassLoadStencilOp(load_op: gpu.RenderPass.LoadStencil) vk.AttachmentLoadOp {
        return switch (load_op) {
            .load => .load,
            .clear => .clear,
            .discard => .dont_care,
        };
    }

    fn renderPassStoreOp(store_op: gpu.RenderPass.Store) vk.AttachmentStoreOp {
        return switch (store_op) {
            .store => .store,
            .discard => .dont_care,
        };
    }

    fn primitiveTopology(topology: gpu.Pipeline.Primitive) vk.PrimitiveTopology {
        return switch (topology) {
            .point_list => .point_list,
            .line_list => .line_list,
            .line_strip => .line_strip,
            .triangle_list => .triangle_list,
            .triangle_strip => .triangle_strip,
        };
    }

    fn compareOp(compare: gpu.Pipeline.CompareOp) vk.CompareOp {
        return switch (compare) {
            .never => .never,
            .less => .less,
            .equal => .equal,
            .less_or_equal => .less_or_equal,
            .greater => .greater,
            .not_equal => .not_equal,
            .greater_or_equal => .greater_or_equal,
            .always => .always,
        };
    }

    fn stencilOp(op: gpu.Pipeline.StencilOp) vk.StencilOp {
        return switch (op) {
            .keep => .keep,
            .zero => .zero,
            .replace => .replace,
            .increment_and_clamp => .increment_and_clamp,
            .decrement_and_clamp => .decrement_and_clamp,
            .invert => .invert,
            .increment_and_wrap => .increment_and_wrap,
            .decrement_and_wrap => .decrement_and_wrap,
        };
    }

    fn stencilOpState(state: *const gpu.Pipeline.StencilState, compare_mask: u8, write_mask: u8) vk.StencilOpState {
        return .{
            .fail_op = stencilOp(state.fail),
            .pass_op = stencilOp(state.pass),
            .depth_fail_op = stencilOp(state.depth_fail),
            .compare_op = compareOp(state.compare),
            .compare_mask = compare_mask,
            .write_mask = write_mask,
            .reference = 0,
        };
    }

    fn blendFactor(factor: gpu.Pipeline.BlendFactor) vk.BlendFactor {
        return switch (factor) {
            .zero => .zero,
            .one => .one,
            .src_color => .src_color,
            .inv_src_color => .one_minus_src_color,
            .dst_color => .dst_color,
            .inv_dst_color => .one_minus_dst_color,
            .src_alpha => .src_alpha,
            .inv_src_alpha => .one_minus_src_alpha,
            .dst_alpha => .dst_alpha,
            .inv_dst_alpha => .one_minus_dst_alpha,
            .constant_color => .constant_color,
            .inv_constant_color => .one_minus_constant_color,
            .src_alpha_saturated => .src_alpha_saturate,
        };
    }

    fn blendOp(op: gpu.Pipeline.BlendOp) vk.BlendOp {
        return switch (op) {
            .add => .add,
            .subtract => .subtract,
            .reverse_subtract => .reverse_subtract,
            .min => .min,
            .max => .max,
        };
    }

    fn filter(mode: gpu.Descriptor.Filter) vk.Filter {
        return switch (mode) {
            .nearest => .nearest,
            .linear => .linear,
        };
    }

    fn mipmapMode(mode: gpu.Descriptor.Filter) vk.SamplerMipmapMode {
        return switch (mode) {
            .nearest => .nearest,
            .linear => .linear,
        };
    }

    fn addressMode(mode: gpu.Descriptor.AddressMode) vk.SamplerAddressMode {
        return switch (mode) {
            .repeat => .repeat,
            .mirror_repeat => .mirrored_repeat,
            .clamp_to_edge => .clamp_to_edge,
        };
    }
};

const vk_mem_alloc = struct {
    const FlagsMixin = vk.FlagsMixin;
    const FlagFormatMixin = vk.FlagFormatMixin;

    pub const AllocatorCreateFlags = packed struct(vk.Flags) {
        externally_synchronized_bit: bool = false,
        khr_dedicated_allocation_bit: bool = false,
        khr_bind_memory_2_bit: bool = false,
        ext_memory_budget_bit: bool = false,
        amd_device_coherent_memory_bit: bool = false,
        buffer_device_address_bit: bool = false,
        ext_memory_priority_bit: bool = false,
        khr_maintenance4_bit: bool = false,
        khr_maintenance5_bit: bool = false,
        khr_external_memory_win32_bit: bool = false,

        _unused_bits: u22 = 0,
        pub const toInt = FlagsMixin(AllocatorCreateFlags).toInt;
        pub const fromInt = FlagsMixin(AllocatorCreateFlags).fromInt;
        pub const merge = FlagsMixin(AllocatorCreateFlags).merge;
        pub const intersect = FlagsMixin(AllocatorCreateFlags).intersect;
        pub const complement = FlagsMixin(AllocatorCreateFlags).complement;
        pub const subtract = FlagsMixin(AllocatorCreateFlags).subtract;
        pub const contains = FlagsMixin(AllocatorCreateFlags).contains;
        pub const format = FlagFormatMixin(AllocatorCreateFlags).format;
    };

    pub const MemoryUsage = enum(c_uint) {
        unknown,
        gpu_only,
        cpu_only,
        cpu_to_gpu,
        gpu_to_cpu,
        cpu_copy,
        gpu_lazily_allocated,
        auto,
        auto_prefer_device,
        auto_prefer_host,
    };

    pub const AllocationCreateFlags = packed struct(vk.Flags) {
        dedicated_memory_bit: bool = false,
        never_allocate_bit: bool = false,
        mapped_bit: bool = false,
        user_data_copy_string_bit: bool = false,
        upper_address_bit: bool = false,
        dont_bind_bit: bool = false,
        within_budget_bit: bool = false,
        can_alias_bit: bool = false,
        host_access_sequential_write_bit: bool = false,
        host_access_random_bit: bool = false,
        host_access_allow_transfer_instead_bit: bool = false,
        strategy_min_memory_bit: bool = false,
        strategy_min_time_bit: bool = false,
        strategy_min_offset_bit: bool = false,
        strategy_best_fit_bit: bool = false,
        strategy_first_fit_bit: bool = false,

        _unused_bits: u16 = 0,
        pub const toInt = FlagsMixin(AllocationCreateFlags).toInt;
        pub const fromInt = FlagsMixin(AllocationCreateFlags).fromInt;
        pub const merge = FlagsMixin(AllocationCreateFlags).merge;
        pub const intersect = FlagsMixin(AllocationCreateFlags).intersect;
        pub const complement = FlagsMixin(AllocationCreateFlags).complement;
        pub const subtract = FlagsMixin(AllocationCreateFlags).subtract;
        pub const contains = FlagsMixin(AllocationCreateFlags).contains;
        pub const format = FlagFormatMixin(AllocationCreateFlags).format;
    };

    pub const PoolCreateFlags = packed struct(vk.Flags) {
        _unused_bit_1: u1 = 0,
        ignore_buffer_image_granularity_bit: bool = false,
        linear_algorithm_bit: bool = false,

        _unused_bits: u29 = 0,
        pub const toInt = FlagsMixin(PoolCreateFlags).toInt;
        pub const fromInt = FlagsMixin(PoolCreateFlags).fromInt;
        pub const merge = FlagsMixin(PoolCreateFlags).merge;
        pub const intersect = FlagsMixin(PoolCreateFlags).intersect;
        pub const complement = FlagsMixin(PoolCreateFlags).complement;
        pub const subtract = FlagsMixin(PoolCreateFlags).subtract;
        pub const contains = FlagsMixin(PoolCreateFlags).contains;
        pub const format = FlagFormatMixin(PoolCreateFlags).format;
    };

    pub const DefragmentationFlags = packed struct(vk.Flags) {
        algorithm_fast_bit: bool = false,
        algorithm_balanced_bit: bool = false,
        algorithm_full_bit: bool = false,
        algorithm_extensive_bit: bool = false,

        _unused_bits: u28 = 0,
        pub const toInt = FlagsMixin(DefragmentationFlags).toInt;
        pub const fromInt = FlagsMixin(DefragmentationFlags).fromInt;
        pub const merge = FlagsMixin(DefragmentationFlags).merge;
        pub const intersect = FlagsMixin(DefragmentationFlags).intersect;
        pub const complement = FlagsMixin(DefragmentationFlags).complement;
        pub const subtract = FlagsMixin(DefragmentationFlags).subtract;
        pub const contains = FlagsMixin(DefragmentationFlags).contains;
        pub const format = FlagFormatMixin(DefragmentationFlags).format;
    };

    pub const DefragmentationMoveOperation = enum(c_uint) {
        copy = 0,
        ignore = 1,
        destroy = 2,
    };

    pub const VirtualBlockCreateFlags = packed struct(vk.Flags) {
        linear_algorithm_bit: bool = false,

        _unused_bits: u31 = 0,
        pub const toInt = FlagsMixin(VirtualBlockCreateFlags).toInt;
        pub const fromInt = FlagsMixin(VirtualBlockCreateFlags).fromInt;
        pub const merge = FlagsMixin(VirtualBlockCreateFlags).merge;
        pub const intersect = FlagsMixin(VirtualBlockCreateFlags).intersect;
        pub const complement = FlagsMixin(VirtualBlockCreateFlags).complement;
        pub const subtract = FlagsMixin(VirtualBlockCreateFlags).subtract;
        pub const contains = FlagsMixin(VirtualBlockCreateFlags).contains;
        pub const format = FlagFormatMixin(VirtualBlockCreateFlags).format;
    };

    pub const VirtualAllocationCreateFlags = packed struct(vk.Flags) {
        _unused_bits_1: u6 = 0,
        upper_address_bit: bool = false,
        _unused_bits_2: u11 = 0,
        strategy_min_memory_bit: bool = false,
        strategy_min_time_bit: bool = false,
        strategy_min_offset_bit: bool = false,

        _unused_bits: u14 = 0,
        pub const toInt = FlagsMixin(VirtualAllocationCreateFlags).toInt;
        pub const fromInt = FlagsMixin(VirtualAllocationCreateFlags).fromInt;
        pub const merge = FlagsMixin(VirtualAllocationCreateFlags).merge;
        pub const intersect = FlagsMixin(VirtualAllocationCreateFlags).intersect;
        pub const complement = FlagsMixin(VirtualAllocationCreateFlags).complement;
        pub const subtract = FlagsMixin(VirtualAllocationCreateFlags).subtract;
        pub const contains = FlagsMixin(VirtualAllocationCreateFlags).contains;
        pub const format = FlagFormatMixin(VirtualAllocationCreateFlags).format;
    };

    pub const Allocator = enum(usize) {
        null_handle = 0,
        _,

        pub const destroyAllocator = vk_mem_alloc.vmaDestroyAllocator;
        pub const getAllocatorInfo = vk_mem_alloc.vmaGetAllocatorInfo;
        pub const getPhysicalDeviceProperties = vk_mem_alloc.vmaGetPhysicalDeviceProperties;
        pub const getMemoryProperties = vk_mem_alloc.vmaGetMemoryProperties;
        pub const getMemoryTypeProperties = vk_mem_alloc.vmaGetMemoryTypeProperties;
        pub const setCurrentFrameIndex = vk_mem_alloc.vmaSetCurrentFrameIndex;
        pub const calculateStatistics = vk_mem_alloc.vmaCalculateStatistics;
        pub const getHeapBudgets = vk_mem_alloc.vmaGetHeapBudgets;
        pub const findMemoryTypeIndex = vk_mem_alloc.vmaFindMemoryTypeIndex;
        pub const findMemoryTypeIndexForBufferInfo = vk_mem_alloc.vmaFindMemoryTypeIndexForBufferInfo;
        pub const findMemoryTypeIndexForImageInfo = vk_mem_alloc.vmaFindMemoryTypeIndexForImageInfo;
        pub const createPool = vk_mem_alloc.vmaCreatePool;
        pub const destroyPool = vk_mem_alloc.vmaDestroyPool;
        pub const getPoolStatistics = vk_mem_alloc.vmaGetPoolStatistics;
        pub const calculatePoolStatistics = vk_mem_alloc.vmaCalculatePoolStatistics;
        pub const checkPoolCorruption = vk_mem_alloc.vmaCheckPoolCorruption;
        pub const getPoolName = vk_mem_alloc.vmaGetPoolName;
        pub const setPoolName = vk_mem_alloc.vmaSetPoolName;
        pub const allocateMemory = vk_mem_alloc.vmaAllocateMemory;
        pub const allocateDedicatedMemory = vk_mem_alloc.vmaAllocateDedicatedMemory;
        pub const allocateMemoryPages = vk_mem_alloc.vmaAllocateMemoryPages;
        pub const allocateMemoryForBuffer = vk_mem_alloc.vmaAllocateMemoryForBuffer;
        pub const allocateMemoryForImage = vk_mem_alloc.vmaAllocateMemoryForImage;
        pub const freeMemory = vk_mem_alloc.vmaFreeMemory;
        pub const freeMemoryPages = vk_mem_alloc.vmaFreeMemoryPages;
        pub const getAllocationInfo = vk_mem_alloc.vmaGetAllocationInfo;
        pub const getAllocationInfo2 = vk_mem_alloc.vmaGetAllocationInfo2;
        pub const setAllocationUserData = vk_mem_alloc.vmaSetAllocationUserData;
        pub const setAllocationName = vk_mem_alloc.vmaSetAllocationName;
        pub const getAllocationMemoryProperties = vk_mem_alloc.vmaGetAllocationMemoryProperties;
        pub const mapMemory = vk_mem_alloc.vmaMapMemory;
        pub const unmapMemory = vk_mem_alloc.vmaUnmapMemory;
        pub const flushAllocation = vk_mem_alloc.vmaFlushAllocation;
        pub const invalidateAllocation = vk_mem_alloc.vmaInvalidateAllocation;
        pub const flushAllocations = vk_mem_alloc.vmaFlushAllocations;
        pub const invalidateAllocations = vk_mem_alloc.vmaInvalidateAllocations;
        pub const copyMemoryToAllocation = vk_mem_alloc.vmaCopyMemoryToAllocation;
        pub const copyAllocationToMemory = vk_mem_alloc.vmaCopyAllocationToMemory;
        pub const checkCorruption = vk_mem_alloc.vmaCheckCorruption;
        pub const beginDefragmentation = vk_mem_alloc.vmaBeginDefragmentation;
        pub const endDefragmentation = vk_mem_alloc.vmaEndDefragmentation;
        pub const beginDefragmentationPass = vk_mem_alloc.vmaBeginDefragmentationPass;
        pub const endDefragmentationPass = vk_mem_alloc.vmaEndDefragmentationPass;
        pub const bindBufferMemory = vk_mem_alloc.vmaBindBufferMemory;
        pub const bindBufferMemory2 = vk_mem_alloc.vmaBindBufferMemory2;
        pub const bindImageMemory = vk_mem_alloc.vmaBindImageMemory;
        pub const bindImageMemory2 = vk_mem_alloc.vmaBindImageMemory2;
        pub const createBuffer = vk_mem_alloc.vmaCreateBuffer;
        pub const createBufferWithAlignment = vk_mem_alloc.vmaCreateBufferWithAlignment;
        pub const createDedicatedBuffer = vk_mem_alloc.vmaCreateDedicatedBuffer;
        pub const createAliasingBuffer = vk_mem_alloc.vmaCreateAliasingBuffer;
        pub const createAliasingBuffer2 = vk_mem_alloc.vmaCreateAliasingBuffer2;
        pub const destroyBuffer = vk_mem_alloc.vmaDestroyBuffer;
        pub const createImage = vk_mem_alloc.vmaCreateImage;
        pub const createDedicatedImage = vk_mem_alloc.vmaCreateDedicatedImage;
        pub const createAliasingImage = vk_mem_alloc.vmaCreateAliasingImage;
        pub const createAliasingImage2 = vk_mem_alloc.vmaCreateAliasingImage2;
        pub const destroyImage = vk_mem_alloc.vmaDestroyImage;
        pub const buildStatsString = vk_mem_alloc.vmaBuildStatsString;
        pub const freeStatsString = vk_mem_alloc.vmaFreeStatsString;
    };
    pub const Pool = enum(usize) { null_handle = 0, _ };
    pub const Allocation = enum(usize) { null_handle = 0, _ };
    pub const DefragmentationContext = enum(usize) { null_handle = 0, _ };
    pub const VirtualAllocation = enum(usize) { null_handle = 0, _ };
    pub const VirtualBlock = enum(usize) {
        null_handle = 0,
        _,
        pub const destroyVirtualBlock = vk_mem_alloc.vmaDestroyVirtualBlock;
        pub const isVirtualBlockEmpty = vk_mem_alloc.vmaIsVirtualBlockEmpty;
        pub const getVirtualAllocationInfo = vk_mem_alloc.vmaGetVirtualAllocationInfo;
        pub const virtualAllocate = vk_mem_alloc.vmaVirtualAllocate;
        pub const virtualFree = vk_mem_alloc.vmaVirtualFree;
        pub const clearVirtualBlock = vk_mem_alloc.vmaClearVirtualBlock;
        pub const setVirtualAllocationUserData = vk_mem_alloc.vmaSetVirtualAllocationUserData;
        pub const getVirtualBlockStatistics = vk_mem_alloc.vmaGetVirtualBlockStatistics;
        pub const calculateVirtualBlockStatistics = vk_mem_alloc.vmaCalculateVirtualBlockStatistics;
        pub const buildVirtualBlockStatsString = vk_mem_alloc.vmaBuildVirtualBlockStatsString;
        pub const freeVirtualBlockStatsString = vk_mem_alloc.vmaFreeVirtualBlockStatsString;
    };
    pub const PFN_AllocateDeviceMemoryFunction = ?*const fn (allocator: Allocator, memoryType: u32, memory: vk.DeviceMemory, size: vk.DeviceSize, pUserData: ?*anyopaque) callconv(.c) void;
    pub const PFN_FreeDeviceMemoryFunction = ?*const fn (allocator: Allocator, memoryType: u32, memory: vk.DeviceMemory, size: vk.DeviceSize, pUserData: ?*anyopaque) callconv(.c) void;
    pub const struct_DeviceMemoryCallbacks = extern struct {
        pfnAllocate: PFN_AllocateDeviceMemoryFunction = null,
        pfnFree: PFN_FreeDeviceMemoryFunction = null,
        pUserData: ?*anyopaque = null,
    };
    pub const DeviceMemoryCallbacks = struct_DeviceMemoryCallbacks;
    pub const struct_VulkanFunctions = extern struct {
        vkGetInstanceProcAddr: ?vk.PfnGetInstanceProcAddr = null,
        vkGetDeviceProcAddr: ?vk.PfnGetDeviceProcAddr = null,
        vkGetPhysicalDeviceProperties: ?vk.PfnGetPhysicalDeviceProperties = null,
        vkGetPhysicalDeviceMemoryProperties: ?vk.PfnGetPhysicalDeviceMemoryProperties = null,
        vkAllocateMemory: ?vk.PfnAllocateMemory = null,
        vkFreeMemory: ?vk.PfnFreeMemory = null,
        vkMapMemory: ?vk.PfnMapMemory = null,
        vkUnmapMemory: ?vk.PfnUnmapMemory = null,
        vkFlushMappedMemoryRanges: ?vk.PfnFlushMappedMemoryRanges = null,
        vkInvalidateMappedMemoryRanges: ?vk.PfnInvalidateMappedMemoryRanges = null,
        vkBindBufferMemory: ?vk.PfnBindBufferMemory = null,
        vkBindImageMemory: ?vk.PfnBindImageMemory = null,
        vkGetBufferMemoryRequirements: ?vk.PfnGetBufferMemoryRequirements = null,
        vkGetImageMemoryRequirements: ?vk.PfnGetImageMemoryRequirements = null,
        vkCreateBuffer: ?vk.PfnCreateBuffer = null,
        vkDestroyBuffer: ?vk.PfnDestroyBuffer = null,
        vkCreateImage: ?vk.PfnCreateImage = null,
        vkDestroyImage: ?vk.PfnDestroyImage = null,
        vkCmdCopyBuffer: ?vk.PfnCmdCopyBuffer = null,
        vkGetBufferMemoryRequirements2KHR: ?vk.PfnGetBufferMemoryRequirements2KHR = null,
        vkGetImageMemoryRequirements2KHR: ?vk.PfnGetImageMemoryRequirements2KHR = null,
        vkBindBufferMemory2KHR: ?vk.PfnBindBufferMemory2KHR = null,
        vkBindImageMemory2KHR: ?vk.PfnBindImageMemory2KHR = null,
        vkGetPhysicalDeviceMemoryProperties2KHR: ?vk.PfnGetPhysicalDeviceMemoryProperties2KHR = null,
        vkGetDeviceBufferMemoryRequirements: ?vk.PfnGetDeviceBufferMemoryRequirementsKHR = null,
        vkGetDeviceImageMemoryRequirements: ?vk.PfnGetDeviceImageMemoryRequirementsKHR = null,
        vkGetMemoryWin32HandleKHR: ?*anyopaque = null,
    };
    pub const VulkanFunctions = struct_VulkanFunctions;
    pub const struct_AllocatorCreateInfo = extern struct {
        flags: AllocatorCreateFlags = .{},
        physicalDevice: vk.PhysicalDevice = .null_handle,
        device: vk.Device = .null_handle,
        preferredLargeHeapBlockSize: vk.DeviceSize = 0,
        pAllocationCallbacks: ?*const vk.AllocationCallbacks = null,
        pDeviceMemoryCallbacks: ?*const DeviceMemoryCallbacks = null,
        pHeapSizeLimit: ?*const vk.DeviceSize = null,
        pVulkanFunctions: *const VulkanFunctions,
        instance: vk.Instance = .null_handle,
        vulkanApiVersion: u32 = 0,
        pTypeExternalMemoryHandleTypes: ?*const vk.ExternalMemoryHandleTypeFlagsKHR = null,
        pub const createAllocator = vk_mem_alloc.vmaCreateAllocator;
    };
    pub const AllocatorCreateInfo = struct_AllocatorCreateInfo;
    pub const struct_AllocatorInfo = extern struct {
        instance: vk.Instance = null,
        physicalDevice: vk.PhysicalDevice = null,
        device: vk.Device = null,
    };
    pub const AllocatorInfo = struct_AllocatorInfo;
    pub const struct_Statistics = extern struct {
        blockCount: u32 = 0,
        allocationCount: u32 = 0,
        blockBytes: vk.DeviceSize = 0,
        allocationBytes: vk.DeviceSize = 0,
    };
    pub const Statistics = struct_Statistics;
    pub const struct_DetailedStatistics = extern struct {
        statistics: Statistics = @import("std").mem.zeroes(Statistics),
        unusedRangeCount: u32 = 0,
        allocationSizeMin: vk.DeviceSize = 0,
        allocationSizeMax: vk.DeviceSize = 0,
        unusedRangeSizeMin: vk.DeviceSize = 0,
        unusedRangeSizeMax: vk.DeviceSize = 0,
    };
    pub const DetailedStatistics = struct_DetailedStatistics;
    pub const struct_TotalStatistics = extern struct {
        memoryType: [32]DetailedStatistics = @import("std").mem.zeroes([32]DetailedStatistics),
        memoryHeap: [16]DetailedStatistics = @import("std").mem.zeroes([16]DetailedStatistics),
        total: DetailedStatistics = @import("std").mem.zeroes(DetailedStatistics),
    };
    pub const TotalStatistics = struct_TotalStatistics;
    pub const struct_Budget = extern struct {
        statistics: Statistics = @import("std").mem.zeroes(Statistics),
        usage: vk.DeviceSize = 0,
        budget: vk.DeviceSize = 0,
    };
    pub const Budget = struct_Budget;
    pub const struct_AllocationCreateInfo = extern struct {
        flags: AllocationCreateFlags = .{},
        usage: MemoryUsage = @import("std").mem.zeroes(MemoryUsage),
        requiredFlags: vk.MemoryPropertyFlags = .{},
        preferredFlags: vk.MemoryPropertyFlags = .{},
        memoryTypeBits: u32 = 0,
        pool: Pool = .null_handle,
        pUserData: ?*anyopaque = null,
        priority: f32 = 0,
    };
    pub const AllocationCreateInfo = struct_AllocationCreateInfo;
    pub const struct_PoolCreateInfo = extern struct {
        memoryTypeIndex: u32 = 0,
        flags: PoolCreateFlags = 0,
        blockSize: vk.DeviceSize = 0,
        minBlockCount: usize = 0,
        maxBlockCount: usize = 0,
        priority: f32 = 0,
        minAllocationAlignment: vk.DeviceSize = 0,
        pMemoryAllocateNext: ?*anyopaque = null,
    };
    pub const PoolCreateInfo = struct_PoolCreateInfo;
    pub const struct_AllocationInfo = extern struct {
        memoryType: u32 = 0,
        deviceMemory: vk.DeviceMemory = .null_handle,
        offset: vk.DeviceSize = 0,
        size: vk.DeviceSize = 0,
        pMappedData: ?*anyopaque = null,
        pUserData: ?*anyopaque = null,
        pName: ?[*:0]const u8 = null,
    };
    pub const AllocationInfo = struct_AllocationInfo;
    pub const struct_AllocationInfo2 = extern struct {
        allocationInfo: AllocationInfo = @import("std").mem.zeroes(AllocationInfo),
        blockSize: vk.DeviceSize = 0,
        dedicatedMemory: vk.Bool32 = 0,
    };
    pub const AllocationInfo2 = struct_AllocationInfo2;
    pub const PFN_CheckDefragmentationBreakFunction = ?*const fn (pUserData: ?*anyopaque) callconv(.c) vk.Bool32;
    pub const struct_DefragmentationInfo = extern struct {
        flags: DefragmentationFlags = 0,
        pool: Pool = null,
        maxBytesPerPass: vk.DeviceSize = 0,
        maxAllocationsPerPass: u32 = 0,
        pfnBreakCallback: PFN_CheckDefragmentationBreakFunction = null,
        pBreakCallbackUserData: ?*anyopaque = null,
    };
    pub const DefragmentationInfo = struct_DefragmentationInfo;
    pub const struct_DefragmentationMove = extern struct {
        operation: DefragmentationMoveOperation = @import("std").mem.zeroes(DefragmentationMoveOperation),
        srcAllocation: Allocation = null,
        dstTmpAllocation: Allocation = null,
    };
    pub const DefragmentationMove = struct_DefragmentationMove;
    pub const struct_DefragmentationPassMoveInfo = extern struct {
        moveCount: u32 = 0,
        pMoves: ?[*]DefragmentationMove = null,
    };
    pub const DefragmentationPassMoveInfo = struct_DefragmentationPassMoveInfo;
    pub const struct_DefragmentationStats = extern struct {
        bytesMoved: vk.DeviceSize = 0,
        bytesFreed: vk.DeviceSize = 0,
        allocationsMoved: u32 = 0,
        deviceMemoryBlocksFreed: u32 = 0,
    };
    pub const DefragmentationStats = struct_DefragmentationStats;
    pub const struct_VirtualBlockCreateInfo = extern struct {
        size: vk.DeviceSize = 0,
        flags: VirtualBlockCreateFlags = 0,
        pAllocationCallbacks: ?*const vk.AllocationCallbacks = null,
        pub const CreateVirtualBlock = vk_mem_alloc.vmaCreateVirtualBlock;
    };
    pub const VirtualBlockCreateInfo = struct_VirtualBlockCreateInfo;
    pub const struct_VirtualAllocationCreateInfo = extern struct {
        size: vk.DeviceSize = 0,
        alignment: vk.DeviceSize = 0,
        flags: VirtualAllocationCreateFlags = 0,
        pUserData: ?*anyopaque = null,
    };
    pub const VirtualAllocationCreateInfo = struct_VirtualAllocationCreateInfo;
    pub const struct_VirtualAllocationInfo = extern struct {
        offset: vk.DeviceSize = 0,
        size: vk.DeviceSize = 0,
        pUserData: ?*anyopaque = null,
    };
    pub const VirtualAllocationInfo = struct_VirtualAllocationInfo;
    pub extern fn vmaCreateAllocator(pCreateInfo: [*c]const AllocatorCreateInfo, pAllocator: [*c]Allocator) vk.Result;
    pub extern fn vmaDestroyAllocator(allocator: Allocator) void;
    pub extern fn vmaGetAllocatorInfo(allocator: Allocator, pAllocatorInfo: [*c]AllocatorInfo) void;
    pub extern fn vmaGetPhysicalDeviceProperties(allocator: Allocator, ppPhysicalDeviceProperties: [*c][*c]const vk.PhysicalDeviceProperties) void;
    pub extern fn vmaGetMemoryProperties(allocator: Allocator, ppPhysicalDeviceMemoryProperties: [*c][*c]const vk.PhysicalDeviceMemoryProperties) void;
    pub extern fn vmaGetMemoryTypeProperties(allocator: Allocator, memoryTypeIndex: u32, pFlags: [*c]vk.MemoryPropertyFlags) void;
    pub extern fn vmaSetCurrentFrameIndex(allocator: Allocator, frameIndex: u32) void;
    pub extern fn vmaCalculateStatistics(allocator: Allocator, pStats: [*c]TotalStatistics) void;
    pub extern fn vmaGetHeapBudgets(allocator: Allocator, pBudgets: [*c]Budget) void;
    pub extern fn vmaFindMemoryTypeIndex(allocator: Allocator, memoryTypeBits: u32, pAllocationCreateInfo: [*c]const AllocationCreateInfo, pMemoryTypeIndex: [*c]u32) vk.Result;
    pub extern fn vmaFindMemoryTypeIndexForBufferInfo(allocator: Allocator, pBufferCreateInfo: [*c]const vk.BufferCreateInfo, pAllocationCreateInfo: [*c]const AllocationCreateInfo, pMemoryTypeIndex: [*c]u32) vk.Result;
    pub extern fn vmaFindMemoryTypeIndexForImageInfo(allocator: Allocator, pImageCreateInfo: [*c]const vk.ImageCreateInfo, pAllocationCreateInfo: [*c]const AllocationCreateInfo, pMemoryTypeIndex: [*c]u32) vk.Result;
    pub extern fn vmaCreatePool(allocator: Allocator, pCreateInfo: [*c]const PoolCreateInfo, pPool: [*c]Pool) vk.Result;
    pub extern fn vmaDestroyPool(allocator: Allocator, pool: Pool) void;
    pub extern fn vmaGetPoolStatistics(allocator: Allocator, pool: Pool, pPoolStats: [*c]Statistics) void;
    pub extern fn vmaCalculatePoolStatistics(allocator: Allocator, pool: Pool, pPoolStats: [*c]DetailedStatistics) void;
    pub extern fn vmaCheckPoolCorruption(allocator: Allocator, pool: Pool) vk.Result;
    pub extern fn vmaGetPoolName(allocator: Allocator, pool: Pool, ppName: [*c][*c]const u8) void;
    pub extern fn vmaSetPoolName(allocator: Allocator, pool: Pool, pName: [*c]const u8) void;
    pub extern fn vmaAllocateMemory(allocator: Allocator, pVkMemoryRequirements: [*c]const vk.MemoryRequirements, pCreateInfo: [*c]const AllocationCreateInfo, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaAllocateDedicatedMemory(allocator: Allocator, pVkMemoryRequirements: [*c]const vk.MemoryRequirements, pCreateInfo: [*c]const AllocationCreateInfo, pMemoryAllocateNext: ?*anyopaque, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaAllocateMemoryPages(allocator: Allocator, pVkMemoryRequirements: [*c]const vk.MemoryRequirements, pCreateInfo: [*c]const AllocationCreateInfo, allocationCount: usize, pAllocations: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaAllocateMemoryForBuffer(allocator: Allocator, buffer: vk.Buffer, pCreateInfo: [*c]const AllocationCreateInfo, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaAllocateMemoryForImage(allocator: Allocator, image: vk.Image, pCreateInfo: [*c]const AllocationCreateInfo, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaFreeMemory(allocator: Allocator, allocation: Allocation) void;
    pub extern fn vmaFreeMemoryPages(allocator: Allocator, allocationCount: usize, pAllocations: [*c]const Allocation) void;
    pub extern fn vmaGetAllocationInfo(allocator: Allocator, allocation: Allocation, pAllocationInfo: [*c]AllocationInfo) void;
    pub extern fn vmaGetAllocationInfo2(allocator: Allocator, allocation: Allocation, pAllocationInfo: [*c]AllocationInfo2) void;
    pub extern fn vmaSetAllocationUserData(allocator: Allocator, allocation: Allocation, pUserData: ?*anyopaque) void;
    pub extern fn vmaSetAllocationName(allocator: Allocator, allocation: Allocation, pName: [*c]const u8) void;
    pub extern fn vmaGetAllocationMemoryProperties(allocator: Allocator, allocation: Allocation, pFlags: [*c]vk.MemoryPropertyFlags) void;
    pub extern fn vmaMapMemory(allocator: Allocator, allocation: Allocation, ppData: [*c]?*anyopaque) vk.Result;
    pub extern fn vmaUnmapMemory(allocator: Allocator, allocation: Allocation) void;
    pub extern fn vmaFlushAllocation(allocator: Allocator, allocation: Allocation, offset: vk.DeviceSize, size: vk.DeviceSize) vk.Result;
    pub extern fn vmaInvalidateAllocation(allocator: Allocator, allocation: Allocation, offset: vk.DeviceSize, size: vk.DeviceSize) vk.Result;
    pub extern fn vmaFlushAllocations(allocator: Allocator, allocationCount: u32, allocations: [*c]const Allocation, offsets: [*c]const vk.DeviceSize, sizes: [*c]const vk.DeviceSize) vk.Result;
    pub extern fn vmaInvalidateAllocations(allocator: Allocator, allocationCount: u32, allocations: [*c]const Allocation, offsets: [*c]const vk.DeviceSize, sizes: [*c]const vk.DeviceSize) vk.Result;
    pub extern fn vmaCopyMemoryToAllocation(allocator: Allocator, pSrcHostPointer: ?*const anyopaque, dstAllocation: Allocation, dstAllocationLocalOffset: vk.DeviceSize, size: vk.DeviceSize) vk.Result;
    pub extern fn vmaCopyAllocationToMemory(allocator: Allocator, srcAllocation: Allocation, srcAllocationLocalOffset: vk.DeviceSize, pDstHostPointer: ?*anyopaque, size: vk.DeviceSize) vk.Result;
    pub extern fn vmaCheckCorruption(allocator: Allocator, memoryTypeBits: u32) vk.Result;
    pub extern fn vmaBeginDefragmentation(allocator: Allocator, pInfo: [*c]const DefragmentationInfo, pContext: [*c]DefragmentationContext) vk.Result;
    pub extern fn vmaEndDefragmentation(allocator: Allocator, context: DefragmentationContext, pStats: [*c]DefragmentationStats) void;
    pub extern fn vmaBeginDefragmentationPass(allocator: Allocator, context: DefragmentationContext, pPassInfo: [*c]DefragmentationPassMoveInfo) vk.Result;
    pub extern fn vmaEndDefragmentationPass(allocator: Allocator, context: DefragmentationContext, pPassInfo: [*c]DefragmentationPassMoveInfo) vk.Result;
    pub extern fn vmaBindBufferMemory(allocator: Allocator, allocation: Allocation, buffer: vk.Buffer) vk.Result;
    pub extern fn vmaBindBufferMemory2(allocator: Allocator, allocation: Allocation, allocationLocalOffset: vk.DeviceSize, buffer: vk.Buffer, pNext: ?*const anyopaque) vk.Result;
    pub extern fn vmaBindImageMemory(allocator: Allocator, allocation: Allocation, image: vk.Image) vk.Result;
    pub extern fn vmaBindImageMemory2(allocator: Allocator, allocation: Allocation, allocationLocalOffset: vk.DeviceSize, image: vk.Image, pNext: ?*const anyopaque) vk.Result;
    pub extern fn vmaCreateBuffer(allocator: Allocator, pBufferCreateInfo: [*c]const vk.BufferCreateInfo, pAllocationCreateInfo: [*c]const AllocationCreateInfo, pBuffer: [*c]vk.Buffer, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaCreateBufferWithAlignment(allocator: Allocator, pBufferCreateInfo: [*c]const vk.BufferCreateInfo, pAllocationCreateInfo: [*c]const AllocationCreateInfo, minAlignment: vk.DeviceSize, pBuffer: [*c]vk.Buffer, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaCreateDedicatedBuffer(allocator: Allocator, pBufferCreateInfo: [*c]const vk.BufferCreateInfo, pAllocationCreateInfo: [*c]const AllocationCreateInfo, pMemoryAllocateNext: ?*anyopaque, pBuffer: [*c]vk.Buffer, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaCreateAliasingBuffer(allocator: Allocator, allocation: Allocation, pBufferCreateInfo: [*c]const vk.BufferCreateInfo, pBuffer: [*c]vk.Buffer) vk.Result;
    pub extern fn vmaCreateAliasingBuffer2(allocator: Allocator, allocation: Allocation, allocationLocalOffset: vk.DeviceSize, pBufferCreateInfo: [*c]const vk.BufferCreateInfo, pBuffer: [*c]vk.Buffer) vk.Result;
    pub extern fn vmaDestroyBuffer(allocator: Allocator, buffer: vk.Buffer, allocation: Allocation) void;
    pub extern fn vmaCreateImage(allocator: Allocator, pImageCreateInfo: [*c]const vk.ImageCreateInfo, pAllocationCreateInfo: [*c]const AllocationCreateInfo, pImage: [*c]vk.Image, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaCreateDedicatedImage(allocator: Allocator, pImageCreateInfo: [*c]const vk.ImageCreateInfo, pAllocationCreateInfo: [*c]const AllocationCreateInfo, pMemoryAllocateNext: ?*anyopaque, pImage: [*c]vk.Image, pAllocation: [*c]Allocation, pAllocationInfo: [*c]AllocationInfo) vk.Result;
    pub extern fn vmaCreateAliasingImage(allocator: Allocator, allocation: Allocation, pImageCreateInfo: [*c]const vk.ImageCreateInfo, pImage: [*c]vk.Image) vk.Result;
    pub extern fn vmaCreateAliasingImage2(allocator: Allocator, allocation: Allocation, allocationLocalOffset: vk.DeviceSize, pImageCreateInfo: [*c]const vk.ImageCreateInfo, pImage: [*c]vk.Image) vk.Result;
    pub extern fn vmaDestroyImage(allocator: Allocator, image: vk.Image, allocation: Allocation) void;
    pub extern fn vmaCreateVirtualBlock(pCreateInfo: [*c]const VirtualBlockCreateInfo, pVirtualBlock: [*c]VirtualBlock) vk.Result;
    pub extern fn vmaDestroyVirtualBlock(virtualBlock: VirtualBlock) void;
    pub extern fn vmaIsVirtualBlockEmpty(virtualBlock: VirtualBlock) vk.Bool32;
    pub extern fn vmaGetVirtualAllocationInfo(virtualBlock: VirtualBlock, allocation: VirtualAllocation, pVirtualAllocInfo: [*c]VirtualAllocationInfo) void;
    pub extern fn vmaVirtualAllocate(virtualBlock: VirtualBlock, pCreateInfo: [*c]const VirtualAllocationCreateInfo, pAllocation: [*c]VirtualAllocation, pOffset: [*c]vk.DeviceSize) vk.Result;
    pub extern fn vmaVirtualFree(virtualBlock: VirtualBlock, allocation: VirtualAllocation) void;
    pub extern fn vmaClearVirtualBlock(virtualBlock: VirtualBlock) void;
    pub extern fn vmaSetVirtualAllocationUserData(virtualBlock: VirtualBlock, allocation: VirtualAllocation, pUserData: ?*anyopaque) void;
    pub extern fn vmaGetVirtualBlockStatistics(virtualBlock: VirtualBlock, pStats: [*c]Statistics) void;
    pub extern fn vmaCalculateVirtualBlockStatistics(virtualBlock: VirtualBlock, pStats: [*c]DetailedStatistics) void;
    pub extern fn vmaBuildVirtualBlockStatsString(virtualBlock: VirtualBlock, ppStatsString: [*c][*c]u8, detailedMap: vk.Bool32) void;
    pub extern fn vmaFreeVirtualBlockStatsString(virtualBlock: VirtualBlock, pStatsString: [*c]u8) void;
    pub extern fn vmaBuildStatsString(allocator: Allocator, ppStatsString: [*c][*c]u8, detailedMap: vk.Bool32) void;
    pub extern fn vmaFreeStatsString(allocator: Allocator, pStatsString: [*c]u8) void;
};

fn setDebugName(device: *vk.DeviceProxy, obj_type: vk.ObjectType, comptime T: type, handle: T, name: []const u8) void {
    var buf: [256]u8 = undefined;
    const name_sentinel: [:0]u8 = std.fmt.bufPrintSentinel(&buf, "{s}", .{name}, 0) catch {
        log.err("Failed to format debug name: {s}", .{name});
        return;
    };

    const info: vk.DebugUtilsObjectNameInfoEXT = .{
        .object_type = obj_type,
        .object_handle = @intFromEnum(handle),
        .p_object_name = name_sentinel.ptr,
    };

    device.setDebugUtilsObjectNameEXT(&info) catch {
        log.err("Failed to set debug name: {s} of {s}", .{ name, @tagName(obj_type) });
    };
}

fn setAllocationName(vma: vk_mem_alloc.Allocator, allocation: vk_mem_alloc.Allocation, name: []const u8) void {
    var buf: [256]u8 = undefined;
    const name_sentinel: [:0]u8 = std.fmt.bufPrintSentinel(&buf, "{s}", .{name}, 0) catch {
        log.err("Failed to format debug name: {s}", .{name});
        return;
    };

    vma.setAllocationName(allocation, name_sentinel.ptr);
}

const std = @import("std");
const builtin = @import("builtin");

const gpu = @import("./root.zig");
const utils = gpu.utils;
const StaticRingBuffer = utils.StaticRingBuffer;
const InlineStorage = utils.InlineStorage;
const Error = gpu.Error;

const vk = @import("vulkan");

const spatial = @import("../math/spatial.zig");

const log = std.log.scoped(.vulkan);

const OffsetAllocator = @import("OffsetAllocator.zig");
