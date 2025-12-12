pub const Device = struct {
    allocator: std.mem.Allocator,

    // @factory
    factory: *dxgi.IFactory6,
    // @tearing_supported
    tearing_supported: bool,

    // @adapter
    adapter: *dxgi.IAdapter1,
    // @device
    device: *d3d12.IDevice5,

    // @heaps
    // cpu
    rtv_heap: DescriptorHeap,
    dsv_heap: DescriptorHeap,
    // gpu
    resource_heap: DescriptorHeap,
    sampler_heap: DescriptorHeap,

    // @queues
    graphics_queue: *d3d12.ICommandQueue,
    compute_queue: *d3d12.ICommandQueue,
    copy_queue: *d3d12.ICommandQueue,
    root_signature: *d3d12.IRootSignature,

    // @d3d12ma
    mem_allocator: *d3d12ma.Allocator,
    // @constant buffers
    // one per frame in flight
    constant_buffers: [gpu.backbuffer_count]utils.LinearAllocatedBuffer,

    // @deletion_queues
    deletion_queue: StaticRingBuffer(*win32.IUnknown, gpu.backbuffer_count, 512),
    allocation_deletion_queue: StaticRingBuffer(*d3d12ma.Allocation, gpu.backbuffer_count, 512),
    rtv_deletion_queue: StaticRingBuffer(DescriptorHeap.Handle, gpu.backbuffer_count, 512),
    dsv_deletion_queue: StaticRingBuffer(DescriptorHeap.Handle, gpu.backbuffer_count, 512),
    cbv_srv_uav_deletion_queue: StaticRingBuffer(DescriptorHeap.Handle, gpu.backbuffer_count, 2048),
    sampler_deletion_queue: StaticRingBuffer(DescriptorHeap.Handle, gpu.backbuffer_count, 512),

    gpu_device_adapter_name: [256]u8,
    frame_idx: u64,
    vendor: gpu.Vendor,
    adapter_name: []const u8,
    options: gpu.Options,

    // @is_done
    is_done: bool,

    // @init
    pub fn init(self: *Device, allocator: std.mem.Allocator, options: gpu.Options) !void {
        self.* = undefined;
        self.is_done = false;
        self.allocator = allocator;
        self.options = options;

        self.gpu_device_adapter_name = @splat(0);
        self.frame_idx = 0;
        self.vendor = .unknown;
        self.adapter_name = &.{};

        var factory_flags: u32 = 0;
        if (options.validation) {
            var debug_controller: ?*d3d12d.IDebug1 = null;
            defer {
                if (debug_controller) |d| _ = d.iunknown.Release();
            }
            if (d3d12.GetDebugInterface(win32.riid(d3d12d.IDebug1), @ptrCast(&debug_controller)) == win32.S_OK) {
                debug_controller.?.EnableDebugLayer();
                // if (options.validation == .full) {
                debug_controller.?.SetEnableGPUBasedValidation(.TRUE);
                // }
                factory_flags |= dxgi.CREATE_FACTORY_DEBUG;
            }
        }

        // @factory
        const hr_factory = dxgi.CreateDXGIFactory2(factory_flags, win32.riid(dxgi.IFactory6), @ptrCast(&self.factory));
        if (hr_factory != win32.S_OK) {
            log.err("Failed to create DXGI factory: {f}", .{win32.fmtHresult(hr_factory, .code_message)});
            return error.Gpu;
        }
        errdefer _ = self.factory.iunknown.Release();

        // @tearing_supported
        var tearing_supported: win32.BOOL = .FALSE;
        const hr_tearing = self.factory.ifactory5.CheckFeatureSupport(
            .PRESENT_ALLOW_TEARING,
            @ptrCast(&tearing_supported),
            @sizeOf(win32.BOOL),
        );
        if (hr_tearing != win32.S_OK) {
            tearing_supported = .FALSE;
        } else self.tearing_supported = tearing_supported.truthy();

        const gpu_preference: dxgi.GPU_PREFERENCE = switch (options.power_preference) {
            .high_performance => .HIGH_PERFORMANCE,
            .low_power => .MINIMUM,
        };

        const feature_level: d3dcommon.FEATURE_LEVEL = .@"12_0";

        var chosen_adapter: ?*dxgi.IAdapter1 = null;
        {
            var it_adapter: ?*dxgi.IAdapter1 = null;
            var adapter_index: u32 = 0;
            while (true) {
                const hr_enum = self.factory.EnumAdapterByGpuPreference(
                    adapter_index,
                    gpu_preference,
                    win32.riid(dxgi.IAdapter1),
                    @ptrCast(&it_adapter),
                );
                if (hr_enum == dxgi.ERROR_NOT_FOUND) {
                    break;
                }
                defer adapter_index += 1;
                defer {
                    if (it_adapter) |a| {
                        _ = a.iunknown.Release();
                    }
                }

                var adapter_desc: dxgi.ADAPTER_DESC1 = undefined;
                // should not fail
                _ = it_adapter.?.GetDesc1(&adapter_desc);
                const adapter_name_len = std.mem.indexOfScalar(u16, &adapter_desc.Description, 0) orelse adapter_desc.Description.len;
                const adapter_name: []const u16 = adapter_desc.Description[0..adapter_name_len];

                log.info(
                    "Found adapter {d}: {f}, dedicated video memory: {d} MB, dedicated system memory: {d} MB, shared system memory: {d} MB",
                    .{
                        adapter_index,
                        std.unicode.fmtUtf16Le(adapter_name),
                        bytesToMegabytes(adapter_desc.DedicatedVideoMemory),
                        bytesToMegabytes(adapter_desc.DedicatedSystemMemory),
                        bytesToMegabytes(adapter_desc.SharedSystemMemory),
                    },
                );

                var out_device: ?*d3d12.IDevice = null;
                const hr_check = d3d12.CreateDevice(@ptrCast(it_adapter), feature_level, win32.riid(d3d12.IDevice), @ptrCast(&out_device));
                const is_compatible = hr_check == win32.S_OK;
                if (out_device) |d| {
                    _ = d.iunknown.Release();
                }

                if (is_compatible) {
                    chosen_adapter = it_adapter;
                    it_adapter = null; // prevent release in defer
                    break;
                } else {
                    std.debug.print("Adapter not compatible: {f}: {f}\n", .{
                        std.unicode.fmtUtf16Le(adapter_name),
                        win32.fmtHresult(hr_check, .code_message),
                    });
                }
            }
        }

        if (chosen_adapter == null) {
            log.err("No compatible adapter found", .{});
            return error.Gpu;
        }
        // @adapter
        self.adapter = chosen_adapter.?;
        errdefer _ = self.adapter.iunknown.Release();

        var adapter_desc: dxgi.ADAPTER_DESC1 = undefined;
        _ = self.adapter.GetDesc1(&adapter_desc);
        switch (adapter_desc.VendorId) {
            0x1002 => self.vendor = .amd,
            0x10de => self.vendor = .nvidia,
            0x8086 => self.vendor = .intel,
            else => self.vendor = .unknown,
        }

        log.info("Vendor: {s}", .{@tagName(self.vendor)});
        const name_len = std.mem.indexOfScalar(u16, &adapter_desc.Description, 0) orelse adapter_desc.Description.len;
        _ = std.unicode.utf16LeToUtf8(&self.gpu_device_adapter_name, adapter_desc.Description[0..name_len]) catch {};
        self.adapter_name = self.gpu_device_adapter_name[0..name_len];
        log.info("Adapter: {s}", .{self.adapter_name});

        // @device
        const hr_device = d3d12.CreateDevice(@ptrCast(self.adapter), feature_level, win32.riid(d3d12.IDevice5), @ptrCast(&self.device));
        if (hr_device != win32.S_OK) {
            log.err("Failed to create D3D12 device: {f}", .{win32.fmtHresult(hr_device, .code_message)});
            return error.Gpu;
        }
        errdefer _ = self.device.iunknown.Release();

        // TODO: check for resource binding 3
        // TODO: check for shading model 6.6
        // TODO: check for renderpasses 0
        // TODO: check for enhanced barriers

        {
            // TODO: add stuff to info queue
            var info_queue: ?*d3d12d.IInfoQueue = null;
            const hr_info = self.device.iunknown.QueryInterface(win32.riid(d3d12d.IInfoQueue), @ptrCast(&info_queue));
            if (hr_info == win32.S_OK) {
                defer _ = info_queue.?.iunknown.Release();
            }

            var info_queue_1: ?*d3d12d.IInfoQueue1 = null;
            const hr_info_1 = self.device.iunknown.QueryInterface(win32.riid(d3d12d.IInfoQueue1), @ptrCast(&info_queue_1));
            if (hr_info_1 == win32.S_OK) {
                defer _ = info_queue_1.?.iunknown.Release();

                var cookie: u32 = 0;
                _ = info_queue_1.?.RegisterMessageCallback(
                    messageCallback,
                    .zero,
                    self,
                    &cookie,
                );
            }
        }

        // @d3d12ma
        {
            var allocator_desc: d3d12ma.ALLOCATOR_DESC = .{};
            allocator_desc.pDevice = &self.device.idevice;
            allocator_desc.pAdapter = &self.adapter.iadapter;

            const hr_allocator = d3d12ma.Allocator.Create(&allocator_desc, @ptrCast(&self.mem_allocator));
            if (hr_allocator != win32.S_OK) {
                log.err("Failed to create D3D12MA allocator: {f}", .{win32.fmtHresult(hr_allocator, .code_message)});
                return error.Gpu;
            }
        }

        // @queues
        {
            var queue_desc: d3d12.COMMAND_QUEUE_DESC = .{
                .Type = .DIRECT,
                .Priority = 0,
                .Flags = .{},
                .NodeMask = 0,
            };

            const hr_graphics = self.device.idevice.CreateCommandQueue(
                &queue_desc,
                win32.riid(d3d12.ICommandQueue),
                @ptrCast(&self.graphics_queue),
            );
            if (hr_graphics != win32.S_OK) {
                log.err(
                    "Failed to create graphics command queue: {f}",
                    .{win32.fmtHresult(hr_graphics, .code_message)},
                );
                return error.Gpu;
            }
            errdefer _ = self.graphics_queue.iunknown.Release();
            _ = self.graphics_queue.iobject.setNameUtf8("Graphics Queue") catch {};

            queue_desc.Type = .COMPUTE;
            const hr_compute = self.device.idevice.CreateCommandQueue(
                &queue_desc,
                win32.riid(d3d12.ICommandQueue),
                @ptrCast(&self.compute_queue),
            );
            if (hr_compute != win32.S_OK) {
                log.err(
                    "Failed to create compute command queue: {f}",
                    .{win32.fmtHresult(hr_compute, .code_message)},
                );
                return error.Gpu;
            }
            errdefer _ = self.compute_queue.iunknown.Release();
            _ = self.compute_queue.iobject.setNameUtf8("Compute Queue") catch {};

            queue_desc.Type = .COPY;
            const hr_copy = self.device.idevice.CreateCommandQueue(
                &queue_desc,
                win32.riid(d3d12.ICommandQueue),
                @ptrCast(&self.copy_queue),
            );
            if (hr_copy != win32.S_OK) {
                log.err(
                    "Failed to create copy command queue: {f}",
                    .{win32.fmtHresult(hr_copy, .code_message)},
                );
                return error.Gpu;
            }
            errdefer _ = self.copy_queue.iunknown.Release();
            _ = self.copy_queue.iobject.setNameUtf8("Copy Queue") catch {};
        }

        // @rootsig
        {
            try self.createRootSignature();
        }

        // @deletion queues
        {
            self.deletion_queue = .empty;
            self.allocation_deletion_queue = .empty;
            self.rtv_deletion_queue = .empty;
            self.dsv_deletion_queue = .empty;
            self.cbv_srv_uav_deletion_queue = .empty;
            self.sampler_deletion_queue = .empty;
        }

        // @heaps
        {
            self.rtv_heap = .{
                .heap_type = .RTV,
                .shader_visible = false,
            };
            try self.rtv_heap.init(allocator, &self.device.idevice, 512, "RTV Heap");
            errdefer self.rtv_heap.deinit(allocator);

            self.dsv_heap = .{
                .heap_type = .DSV,
                .shader_visible = false,
            };
            try self.dsv_heap.init(allocator, &self.device.idevice, 128, "DSV Heap");
            errdefer self.dsv_heap.deinit(allocator);

            self.resource_heap = .{
                .heap_type = .CBV_SRV_UAV,
                .shader_visible = true,
            };
            try self.resource_heap.init(allocator, &self.device.idevice, gpu.max_resource_descriptor_count, "Resource Heap");
            errdefer self.resource_heap.deinit(allocator);

            self.sampler_heap = .{
                .heap_type = .SAMPLER,
                .shader_visible = true,
            };
            try self.sampler_heap.init(allocator, &self.device.idevice, gpu.max_sampler_descriptor_count, "Sampler Heap");
            errdefer self.sampler_heap.deinit(allocator);
        }

        // @constant buffers
        {
            var name_buf: [64]u8 = undefined;
            self.constant_buffers = @splat(.zero);
            for (self.constant_buffers[0..], 0..) |*cb, i| {
                const name = std.fmt.bufPrint(name_buf[0..], "Constant Buffer Frame {}", .{i}) catch "Constant Buffer";
                cb.* = try .init(self.interface(), allocator, 8 * 1024 * 1024, name);
            }
        }
    }

    pub fn deinit(self: *Device) void {
        const allocator = self.allocator;
        for (self.constant_buffers[0..]) |*cb| {
            cb.deinit();
        }
        self.cleanupFully();

        self.sampler_heap.deinit(allocator);
        self.resource_heap.deinit(allocator);
        self.dsv_heap.deinit(allocator);
        self.rtv_heap.deinit(allocator);

        _ = self.root_signature.iunknown.Release();

        _ = self.copy_queue.iunknown.Release();
        self.copy_queue = undefined;
        _ = self.compute_queue.iunknown.Release();
        self.compute_queue = undefined;
        _ = self.graphics_queue.iunknown.Release();
        self.graphics_queue = undefined;

        _ = self.adapter.iunknown.Release();
        self.adapter = undefined;
        _ = self.factory.iunknown.Release();
        self.factory = undefined;

        _ = self.mem_allocator.Release();

        var debug_device: ?*d3d12.IDebugDevice = null;
        if (self.options.validation) {
            const hr_debug = self.device.iunknown.QueryInterface(
                win32.riid(d3d12.IDebugDevice),
                @ptrCast(&debug_device),
            );
            if (hr_debug == win32.S_OK) {
                errdefer _ = debug_device.?.iunknown.Release();
            }
        }

        _ = self.device.iunknown.Release();
        self.device = undefined;

        if (debug_device) |d| {
            _ = d.ReportLiveDeviceObjects(.{
                .DETAIL = true,
                .IGNORE_INTERNAL = true,
            });
            _ = d.iunknown.Release();
        }
    }

    fn messageCallback(
        category: d3d12d.MESSAGE_CATEGORY,
        severity: d3d12d.MESSAGE_SEVERITY,
        id: d3d12d.MESSAGE_ID,
        description: [*:0]const u8,
        pContext: *anyopaque,
    ) callconv(.winapi) void {
        _ = pContext;
        switch (severity) {
            .CORRUPTION, .ERROR => {
                log.err("{s}: {s}", .{ @tagName(category), std.mem.span(description) });
                unreachable;
            },
            .WARNING => {
                log.warn("{s}: {s}", .{ @tagName(category), std.mem.span(description) });
            },
            .INFO => {
                log.info("{s} {s}: {s}", .{ @tagName(category), @tagName(id), std.mem.span(description) });
            },
            .MESSAGE => {
                log.debug("{s}: {s}", .{ @tagName(category), std.mem.span(description) });
            },
        }
    }

    fn beginFrame(self: *Device) void {
        self.garbageCollect();

        const index = self.frame_idx % gpu.backbuffer_count;
        const cb: *utils.LinearAllocatedBuffer = &self.constant_buffers[index];
        cb.reset();

        return;
    }

    fn endFrame(self: *Device) void {
        self.frame_idx += 1;
        self.mem_allocator.SetCurrentFrameIndex(@intCast(self.frame_idx));

        return;
    }

    fn allocateRTV(self: *Device) !DescriptorHeap.Handle {
        return self.rtv_heap.alloc(1);
    }

    fn allocateDSV(self: *Device) !DescriptorHeap.Handle {
        return self.dsv_heap.alloc(1);
    }

    fn allocateCBVSRVUAV(self: *Device) !DescriptorHeap.Handle {
        return self.resource_heap.alloc(1);
    }

    fn allocateSampler(self: *Device) !DescriptorHeap.Handle {
        return self.sampler_heap.alloc(1);
    }

    fn deleteIUnknown(self: *Device, iunk: *win32.IUnknown) void {
        if (self.is_done) {
            _ = iunk.Release();
            return;
        }
        self.deletion_queue.add(iunk);
    }

    fn deleteAllocation(self: *Device, allocation: *d3d12ma.Allocation) void {
        if (self.is_done) {
            allocation.Release();
            return;
        }
        self.allocation_deletion_queue.add(allocation);
    }

    fn deleteRTV(self: *Device, handle: DescriptorHeap.Handle) void {
        if (handle.isInvalid()) return;
        if (self.is_done) {
            self.rtv_heap.free(handle);
            return;
        }
        self.rtv_deletion_queue.add(handle);
    }

    fn deleteDSV(self: *Device, handle: DescriptorHeap.Handle) void {
        if (handle.isInvalid()) return;
        if (self.is_done) {
            self.dsv_heap.free(handle);
            return;
        }
        self.dsv_deletion_queue.add(handle);
    }

    fn deleteCBVSRVUAV(self: *Device, handle: DescriptorHeap.Handle) void {
        if (handle.isInvalid()) return;
        if (self.is_done) {
            self.resource_heap.free(handle);
            return;
        }
        self.cbv_srv_uav_deletion_queue.add(handle);
    }

    fn deleteSampler(self: *Device, handle: DescriptorHeap.Handle) void {
        if (handle.isInvalid()) return;
        if (self.is_done) {
            self.sampler_heap.free(handle);
            return;
        }
        self.sampler_deletion_queue.add(handle);
    }

    fn cleanupFully(self: *Device) void {
        for (0..gpu.backbuffer_count + 1) |_| {
            self.garbageCollect();
        }
    }

    fn garbageCollect(self: *Device) void {
        for (self.deletion_queue.nextBuffer()) |iunk| {
            _ = iunk.Release();
            // releaseFully(iunk);
        }

        for (self.allocation_deletion_queue.nextBuffer()) |allocation| {
            allocation.Release();
            // std.debug.print("Released allocation: {any}\n", .{allocation});
        }

        for (self.rtv_deletion_queue.nextBuffer()) |handle| {
            self.rtv_heap.free(handle);
        }

        for (self.dsv_deletion_queue.nextBuffer()) |handle| {
            self.dsv_heap.free(handle);
        }

        for (self.cbv_srv_uav_deletion_queue.nextBuffer()) |handle| {
            self.resource_heap.free(handle);
        }

        for (self.sampler_deletion_queue.nextBuffer()) |handle| {
            self.sampler_heap.free(handle);
        }
    }

    // non public stuff
    fn allocateConstant(self: *Device, data: []const u8) error{OutOfMemory}!d3d12.GPU_VIRTUAL_ADDRESS {
        const cb: *utils.LinearAllocatedBuffer = &self.constant_buffers[self.frame_idx % gpu.backbuffer_count];
        const address = try cb.alloc(@intCast(data.len));
        const cpu_address = address.cpu;
        @memcpy(cpu_address, data);
        return address.gpu.toInt();
    }

    fn bytesToMegabytes(bytes: u64) u64 {
        const as_float: f64 = @floatFromInt(bytes);
        const mb_float = as_float / 1024.0 / 1024.0;
        const mb_int: u64 = @intFromFloat(@trunc(mb_float));
        return mb_int;
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

    fn createRootSignature(self: *Device) !void {
        const slot_count = @typeInfo(gpu.ConstantSlot).@"enum".fields.len;
        var root_params: [slot_count]d3d12.ROOT_PARAMETER1 = undefined;
        root_params[0] = .{
            .ParameterType = .@"32BIT_CONSTANTS",
            .ShaderVisibility = .ALL,
            .u = .{
                .Constants = .{
                    .ShaderRegister = 0,
                    .RegisterSpace = 0,
                    .Num32BitValues = @divExact(gpu.max_root_constant_size_bytes, 4),
                },
            },
        };
        for (1..slot_count) |i| {
            root_params[i] = .{
                .ParameterType = .CBV,
                .ShaderVisibility = .ALL,
                .u = .{
                    .Descriptor = .{
                        .ShaderRegister = @intCast(i),
                        .RegisterSpace = 0,
                    },
                },
            };
        }

        const flags: d3d12.ROOT_SIGNATURE_FLAGS = .{
            .DENY_HULL_SHADER_ROOT_ACCESS = true,
            .DENY_DOMAIN_SHADER_ROOT_ACCESS = true,
            .DENY_GEOMETRY_SHADER_ROOT_ACCESS = true,
            .CBV_SRV_UAV_HEAP_DIRECTLY_INDEXED = true,
            .SAMPLER_HEAP_DIRECTLY_INDEXED = true,
        };

        const desc: d3d12.ROOT_SIGNATURE_DESC1 = .init(&root_params, &.{}, flags);
        const versioned_desc: d3d12.VERSIONED_ROOT_SIGNATURE_DESC = .{
            .Version = .VERSION_1_1,
            .u = .{
                .Desc_1_1 = desc,
            },
        };

        var signature: ?*d3dcommon.IBlob = null;
        var err: ?*d3dcommon.IBlob = null;
        defer {
            if (signature) |s| _ = s.iunknown.Release();
            if (err) |e| _ = e.iunknown.Release();
        }
        const hr_serialize = d3d12.SerializeVersionedRootSignature(&versioned_desc, &signature, &err);
        if (hr_serialize != win32.S_OK) {
            if (err) |e| {
                log.err("Failed to serialize root signature: {s}", .{e.getSlice()});
            } else {
                log.err("Failed to serialize root signature: unknown error", .{});
            }
            return error.Gpu;
        }

        const hr_create = self.device.idevice.CreateRootSignature(
            0,
            signature.?.GetBufferPointer(),
            signature.?.GetBufferSize(),
            win32.riid(d3d12.IRootSignature),
            @ptrCast(&self.root_signature),
        );
        if (hr_create != win32.S_OK) {
            log.err("Failed to create root signature: {f}", .{win32.fmtHresult(hr_create, .code_message)});
            return error.Gpu;
        }

        _ = self.root_signature.iobject.setNameUtf8("Global Root Signature") catch {};
    }
};

const DescriptorHeap = struct {
    pub const Handle = struct {
        cpu_handle: d3d12.CPU_DESCRIPTOR_HANDLE,
        gpu_handle: ?d3d12.GPU_DESCRIPTOR_HANDLE,
        allocation: OffsetAllocator.Allocation,

        pub const invalid: Handle = .{
            .cpu_handle = .{ .ptr = 0 },
            .gpu_handle = null,
            .allocation = .invalid,
        };

        fn isInvalid(self: *const Handle) bool {
            if (self.cpu_handle.ptr == 0) {
                return true;
            }
            return self.allocation.isInvalid();
        }
    };

    heap: *d3d12.IDescriptorHeap = undefined,
    heap_type: d3d12.DESCRIPTOR_HEAP_TYPE,
    offset_allocator: OffsetAllocator = undefined,
    base_cpu: d3d12.CPU_DESCRIPTOR_HANDLE = .{ .ptr = 0 },
    base_gpu: ?d3d12.GPU_DESCRIPTOR_HANDLE = null,
    descriptor_size: u32 = 0,
    shader_visible: bool,

    fn init(
        heap: *DescriptorHeap,
        allocator: std.mem.Allocator,
        device: *d3d12.IDevice,
        count: u32,
        name: []const u8,
    ) !void {
        const desc: d3d12.DESCRIPTOR_HEAP_DESC = .{
            .Type = heap.heap_type,
            .NumDescriptors = count,
            .Flags = .{
                .SHADER_VISIBLE = heap.shader_visible,
            },
            .NodeMask = 0,
        };

        const hr_create = device.CreateDescriptorHeap(
            &desc,
            win32.riid(d3d12.IDescriptorHeap),
            @ptrCast(&heap.heap),
        );
        if (hr_create != win32.S_OK) {
            log.err("Failed to create D3D12 descriptor heap: {f}", .{
                win32.fmtHresult(hr_create, .code_message),
            });
            return error.Gpu;
        }
        errdefer _ = heap.heap.iunknown.Release();
        _ = try heap.heap.iobject.setNameUtf8(name);

        heap.heap.GetCPUDescriptorHandleForHeapStart(&heap.base_cpu);

        if (heap.shader_visible) {
            var heap_gpu_start: d3d12.GPU_DESCRIPTOR_HANDLE = undefined;
            heap.heap.GetGPUDescriptorHandleForHeapStart(&heap_gpu_start);
            heap.base_gpu = heap_gpu_start;
        }
        heap.descriptor_size = device.GetDescriptorHandleIncrementSize(heap.heap_type);

        heap.offset_allocator = try .init(allocator, count, count);
    }

    fn deinit(heap: *DescriptorHeap, allocator: std.mem.Allocator) void {
        heap.offset_allocator.deinit(allocator);
        _ = heap.heap.iunknown.Release();
        heap.heap = undefined;
    }

    fn alloc(heap: *DescriptorHeap, count: u32) !Handle {
        const allocation = try heap.offset_allocator.allocate(count);
        return .{
            .cpu_handle = d3d12.CPU_DESCRIPTOR_HANDLE{
                .ptr = heap.base_cpu.ptr + allocation.offset * heap.descriptor_size,
            },
            .gpu_handle = if (heap.base_gpu) |base_gpu|
                .{
                    .ptr = base_gpu.ptr + allocation.offset * heap.descriptor_size,
                }
            else
                null,
            .allocation = allocation,
        };
    }

    fn free(heap: *DescriptorHeap, desc: Handle) void {
        heap.offset_allocator.free(desc.allocation) catch unreachable;
    }
};

const Buffer = struct {
    device: *Device,
    allocator: std.mem.Allocator,
    handle: *d3d12.IResource = undefined,
    allocation: ?*d3d12ma.Allocation = null,
    cpu_address: ?[*]u8 = null,

    desc: gpu.Buffer.Desc,

    fn init(self: *Buffer, device: *Device, allocator: std.mem.Allocator, desc: gpu.Buffer.Desc, name: []const u8) Error!void {
        self.* = .{
            .device = device,
            .allocator = allocator,
            .desc = desc,
        };

        const resource_desc: d3d12.RESOURCE_DESC1 = conv.bufferResourceDesc(&desc);
        const layout: d3d12.BARRIER_LAYOUT = if (desc.usage.shader_write) .UNORDERED_ACCESS else .UNDEFINED;

        var hr: win32.HRESULT = win32.S_OK;
        var allocation_desc: d3d12ma.ALLOCATION_DESC = .{};
        allocation_desc.HeapType = conv.heapType(desc.location);
        allocation_desc.Flags = d3d12ma._ALLOCATION_FLAG_COMMITTED;

        hr = device.mem_allocator.CreateResource3(
            &allocation_desc,
            &resource_desc,
            layout,
            null,
            0,
            null,
            &self.allocation,
            win32.riid(d3d12.IResource),
            @ptrCast(&self.handle),
        );

        if (hr != win32.S_OK) {
            log.err("Failed to create D3D12 buffer ({s}): {f}", .{ name, win32.fmtHresult(hr, .code_message) });
            return error.Gpu;
        }

        const hr_set_name = try self.handle.iobject.setNameUtf8(name);
        if (hr_set_name != win32.S_OK) {
            log.err("Failed to set buffer name: {f}", .{win32.fmtHresult(hr_set_name, .code_message)});
            return error.Gpu;
        }

        setAllocationName(self.allocation.?, name);

        if (self.desc.location != .gpu_only) {
            var mapped_ptr: ?[*]u8 = null;
            const hr_map = self.handle.Map(
                0,
                null,
                @ptrCast(&mapped_ptr),
            );
            if (hr_map != win32.S_OK) {
                log.err("Failed to map buffer ({s}): {f}", .{ name, win32.fmtHresult(hr_map, .code_message) });
                return error.Gpu;
            }
            self.cpu_address = mapped_ptr;
        }
    }

    fn deinit(self: *Buffer) void {
        self.device.deleteIUnknown(&self.handle.iunknown);
        if (self.allocation) |allocation| {
            self.device.deleteAllocation(allocation);
            self.allocation = null;
        }
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

    fn cpuAddress(self: *Buffer) ?[*]u8 {
        return self.cpu_address;
    }

    fn gpuAddress(self: *Buffer) gpu.Buffer.GpuAddress {
        return @enumFromInt(self.handle.GetGPUVirtualAddress());
    }

    fn requiredStagingSize(self: *const Buffer) usize {
        const desc = self.handle.GetDesc();

        var size: u64 = 0;
        self.device.device.idevice.GetCopyableFootprints(
            &desc,
            0,
            1,
            0,
            null,
            null,
            null,
            &size,
        );
        return @intCast(size);
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
    name_buf: [256]u8 = undefined,
    name: []const u8 = &.{},
    command_queue: *d3d12.ICommandQueue = undefined,
    command_allocator: *d3d12.ICommandAllocator = undefined,
    command_list: *d3d12.IGraphicsCommandList7 = undefined,

    current_pipeline_state: ?*d3d12.IPipelineState = null,

    texture_barriers: [max_barriers_store]d3d12.TEXTURE_BARRIER = undefined,
    texture_barriers_count: usize = 0,

    buffer_barriers: [max_barriers_store]d3d12.BUFFER_BARRIER = undefined,
    buffer_barriers_count: usize = 0,

    global_barriers: [max_barriers_store]d3d12.GLOBAL_BARRIER = undefined,
    global_barriers_count: usize = 0,

    pending_waits: [max_fence_operations]FenceValue = undefined,
    pending_waits_count: usize = 0,

    pending_signals: [max_fence_operations]FenceValue = undefined,
    pending_signals_count: usize = 0,

    pending_swapchains: [max_present_swapchains]*Swapchain = undefined,
    pending_swapchains_count: usize = 0,

    render_pass_render_targets: [8]d3d12.RENDER_PASS_RENDER_TARGET_DESC = undefined,
    render_pass_render_target_count: usize = 0,
    render_pass_depth_stencil: ?d3d12.RENDER_PASS_DEPTH_STENCIL_DESC = null,
    is_in_render_pass: bool = false,
    command_count: u64 = 0,

    is_open: bool = false,

    queue: gpu.Queue,

    fn init(self: *CommandList, device: *Device, allocator: std.mem.Allocator, command_queue: gpu.Queue, name: []const u8) Error!void {
        self.* = .{
            .allocator = allocator,
            .device = device,
            .command_queue = switch (command_queue) {
                .graphics => device.graphics_queue,
                .compute => device.compute_queue,
                .copy => device.copy_queue,
            },
            .queue = command_queue,
        };

        const name_len = @min(name.len, self.name_buf.len);
        @memcpy(self.name_buf[0..name_len], name[0..name_len]);
        const name_slice = self.name_buf[0..name_len];
        self.name = name_slice;

        const hr_create_command_allocator = device.device.idevice.CreateCommandAllocator(
            conv.commandType(command_queue),
            win32.riid(d3d12.ICommandAllocator),
            @ptrCast(&self.command_allocator),
        );
        if (hr_create_command_allocator != win32.S_OK) {
            log.err("Failed to create D3D12 command allocator ({s}): {f}", .{
                name,
                win32.fmtHresult(hr_create_command_allocator, .code_message),
            });
            return error.Gpu;
        }

        var buf: [256]u8 = undefined;
        const command_allocator_name: []const u8 = std.fmt.bufPrint(&buf, "{s} allocator", .{name}) catch name;
        const hr_set_command_allocator_name = self.command_allocator.iobject.setNameUtf8(command_allocator_name) catch unreachable;
        if (hr_set_command_allocator_name != win32.S_OK) {
            log.err("Failed to set command allocator name: {f}", .{
                win32.fmtHresult(hr_set_command_allocator_name, .code_message),
            });
        }

        const hr_create_command_list = device.device.idevice.CreateCommandList(
            0,
            conv.commandType(command_queue),
            self.command_allocator,
            null,
            win32.riid(d3d12.IGraphicsCommandList7),
            @ptrCast(&self.command_list),
        );
        if (hr_create_command_list != win32.S_OK) {
            log.err("Failed to create D3D12 command list ({s}): {f}", .{
                name,
                win32.fmtHresult(hr_create_command_list, .code_message),
            });
            return error.Gpu;
        }
        const hr_set_command_list_name = try self.command_list.iobject.setNameUtf8(name);
        if (hr_set_command_list_name != win32.S_OK) {
            log.err("Failed to set command list name: {f}", .{
                win32.fmtHresult(hr_set_command_list_name, .code_message),
            });
        }

        _ = self.command_list.igraphicscommandlist.Close();
    }

    fn deinit(self: *CommandList) void {
        self.device.deleteIUnknown(&self.command_allocator.iunknown);
        self.device.deleteIUnknown(&self.command_list.iunknown);
    }

    fn fromGpuCommandList(command_list: *gpu.CommandList) *CommandList {
        return @ptrCast(@alignCast(command_list));
    }

    fn toGpuCommandList(command_list: *CommandList) *gpu.CommandList {
        return @ptrCast(@alignCast(command_list));
    }

    fn resetAllocator(self: *CommandList) void {
        if (self.is_open) {
            log.err("Cannot reset command allocator while command list is open ({s})", .{self.name});
            self.end() catch {};
        }
        const hr = self.command_allocator.Reset();
        if (hr != win32.S_OK) {
            log.err("Failed to reset command allocator ({s}): {f}", .{
                self.name,
                win32.fmtHresult(hr, .code_message),
            });
        }
    }

    fn begin(self: *CommandList) Error!void {
        const hr_reset = self.command_list.igraphicscommandlist.Reset(self.command_allocator, null);
        if (hr_reset != win32.S_OK) {
            log.err("Failed to reset command list: {f}", .{win32.fmtHresult(hr_reset, .code_message)});
            return error.Gpu;
        }
        self.is_open = true;

        const hr_set_name = try self.command_list.iobject.setNameUtf8(self.name);
        if (hr_set_name != win32.S_OK) {
            log.err("Failed to set command list name: {f}", .{win32.fmtHresult(hr_set_name, .code_message)});
            return error.Gpu;
        }

        self.resetState();
        return;
    }

    fn end(self: *CommandList) Error!void {
        self.flushBarriers();

        const hr_close = self.command_list.igraphicscommandlist.Close();
        if (hr_close != win32.S_OK) {
            log.err("Failed to close command list: {f}", .{win32.fmtHresult(hr_close, .code_message)});
            return error.Gpu;
        }
        self.is_open = false;
        return;
    }

    fn wait(self: *CommandList, fence: *Fence, value: u64) void {
        if (self.pending_waits_count >= max_fence_operations) {
            log.err("Exceeded maximum pending fence waits in command list ({s})", .{self.name});
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
            log.err("Exceeded maximum pending fence signals in command list ({s})", .{self.name});
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
            log.err("Exceeded maximum pending swapchains in command list ({s})", .{self.name});
            return;
        }
        self.pending_swapchains[self.pending_swapchains_count] = swapchain;
        self.pending_swapchains_count += 1;
        return;
    }

    fn submit(self: *CommandList) Error!void {
        for (self.pending_waits[0..self.pending_waits_count]) |fence_value| {
            _ = self.command_queue.Wait(fence_value.fence.handle, fence_value.value);
        }
        self.pending_waits_count = 0;

        if (self.command_count > 0) {
            const command_lists: [1]*d3d12.ICommandList = .{&self.command_list.icommandlist};
            self.command_queue.ExecuteCommandLists(1, &command_lists);
            self.command_count = 0;
        }

        for (self.pending_swapchains[0..self.pending_swapchains_count]) |swapchain| {
            try swapchain.present();
        }
        self.pending_swapchains_count = 0;

        for (self.pending_signals[0..self.pending_signals_count]) |fence_value| {
            const hr_signal = self.command_queue.Signal(fence_value.fence.handle, fence_value.value);
            if (hr_signal != win32.S_OK) {
                log.err("Failed to signal fence: {f}", .{
                    win32.fmtHresult(hr_signal, .code_message),
                });
            }
        }
        self.pending_signals_count = 0;
    }

    fn resetState(self: *CommandList) void {
        self.texture_barriers_count = 0;
        self.buffer_barriers_count = 0;
        self.global_barriers_count = 0;
        self.pending_waits_count = 0;
        self.pending_signals_count = 0;
        self.pending_swapchains_count = 0;
        self.is_in_render_pass = false;
        self.command_count = 0;
        self.current_pipeline_state = null;

        if (self.queue == .graphics or self.queue == .compute) {
            // Set a default descriptor heap to avoid validation errors
            const heaps: [2]*d3d12.IDescriptorHeap = .{ self.device.resource_heap.heap, self.device.sampler_heap.heap };
            self.command_list.igraphicscommandlist.SetDescriptorHeaps(2, &heaps);

            self.command_list.igraphicscommandlist.SetComputeRootSignature(self.device.root_signature);
            if (self.queue == .graphics) {
                self.command_list.igraphicscommandlist.SetGraphicsRootSignature(self.device.root_signature);
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
            log.err("Exceeded maximum texture barriers in command list ({s})", .{self.name});
            return;
        }

        const barrier: d3d12.TEXTURE_BARRIER = .{
            .SyncBefore = conv.barrierSync(before),
            .SyncAfter = conv.barrierSync(after),
            .AccessBefore = conv.barrierAccess(before),
            .AccessAfter = conv.barrierAccess(after),
            .LayoutBefore = conv.barrierLayout(before),
            .LayoutAfter = conv.barrierLayout(after),
            .pResource = texture.handle.?,
            .Subresources = .{
                .IndexOrFirstMipLevel = subresource,
                .NumMipLevels = 0,
                .FirstArraySlice = 0,
                .NumArraySlices = 0,
                .FirstPlane = 0,
                .NumPlanes = 0,
            },
            .Flags = .{
                .DISCARD = before.discard,
            },
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
            log.err("Exceeded maximum buffer barriers in command list ({s})", .{self.name});
            return;
        }

        const barrier: d3d12.BUFFER_BARRIER = .{
            .SyncBefore = conv.barrierSync(before),
            .SyncAfter = conv.barrierSync(after),
            .AccessBefore = conv.barrierAccess(before),
            .AccessAfter = conv.barrierAccess(after),
            .pResource = buffer.handle,
            .Offset = 0,
            .Size = std.math.maxInt(u64),
        };

        self.buffer_barriers[self.buffer_barriers_count] = barrier;
        self.buffer_barriers_count += 1;
    }

    fn globalBarrier(
        self: *CommandList,
        before: gpu.Access,
        after: gpu.Access,
    ) void {
        if (self.global_barriers_count >= max_barriers_store) {
            log.err("Exceeded maximum global barriers in command list ({s})", .{self.name});
            return;
        }

        const barrier: d3d12.GLOBAL_BARRIER = .{
            .SyncBefore = conv.barrierSync(before),
            .SyncAfter = conv.barrierSync(after),
            .AccessBefore = conv.barrierAccess(before),
            .AccessAfter = conv.barrierAccess(after),
        };

        self.global_barriers[self.global_barriers_count] = barrier;
        self.global_barriers_count += 1;
    }

    fn flushBarriers(self: *CommandList) void {
        var barrier_groups: [3]d3d12.BARRIER_GROUP = undefined;
        var barrier_group_count: usize = 0;

        if (self.texture_barriers_count > 0) {
            barrier_groups[barrier_group_count] = .{
                .Type = .TEXTURE,
                .NumBarriers = @intCast(self.texture_barriers_count),
                .u = .{
                    .pTextureBarriers = &self.texture_barriers,
                },
            };
            barrier_group_count += 1;
        }

        if (self.buffer_barriers_count > 0) {
            barrier_groups[barrier_group_count] = .{
                .Type = .BUFFER,
                .NumBarriers = @intCast(self.buffer_barriers_count),
                .u = .{
                    .pBufferBarriers = &self.buffer_barriers,
                },
            };
            barrier_group_count += 1;
        }

        if (self.global_barriers_count > 0) {
            barrier_groups[barrier_group_count] = .{
                .Type = .GLOBAL,
                .NumBarriers = @intCast(self.global_barriers_count),
                .u = .{
                    .pGlobalBarriers = &self.global_barriers,
                },
            };
            barrier_group_count += 1;
        }

        if (barrier_group_count > 0) {
            self.command_list.Barrier(
                @intCast(barrier_group_count),
                &barrier_groups,
            );
            self.texture_barriers_count = 0;
            self.buffer_barriers_count = 0;
            self.global_barriers_count = 0;
        }
    }

    // shared stuff
    fn bindPipeline(self: *CommandList, pipeline: *Pipeline) void {
        if (self.current_pipeline_state == pipeline.handle) {
            return;
        }
        self.current_pipeline_state = pipeline.handle;
        self.command_list.igraphicscommandlist.SetPipelineState(pipeline.handle);
        if (pipeline.topology) |topology| {
            self.command_list.igraphicscommandlist.IASetPrimitiveTopology(topology);
        }
    }

    fn setComputeConstants(self: *CommandList, slot: gpu.ConstantSlot, data: []const u8) void {
        const buffer_slot: u32 = switch (slot) {
            .root => {
                const count_constants = @divFloor(data.len, 4) + 1;
                std.debug.assert(data.len <= gpu.max_root_constant_size_bytes);
                self.command_list.igraphicscommandlist.SetComputeRoot32BitConstants(
                    0,
                    @intCast(count_constants),
                    @ptrCast(data.ptr),
                    0,
                );
                return;
            },
            .buffer1 => 1,
            .buffer2 => 2,
        };

        const address = self.device.allocateConstant(data) catch {
            log.err("Failed to allocate constant buffer for compute root constants ({s})", .{self.name});
            return;
        };
        self.command_list.igraphicscommandlist.SetComputeRootConstantBufferView(
            buffer_slot,
            address,
        );
    }

    fn setGraphicsConstants(self: *CommandList, slot: gpu.ConstantSlot, data: []const u8) void {
        const buffer_slot: u32 = switch (slot) {
            .root => {
                const count_constants = @divFloor(data.len, 4) + 1;
                std.debug.assert(data.len <= gpu.max_root_constant_size_bytes);
                self.command_list.igraphicscommandlist.SetGraphicsRoot32BitConstants(
                    0,
                    @intCast(count_constants),
                    @ptrCast(data.ptr),
                    0,
                );
                return;
            },
            .buffer1 => 1,
            .buffer2 => 2,
        };

        const address = self.device.allocateConstant(data) catch {
            log.err("Failed to allocate constant buffer for graphics root constants ({s})", .{self.name});
            return;
        };
        self.command_list.igraphicscommandlist.SetGraphicsRootConstantBufferView(
            buffer_slot,
            address,
        );
    }

    // render pass
    fn beginRenderPass(self: *CommandList, desc: gpu.RenderPass.Desc) void {
        self.flushBarriers();
        var rt_descs: [8]d3d12.RENDER_PASS_RENDER_TARGET_DESC = undefined;
        var ds_desc: d3d12.RENDER_PASS_DEPTH_STENCIL_DESC = undefined;

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
                .cpuDescriptor = texture.getRTV(
                    attachment.texture.mip_level,
                    attachment.texture.depth_or_array_layer,
                ),
                .BeginningAccess = .{
                    .Type = conv.renderPassBeginningAccessTypeColor(attachment.load),
                    .u = .{ .Clear = .{
                        .ClearValue = .{
                            .Format = conv.dxgiFormat(texture.desc.format, .{}),
                            .u = .{ .Color = switch (attachment.load) {
                                .clear => |c| c,
                                else => .{ 0.0, 0.0, 0.0, 0.0 },
                            } },
                        },
                    } },
                },
                .EndingAccess = .{
                    .Type = conv.renderPassEndingAccessType(attachment.store),
                    .u = undefined,
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

            ds_desc.cpuDescriptor = texture.getDSV(
                ds_attachment.texture.mip_level,
                ds_attachment.texture.depth_or_array_layer,
            );

            ds_desc.DepthBeginningAccess = .{
                .Type = conv.renderPassBeginningAccessTypeDepth(ds_attachment.depth_load),
                .u = .{ .Clear = .{
                    .ClearValue = .{
                        .Format = conv.dxgiFormat(texture.desc.format, .{}),
                        .u = .{ .DepthStencil = switch (ds_attachment.depth_load) {
                            .clear => |c| .{
                                .Depth = c,
                                .Stencil = 0,
                            },
                            else => .{ .Depth = 0.0, .Stencil = 0 },
                        } },
                    },
                } },
            };
            ds_desc.DepthEndingAccess = .{
                .Type = conv.renderPassEndingAccessType(ds_attachment.depth_store),
                .u = undefined,
            };

            if (texture.desc.format.isStencilFormat()) {
                ds_desc.StencilBeginningAccess = .{
                    .Type = conv.renderPassBeginningAccessTypeStencil(ds_attachment.stencil_load),
                    .u = .{ .Clear = .{
                        .ClearValue = .{
                            .Format = conv.dxgiFormat(texture.desc.format, .{}),
                            .u = .{ .DepthStencil = switch (ds_attachment.stencil_load) {
                                .clear => |c| .{
                                    .Depth = 0.0,
                                    .Stencil = @as(u8, c),
                                },
                                else => .{ .Depth = 0.0, .Stencil = 0 },
                            } },
                        },
                    } },
                };
                ds_desc.StencilEndingAccess = .{
                    .Type = conv.renderPassEndingAccessType(ds_attachment.stencil_store),
                    .u = undefined,
                };
            } else {
                ds_desc.StencilBeginningAccess = .{
                    .Type = .NO_ACCESS,
                    .u = undefined,
                };
                ds_desc.StencilEndingAccess = .{
                    .Type = .NO_ACCESS,
                    .u = undefined,
                };
            }
        }

        var rt_descriptors: [8]d3d12.CPU_DESCRIPTOR_HANDLE = undefined;
        for (rt_descs[0..rt_count], self.render_pass_render_targets[0..rt_count], rt_descriptors[0..rt_count]) |rt_desc, *desc_rt, *descriptor| {
            std.debug.assert(rt_desc.cpuDescriptor.ptr != 0);
            if (rt_desc.BeginningAccess.Type == .CLEAR) {
                self.command_list.igraphicscommandlist.ClearRenderTargetView(
                    rt_desc.cpuDescriptor,
                    &rt_desc.BeginningAccess.u.Clear.ClearValue.u.Color,
                    0,
                    null,
                );
            }
            desc_rt.* = rt_desc;
            descriptor.* = rt_desc.cpuDescriptor;
        }
        self.render_pass_render_target_count = rt_count;

        if (desc.depth_stencil_attachment) |_| {
            std.debug.assert(ds_desc.cpuDescriptor.ptr != 0);
            var flags: d3d12.CLEAR_FLAGS = .{};
            if (ds_desc.DepthBeginningAccess.Type == .CLEAR) {
                flags.DEPTH = true;
            }
            if (ds_desc.StencilBeginningAccess.Type == .CLEAR) {
                flags.STENCIL = true;
            }

            if (flags.DEPTH or flags.STENCIL) {
                self.command_list.igraphicscommandlist.ClearDepthStencilView(
                    ds_desc.cpuDescriptor,
                    flags,
                    ds_desc.DepthBeginningAccess.u.Clear.ClearValue.u.DepthStencil.Depth,
                    ds_desc.StencilBeginningAccess.u.Clear.ClearValue.u.DepthStencil.Stencil,
                    0,
                    null,
                );
            }
            self.render_pass_depth_stencil = ds_desc;
        }

        self.command_list.igraphicscommandlist.OMSetRenderTargets(
            @intCast(rt_count),
            &rt_descriptors,
            .FALSE,
            if (desc.depth_stencil_attachment) |_| &self.render_pass_depth_stencil.?.cpuDescriptor else null,
        );

        // self.command_list.igraphicscommandlist4.BeginRenderPass(
        //     @intCast(rt_count),
        //     &rt_descs,
        //     if (desc.depth_stencil_attachment) |_| &ds_desc else null,
        //     .{},
        // );
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
            log.err("Cannot end render pass when not in a render pass ({s})", .{self.name});
            return;
        }

        // self.command_list.igraphicscommandlist4.EndRenderPass();
        self.command_list.igraphicscommandlist.OMSetRenderTargets(0, null, .FALSE, null);

        self.is_in_render_pass = false;

        self.command_count += 1;
        return;
    }

    fn setViewports(self: *CommandList, viewports: []const spatial.Viewport) void {
        var d3d_viewports: [16]d3d12.VIEWPORT = undefined;
        const count = @min(viewports.len, d3d_viewports.len);

        for (viewports[0..count], 0..) |viewport, i| {
            d3d_viewports[i] = .{
                .TopLeftX = viewport.x,
                .TopLeftY = viewport.y,
                .Width = viewport.width,
                .Height = viewport.height,
                .MinDepth = viewport.min_depth,
                .MaxDepth = viewport.max_depth,
            };
        }

        self.command_list.igraphicscommandlist.RSSetViewports(@intCast(count), &d3d_viewports);
    }

    fn setScissors(self: *CommandList, rects: []const spatial.Rect) void {
        var d3d_rects: [16]d3d12.RECT = undefined;
        const count = @min(rects.len, d3d_rects.len);

        for (rects[0..count], 0..) |rect, i| {
            d3d_rects[i] = .{
                .left = @intCast(rect.x),
                .top = @intCast(rect.y),
                .right = @intCast(rect.x + @as(i32, @intCast(rect.width))),
                .bottom = @intCast(rect.y + @as(i32, @intCast(rect.height))),
            };
        }

        self.command_list.igraphicscommandlist.RSSetScissorRects(@intCast(count), &d3d_rects);
    }

    fn setBlendConstants(self: *CommandList, constants: [4]f32) void {
        self.command_list.igraphicscommandlist.OMSetBlendFactor(&constants);
    }

    fn setStencilReference(self: *CommandList, reference: u32) void {
        self.command_list.igraphicscommandlist.OMSetStencilRef(reference);
    }

    fn bindIndexBuffer(self: *CommandList, region: gpu.Buffer.Slice, index_element: gpu.IndexFormat) void {
        const buffer: *Buffer = .fromGpuBuffer(region.buffer);
        const address = buffer.gpuAddress().toInt();
        const view: d3d12.INDEX_BUFFER_VIEW = .{
            .BufferLocation = address + region.offset,
            .SizeInBytes = @intCast(region.size.toInt() orelse (buffer.desc.size - region.offset)),
            .Format = switch (index_element) {
                .uint32 => .R32_UINT,
                .uint16 => .R16_UINT,
            },
        };
        self.command_list.igraphicscommandlist.IASetIndexBuffer(&view);
    }

    fn draw(self: *CommandList, vertex_count: u32, instance_count: u32, start_vertex: u32, start_instance: u32) void {
        self.command_list.igraphicscommandlist.DrawInstanced(
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
        self.command_list.igraphicscommandlist.DrawIndexedInstanced(
            index_count,
            instance_count,
            start_index,
            base_vertex,
            start_instance,
        );
        self.command_count += 1;
    }

    fn drawIndirect(self: *CommandList, buffer: gpu.Buffer.Slice, draw_count: u32) void {
        _ = self;
        _ = buffer;
        _ = draw_count;
        @panic("TODO: Not implemented yet, implement draw signature");
    }

    fn drawIndexedIndirect(self: *CommandList, buffer: gpu.Buffer.Slice, draw_count: u32) void {
        _ = self;
        _ = buffer;
        _ = draw_count;
        @panic("TODO: Not implemented yet, implement draw indexed signature");
    }

    fn multiDrawIndirect(self: *CommandList, buffer: gpu.Buffer.Slice, count: gpu.Buffer.Location) void {
        _ = self;
        _ = buffer;
        _ = count;
        @panic("TODO: Not implemented yet, implement multi draw signature");
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

        self.command_list.igraphicscommandlist.Dispatch(workgroup_x, workgroup_y, workgroup_z);
        self.command_count += 1;
    }

    fn dispatchIndirect(self: *CommandList, buffer: gpu.Buffer.Slice) void {
        self.flushBarriers();

        _ = buffer;
        @panic("TODO: Not implemented yet, implement dispatch indirect signature");
    }

    // copy
    fn writeBuffer(self: *CommandList, buffer: *Buffer, offset: u32, data: u32) void {
        self.flushBarriers();

        const param: d3d12.WRITEBUFFERIMMEDIATE_PARAMETER = .{
            .Dest = buffer.gpuAddress().toInt() + offset,
            .Value = data,
        };
        self.command_list.igraphicscommandlist2.WriteBufferImmediate(1, @ptrCast(&param), null);
        self.command_count += 1;
    }

    fn copyBufferToTexture(self: *CommandList, source: gpu.Buffer.Location, destination: gpu.Texture.Slice) void {
        self.flushBarriers();

        const dst_texture: *Texture = .fromGpuTexture(destination.texture);
        const src_buffer: *Buffer = .fromGpuBuffer(source.buffer);
        const desc = dst_texture.desc;

        const min_width = desc.format.getBlockWidth();
        const min_height = desc.format.getBlockHeight();
        const width = @max(desc.width >> @as(u5, @intCast(destination.mip_level)), min_width);
        const height = @max(desc.height >> @as(u5, @intCast(destination.mip_level)), min_height);
        const depth = @max(desc.depth_or_array_layers >> @as(u5, @intCast(destination.mip_level)), 1);

        const dst: d3d12.TEXTURE_COPY_LOCATION = .{
            .pResource = dst_texture.handle.?,
            .Type = .SUBRESOURCE_INDEX,
            .u = .{
                .SubresourceIndex = desc.calcSubresource(
                    destination.mip_level,
                    destination.depth_or_array_layer,
                ),
            },
        };

        const src: d3d12.TEXTURE_COPY_LOCATION = .{
            .pResource = src_buffer.handle,
            .Type = .PLACED_FOOTPRINT,
            .u = .{
                .PlacedFootprint = .{
                    .Offset = source.offset,
                    .Footprint = .{
                        .Format = conv.dxgiFormat(desc.format, .{}),
                        .Width = width,
                        .Height = height,
                        .Depth = depth,
                        .RowPitch = @intCast(dst_texture.getRowPitch(destination.mip_level)),
                    },
                },
            },
        };

        self.command_list.igraphicscommandlist.CopyTextureRegion(
            &dst,
            0,
            0,
            0,
            &src,
            null,
        );
        self.command_count += 1;
    }

    fn copyTextureToBuffer(self: *CommandList, source: gpu.Texture.Slice, destination: gpu.Buffer.Location) void {
        self.flushBarriers();

        const src_texture: *Texture = .fromGpuTexture(source.texture);
        const dst_buffer: *Buffer = .fromGpuBuffer(destination.buffer);
        const desc = src_texture.desc;

        const min_width = desc.format.getBlockWidth();
        const min_height = desc.format.getBlockHeight();
        const width = @max(desc.width >> @as(u5, @intCast(source.mip_level)), min_width);
        const height = @max(desc.height >> @as(u5, @intCast(source.mip_level)), min_height);
        const depth = @max(desc.depth_or_array_layers >> @as(u5, @intCast(source.mip_level)), 1);

        const src: d3d12.TEXTURE_COPY_LOCATION = .{
            .pResource = src_texture.handle.?,
            .Type = .SUBRESOURCE_INDEX,
            .u = .{
                .SubresourceIndex = desc.calcSubresource(
                    source.mip_level,
                    source.depth_or_array_layer,
                ),
            },
        };

        const dst: d3d12.TEXTURE_COPY_LOCATION = .{
            .pResource = dst_buffer.handle,
            .Type = .PLACED_FOOTPRINT,
            .u = .{
                .PlacedFootprint = .{
                    .Offset = destination.offset,
                    .Footprint = .{
                        .Format = conv.dxgiFormat(desc.format, .{}),
                        .Width = width,
                        .Height = height,
                        .Depth = depth,
                        .RowPitch = @intCast(src_texture.getRowPitch(source.mip_level)),
                    },
                },
            },
        };

        self.command_list.igraphicscommandlist.CopyTextureRegion(
            &dst,
            0,
            0,
            0,
            &src,
            null,
        );
        self.command_count += 1;
    }

    fn copyTextureToTexture(self: *CommandList, source: gpu.Texture.Slice, destination: gpu.Texture.Slice) void {
        self.flushBarriers();

        const src_texture: *Texture = .fromGpuTexture(source.texture);
        const dst_texture: *Texture = .fromGpuTexture(destination.texture);

        const dst: d3d12.TEXTURE_COPY_LOCATION = .{
            .pResource = dst_texture.handle.?,
            .Type = .SUBRESOURCE_INDEX,
            .u = .{
                .SubresourceIndex = dst_texture.desc.calcSubresource(
                    destination.mip_level,
                    destination.depth_or_array_layer,
                ),
            },
        };

        const src: d3d12.TEXTURE_COPY_LOCATION = .{
            .pResource = src_texture.handle.?,
            .Type = .SUBRESOURCE_INDEX,
            .u = .{
                .SubresourceIndex = src_texture.desc.calcSubresource(
                    source.mip_level,
                    source.depth_or_array_layer,
                ),
            },
        };

        self.command_list.igraphicscommandlist.CopyTextureRegion(
            &dst,
            0,
            0,
            0,
            &src,
            null,
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

        self.command_list.igraphicscommandlist.CopyBufferRegion(
            dst_buffer.handle,
            destination.offset,
            src_buffer.handle,
            source.offset,
            copy_size,
        );
        self.command_count += 1;
    }
};

const Descriptor = struct {
    device: *Device,
    allocator: std.mem.Allocator = undefined,
    /// will be null if this is a sampler
    resource: ?*d3d12.IResource = null,
    range_type: d3d12.DESCRIPTOR_RANGE_TYPE = .CBV,
    descriptor: DescriptorHeap.Handle = .invalid,

    kind: gpu.Descriptor.Kind,

    fn init(self: *Descriptor, device: *Device, desc: gpu.Descriptor.Desc, name: []const u8) !void {
        _ = name;

        self.* = .{
            .device = device,
            .kind = desc.kind,
        };

        var srv_desc: d3d12.SHADER_RESOURCE_VIEW_DESC = undefined;
        srv_desc.Shader4ComponentMapping = d3d12.DEFAULT_SHADER_4_COMPONENT_MAPPING;
        var uav_desc: d3d12.UNORDERED_ACCESS_VIEW_DESC = undefined;
        var cbv_desc: d3d12.CONSTANT_BUFFER_VIEW_DESC = undefined;
        var sampler_desc: d3d12.SAMPLER_DESC = undefined;

        var kind: d3d12.DESCRIPTOR_RANGE_TYPE = undefined;

        self.resource = null;

        switch (desc.kind) {
            .shader_read_texture_2d => {
                const texture: *Texture = .fromGpuTexture(desc.resource.texture.texture);
                const tex_desc = texture.desc;

                self.resource = texture.handle;
                srv_desc.Format = conv.dxgiFormat(
                    desc.format,
                    .{ .depth_srv = tex_desc.usage.depth_stencil },
                );
                srv_desc.ViewDimension = .TEXTURE2D;
                srv_desc.u.Texture2D = .{
                    .MostDetailedMip = desc.resource.texture.mip_level,
                    .MipLevels = tex_desc.mip_levels,
                    .PlaneSlice = desc.resource.texture.depth_or_array_layer,
                    .ResourceMinLODClamp = 0.0,
                };
                kind = .SRV;
            },
            .shader_read_texture_2d_array => {
                const texture: *Texture = .fromGpuTexture(desc.resource.texture.texture);
                const tex_desc = texture.desc;

                self.resource = texture.handle;
                srv_desc.Format = conv.dxgiFormat(
                    desc.format,
                    .{ .depth_srv = tex_desc.usage.depth_stencil },
                );
                srv_desc.ViewDimension = .TEXTURE2DARRAY;
                srv_desc.u.Texture2DArray = .{
                    .MostDetailedMip = desc.resource.texture.mip_level,
                    .MipLevels = desc.resource.texture.mip_level_count,
                    .FirstArraySlice = desc.resource.texture.depth_or_array_layer,
                    .ArraySize = desc.resource.texture.depth_or_array_layer_count,
                    .PlaneSlice = desc.resource.texture.plane,
                    .ResourceMinLODClamp = 0.0,
                };
                kind = .SRV;
            },
            .shader_read_texture_cube => {
                const texture: *Texture = .fromGpuTexture(desc.resource.texture.texture);
                const tex_desc = texture.desc;

                self.resource = texture.handle;
                srv_desc.Format = conv.dxgiFormat(desc.format, .{});
                srv_desc.ViewDimension = .TEXTURECUBE;
                srv_desc.u.TextureCube = .{
                    .MostDetailedMip = desc.resource.texture.mip_level,
                    .MipLevels = tex_desc.mip_levels,
                    .ResourceMinLODClamp = 0.0,
                };
                kind = .SRV;
            },
            .shader_read_texture_3d => {
                const texture: *Texture = .fromGpuTexture(desc.resource.texture.texture);
                const tex_desc = texture.desc;

                self.resource = texture.handle;
                srv_desc.Format = conv.dxgiFormat(desc.format, .{});
                srv_desc.ViewDimension = .TEXTURE3D;
                srv_desc.u.Texture3D = .{
                    .MostDetailedMip = desc.resource.texture.mip_level,
                    .MipLevels = tex_desc.mip_levels,
                    .ResourceMinLODClamp = 0.0,
                };
                kind = .SRV;
            },
            .shader_read_buffer => {
                const buffer: *Buffer = .fromGpuBuffer(desc.resource.buffer.buffer);
                self.resource = buffer.handle;

                const buffer_desc = buffer.desc;

                const computed_size = desc.resource.buffer.size.toInt() orelse
                    buffer_desc.size - desc.resource.buffer.offset;

                // std.debug.assert(desc.format == .unknown);
                std.debug.assert(desc.resource.buffer.offset % 4 == 0);
                std.debug.assert(computed_size % 4 == 0);

                srv_desc.Format = .R32_TYPELESS;
                srv_desc.ViewDimension = .BUFFER;
                srv_desc.u.Buffer = .{
                    .FirstElement = desc.resource.buffer.offset / 4,
                    .NumElements = @intCast(computed_size / 4),
                    .StructureByteStride = 0,
                    .Flags = .{ .RAW = true },
                };
                kind = .SRV;
            },
            .shader_read_top_level_acceleration_structure => {
                kind = .SRV;
                @panic("TODO");
            },

            .shader_write_texture_2d => {
                const texture: *Texture = .fromGpuTexture(desc.resource.texture.texture);
                const tex_desc = texture.desc;
                std.debug.assert(tex_desc.usage.shader_write);
                self.resource = texture.handle;
                uav_desc.Format = conv.dxgiFormat(desc.format, .{ .uav = true });
                uav_desc.ViewDimension = .TEXTURE2D;
                uav_desc.u.Texture2D = .{
                    .MipSlice = desc.resource.texture.mip_level,
                    .PlaneSlice = desc.resource.texture.depth_or_array_layer,
                };
                kind = .UAV;
            },
            .shader_write_texture_2d_array => {
                const texture: *Texture = .fromGpuTexture(desc.resource.texture.texture);
                const tex_desc = texture.desc;
                std.debug.assert(tex_desc.usage.shader_write);
                self.resource = texture.handle;
                uav_desc.Format = conv.dxgiFormat(desc.format, .{ .uav = true });
                uav_desc.ViewDimension = .TEXTURE2DARRAY;
                uav_desc.u.Texture2DArray = .{
                    .MipSlice = desc.resource.texture.mip_level,
                    .FirstArraySlice = desc.resource.texture.depth_or_array_layer,
                    .ArraySize = desc.resource.texture.depth_or_array_layer_count,
                    .PlaneSlice = desc.resource.texture.plane,
                };
                kind = .UAV;
            },
            .shader_write_texture_3d => {
                const texture: *Texture = .fromGpuTexture(desc.resource.texture.texture);
                const tex_desc = texture.desc;
                std.debug.assert(tex_desc.usage.shader_write);
                self.resource = texture.handle;
                uav_desc.Format = conv.dxgiFormat(desc.format, .{ .uav = true });
                uav_desc.ViewDimension = .TEXTURE3D;
                uav_desc.u.Texture3D = .{
                    .MipSlice = desc.resource.texture.mip_level,
                    .FirstWSlice = 0,
                    .WSize = tex_desc.depth_or_array_layers,
                };
                kind = .UAV;
            },
            .shader_write_buffer => {
                const buffer: *Buffer = .fromGpuBuffer(desc.resource.buffer.buffer);
                self.resource = buffer.handle;

                const buffer_desc = buffer.desc;

                std.debug.assert(buffer_desc.usage.shader_write);

                const computed_size = desc.resource.buffer.size.toInt() orelse
                    buffer_desc.size - desc.resource.buffer.offset;

                // std.debug.assert(desc.format == .unknown);
                std.debug.assert(desc.resource.buffer.offset % 4 == 0);
                std.debug.assert(computed_size % 4 == 0);

                uav_desc.Format = .R32_TYPELESS;
                uav_desc.ViewDimension = .BUFFER;
                uav_desc.u.Buffer = .{
                    .FirstElement = desc.resource.buffer.offset / 4,
                    .NumElements = @intCast(computed_size / 4),
                    .StructureByteStride = 0,
                    .CounterOffsetInBytes = 0,
                    .Flags = .{ .RAW = true },
                };
                kind = .UAV;
            },

            .constant_buffer => {
                const buffer: *Buffer = .fromGpuBuffer(desc.resource.buffer.buffer);
                self.resource = buffer.handle;

                const buffer_desc = buffer.desc;

                const computed_size = desc.resource.buffer.size.toInt() orelse
                    buffer_desc.size - desc.resource.buffer.offset;

                std.debug.assert(desc.format == .unknown);
                std.debug.assert(computed_size % 256 == 0);

                cbv_desc.BufferLocation = buffer.handle.GetGPUVirtualAddress() + desc.resource.buffer.offset;
                cbv_desc.SizeInBytes = @intCast(computed_size);
                kind = .CBV;
            },
            .sampler => {
                const sampler_info = desc.resource.sampler;
                const use_anisotropy = sampler_info.anisotropy > 1;
                const use_comparison = sampler_info.compare_op != .never;
                const anisotropy_filter: d3d12.FILTER = filter: {
                    if (sampler_info.filters.ext == .min) break :filter .MINIMUM_ANISOTROPIC;
                    if (sampler_info.filters.ext == .max) break :filter .MAXIMUM_ANISOTROPIC;
                    if (use_comparison) break :filter .COMPARISON_ANISOTROPIC;
                    break :filter .ANISOTROPIC;
                };
                const isotropy_filter: d3d12.FILTER = filter: {
                    var mask: std.os.windows.UINT = 0;
                    if (sampler_info.filters.mip == .nearest) mask |= 0x1;
                    if (sampler_info.filters.mag == .linear) mask |= 0x4;
                    if (sampler_info.filters.min == .linear) mask |= 0x10;

                    if (use_comparison)
                        mask |= 0x80
                    else if (sampler_info.filters.ext == .min)
                        mask |= 0x100
                    else if (sampler_info.filters.ext == .max)
                        mask |= 0x180;

                    break :filter @enumFromInt(mask);
                };
                const filter = if (use_anisotropy) anisotropy_filter else isotropy_filter;

                sampler_desc = .{
                    .Filter = filter,
                    .AddressU = conv.addressMode(sampler_info.address_modes.u),
                    .AddressV = conv.addressMode(sampler_info.address_modes.v),
                    .AddressW = conv.addressMode(sampler_info.address_modes.w),
                    .MipLODBias = sampler_info.mip_bias,
                    .MaxAnisotropy = sampler_info.anisotropy,
                    .ComparisonFunc = conv.comparisonFunc(sampler_info.compare_op),
                    .BorderColor = sampler_info.border_color,
                    .MinLOD = sampler_info.mip_min,
                    .MaxLOD = sampler_info.mip_max,
                };
                kind = .SAMPLER;
            },
        }

        switch (kind) {
            .SRV => {
                self.descriptor = try device.allocateCBVSRVUAV();
                device.device.idevice.CreateShaderResourceView(
                    self.resource,
                    &srv_desc,
                    self.descriptor.cpu_handle,
                );
            },
            .UAV => {
                self.descriptor = try device.allocateCBVSRVUAV();
                device.device.idevice.CreateUnorderedAccessView(
                    self.resource,
                    null,
                    &uav_desc,
                    self.descriptor.cpu_handle,
                );
            },
            .CBV => {
                self.descriptor = try device.allocateCBVSRVUAV();
                device.device.idevice.CreateConstantBufferView(
                    &cbv_desc,
                    self.descriptor.cpu_handle,
                );
            },
            .SAMPLER => {
                self.descriptor = try device.allocateSampler();
                device.device.idevice.CreateSampler(
                    &sampler_desc,
                    self.descriptor.cpu_handle,
                );
            },
        }
        self.range_type = kind;
    }

    fn deinit(self: *Descriptor) void {
        switch (self.range_type) {
            .CBV, .SRV, .UAV => self.device.deleteCBVSRVUAV(self.descriptor),
            .SAMPLER => self.device.deleteSampler(self.descriptor),
        }
        self.descriptor = .invalid;
        self.resource = null;
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
        return self.descriptor.allocation.offset;
    }
};

const Fence = struct {
    device: *Device,
    allocator: std.mem.Allocator = undefined,
    handle: *d3d12.IFence,
    event: win32.HANDLE = std.os.windows.INVALID_HANDLE_VALUE,

    fn init(self: *Fence, device: *Device, name: []const u8) !void {
        self.* = .{
            .handle = undefined,
            .device = device,
        };

        const hr_create_fence = device.device.idevice.CreateFence(
            0,
            .{},
            win32.riid(d3d12.IFence),
            @ptrCast(&self.handle),
        );
        if (hr_create_fence != win32.S_OK) {
            log.err("Failed to create fence ({s}): {f}", .{ name, win32.fmtHresult(hr_create_fence, .code_message) });
            return error.OutOfMemory;
        }
        const hr_set_name = try self.handle.iobject.setNameUtf8(name);
        if (hr_set_name != win32.S_OK) {
            log.err("Failed to set fence name ({s}): {f}", .{ name, win32.fmtHresult(hr_set_name, .code_message) });
            return error.Gpu;
        }
        self.event = win32.CreateEventExW(
            null,
            win32.L("fence"),
            0,
            std.os.windows.EVENT_ALL_ACCESS,
        ) orelse {
            log.err("Failed to create fence event ({s})", .{name});
            return error.OutOfMemory;
        };
    }

    fn deinit(self: *Fence) void {
        self.device.deleteIUnknown(&self.handle.iunknown);

        std.os.windows.CloseHandle(self.event);
    }

    fn fromGpuFence(fence: *gpu.Fence) *Fence {
        return @ptrCast(@alignCast(fence));
    }

    fn toGpuFence(fence: *Fence) *gpu.Fence {
        return @ptrCast(@alignCast(fence));
    }

    fn wait(self: *Fence, value: u64) Error!void {
        if (self.handle.GetCompletedValue() != value and value != 0) {
            const hr = self.handle.SetEventOnCompletion(value, self.event);
            if (hr != win32.S_OK) {
                log.err("Failed to set fence event on completion: {f} {*}", .{ win32.fmtHresult(hr, .code_message), self.event });
                return error.Gpu;
            }
            std.os.windows.WaitForSingleObjectEx(
                self.event,
                std.os.windows.INFINITE,
                false,
            ) catch unreachable;
        }
    }

    fn signal(self: *Fence, value: u64) Error!void {
        const hr = self.handle.Signal(value);
        if (hr != win32.S_OK) {
            log.err("Failed to signal fence: {f}", .{win32.fmtHresult(hr, .code_message)});
            return error.Gpu;
        }
    }
};

const Pipeline = struct {
    device: *Device,
    allocator: std.mem.Allocator = undefined,
    handle: *d3d12.IPipelineState,
    /// only has a valid value if this is a graphics pipeline
    topology: ?d3d12.PRIMITIVE_TOPOLOGY,

    kind: gpu.Pipeline.Kind,

    fn initGraphics(self: *Pipeline, device: *Device, desc: gpu.Pipeline.GraphicsDesc, name: []const u8) Error!void {
        self.* = .{
            .device = device,
            .topology = conv.primitiveTopology(desc.primitive_topology),
            .handle = undefined,
            .kind = .graphics,
        };

        const root_signature = device.root_signature;

        var gpdesc: d3d12.GRAPHICS_PIPELINE_STATE_DESC = .initDefault();
        gpdesc.pRootSignature = root_signature;
        gpdesc.VS = conv.shaderBytecode(desc.vs);
        gpdesc.PS = conv.shaderBytecode(desc.fs);

        gpdesc.RasterizerState = conv.rasterizerState(desc.rasterization);
        gpdesc.DepthStencilState = conv.depthStencilState(desc.depth_stencil);
        gpdesc.BlendState = conv.blendState(desc.target_state);
        gpdesc.NumRenderTargets = desc.target_state.color_attachments.len;
        for (desc.target_state.color_attachments, 0..) |att, i| {
            gpdesc.RTVFormats[i] = conv.dxgiFormat(att.format, .{});
        }
        gpdesc.DSVFormat = if (desc.target_state.depth_stencil_format) |dsf|
            conv.dxgiFormat(dsf, .{})
        else
            .UNKNOWN;
        gpdesc.PrimitiveTopologyType = conv.topologyType(desc.primitive_topology);
        gpdesc.SampleMask = 0xFFFFFFFF;
        gpdesc.SampleDesc.Count = 1;

        var pipeline_state: ?*d3d12.IPipelineState = null;
        const hr_create_pipeline = device.device.idevice.CreateGraphicsPipelineState(
            &gpdesc,
            win32.riid(d3d12.IPipelineState),
            @ptrCast(&pipeline_state),
        );
        if (hr_create_pipeline != win32.S_OK) {
            log.err("Failed to create D3D12 graphics pipeline state ({s}): {f}", .{
                name,
                win32.fmtHresult(hr_create_pipeline, .code_message),
            });
            return error.Gpu;
        }
        self.handle = pipeline_state.?;

        const hr_set_name = try self.handle.iobject.setNameUtf8(name);
        if (hr_set_name != win32.S_OK) {
            log.err("Failed to set pipeline name: {f}", .{win32.fmtHresult(hr_set_name, .code_message)});
            return error.Gpu;
        }
    }

    fn initCompute(self: *Pipeline, device: *Device, desc: gpu.Pipeline.ComputeDesc, name: []const u8) Error!void {
        self.* = .{
            .device = device,
            .topology = null,
            .handle = undefined,
            .kind = .compute,
        };

        const root_signature = device.root_signature;

        var cpdesc: d3d12.COMPUTE_PIPELINE_STATE_DESC = .initDefault();
        cpdesc.pRootSignature = root_signature;
        cpdesc.CS = conv.shaderBytecode(desc.cs);

        var pipeline_state: ?*d3d12.IPipelineState = null;
        const hr_create_pipeline = device.device.idevice.CreateComputePipelineState(
            &cpdesc,
            win32.riid(d3d12.IPipelineState),
            @ptrCast(&pipeline_state),
        );
        if (hr_create_pipeline != win32.S_OK) {
            log.err("Failed to create D3D12 compute pipeline state ({s}): {f}", .{
                name,
                win32.fmtHresult(hr_create_pipeline, .code_message),
            });
            return error.Gpu;
        }
        self.handle = pipeline_state.?;

        const hr_set_name = try self.handle.iobject.setNameUtf8(name);
        if (hr_set_name != win32.S_OK) {
            log.err("Failed to set pipeline name: {f}", .{win32.fmtHresult(hr_set_name, .code_message)});
            return error.Gpu;
        }
    }

    fn deinit(self: *Pipeline) void {
        self.device.deleteIUnknown(&self.handle.iunknown);
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
    hwnd: win32.HWND = undefined,
    handle: ?*dxgi.ISwapChain3 = null,

    present_mode: gpu.Swapchain.PresentMode = .vsync,
    composition: gpu.Swapchain.Composition = .sdr,

    width: u32 = 0,
    height: u32 = 0,

    backbuffer_index: u32 = 0,
    textures: [gpu.backbuffer_count]?Texture = @splat(null),

    name_buffer: [256]u8 = undefined,
    name: []const u8 = &.{},

    desc: gpu.Swapchain.Desc = undefined,

    fn init(
        self: *Swapchain,
        device: *Device,
        desc: gpu.Swapchain.Desc,
        name: []const u8,
    ) Error!void {
        const hwnd: win32.HWND = @ptrCast(desc.window_handle.window_handle.?);
        self.* = .{};

        const name_len = @min(name.len, self.name_buffer.len);
        @memcpy(self.name_buffer[0..name_len], name[0..name_len]);
        self.name = self.name_buffer[0..name_len];

        self.desc = desc;
        self.hwnd = hwnd;
        self.device = device;

        var swapchain_desc: dxgi.SWAP_CHAIN_DESC1 = .{
            .Width = 0,
            .Height = 0,
            .Format = compositionToTextureFormat(self.desc.composition),
            .Stereo = .FALSE,
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .BufferUsage = .{ .RENDER_TARGET_OUTPUT = true },
            .BufferCount = gpu.backbuffer_count,
            .Scaling = .NONE,
            .SwapEffect = .FLIP_DISCARD,
            .AlphaMode = .IGNORE,
            .Flags = .{ .ALLOW_TEARING = device.tearing_supported },
        };

        const hr_swapchain = device.factory.ifactory2.CreateSwapChainForHwnd(
            @ptrCast(device.graphics_queue),
            hwnd,
            &swapchain_desc,
            null,
            null,
            @ptrCast(&self.handle),
        );
        if (hr_swapchain != win32.S_OK) {
            log.err("Failed to create D3D12 swapchain: {f}", .{win32.fmtHresult(hr_swapchain, .code_message)});
            return error.Gpu;
        }
        const hr_set_name = try self.handle.?.iobject.setNameUtf8(name);
        if (hr_set_name != win32.S_OK) {
            log.err("Failed to set swapchain name: {f}", .{win32.fmtHresult(hr_set_name, .code_message)});
            return error.Gpu;
        }

        if (self.desc.composition != .sdr) {
            const hr_color_space = self.handle.?.SetColorSpace1(
                compositionToColorSpace(self.desc.composition),
            );
            if (hr_color_space != win32.S_OK) {
                log.err("Failed to set swapchain color space: {f}", .{win32.fmtHresult(hr_color_space, .code_message)});
                return error.Gpu;
            }
        }

        const hr_desc = self.handle.?.iswap_chain1.GetDesc1(&swapchain_desc);
        if (hr_desc != win32.S_OK) {
            log.err("Failed to get swapchain description: {f}", .{win32.fmtHresult(hr_desc, .code_message)});
            return error.Gpu;
        }

        self.width = @intCast(swapchain_desc.Width);
        self.height = @intCast(swapchain_desc.Height);
        self.present_mode = self.desc.present_mode;
        self.composition = self.desc.composition;

        try self.acquireSwapchainResources();
    }

    fn deinit(swapchain: *Swapchain) void {
        if (swapchain.handle) |handle| {
            _ = handle.iunknown.Release();
            swapchain.handle = null;
        }

        swapchain.releaseSwapchainResources();
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

    fn present(swapchain: *Swapchain) Error!void {
        var interval: c_uint = 0;
        var flags: dxgi.PRESENT_FLAG = .{};
        if (swapchain.present_mode == .vsync) {
            interval = 0;
        } else if (swapchain.present_mode == .immediate) {
            interval = 0;
            // TODO: check windowed
            flags.ALLOW_TEARING = swapchain.device.tearing_supported;
        }

        const hr_present = swapchain.handle.?.iswap_chain.Present(
            interval,
            flags,
        );
        if (hr_present != win32.S_OK) {
            log.err("Failed to present swapchain: {f}", .{win32.fmtHresult(hr_present, .code_message)});
            return error.Gpu;
        }
    }

    fn acquireNext(
        swapchain: *Swapchain,
    ) Error!void {
        swapchain.backbuffer_index = @intCast(swapchain.handle.?.GetCurrentBackBufferIndex());
    }

    fn getBackbuffer(
        swapchain: *Swapchain,
    ) gpu.Swapchain.Backbuffer {
        return .{
            .texture = swapchain.textures[swapchain.backbuffer_index].?.toGpuTexture(),
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

        swapchain.releaseSwapchainResources();

        // TODO: flush deferred deletes
        swapchain.device.cleanupFully();

        var desc: dxgi.SWAP_CHAIN_DESC1 = .zero;
        const hr_get_desc = swapchain.handle.?.iswap_chain1.GetDesc1(&desc);
        if (hr_get_desc != win32.S_OK) {
            log.err("Failed to get swapchain description for resize: {f}", .{win32.fmtHresult(hr_get_desc, .code_message)});
            return error.Gpu;
        }

        const hr_resize = swapchain.handle.?.iswap_chain.ResizeBuffers(
            desc.BufferCount,
            width,
            height,
            desc.Format,
            desc.Flags,
        );
        if (hr_resize != win32.S_OK) {
            log.err("Failed to resize swapchain buffers: {f}", .{win32.fmtHresult(hr_resize, .code_message)});
            return error.Gpu;
        }

        try swapchain.acquireSwapchainResources();

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
        try self.recreate();
    }

    fn isCompositionModeSupported(
        self: *Swapchain,
        composition: gpu.Swapchain.Composition,
    ) Error!bool {
        if (is_xbox) {
            switch (composition) {
                .sdr, .sdr_linear => return true,
                else => return false,
            }
        }
        if (composition == .sdr) return true;

        const format = compositionToTextureFormat(composition);
        var format_support: d3d12.FEATURE_DATA_FORMAT_SUPPORT = .{
            .Format = format,
            .Support1 = .NONE,
            .Support2 = .NONE,
        };

        const hr_support = self.device.device.idevice.CheckFeatureSupport(
            .FORMAT_SUPPORT,
            @ptrCast(&format_support),
            @sizeOf(d3d12.FEATURE_DATA_FORMAT_SUPPORT),
        );
        if (hr_support != win32.S_OK) {
            return false;
        }

        const support1: u32 = @intFromEnum(format_support.Support1);
        if (support1 & @as(u32, @intFromEnum(d3d12.FORMAT_SUPPORT1.DISPLAY)) == 0) {
            return false;
        }

        var supports: c_uint = 0;
        const hr_supports = self.handle.?.CheckColorSpaceSupport(compositionToColorSpace(composition), &supports);
        if (hr_supports != win32.S_OK) {
            return false;
        }

        if (supports & dxgi.SWAP_CHAIN_COLOR_SPACE_SUPPORT_FLAG_PRESENT == 0) {
            return false;
        }

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
        try self.recreate();
    }

    fn releaseSwapchainResources(self: *Swapchain) void {
        for (0..gpu.backbuffer_count) |i| {
            if (self.textures[i] == null) continue;
            const tex = &self.textures[i];
            tex.*.?.deinit();
            tex.* = null;
        }

        self.device.cleanupFully();
    }

    fn acquireSwapchainResources(self: *Swapchain) Error!void {
        self.releaseSwapchainResources();

        const texture_desc: gpu.Texture.Desc = .{
            .width = self.width,
            .height = self.height,
            .format = compositionToApiTextureFormat(self.composition),
            .usage = .read_only_render_target,
        };

        var fmt_buf: [512]u8 = undefined;

        for (0..gpu.backbuffer_count) |i| {
            // var texture = &self.textures[i];
            var backbuffer: ?*d3d12.IResource = null;
            const hr_get_buffer = self.handle.?.iswap_chain.GetBuffer(
                @as(u32, @intCast(i)),
                win32.riid(d3d12.IResource),
                @ptrCast(&backbuffer),
            );
            if (hr_get_buffer != win32.S_OK) {
                log.err("Failed to get swapchain buffer {d}: {f}", .{ i, win32.fmtHresult(hr_get_buffer, .code_message) });
                return error.Gpu;
            }

            const name = std.fmt.bufPrint(&fmt_buf, "swapchain texture {}", .{i}) catch unreachable;
            self.textures[i] = @as(Texture, undefined);
            try self.textures[i].?.initSwapchain(self.device, backbuffer.?, texture_desc, name);
        }
    }

    fn recreate(self: *Swapchain) Error!void {
        const old_present_mode = self.present_mode;
        const old_composition = self.composition;

        if (!try self.isCompositionModeSupported(self.composition)) {
            self.composition = .sdr;
        }

        const is_same_presentation = old_present_mode == self.present_mode;
        const is_same_composition = old_composition == self.composition;
        if (is_same_presentation and is_same_composition) {
            return;
        }

        self.deinit();
        try self.init(self.device, self.desc, self.name);
    }

    fn compositionToApiTextureFormat(composition: gpu.Swapchain.Composition) gpu.Format {
        return switch (composition) {
            .sdr => .rgba8unorm,
            .sdr_linear => .rgba8srgb,
            .hdr_extended_linear => .rgba16f,
            .hdr10_st2084 => .rgb10a2unorm,
        };
    }

    fn compositionToTextureFormat(composition: gpu.Swapchain.Composition) dxgi.FORMAT {
        return switch (composition) {
            .sdr => .R8G8B8A8_UNORM,
            .sdr_linear => .R8G8B8A8_UNORM,
            .hdr_extended_linear => .R16G16B16A16_FLOAT,
            .hdr10_st2084 => .R10G10B10A2_UNORM,
        };
    }

    fn compositionToColorSpace(composition: gpu.Swapchain.Composition) dxgi.COLOR_SPACE_TYPE {
        return switch (composition) {
            .sdr => .RGB_FULL_G22_NONE_P709,
            .sdr_linear => .RGB_FULL_G22_NONE_P709,
            .hdr_extended_linear => .RGB_FULL_G10_NONE_P709,
            .hdr10_st2084 => .RGB_FULL_G2084_NONE_P2020,
        };
    }
};

const Texture = struct {
    device: *Device,
    allocator: ?std.mem.Allocator = null,
    handle: ?*d3d12.IResource,
    allocation: ?*d3d12ma.Allocation = null,
    /// length is layer * levels
    rtvs: InlineStorage(DescriptorHeap.Handle, 1) = .empty,
    /// length is layer * levels
    dsvs: InlineStorage(DescriptorHeap.Handle, 1) = .empty,
    /// staging heap descriptor
    // srv: ?instance.DescriptorHeap.Descriptor,

    desc: gpu.Texture.Desc,

    /// set .handle to a backing texture to use it aliasing
    fn init(self: *Texture, device: *Device, allocator: std.mem.Allocator, desc: gpu.Texture.Desc, name: []const u8) Error!void {
        self.* = .{
            .device = device,
            .allocator = allocator,
            .handle = null,
            .allocation = self.allocation,
            .desc = desc,
        };

        const resource_desc: d3d12.RESOURCE_DESC1 = conv.textureResourceDesc(&desc);
        var layout: d3d12.BARRIER_LAYOUT = .COMMON;
        if (desc.usage.render_target) {
            layout = .RENDER_TARGET;
        } else if (desc.usage.depth_stencil) {
            layout = .DEPTH_STENCIL_WRITE;
        } else if (desc.usage.shader_write) {
            layout = .UNORDERED_ACCESS;
        }

        const optimized_clear_value: d3d12.CLEAR_VALUE = if (desc.usage.depth_stencil)
            .initDepthStencil(resource_desc.Format, 1.0, 0)
        else if (desc.usage.render_target)
            .initColor(resource_desc.Format, .{ 0.0, 0.0, 0.0, 1.0 })
        else
            std.mem.zeroes(d3d12.CLEAR_VALUE);
        const optimized_clear_value_ptr: ?*const d3d12.CLEAR_VALUE = if (desc.usage.render_target or desc.usage.depth_stencil)
            &optimized_clear_value
        else
            null;

        var hr: win32.HRESULT = win32.S_OK;

        var allocation_desc: d3d12ma.ALLOCATION_DESC = .{};
        allocation_desc.HeapType = conv.heapType(desc.location);
        allocation_desc.Flags = d3d12ma._ALLOCATION_FLAG_COMMITTED;

        hr = device.mem_allocator.CreateResource3(
            &allocation_desc,
            &resource_desc,
            layout,
            optimized_clear_value_ptr,
            0,
            null,
            &self.allocation,
            win32.riid(d3d12.IResource),
            @ptrCast(&self.handle),
        );

        if (hr != win32.S_OK) {
            log.err("Failed to create D3D12 texture ({s}): {f}", .{ name, win32.fmtHresult(hr, .code_message) });
            return error.Gpu;
        }

        const hr_set_name = try self.handle.?.iobject.setNameUtf8(name);
        if (hr_set_name != win32.S_OK) {
            log.err("Failed to set texture name: {f}", .{win32.fmtHresult(hr_set_name, .code_message)});
            return error.Gpu;
        }

        self.rtvs = .initSlice(try allocator.alloc(DescriptorHeap.Handle, desc.mip_levels * desc.depth_or_array_layers));
        @memset(self.rtvs.slice(), .invalid);
        self.dsvs = .initSlice(try allocator.alloc(DescriptorHeap.Handle, desc.mip_levels * desc.depth_or_array_layers));
        @memset(self.dsvs.slice(), .invalid);
    }

    fn initSwapchain(
        self: *Texture,
        device: *Device,
        resource: *d3d12.IResource,
        desc: gpu.Texture.Desc,
        name: []const u8,
    ) Error!void {
        self.* = .{
            .device = device,
            .allocator = null,
            .handle = resource,
            .allocation = null,
            .desc = desc,
        };

        const hr_set_name = try self.handle.?.iobject.setNameUtf8(name);
        if (hr_set_name != win32.S_OK) {
            log.err("Failed to set texture name: {f}", .{win32.fmtHresult(hr_set_name, .code_message)});
            return error.Gpu;
        }

        self.rtvs = InlineStorage(DescriptorHeap.Handle, 1).initFixed(&.{.invalid}) catch unreachable;
        self.dsvs = InlineStorage(DescriptorHeap.Handle, 1).initFixed(&.{}) catch unreachable;
        _ = self.getRTV(0, 0);
    }

    fn deinit(self: *Texture) void {
        if (self.allocation) |allocation| {
            self.device.deleteAllocation(allocation);
            self.allocation = null;
        }
        if (self.handle) |handle| {
            self.device.deleteIUnknown(&handle.iunknown);
            self.handle = null;
        }
        for (self.rtvs.constSlice()) |rtv| {
            self.device.deleteRTV(rtv);
        }
        switch (self.rtvs) {
            .buf => |b| self.allocator.?.free(b),
            else => {},
        }
        for (self.dsvs.constSlice()) |dsv| {
            self.device.deleteDSV(dsv);
        }
        switch (self.dsvs) {
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

    fn getRTV(self: *Texture, mip_slice: u32, array_slice: u32) d3d12.CPU_DESCRIPTOR_HANDLE {
        const index = mip_slice * self.desc.depth_or_array_layers + array_slice;
        const rtv_slice = self.rtvs.slice();
        const rtv = rtv_slice[index];
        if (rtv.isInvalid()) {
            rtv_slice[index] = self.device.allocateRTV() catch {
                log.err("Failed to allocate RTV descriptor (full)", .{});
                return .{ .ptr = 0 };
            };

            var rtv_desc: d3d12.RENDER_TARGET_VIEW_DESC = std.mem.zeroes(d3d12.RENDER_TARGET_VIEW_DESC);
            rtv_desc.Format = conv.dxgiFormat(self.desc.format, .{});

            switch (self.desc.dimension) {
                .@"2d" => {
                    rtv_desc.ViewDimension = .TEXTURE2D;
                    rtv_desc.u.Texture2D.MipSlice = mip_slice;
                },
                .cube => {
                    rtv_desc.ViewDimension = .TEXTURE2DARRAY;
                    rtv_desc.u.Texture2DArray.MipSlice = mip_slice;
                    rtv_desc.u.Texture2DArray.FirstArraySlice = array_slice;
                    rtv_desc.u.Texture2DArray.ArraySize = 1;
                },
                else => @panic("Unsupported texture kind for RTV (3d)"),
            }

            self.device.device.idevice.CreateRenderTargetView(
                self.handle,
                &rtv_desc,
                rtv_slice[index].cpu_handle,
            );

            return rtv_slice[index].cpu_handle;
        }

        return rtv_slice[index].cpu_handle;
    }

    fn getDSV(self: *Texture, mip_slice: u32, array_slice: u32) d3d12.CPU_DESCRIPTOR_HANDLE {
        const index = mip_slice * self.desc.depth_or_array_layers + array_slice;
        const dsv_slice = self.dsvs.slice();
        const dsv = dsv_slice[index];
        if (dsv.isInvalid()) {
            dsv_slice[index] = self.device.allocateDSV() catch {
                log.err("Failed to allocate DSV descriptor (full)", .{});
                return .{ .ptr = 0 };
            };

            var dsv_desc: d3d12.DEPTH_STENCIL_VIEW_DESC = std.mem.zeroes(d3d12.DEPTH_STENCIL_VIEW_DESC);
            dsv_desc.Format = conv.dxgiFormat(self.desc.format, .{});

            switch (self.desc.dimension) {
                .@"2d" => {
                    dsv_desc.ViewDimension = .TEXTURE2D;
                    dsv_desc.u.Texture2D.MipSlice = mip_slice;
                },
                .cube => {
                    dsv_desc.ViewDimension = .TEXTURE2DARRAY;
                    dsv_desc.u.Texture2DArray.MipSlice = mip_slice;
                    dsv_desc.u.Texture2DArray.FirstArraySlice = array_slice;
                    dsv_desc.u.Texture2DArray.ArraySize = 1;
                },
                else => @panic("Unsupported texture kind for DSV (3d)"),
            }

            self.device.device.idevice.CreateDepthStencilView(
                self.handle,
                &dsv_desc,
                dsv_slice[index].cpu_handle,
            );

            return dsv_slice[index].cpu_handle;
        }

        return dsv_slice[index].cpu_handle;
    }

    fn requiredStagingSize(self: *const Texture) usize {
        const desc = self.handle.?.GetDesc();
        const subresource_count = self.desc.mip_levels * self.desc.depth_or_array_layers;

        var size: u64 = 0;
        self.device.device.idevice.GetCopyableFootprints(
            &desc,
            0,
            subresource_count,
            0,
            null,
            null,
            null,
            &size,
        );
        return size;
    }

    fn getRowPitch(self: *const Texture, mip_level: u32) u32 {
        const desc = self.handle.?.GetDesc();
        std.debug.assert(mip_level < self.desc.mip_levels);

        var footprints: [1]d3d12.PLACED_SUBRESOURCE_FOOTPRINT = undefined;
        self.device.device.idevice.GetCopyableFootprints(
            &desc,
            mip_level,
            1,
            0,
            &footprints,
            null,
            null,
            null,
        );
        return @intCast(footprints[0].Footprint.RowPitch);
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

    fn beginFrame(data: *anyopaque) void {
        const device: *Device = .fromData(data);
        device.beginFrame();
    }

    fn endFrame(data: *anyopaque) void {
        const device: *Device = .fromData(data);
        device.endFrame();
    }

    fn getFrameIndex(data: *anyopaque) usize {
        const device: *Device = .fromData(data);
        return device.frame_idx;
    }

    fn shutdown(data: *anyopaque) void {
        const device: *Device = .fromData(data);
        device.is_done = true;
    }

    // buffer stuff
    fn createBuffer(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Buffer.Desc,
        debug_name: []const u8,
    ) Error!*gpu.Buffer {
        const device: *Device = .fromData(data);
        var buffer = try allocator.create(Buffer);
        errdefer allocator.destroy(buffer);
        try buffer.init(device, allocator, desc.*, debug_name);
        return buffer.toGpuBuffer();
    }

    fn destroyBuffer(_: *anyopaque, buffer: *gpu.Buffer) void {
        const buf: *Buffer = .fromGpuBuffer(buffer);
        buf.deinit();
        buf.allocator.destroy(buf);
    }

    fn getBufferDesc(_: *anyopaque, buffer: *const gpu.Buffer) *const gpu.Buffer.Desc {
        const buf: *const Buffer = .fromGpuBufferConst(buffer);
        return &buf.desc;
    }

    fn getBufferCpuAddress(
        _: *anyopaque,
        buffer: *gpu.Buffer,
    ) ?[*]u8 {
        const buf: *Buffer = .fromGpuBuffer(buffer);
        return buf.cpuAddress();
    }

    fn getBufferGpuAddress(
        _: *anyopaque,
        buffer: *gpu.Buffer,
    ) gpu.Buffer.GpuAddress {
        const buf: *Buffer = .fromGpuBuffer(buffer);
        return buf.gpuAddress();
    }

    fn getBufferRequiredStagingSize(
        _: *anyopaque,
        buffer: *const gpu.Buffer,
    ) usize {
        const buf: *const Buffer = .fromGpuBufferConst(buffer);
        return buf.requiredStagingSize();
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
        debug_name: []const u8,
    ) Error!*gpu.Fence {
        const device: *Device = .fromData(data);
        var fence = try allocator.create(Fence);
        errdefer allocator.destroy(fence);
        try fence.init(device, debug_name);
        fence.allocator = allocator;
        return fence.toGpuFence();
    }

    fn destroyFence(_: *anyopaque, fence: *gpu.Fence) void {
        const f: *Fence = .fromGpuFence(fence);
        f.deinit();
        f.allocator.destroy(f);
    }

    fn signalFence(
        _: *anyopaque,
        fence: *gpu.Fence,
        value: u64,
    ) Error!void {
        const f: *Fence = .fromGpuFence(fence);
        try f.signal(value);
    }

    fn waitFence(
        _: *anyopaque,
        fence: *gpu.Fence,
        value: u64,
    ) Error!void {
        const f: *Fence = .fromGpuFence(fence);
        try f.wait(value);
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
        try descriptor.init(device, desc.*, debug_name);
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
        debug_name: []const u8,
    ) Error!*gpu.Pipeline {
        const device: *Device = .fromData(data);
        var pipeline = try allocator.create(Pipeline);
        errdefer allocator.destroy(pipeline);
        try pipeline.initGraphics(device, desc.*, debug_name);
        pipeline.allocator = allocator;
        return pipeline.toGpuPipeline();
    }

    fn createComputePipeline(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Pipeline.ComputeDesc,
        debug_name: []const u8,
    ) Error!*gpu.Pipeline {
        const device: *Device = .fromData(data);
        var pipeline = try allocator.create(Pipeline);
        errdefer allocator.destroy(pipeline);
        try pipeline.initCompute(device, desc.*, debug_name);
        pipeline.allocator = allocator;
        return pipeline.toGpuPipeline();
    }

    fn destroyPipeline(
        _: *anyopaque,
        pipeline: *gpu.Pipeline,
    ) void {
        const pl: *Pipeline = .fromGpuPipeline(pipeline);
        pl.deinit();
        pl.allocator.destroy(pl);
    }

    fn getPipelineKind(
        _: *anyopaque,
        pipeline: *const gpu.Pipeline,
    ) gpu.Pipeline.Kind {
        const pl: *const Pipeline = .fromGpuPipelineConst(pipeline);
        return pl.kind;
    }

    // swapchain stuff
    fn createSwapchain(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Swapchain.Desc,
        debug_name: []const u8,
    ) Error!*gpu.Swapchain {
        const device: *Device = .fromData(data);
        var swapchain = try allocator.create(Swapchain);
        errdefer allocator.destroy(swapchain);
        try swapchain.init(device, desc.*, debug_name);
        swapchain.allocator = allocator;
        return swapchain.toGpuSwapchain();
    }

    fn destroySwapchain(
        _: *anyopaque,
        swapchain: *gpu.Swapchain,
    ) void {
        const sc: *Swapchain = .fromGpuSwapchain(swapchain);
        sc.deinit();
        sc.allocator.destroy(sc);
    }

    fn acquireNextSwapchainImage(
        _: *anyopaque,
        swapchain: *gpu.Swapchain,
    ) Error!void {
        const sc: *Swapchain = .fromGpuSwapchain(swapchain);
        try sc.acquireNext();
    }

    fn getSwapchainBackbuffer(
        _: *anyopaque,
        swapchain: *gpu.Swapchain,
    ) gpu.Swapchain.Backbuffer {
        const sc: *Swapchain = .fromGpuSwapchain(swapchain);
        return sc.getBackbuffer();
    }

    fn resizeSwapchain(
        _: *anyopaque,
        swapchain: *gpu.Swapchain,
        width: u32,
        height: u32,
    ) Error!bool {
        const sc: *Swapchain = .fromGpuSwapchain(swapchain);
        return sc.resize(width, height);
    }

    // texture
    fn createTexture(
        data: *anyopaque,
        allocator: std.mem.Allocator,
        desc: *const gpu.Texture.Desc,
        debug_name: []const u8,
    ) Error!*gpu.Texture {
        const device: *Device = .fromData(data);
        var texture = try allocator.create(Texture);
        errdefer allocator.destroy(texture);
        try texture.init(device, allocator, desc.*, debug_name);
        texture.allocator = allocator;
        return texture.toGpuTexture();
    }

    fn destroyTexture(
        _: *anyopaque,
        texture: *gpu.Texture,
    ) void {
        const tex: *Texture = .fromGpuTexture(texture);
        tex.deinit();
        if (tex.allocator) |alloc|
            alloc.destroy(tex);
    }

    fn getTextureDesc(
        _: *anyopaque,
        texture: *const gpu.Texture,
    ) *const gpu.Texture.Desc {
        const tex: *const Texture = .fromGpuTextureConst(texture);
        return &tex.desc;
    }

    fn getTextureRequiredStagingSize(
        _: *anyopaque,
        texture: *const gpu.Texture,
    ) usize {
        const tex: *const Texture = .fromGpuTextureConst(texture);
        return tex.requiredStagingSize();
    }

    fn getTextureRowPitch(
        _: *anyopaque,
        texture: *const gpu.Texture,
        mip_level: u32,
    ) u32 {
        const tex: *const Texture = .fromGpuTextureConst(texture);
        return tex.getRowPitch(mip_level);
    }
};

const vtable: gpu.Interface.VTable = .{
    .deinit = impl.deinit,
    .get_interface_options = impl.getInterfaceOptions,
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
    .create_compute_pipeline = impl.createComputePipeline,
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

const conv = struct {
    fn dxgiFormat(format: gpu.Format, props: struct {
        depth_srv: bool = false,
        uav: bool = false,
    }) dxgi.FORMAT {
        return switch (format) {
            .unknown => .UNKNOWN,
            .rgba32f => .R32G32B32A32_FLOAT,
            .rgba32ui => .R32G32B32A32_UINT,
            .rgba32si => .R32G32B32A32_SINT,
            .rgba16f => .R16G16B16A16_FLOAT,
            .rgba16ui => .R16G16B16A16_UINT,
            .rgba16si => .R16G16B16A16_SINT,
            .rgba16unorm => .R16G16B16A16_UNORM,
            .rgba16snorm => .R16G16B16A16_SNORM,
            .rgba8ui => .R8G8B8A8_UINT,
            .rgba8si => .R8G8B8A8_SINT,
            .rgba8unorm => .R8G8B8A8_UNORM,
            .rgba8snorm => .R8G8B8A8_SNORM,
            .rgba8srgb => if (props.uav) .R8G8B8A8_UNORM else .R8G8B8A8_UNORM_SRGB,
            .bgra8unorm => .B8G8R8A8_UNORM,
            .bgra8srgb => if (props.uav) .B8G8R8A8_UNORM else .B8G8R8A8_UNORM_SRGB,
            .rgb10a2ui => .R10G10B10A2_UINT,
            .rgb10a2unorm => .R10G10B10A2_UNORM,
            .rgb32f => .R32G32B32_FLOAT,
            .rgb32ui => .R32G32B32_UINT,
            .rgb32si => .R32G32B32_SINT,
            .r11g11b10f => .R11G11B10_FLOAT,
            .rgb9e5 => .R9G9B9E5_SHAREDEXP,
            .rg32f => .R32G32_FLOAT,
            .rg32ui => .R32G32_UINT,
            .rg32si => .R32G32_SINT,
            .rg16f => .R16G16_FLOAT,
            .rg16ui => .R16G16_UINT,
            .rg16si => .R16G16_SINT,
            .rg16unorm => .R16G16_UNORM,
            .rg16snorm => .R16G16_SNORM,
            .rg8ui => .R8G8_UINT,
            .rg8si => .R8G8_SINT,
            .rg8unorm => .R8G8_UNORM,
            .rg8snorm => .R8G8_SNORM,
            .r32f => .R32_FLOAT,
            .r32ui => .R32_UINT,
            .r32si => .R32_SINT,
            .r16f => .R16_FLOAT,
            .r16ui => .R16_UINT,
            .r16si => .R16_SINT,
            .r16unorm => .R16_UNORM,
            .r16snorm => .R16_SNORM,
            .r8ui => .R8_UINT,
            .r8si => .R8_SINT,
            .r8unorm => .R8_UNORM,
            .r8snorm => .R8_SNORM,
            .d32f => if (props.depth_srv) .R32_FLOAT else .D32_FLOAT,
            .d32fs8 => if (props.depth_srv) .R32_FLOAT_X8X24_TYPELESS else .D32_FLOAT_S8X24_UINT,
            .d16 => if (props.depth_srv) .R16_UNORM else .D16_UNORM,
            .bc1unorm => .BC1_UNORM,
            .bc1srgb => .BC1_UNORM_SRGB,
            .bc2unorm => .BC2_UNORM,
            .bc2srgb => .BC2_UNORM_SRGB,
            .bc3unorm => .BC3_UNORM,
            .bc3srgb => .BC3_UNORM_SRGB,
            .bc4unorm => .BC4_UNORM,
            .bc4snorm => .BC4_SNORM,
            .bc5unorm => .BC5_UNORM,
            .bc5snorm => .BC5_SNORM,
            .bc6u16f => .BC6H_UF16,
            .bc6s16f => .BC6H_SF16,
            .bc7unorm => .BC7_UNORM,
            .bc7srgb => .BC7_UNORM_SRGB,
        };
    }

    fn bufferResourceDesc(desc: *const gpu.Buffer.Desc) d3d12.RESOURCE_DESC1 {
        var res: d3d12.RESOURCE_DESC1 = std.mem.zeroes(d3d12.RESOURCE_DESC1);
        res.Dimension = .BUFFER;
        res.Width = @intCast(desc.size);
        res.Height = 1;
        res.DepthOrArraySize = 1;
        res.MipLevels = 1;
        res.Format = dxgi.FORMAT.UNKNOWN;
        res.SampleDesc.Count = 1;
        res.Layout = .ROW_MAJOR;

        if (desc.usage.shader_write) {
            res.Flags.ALLOW_UNORDERED_ACCESS = true;
        }

        return res;
    }

    fn textureResourceDesc(desc: *const gpu.Texture.Desc) d3d12.RESOURCE_DESC1 {
        var res: d3d12.RESOURCE_DESC1 = std.mem.zeroes(d3d12.RESOURCE_DESC1);
        res.Width = desc.width;
        res.Height = desc.height;
        res.MipLevels = @intCast(desc.mip_levels);
        res.Format = dxgiFormat(desc.format, .{});
        res.SampleDesc.Count = desc.sample_count.toInt();

        if (desc.usage.render_target) {
            res.Flags.ALLOW_RENDER_TARGET = true;
        }

        if (desc.usage.depth_stencil) {
            res.Flags.ALLOW_DEPTH_STENCIL = true;
        }

        if (desc.usage.shader_write) {
            res.Flags.ALLOW_UNORDERED_ACCESS = true;
        }

        switch (desc.dimension) {
            .@"2d" => {
                res.Dimension = .TEXTURE2D;
                res.DepthOrArraySize = 1;
            },
            .@"3d" => {
                res.Dimension = .TEXTURE3D;
                res.DepthOrArraySize = @intCast(desc.depth_or_array_layers);
            },
            .cube => {
                res.Dimension = .TEXTURE2D;
                std.debug.assert(desc.depth_or_array_layers == 6);
                res.DepthOrArraySize = 6;
            },
        }

        return res;
    }

    fn heapType(location: gpu.MemoryLocation) d3d12.HEAP_TYPE {
        return switch (location) {
            .cpu_only => .UPLOAD,
            .gpu_only => .DEFAULT,
            .cpu_to_gpu => .UPLOAD,
            .gpu_to_cpu => .READBACK,
        };
    }

    fn commandType(command_queue: gpu.Queue) d3d12.COMMAND_LIST_TYPE {
        return switch (command_queue) {
            .graphics => .DIRECT,
            .compute => .COMPUTE,
            .copy => .COPY,
        };
    }
    fn barrierSync(access: gpu.Access) d3d12.BARRIER_SYNC {
        var sync: d3d12.BARRIER_SYNC = .{};
        const discard = access.discard;
        if (!discard) {
            if (access.clear_write) sync.CLEAR_UNORDERED_ACCESS_VIEW = true;
        }

        if (access.present) sync.ALL = true;
        if (access.render_target) sync.RENDER_TARGET = true;
        if (access.isDSV()) sync.DEPTH_STENCIL = true;
        if (access.isVertex()) sync.VERTEX_SHADING = true;
        if (access.isFragment()) sync.PIXEL_SHADING = true;
        if (access.isCompute()) sync.COMPUTE_SHADING = true;
        if (access.isCopy()) sync.COPY = true;
        if (access.index_buffer) sync.INDEX_INPUT = true;
        if (access.indirect_argument) sync.EXECUTE_INDIRECT_OR_PREDICATION = true;
        // TODO: acceleration structure

        return sync;
    }

    fn barrierAccess(access: gpu.Access) d3d12.BARRIER_ACCESS {
        if (access.discard) return .{ .NO_ACCESS = true };

        var res: d3d12.BARRIER_ACCESS = .COMMON;
        if (access.render_target) res.RENDER_TARGET = true;
        if (access.depth_stencil) res.DEPTH_STENCIL_WRITE = true;
        if (access.depth_stencil_read_only) res.DEPTH_STENCIL_READ = true;
        if (access.isRead()) res.SHADER_RESOURCE = true;
        if (access.isWrite()) res.UNORDERED_ACCESS = true;
        if (access.clear_write) res.UNORDERED_ACCESS = true;
        if (access.copy_dst) res.COPY_DEST = true;
        if (access.copy_src) res.COPY_SOURCE = true;
        // if (access.shading_rate) res.SHADING_RATE_SOURCE = true;
        if (access.index_buffer) res.INDEX_BUFFER = true;
        if (access.indirect_argument) res.INDIRECT_ARGUMENT_OR_PREDICATION = true;
        // if (access.as_read) res.RAYTRACING_ACCELERATION_STRUCTURE_READ = true;
        // if (access.as_write) res.RAYTRACING_ACCELERATION_STRUCTURE_WRITE = true;

        return res;
    }

    fn barrierLayout(access: gpu.Access) d3d12.BARRIER_LAYOUT {
        if (access.discard) return .UNDEFINED;
        if (access.present) return .PRESENT;
        if (access.render_target) return .RENDER_TARGET;
        if (access.depth_stencil) return .DEPTH_STENCIL_WRITE;
        if (access.depth_stencil_read_only) return .DEPTH_STENCIL_READ;
        if (access.isRead()) return .SHADER_RESOURCE;
        if (access.isWrite()) return .UNORDERED_ACCESS;
        if (access.clear_write) return .UNORDERED_ACCESS;
        if (access.copy_dst) return .COPY_DEST;
        if (access.copy_src) return .COPY_SOURCE;
        // if (access.shading_rate) return .SHADING_RATE_SOURCE;

        @panic("unhandled gpu.Access layout, none of the known usages matched");
    }

    fn renderPassBeginningAccessTypeColor(load: gpu.RenderPass.LoadColor) d3d12.RENDER_PASS_BEGINNING_ACCESS_TYPE {
        return switch (load) {
            .load => .PRESERVE,
            .clear => .CLEAR,
            .discard => .DISCARD,
        };
    }

    fn renderPassBeginningAccessTypeDepth(load: gpu.RenderPass.LoadDepth) d3d12.RENDER_PASS_BEGINNING_ACCESS_TYPE {
        return switch (load) {
            .load => .PRESERVE,
            .clear => .CLEAR,
            .discard => .DISCARD,
        };
    }

    fn renderPassBeginningAccessTypeStencil(load: gpu.RenderPass.LoadStencil) d3d12.RENDER_PASS_BEGINNING_ACCESS_TYPE {
        return switch (load) {
            .load => .PRESERVE,
            .clear => .CLEAR,
            .discard => .DISCARD,
        };
    }

    fn renderPassEndingAccessType(store_op: gpu.RenderPass.Store) d3d12.RENDER_PASS_ENDING_ACCESS_TYPE {
        return switch (store_op) {
            .store => .PRESERVE,
            .discard => .DISCARD,
        };
    }

    fn primitiveTopology(primitive: gpu.Pipeline.Primitive) d3d12.PRIMITIVE_TOPOLOGY {
        return switch (primitive) {
            .triangle_list => .TRIANGLELIST,
            .triangle_strip => .TRIANGLESTRIP,
            .line_list => .LINELIST,
            .line_strip => .LINESTRIP,
            .point_list => .POINTLIST,
        };
    }

    fn shaderBytecode(shader: []const u8) d3d12.SHADER_BYTECODE {
        return .{
            .pShaderBytecode = @ptrCast(shader.ptr),
            .BytecodeLength = @intCast(shader.len),
        };
    }

    fn cullMode(cull_mode: gpu.Pipeline.CullMode) d3d12.CULL_MODE {
        return switch (cull_mode) {
            .none => .NONE,
            .front => .FRONT,
            .back => .BACK,
        };
    }

    fn rasterizerState(rasterization: gpu.Pipeline.RasterizationState) d3d12.RASTERIZER_DESC {
        var out: d3d12.RASTERIZER_DESC = .{
            .FillMode = switch (rasterization.fill_mode) {
                .wireframe => .WIREFRAME,
                .solid => .SOLID,
            },
            .CullMode = cullMode(rasterization.cull_mode),
            .FrontCounterClockwise = switch (rasterization.front_face) {
                .clockwise => .FALSE,
                .counter_clockwise => .TRUE,
            },
            .MultisampleEnable = .FALSE,
            .AntialiasedLineEnable = .TRUE,
        };

        if (rasterization.depth_bias) |depth_bias| {
            out.DepthBias = @intFromFloat(depth_bias.constant_factor);
            out.DepthBiasClamp = depth_bias.clamp;
            out.SlopeScaledDepthBias = depth_bias.slope_factor;
        }

        return out;
    }

    fn comparisonFunc(compare_op: gpu.Pipeline.CompareOp) d3d12.COMPARISON_FUNC {
        return switch (compare_op) {
            .never => .NEVER,
            .less => .LESS,
            .equal => .EQUAL,
            .less_or_equal => .LESS_EQUAL,
            .greater => .GREATER,
            .not_equal => .NOT_EQUAL,
            .greater_or_equal => .GREATER_EQUAL,
            .always => .ALWAYS,
        };
    }

    fn stencilOp(op: gpu.Pipeline.StencilOp) d3d12.STENCIL_OP {
        return switch (op) {
            .keep => .KEEP,
            .zero => .ZERO,
            .replace => .REPLACE,
            .increment_and_clamp => .INCR_SAT,
            .decrement_and_clamp => .DECR_SAT,
            .invert => .INVERT,
            .increment_and_wrap => .INCR,
            .decrement_and_wrap => .DECR,
        };
    }

    fn depthStencilOp(face: gpu.Pipeline.StencilState) d3d12.DEPTH_STENCILOP_DESC {
        return .{
            .StencilFailOp = stencilOp(face.fail),
            .StencilDepthFailOp = stencilOp(face.depth_fail),
            .StencilPassOp = stencilOp(face.pass),
            .StencilFunc = comparisonFunc(face.compare),
        };
    }

    fn depthStencilState(depth_stencil: gpu.Pipeline.DepthStencilState) d3d12.DEPTH_STENCIL_DESC {
        var out: d3d12.DEPTH_STENCIL_DESC = .{
            .DepthWriteMask = if (depth_stencil.depth_write) .ALL else .ZERO,
        };
        if (depth_stencil.depth_test) |depth_test| {
            out.DepthEnable = .TRUE;
            out.DepthFunc = comparisonFunc(depth_test.op);
        } else {
            out.DepthEnable = .FALSE;
        }
        if (depth_stencil.stencil_test) |stencil_test| {
            out.StencilEnable = .TRUE;
            out.StencilReadMask = stencil_test.compare_mask;
            out.StencilWriteMask = stencil_test.write_mask;
            out.FrontFace = depthStencilOp(stencil_test.front);
            out.BackFace = depthStencilOp(stencil_test.back);
        } else {
            out.StencilEnable = .FALSE;
        }

        return out;
    }

    fn topologyType(primitive: gpu.Pipeline.Primitive) d3d12.PRIMITIVE_TOPOLOGY_TYPE {
        return switch (primitive) {
            .triangle_list => .TRIANGLE,
            .triangle_strip => .TRIANGLE,
            .line_list => .LINE,
            .line_strip => .LINE,
            .point_list => .POINT,
        };
    }

    fn blendFactor(factor: gpu.Pipeline.BlendFactor) d3d12.BLEND {
        return switch (factor) {
            .zero => .ZERO,
            .one => .ONE,
            .src_color => .SRC_COLOR,
            .inv_src_color => .INV_SRC_COLOR,
            .dst_color => .DEST_COLOR,
            .inv_dst_color => .INV_DEST_COLOR,
            .src_alpha => .SRC_ALPHA,
            .inv_src_alpha => .INV_SRC_ALPHA,
            .dst_alpha => .DEST_ALPHA,
            .inv_dst_alpha => .INV_DEST_ALPHA,
            .constant_color => .BLEND_FACTOR,
            .inv_constant_color => .INV_BLEND_FACTOR,
            .src_alpha_saturated => .SRC_ALPHA_SAT,
        };
    }

    fn blendOp(op: gpu.Pipeline.BlendOp) d3d12.BLEND_OP {
        return switch (op) {
            .add => .ADD,
            .subtract => .SUBTRACT,
            .reverse_subtract => .REV_SUBTRACT,
            .min => .MIN,
            .max => .MAX,
        };
    }

    fn rtBlendState(opt_blending: ?gpu.Pipeline.ColorAttachmentBlendState) d3d12.RENDER_TARGET_BLEND_DESC {
        const blending = opt_blending orelse return .{
            .BlendEnable = .FALSE,
        };
        return .{
            .BlendEnable = .TRUE,
            .LogicOpEnable = .FALSE,
            .SrcBlend = blendFactor(blending.color.src),
            .DestBlend = blendFactor(blending.color.dst),
            .BlendOp = blendOp(blending.color.op),
            .SrcBlendAlpha = blendFactor(blending.alpha.src),
            .DestBlendAlpha = blendFactor(blending.alpha.dst),
            .BlendOpAlpha = blendOp(blending.alpha.op),
            .RenderTargetWriteMask = .{
                .RED = blending.mask.r,
                .GREEN = blending.mask.g,
                .BLUE = blending.mask.b,
                .ALPHA = blending.mask.a,
            },
        };
    }

    fn blendState(target: gpu.Pipeline.TargetState) d3d12.BLEND_DESC {
        var res: d3d12.BLEND_DESC = .{
            .AlphaToCoverageEnable = .FALSE,
            .IndependentBlendEnable = .fromBool(target.color_attachments.len > 1),
        };

        for (target.color_attachments, 0..) |attachment, i| {
            res.RenderTarget[i] = rtBlendState(attachment.blend);
        }

        return res;
    }

    fn addressMode(mode: gpu.Descriptor.AddressMode) d3d12.TEXTURE_ADDRESS_MODE {
        return switch (mode) {
            .repeat => .WRAP,
            .mirror_repeat => .MIRROR,
            .clamp_to_edge => .CLAMP,
        };
    }
};

fn setAllocationName(allocation: *d3d12ma.Allocation, name: []const u8) void {
    var buf: [256:0]u16 = undefined;
    const len = std.unicode.utf8ToUtf16Le(&buf, name) catch unreachable;
    buf[len] = 0; // null terminate
    allocation.SetName(&buf);
}

fn releaseFully(iunknown: *win32.IUnknown) void {
    var count: u32 = iunknown.AddRef();
    while (true) {
        count = iunknown.Release();
        if (count == 0) break;
    }
}

const d3d12ma = struct {
    pub const struct_Pool = opaque {};
    pub const Pool = struct_Pool;
    pub const AllocHandle = u64;
    pub const _AllocateFunctionType = ?*const fn (usize, usize, ?*anyopaque) callconv(.c) ?*anyopaque;
    pub const _FreeFunctionType = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.c) void;
    pub const struct__ALLOCATION_CALLBACKS = extern struct {
        pAllocate: [*c]_AllocateFunctionType = @import("std").mem.zeroes([*c]_AllocateFunctionType),
        pFree: [*c]_FreeFunctionType = @import("std").mem.zeroes([*c]_FreeFunctionType),
        pPrivateData: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    };
    pub const _ALLOCATION_CALLBACKS = struct__ALLOCATION_CALLBACKS;
    pub const _ALLOCATION_FLAG_NONE: c_int = 0;
    pub const _ALLOCATION_FLAG_COMMITTED: c_int = 1;
    pub const _ALLOCATION_FLAG_NEVER_ALLOCATE: c_int = 2;
    pub const _ALLOCATION_FLAG_WITHIN_BUDGET: c_int = 4;
    pub const _ALLOCATION_FLAG_UPPER_ADDRESS: c_int = 8;
    pub const _ALLOCATION_FLAG_CAN_ALIAS: c_int = 16;
    pub const _ALLOCATION_FLAG_STRATEGY_MIN_MEMORY: c_int = 65536;
    pub const _ALLOCATION_FLAG_STRATEGY_MIN_TIME: c_int = 131072;
    pub const _ALLOCATION_FLAG_STRATEGY_MIN_OFFSET: c_int = 262144;
    pub const _ALLOCATION_FLAG_STRATEGY_BEST_FIT: c_int = 65536;
    pub const _ALLOCATION_FLAG_STRATEGY_FIRST_FIT: c_int = 131072;
    pub const _ALLOCATION_FLAG_STRATEGY_MASK: c_int = 458752;
    pub const enum__ALLOCATION_FLAGS = c_uint;
    pub const _ALLOCATION_FLAGS = enum__ALLOCATION_FLAGS;
    pub const ALLOCATION_DESC = extern struct {
        Flags: _ALLOCATION_FLAGS = @import("std").mem.zeroes(_ALLOCATION_FLAGS),
        HeapType: d3d12.HEAP_TYPE = .DEFAULT,
        ExtraHeapFlags: d3d12.HEAP_FLAGS = @import("std").mem.zeroes(d3d12.HEAP_FLAGS),
        CustomPool: ?*Pool = @import("std").mem.zeroes(?*Pool),
        pPrivateData: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    };
    pub const struct_Statistics = extern struct {
        BlockCount: u32 = @import("std").mem.zeroes(u32),
        AllocationCount: u32 = @import("std").mem.zeroes(u32),
        BlockBytes: u64 = @import("std").mem.zeroes(u64),
        AllocationBytes: u64 = @import("std").mem.zeroes(u64),
    };
    pub const Statistics = struct_Statistics;
    pub const struct_DetailedStatistics = extern struct {
        Stats: Statistics = @import("std").mem.zeroes(Statistics),
        UnusedRangeCount: u32 = @import("std").mem.zeroes(u32),
        AllocationSizeMin: u64 = @import("std").mem.zeroes(u64),
        AllocationSizeMax: u64 = @import("std").mem.zeroes(u64),
        UnusedRangeSizeMin: u64 = @import("std").mem.zeroes(u64),
        UnusedRangeSizeMax: u64 = @import("std").mem.zeroes(u64),
    };
    pub const DetailedStatistics = struct_DetailedStatistics;
    pub const struct_TotalStatistics = extern struct {
        HeapType: [5]DetailedStatistics = @import("std").mem.zeroes([5]DetailedStatistics),
        MemorySegmentGroup: [2]DetailedStatistics = @import("std").mem.zeroes([2]DetailedStatistics),
        Total: DetailedStatistics = @import("std").mem.zeroes(DetailedStatistics),
    };
    pub const TotalStatistics = struct_TotalStatistics;
    pub const struct_Budget = extern struct {
        Stats: Statistics = @import("std").mem.zeroes(Statistics),
        UsageBytes: u64 = @import("std").mem.zeroes(u64),
        BudgetBytes: u64 = @import("std").mem.zeroes(u64),
    };
    pub const Budget = struct_Budget;
    pub const struct_VirtualAllocation = extern struct {
        AllocHandle: AllocHandle = @import("std").mem.zeroes(AllocHandle),
    };
    pub const VirtualAllocation = struct_VirtualAllocation;
    pub const _DEFRAGMENTATION_FLAG_ALGORITHM_FAST: c_int = 1;
    pub const _DEFRAGMENTATION_FLAG_ALGORITHM_BALANCED: c_int = 2;
    pub const _DEFRAGMENTATION_FLAG_ALGORITHM_FULL: c_int = 4;
    pub const DEFRAGMENTATION_FLAG_ALGORITHM_MASK: c_int = 7;
    pub const enum__DEFRAGMENTATION_FLAGS = c_uint;
    pub const _DEFRAGMENTATION_FLAGS = enum__DEFRAGMENTATION_FLAGS;
    pub const struct__DEFRAGMENTATION_DESC = extern struct {
        Flags: _DEFRAGMENTATION_FLAGS = @import("std").mem.zeroes(_DEFRAGMENTATION_FLAGS),
        MaxBytesPerPass: u64 = @import("std").mem.zeroes(u64),
        MaxAllocationsPerPass: u32 = @import("std").mem.zeroes(u32),
    };
    pub const _DEFRAGMENTATION_DESC = struct__DEFRAGMENTATION_DESC;
    pub const _DEFRAGMENTATION_MOVE_OPERATION_COPY: c_int = 0;
    pub const _DEFRAGMENTATION_MOVE_OPERATION_IGNORE: c_int = 1;
    pub const _DEFRAGMENTATION_MOVE_OPERATION_DESTROY: c_int = 2;
    pub const enum__DEFRAGMENTATION_MOVE_OPERATION = c_uint;
    pub const _DEFRAGMENTATION_MOVE_OPERATION = enum__DEFRAGMENTATION_MOVE_OPERATION;
    pub const struct__DEFRAGMENTATION_MOVE = extern struct {
        Operation: _DEFRAGMENTATION_MOVE_OPERATION = @import("std").mem.zeroes(_DEFRAGMENTATION_MOVE_OPERATION),
        pSrcAllocation: ?*Allocation = @import("std").mem.zeroes(?*Allocation),
        pDstTmpAllocation: ?*Allocation = @import("std").mem.zeroes(?*Allocation),
    };
    pub const _DEFRAGMENTATION_MOVE = struct__DEFRAGMENTATION_MOVE;
    pub const struct__DEFRAGMENTATION_PASS_MOVE_INFO = extern struct {
        MoveCount: u32 = @import("std").mem.zeroes(u32),
        pMoves: [*c]_DEFRAGMENTATION_MOVE = @import("std").mem.zeroes([*c]_DEFRAGMENTATION_MOVE),
    };
    pub const _DEFRAGMENTATION_PASS_MOVE_INFO = struct__DEFRAGMENTATION_PASS_MOVE_INFO;
    pub const struct__DEFRAGMENTATION_STATS = extern struct {
        BytesMoved: u64 = @import("std").mem.zeroes(u64),
        BytesFreed: u64 = @import("std").mem.zeroes(u64),
        AllocationsMoved: u32 = @import("std").mem.zeroes(u32),
        HeapsFreed: u32 = @import("std").mem.zeroes(u32),
    };
    pub const _DEFRAGMENTATION_STATS = struct__DEFRAGMENTATION_STATS;
    pub const struct_DefragmentationContext = opaque {};
    pub const DefragmentationContext = struct_DefragmentationContext;
    pub const _POOL_FLAG_NONE: c_int = 0;
    pub const _POOL_FLAG_ALGORITHM_LINEAR: c_int = 1;
    pub const _POOL_FLAG_MSAA_TEXTURES_ALWAYS_COMMITTED: c_int = 2;
    pub const _POOL_FLAG_ALGORITHM_MASK: c_int = 1;
    pub const enum__POOL_FLAGS = c_uint;
    pub const _POOL_FLAGS = enum__POOL_FLAGS;
    pub const struct__POOL_DESC = extern struct {
        Flags: _POOL_FLAGS = @import("std").mem.zeroes(_POOL_FLAGS),
        HeapProperties: d3d12.HEAP_PROPERTIES = @import("std").mem.zeroes(d3d12.HEAP_PROPERTIES),
        HeapFlags: d3d12.HEAP_FLAGS = @import("std").mem.zeroes(d3d12.HEAP_FLAGS),
        BlockSize: u64 = @import("std").mem.zeroes(u64),
        MinBlockCount: u32 = @import("std").mem.zeroes(u32),
        MaxBlockCount: u32 = @import("std").mem.zeroes(u32),
        MinAllocationAlignment: u64 = @import("std").mem.zeroes(u64),
        pProtectedSession: [*c]d3d12.IProtectedResourceSession = @import("std").mem.zeroes([*c]d3d12.IProtectedResourceSession),
        ResidencyPriority: d3d12.RESIDENCY_PRIORITY = @import("std").mem.zeroes(d3d12.RESIDENCY_PRIORITY),
    };
    pub const _POOL_DESC = struct__POOL_DESC;
    pub const _ALLOCATOR_FLAG_NONE: c_int = 0;
    pub const _ALLOCATOR_FLAG_SINGLETHREADED: c_int = 1;
    pub const _ALLOCATOR_FLAG_ALWAYS_COMMITTED: c_int = 2;
    pub const _ALLOCATOR_FLAG_DEFAULT_POOLS_NOT_ZEROED: c_int = 4;
    pub const _ALLOCATOR_FLAG_MSAA_TEXTURES_ALWAYS_COMMITTED: c_int = 8;
    pub const _ALLOCATOR_FLAG_DONT_PREFER_SMALL_BUFFERS_COMMITTED: c_int = 16;
    pub const enum__ALLOCATOR_FLAGS = c_uint;
    pub const _ALLOCATOR_FLAGS = enum__ALLOCATOR_FLAGS;
    pub const ALLOCATOR_DESC = extern struct {
        Flags: _ALLOCATOR_FLAGS = @import("std").mem.zeroes(_ALLOCATOR_FLAGS),
        pDevice: [*c]d3d12.IDevice = @import("std").mem.zeroes([*c]d3d12.IDevice),
        PreferredBlockSize: u64 = @import("std").mem.zeroes(u64),
        pAllocationCallbacks: [*c]const _ALLOCATION_CALLBACKS = @import("std").mem.zeroes([*c]const _ALLOCATION_CALLBACKS),
        pAdapter: [*c]dxgi.IAdapter = @import("std").mem.zeroes([*c]dxgi.IAdapter),
    };
    pub const _VIRTUAL_BLOCK_FLAG_NONE: c_int = 0;
    pub const _VIRTUAL_BLOCK_FLAG_ALGORITHM_LINEAR: c_int = 1;
    pub const _VIRTUAL_BLOCK_FLAG_ALGORITHM_MASK: c_int = 1;
    pub const enum__VIRTUAL_BLOCK_FLAGS = c_uint;
    pub const _VIRTUAL_BLOCK_FLAGS = enum__VIRTUAL_BLOCK_FLAGS;
    pub const struct__VIRTUAL_BLOCK_DESC = extern struct {
        Flags: _VIRTUAL_BLOCK_FLAGS = @import("std").mem.zeroes(_VIRTUAL_BLOCK_FLAGS),
        Size: u64 = @import("std").mem.zeroes(u64),
        pAllocationCallbacks: [*c]const _ALLOCATION_CALLBACKS = @import("std").mem.zeroes([*c]const _ALLOCATION_CALLBACKS),
    };
    pub const _VIRTUAL_BLOCK_DESC = struct__VIRTUAL_BLOCK_DESC;
    pub const _VIRTUAL_ALLOCATION_FLAG_NONE: c_int = 0;
    pub const _VIRTUAL_ALLOCATION_FLAG_UPPER_ADDRESS: c_int = 8;
    pub const _VIRTUAL_ALLOCATION_FLAG_STRATEGY_MIN_MEMORY: c_int = 65536;
    pub const _VIRTUAL_ALLOCATION_FLAG_STRATEGY_MIN_TIME: c_int = 131072;
    pub const _VIRTUAL_ALLOCATION_FLAG_STRATEGY_MIN_OFFSET: c_int = 262144;
    pub const _VIRTUAL_ALLOCATION_FLAG_STRATEGY_MASK: c_int = 458752;
    pub const enum__VIRTUAL_ALLOCATION_FLAGS = c_uint;
    pub const _VIRTUAL_ALLOCATION_FLAGS = enum__VIRTUAL_ALLOCATION_FLAGS;
    pub const struct__VIRTUAL_ALLOCATION_DESC = extern struct {
        Flags: _VIRTUAL_ALLOCATION_FLAGS = @import("std").mem.zeroes(_VIRTUAL_ALLOCATION_FLAGS),
        Size: u64 = @import("std").mem.zeroes(u64),
        Alignment: u64 = @import("std").mem.zeroes(u64),
        pPrivateData: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    };
    pub const _VIRTUAL_ALLOCATION_DESC = struct__VIRTUAL_ALLOCATION_DESC;
    pub const struct__VIRTUAL_ALLOCATION_INFO = extern struct {
        Offset: u64 = @import("std").mem.zeroes(u64),
        Size: u64 = @import("std").mem.zeroes(u64),
        pPrivateData: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    };
    pub const _VIRTUAL_ALLOCATION_INFO = struct__VIRTUAL_ALLOCATION_INFO;
    pub const struct_VirtualBlock = opaque {};
    pub const VirtualBlock = struct_VirtualBlock;
    extern fn D3D12MADefragmentationContext_BeginPass(pSelf: ?*anyopaque, pPassInfo: [*c]_DEFRAGMENTATION_PASS_MOVE_INFO) win32.HRESULT;
    extern fn D3D12MADefragmentationContext_EndPass(pSelf: ?*anyopaque, pPassInfo: [*c]_DEFRAGMENTATION_PASS_MOVE_INFO) win32.HRESULT;
    extern fn D3D12MADefragmentationContext_GetStats(pSelf: ?*anyopaque, pStats: [*c]_DEFRAGMENTATION_STATS) void;
    extern fn D3D12MAPool_GetDesc(pSelf: ?*anyopaque) _POOL_DESC;
    extern fn D3D12MAPool_GetStatistics(pSelf: ?*anyopaque, pStats: [*c]Statistics) void;
    extern fn D3D12MAPool_CalculateStatistics(pSelf: ?*anyopaque, pStats: [*c]DetailedStatistics) void;
    extern fn D3D12MAPool_SetName(pSelf: ?*anyopaque, Name: win32.LPCWSTR) void;
    extern fn D3D12MAPool_GetName(pSelf: ?*anyopaque) win32.LPCWSTR;
    extern fn D3D12MAPool_BeginDefragmentation(pSelf: ?*anyopaque, pDesc: [*c]const _DEFRAGMENTATION_DESC, ppContext: [*c]?*DefragmentationContext) win32.HRESULT;

    pub const Allocator = opaque {
        pub inline fn Create(pDesc: *const ALLOCATOR_DESC, ppAllocator: *?*Allocator) win32.HRESULT {
            return D3D12MACreateAllocator(pDesc, ppAllocator);
        }

        pub inline fn Release(self: *Allocator) void {
            _ = D3D12MAAllocator_Release(self);
        }

        pub inline fn CreateResource(
            self: *Allocator,
            pAllocDesc: *const ALLOCATION_DESC,
            pResourceDesc: *const d3d12.RESOURCE_DESC,
            InitialResourceState: d3d12.RESOURCE_STATES,
            pOptimizedClearValue: ?*const d3d12.CLEAR_VALUE,
            ppAllocation: *?*Allocation,
            riidResource: *const win32.GUID,
            ppvResource: *?*anyopaque,
        ) win32.HRESULT {
            return D3D12MAAllocator_CreateResource(
                self,
                pAllocDesc,
                pResourceDesc,
                InitialResourceState,
                pOptimizedClearValue,
                ppAllocation,
                riidResource,
                ppvResource,
            );
        }

        pub inline fn CreateResource3(
            self: *Allocator,
            pAllocDesc: *const ALLOCATION_DESC,
            pResourceDesc: *const d3d12.RESOURCE_DESC1,
            InitialLayout: d3d12.BARRIER_LAYOUT,
            pOptimizedClearValue: ?*const d3d12.CLEAR_VALUE,
            NumCastableFormats: u32,
            pCastableFormats: ?[*]const dxgi.FORMAT,
            ppAllocation: *?*Allocation,
            riidResource: *const win32.GUID,
            ppvResource: *?*anyopaque,
        ) win32.HRESULT {
            return D3D12MAAllocator_CreateResource3(
                self,
                pAllocDesc,
                pResourceDesc,
                InitialLayout,
                pOptimizedClearValue,
                NumCastableFormats,
                @ptrCast(pCastableFormats),
                ppAllocation,
                riidResource,
                ppvResource,
            );
        }

        pub inline fn CreateAliasingResource(
            self: *Allocator,
            pAllocation: ?*Allocation,
            AllocationLocalOffset: u64,
            pResourceDesc: *const d3d12.RESOURCE_DESC,
            InitialResourceState: d3d12.RESOURCE_STATES,
            pOptimizedClearValue: ?*const d3d12.CLEAR_VALUE,
            riidResource: *const win32.GUID,
            ppvResource: *?*anyopaque,
        ) win32.HRESULT {
            return D3D12MAAllocator_CreateAliasingResource(
                self,
                pAllocation,
                AllocationLocalOffset,
                pResourceDesc,
                InitialResourceState,
                pOptimizedClearValue,
                riidResource,
                ppvResource,
            );
        }

        pub inline fn AllocateMemory(
            self: *Allocator,
            pAllocDesc: *const ALLOCATION_DESC,
            pAllocInfo: *const d3d12.RESOURCE_ALLOCATION_INFO,
            ppAllocation: *?*Allocation,
        ) win32.HRESULT {
            return D3D12MAAllocator_AllocateMemory(
                self,
                pAllocDesc,
                pAllocInfo,
                ppAllocation,
            );
        }

        pub inline fn SetCurrentFrameIndex(self: *Allocator, FrameIndex: u32) void {
            D3D12MAAllocator_SetCurrentFrameIndex(self, FrameIndex);
        }

        extern fn D3D12MAAllocator_GetD3D12Options(pSelf: ?*anyopaque) [*c]const d3d12.FEATURE_DATA_D3D12_OPTIONS;
        extern fn D3D12MAAllocator_IsUMA(pSelf: ?*anyopaque) win32.BOOL;
        extern fn D3D12MAAllocator_IsCacheCoherentUMA(pSelf: ?*anyopaque) win32.BOOL;
        extern fn D3D12MAAllocator_IsGPUUploadHeapSupported(pSelf: ?*anyopaque) win32.BOOL;
        extern fn D3D12MAAllocator_GetMemoryCapacity(pSelf: ?*anyopaque, MemorySegmentGroup: u32) u64;
        extern fn D3D12MAAllocator_CreateResource(pSelf: ?*anyopaque, pAllocDesc: [*c]const ALLOCATION_DESC, pResourceDesc: [*c]const d3d12.RESOURCE_DESC, InitialResourceState: d3d12.RESOURCE_STATES, pOptimizedClearValue: [*c]const d3d12.CLEAR_VALUE, ppAllocation: [*c]?*Allocation, riidResource: [*c]const win32.GUID, ppvResource: [*c]?*anyopaque) win32.HRESULT;
        extern fn D3D12MAAllocator_CreateResource2(pSelf: ?*anyopaque, pAllocDesc: [*c]const ALLOCATION_DESC, pResourceDesc: [*c]const d3d12.RESOURCE_DESC1, InitialResourceState: d3d12.RESOURCE_STATES, pOptimizedClearValue: [*c]const d3d12.CLEAR_VALUE, ppAllocation: [*c]?*Allocation, riidResource: [*c]const win32.GUID, ppvResource: [*c]?*anyopaque) win32.HRESULT;
        extern fn D3D12MAAllocator_CreateResource3(pSelf: ?*anyopaque, pAllocDesc: [*c]const ALLOCATION_DESC, pResourceDesc: [*c]const d3d12.RESOURCE_DESC1, InitialLayout: d3d12.BARRIER_LAYOUT, pOptimizedClearValue: [*c]const d3d12.CLEAR_VALUE, NumCastableFormats: u32, pCastableFormats: [*c]const dxgi.FORMAT, ppAllocation: [*c]?*Allocation, riidResource: [*c]const win32.GUID, ppvResource: [*c]?*anyopaque) win32.HRESULT;
        extern fn D3D12MAAllocator_AllocateMemory(pSelf: ?*anyopaque, pAllocDesc: [*c]const ALLOCATION_DESC, pAllocInfo: [*c]const d3d12.RESOURCE_ALLOCATION_INFO, ppAllocation: [*c]?*Allocation) win32.HRESULT;
        extern fn D3D12MAAllocator_CreateAliasingResource(pSelf: ?*anyopaque, pAllocation: ?*Allocation, AllocationLocalOffset: u64, pResourceDesc: [*c]const d3d12.RESOURCE_DESC, InitialResourceState: d3d12.RESOURCE_STATES, pOptimizedClearValue: [*c]const d3d12.CLEAR_VALUE, riidResource: [*c]const win32.GUID, ppvResource: [*c]?*anyopaque) win32.HRESULT;
        extern fn D3D12MAAllocator_CreateAliasingResource1(pSelf: ?*anyopaque, pAllocation: ?*Allocation, AllocationLocalOffset: u64, pResourceDesc: [*c]const d3d12.RESOURCE_DESC1, InitialResourceState: d3d12.RESOURCE_STATES, pOptimizedClearValue: [*c]const d3d12.CLEAR_VALUE, riidResource: [*c]const win32.GUID, ppvResource: [*c]?*anyopaque) win32.HRESULT;
        extern fn D3D12MAAllocator_CreateAliasingResource2(pSelf: ?*anyopaque, pAllocation: ?*Allocation, AllocationLocalOffset: u64, pResourceDesc: [*c]const d3d12.RESOURCE_DESC1, InitialLayout: d3d12.BARRIER_LAYOUT, pOptimizedClearValue: [*c]const d3d12.CLEAR_VALUE, NumCastableFormats: u32, pCastableFormats: [*c]dxgi.FORMAT, riidResource: [*c]const win32.GUID, ppvResource: [*c]?*anyopaque) win32.HRESULT;
        extern fn D3D12MAAllocator_CreatePool(pSelf: ?*anyopaque, pPoolDesc: [*c]const _POOL_DESC, ppPool: [*c]?*Pool) win32.HRESULT;
        extern fn D3D12MAAllocator_SetCurrentFrameIndex(pSelf: ?*anyopaque, FrameIndex: u32) void;
        extern fn D3D12MAAllocator_GetBudget(pSelf: ?*anyopaque, pLocalBudget: [*c]Budget, pNonLocalBudget: [*c]Budget) void;
        extern fn D3D12MAAllocator_CalculateStatistics(pSelf: ?*anyopaque, pStats: [*c]TotalStatistics) void;
        extern fn D3D12MAAllocator_BuildStatsString(pSelf: ?*anyopaque, ppStatsString: [*c][*c]win32.WCHAR, DetailedMap: win32.BOOL) void;
        extern fn D3D12MAAllocator_FreeStatsString(pSelf: ?*anyopaque, pStatsString: [*c]win32.WCHAR) void;
        extern fn D3D12MAAllocator_BeginDefragmentation(pSelf: ?*anyopaque, pDesc: [*c]const _DEFRAGMENTATION_DESC, ppContext: [*c]?*DefragmentationContext) void;
    };
    extern fn D3D12MAVirtualBlock_IsEmpty(pSelf: ?*anyopaque) win32.BOOL;
    extern fn D3D12MAVirtualBlock_GetAllocationInfo(pSelf: ?*anyopaque, Allocation: VirtualAllocation, pInfo: [*c]_VIRTUAL_ALLOCATION_INFO) void;
    extern fn D3D12MAVirtualBlock_Allocate(pSelf: ?*anyopaque, pDesc: [*c]const _VIRTUAL_ALLOCATION_DESC, pAllocation: [*c]VirtualAllocation, pOffset: [*c]u64) win32.HRESULT;
    extern fn D3D12MAVirtualBlock_FreeAllocation(pSelf: ?*anyopaque, Allocation: VirtualAllocation) void;
    extern fn D3D12MAVirtualBlock_Clear(pSelf: ?*anyopaque) void;
    extern fn D3D12MAVirtualBlock_SetAllocationPrivateData(pSelf: ?*anyopaque, Allocation: VirtualAllocation, pPrivateData: ?*anyopaque) void;
    extern fn D3D12MAVirtualBlock_GetStatistics(pSelf: ?*anyopaque, pStats: [*c]Statistics) void;
    extern fn D3D12MAVirtualBlock_CalculateStatistics(pSelf: ?*anyopaque, pStats: [*c]DetailedStatistics) void;
    extern fn D3D12MAVirtualBlock_BuildStatsString(pSelf: ?*anyopaque, ppStatsString: [*c][*c]win32.WCHAR) void;
    extern fn D3D12MAVirtualBlock_FreeStatsString(pSelf: ?*anyopaque, pStatsString: [*c]win32.WCHAR) void;
    extern fn D3D12MACreateAllocator(pDesc: [*c]const ALLOCATOR_DESC, ppAllocator: [*c]?*Allocator) win32.HRESULT;
    extern fn D3D12MACreateVirtualBlock(pDesc: [*c]const _VIRTUAL_BLOCK_DESC, ppVirtualBlock: [*c]?*VirtualBlock) win32.HRESULT;
    pub const Allocation = opaque {
        pub inline fn Release(self: *Allocation) void {
            _ = D3D12MAAllocation_Release(self);
        }

        pub inline fn GetHeap(self: *Allocation) *d3d12.IHeap {
            return D3D12MAAllocation_GetHeap(self);
        }

        pub inline fn SetName(self: *Allocation, name: [*:0]const u16) void {
            D3D12MAAllocation_SetName(self, name);
        }

        extern fn D3D12MAAllocation_QueryInterface(pSelf: ?*anyopaque, riid: [*c]const win32.GUID, ppvObject: [*c]?*anyopaque) win32.HRESULT;
        extern fn D3D12MAAllocation_AddRef(pSelf: ?*anyopaque) win32.ULONG;
        extern fn D3D12MAAllocation_Release(pSelf: ?*anyopaque) win32.ULONG;

        extern fn D3D12MAAllocation_GetOffset(pSelf: ?*anyopaque) u64;
        extern fn D3D12MAAllocation_GetAlignment(pSelf: ?*anyopaque) u64;
        extern fn D3D12MAAllocation_GetSize(pSelf: ?*anyopaque) u64;
        extern fn D3D12MAAllocation_GetResource(pSelf: ?*anyopaque) [*c]d3d12.IResource;
        extern fn D3D12MAAllocation_SetResource(pSelf: ?*anyopaque, pResource: [*c]d3d12.IResource) void;
        extern fn D3D12MAAllocation_GetHeap(pSelf: ?*anyopaque) [*c]d3d12.IHeap;
        extern fn D3D12MAAllocation_SetPrivateData(pSelf: ?*anyopaque, pPrivateData: ?*anyopaque) void;
        extern fn D3D12MAAllocation_GetPrivateData(pSelf: ?*anyopaque) ?*anyopaque;
        extern fn D3D12MAAllocation_SetName(pSelf: ?*anyopaque, Name: win32.LPCWSTR) void;
        extern fn D3D12MAAllocation_GetName(pSelf: ?*anyopaque) win32.LPCWSTR;
    };
    extern fn D3D12MADefragmentationContext_QueryInterface(pSelf: ?*anyopaque, riid: [*c]const win32.GUID, ppvObject: [*c]?*anyopaque) win32.HRESULT;
    extern fn D3D12MADefragmentationContext_AddRef(pSelf: ?*anyopaque) win32.ULONG;
    extern fn D3D12MADefragmentationContext_Release(pSelf: ?*anyopaque) win32.ULONG;
    extern fn D3D12MAPool_QueryInterface(pSelf: ?*anyopaque, riid: [*c]const win32.GUID, ppvObject: [*c]?*anyopaque) win32.HRESULT;
    extern fn D3D12MAPool_AddRef(pSelf: ?*anyopaque) win32.ULONG;
    extern fn D3D12MAPool_Release(pSelf: ?*anyopaque) win32.ULONG;
    extern fn D3D12MAAllocator_QueryInterface(pSelf: ?*anyopaque, riid: [*c]const win32.GUID, ppvObject: [*c]?*anyopaque) win32.HRESULT;
    extern fn D3D12MAAllocator_AddRef(pSelf: ?*anyopaque) win32.ULONG;
    extern fn D3D12MAAllocator_Release(pSelf: ?*anyopaque) win32.ULONG;
    extern fn D3D12MAVirtualBlock_QueryInterface(pSelf: ?*anyopaque, riid: [*c]const win32.GUID, ppvObject: [*c]?*anyopaque) win32.HRESULT;
    extern fn D3D12MAVirtualBlock_AddRef(pSelf: ?*anyopaque) win32.ULONG;
    extern fn D3D12MAVirtualBlock_Release(pSelf: ?*anyopaque) win32.ULONG;
};

const is_xbox = false;

const std = @import("std");
const gpu = @import("root.zig");
const Error = gpu.Error;

const spatial = @import("../math/spatial.zig");

const windows = @import("../vendor/windows/root.zig");
const win32 = windows.win32;
const dxgi = windows.dxgi;
const d3d12 = windows.d3d12;
const d3d12d = windows.d3d12sdklayers;
const d3dcommon = windows.d3dcommon;

pub const log = std.log.scoped(.d3d12);

const utils = @import("utils.zig");
const InlineStorage = utils.InlineStorage;
const OffsetAllocator = @import("OffsetAllocator.zig");
const StaticRingBuffer = utils.StaticRingBuffer;
