const std = @import("std");

const windows = @import("win32.zig");
const UINT = windows.UINT;
const IUnknown = windows.IUnknown;
const HRESULT = windows.HRESULT;
const GUID = windows.GUID;
const LUID = windows.LUID;
const FLOAT = windows.FLOAT;
const LPCWSTR = windows.LPCWSTR;
const LPCSTR = windows.LPCSTR;
const UINT8 = windows.UINT8;
const UINT16 = windows.UINT16;
const UINT32 = windows.UINT32;
const UINT64 = windows.UINT64;
const INT = windows.INT;
const INT8 = windows.INT8;
const BYTE = windows.BYTE;
const DWORD = windows.DWORD;
const SIZE_T = windows.SIZE_T;
const HANDLE = windows.HANDLE;
const SECURITY_ATTRIBUTES = windows.SECURITY_ATTRIBUTES;
const BOOL = windows.BOOL;

const dxgi = @import("dxgi.zig");
const d3d = @import("d3dcommon.zig");

pub const req_blend_object_count_per_device: u32 = 4096;
pub const req_buffer_resource_texel_count_2_to_exp: u32 = 27;
pub const req_constant_buffer_element_count: u32 = 4096;
pub const req_depth_stencil_object_count_per_device: u32 = 4096;
pub const req_drawindexed_index_count_2_to_exp: u32 = 32;
pub const req_draw_vertex_count_2_to_exp: u32 = 32;
pub const req_filtering_hw_addressable_resource_dimension: u32 = 16384;
pub const req_gs_invocation_32bit_output_component_limit: u32 = 1024;
pub const req_immediate_constant_buffer_element_count: u32 = 4096;
pub const req_maxanisotropy: u32 = 16;
pub const req_mip_levels: u32 = 15;
pub const req_multi_element_structure_size_in_bytes: u32 = 2048;
pub const req_rasterizer_object_count_per_device: u32 = 4096;
pub const req_render_to_buffer_window_width: u32 = 16384;
pub const req_resource_size_in_megabytes_expression_a_term: u32 = 128;
pub const req_resource_size_in_megabytes_expression_b_term: f32 = 0.25;
pub const req_resource_size_in_megabytes_expression_c_term: u32 = 2048;
pub const req_resource_view_count_per_device_2_to_exp: u32 = 20;
pub const req_sampler_object_count_per_device: u32 = 4096;
pub const req_subresources: u32 = 30720;
pub const req_texture1d_array_axis_dimension: u32 = 2024;
pub const req_texture1d_u_dimension: u32 = 16384;
pub const req_texture2d_array_axis_dimension: u32 = 2024;
pub const req_texture2d_u_or_v_dimension: u32 = 16384;
pub const req_texture3d_u_v_or_w_dimension: u32 = 2048;
pub const req_texturecube_dimension: u32 = 16384;

pub const RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xffff_ffff;

pub const SHADER_IDENTIFIER_SIZE_IN_BYTES = 32;

pub const DEFAULT_MSAA_RESOURCE_PLACEMENT_ALIGNMENT: UINT64 = 4 * 1024 * 1024;
pub const DEFAULT_RESOURCE_PLACEMENT_ALIGNMENT: UINT64 = 64 * 1024;
pub const CONSTANT_BUFFER_DATA_PLACEMENT_ALIGNMENT = 256;

pub const GPU_VIRTUAL_ADDRESS = UINT64;

pub const PRIMITIVE_TOPOLOGY = d3d.PRIMITIVE_TOPOLOGY;

pub const CPU_DESCRIPTOR_HANDLE = extern struct {
    ptr: UINT64,
};

pub const GPU_DESCRIPTOR_HANDLE = extern struct {
    ptr: UINT64,
};

pub const PRIMITIVE_TOPOLOGY_TYPE = enum(UINT) {
    UNDEFINED = 0,
    POINT = 1,
    LINE = 2,
    TRIANGLE = 3,
    PATCH = 4,
};

pub const HEAP_TYPE = enum(UINT) {
    DEFAULT = 1,
    UPLOAD = 2,
    READBACK = 3,
    CUSTOM = 4,
};

pub const CPU_PAGE_PROPERTY = enum(UINT) {
    UNKNOWN = 0,
    NOT_AVAILABLE = 1,
    WRITE_COMBINE = 2,
    WRITE_BACK = 3,
};

pub const MEMORY_POOL = enum(UINT) {
    UNKNOWN = 0,
    L0 = 1,
    L1 = 2,
};

pub const HEAP_PROPERTIES = extern struct {
    Type: HEAP_TYPE,
    CPUPageProperty: CPU_PAGE_PROPERTY,
    MemoryPoolPreference: MEMORY_POOL,
    CreationNodeMask: UINT,
    VisibleNodeMask: UINT,

    pub fn initType(heap_type: HEAP_TYPE) HEAP_PROPERTIES {
        var v = std.mem.zeroes(@This());
        v = HEAP_PROPERTIES{
            .Type = heap_type,
            .CPUPageProperty = .UNKNOWN,
            .MemoryPoolPreference = .UNKNOWN,
            .CreationNodeMask = 0,
            .VisibleNodeMask = 0,
        };
        return v;
    }
};

pub const HEAP_FLAGS = packed struct(UINT) {
    SHARED: bool = false,
    __unused1: bool = false,
    DENY_BUFFERS: bool = false,
    ALLOW_DISPLAY: bool = false,
    __unused4: bool = false,
    SHARED_CROSS_ADAPTER: bool = false,
    DENY_RT_DS_TEXTURES: bool = false,
    DENY_NON_RT_DS_TEXTURES: bool = false,
    HARDWARE_PROTECTED: bool = false,
    ALLOW_WRITE_WATCH: bool = false,
    ALLOW_SHADER_ATOMICS: bool = false,
    CREATE_NOT_RESIDENT: bool = false,
    CREATE_NOT_ZEROED: bool = false,
    __unused: u19 = 0,

    pub const ALLOW_ALL_BUFFERS_AND_TEXTURES = HEAP_FLAGS{};
    pub const ALLOW_ONLY_NON_RT_DS_TEXTURES = HEAP_FLAGS{ .DENY_BUFFERS = true, .DENY_RT_DS_TEXTURES = true };
    pub const ALLOW_ONLY_BUFFERS = HEAP_FLAGS{ .DENY_RT_DS_TEXTURES = true, .DENY_NON_RT_DS_TEXTURES = true };
    pub const HEAP_FLAG_ALLOW_ONLY_RT_DS_TEXTURES = HEAP_FLAGS{
        .DENY_BUFFERS = true,
        .DENY_NON_RT_DS_TEXTURES = true,
    };
};

pub const HEAP_DESC = extern struct {
    SizeInBytes: UINT64,
    Properties: HEAP_PROPERTIES,
    Alignment: UINT64,
    Flags: HEAP_FLAGS,
};

pub const RANGE = extern struct {
    Begin: UINT64,
    End: UINT64,
};

pub const BOX = extern struct {
    left: UINT,
    top: UINT,
    front: UINT,
    right: UINT,
    bottom: UINT,
    back: UINT,
};

pub const RESOURCE_DIMENSION = enum(UINT) {
    UNKNOWN = 0,
    BUFFER = 1,
    TEXTURE1D = 2,
    TEXTURE2D = 3,
    TEXTURE3D = 4,
};

pub const TEXTURE_LAYOUT = enum(UINT) {
    UNKNOWN = 0,
    ROW_MAJOR = 1,
    @"64KB_UNDEFINED_SWIZZLE" = 2,
    @"64KB_STANDARD_SWIZZLE" = 3,
};

pub const RESOURCE_FLAGS = packed struct(UINT) {
    ALLOW_RENDER_TARGET: bool = false,
    ALLOW_DEPTH_STENCIL: bool = false,
    ALLOW_UNORDERED_ACCESS: bool = false,
    DENY_SHADER_RESOURCE: bool = false,
    ALLOW_CROSS_ADAPTER: bool = false,
    ALLOW_SIMULTANEOUS_ACCESS: bool = false,
    VIDEO_DECODE_REFERENCE_ONLY: bool = false,
    VIDEO_ENCODE_REFERENCE_ONLY: bool = false,
    __unused: u24 = 0,
};

pub const RESOURCE_DESC = extern struct {
    Dimension: RESOURCE_DIMENSION,
    Alignment: UINT64,
    Width: UINT64,
    Height: UINT,
    DepthOrArraySize: UINT16,
    MipLevels: UINT16,
    Format: dxgi.FORMAT,
    SampleDesc: dxgi.SAMPLE_DESC,
    Layout: TEXTURE_LAYOUT,
    Flags: RESOURCE_FLAGS,

    pub fn initBuffer(width: UINT64) RESOURCE_DESC {
        var v = std.mem.zeroes(@This());
        v = .{
            .Dimension = .BUFFER,
            .Alignment = 0,
            .Width = width,
            .Height = 1,
            .DepthOrArraySize = 1,
            .MipLevels = 1,
            .Format = .UNKNOWN,
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .Layout = .ROW_MAJOR,
            .Flags = .{},
        };
        return v;
    }

    pub fn initTex2d(format: dxgi.FORMAT, width: UINT64, height: UINT, mip_levels: u32) RESOURCE_DESC {
        var v = std.mem.zeroes(@This());
        v = .{
            .Dimension = .TEXTURE2D,
            .Alignment = 0,
            .Width = width,
            .Height = height,
            .DepthOrArraySize = 1,
            .MipLevels = @as(u16, @intCast(mip_levels)),
            .Format = format,
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .Layout = .UNKNOWN,
            .Flags = .{},
        };
        return v;
    }

    pub fn initDepthBuffer(format: dxgi.FORMAT, width: UINT64, height: UINT) RESOURCE_DESC {
        var v = std.mem.zeroes(@This());
        v = .{
            .Dimension = .TEXTURE2D,
            .Alignment = 0,
            .Width = width,
            .Height = height,
            .DepthOrArraySize = 1,
            .MipLevels = 1,
            .Format = format,
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .Layout = .UNKNOWN,
            .Flags = .{ .ALLOW_DEPTH_STENCIL = true, .DENY_SHADER_RESOURCE = true },
        };
        return v;
    }

    pub fn initTexCube(format: dxgi.FORMAT, width: UINT64, height: UINT, mip_levels: u32) RESOURCE_DESC {
        var v = std.mem.zeroes(@This());
        v = .{
            .Dimension = .TEXTURE2D,
            .Alignment = 0,
            .Width = width,
            .Height = height,
            .DepthOrArraySize = 6,
            .MipLevels = @as(u16, @intCast(mip_levels)),
            .Format = format,
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .Layout = .UNKNOWN,
            .Flags = .{},
        };
        return v;
    }

    pub fn initFrameBuffer(format: dxgi.FORMAT, width: UINT64, height: UINT, sample_count: u32) RESOURCE_DESC {
        var v = std.mem.zeroes(@This());
        v = .{
            .Dimension = .TEXTURE2D,
            .Alignment = 0,
            .Width = width,
            .Height = height,
            .DepthOrArraySize = 1,
            .MipLevels = 1,
            .Format = format,
            .SampleDesc = .{ .Count = sample_count, .Quality = 0 },
            .Layout = .UNKNOWN,
            .Flags = .{ .ALLOW_RENDER_TARGET = true },
        };
        return v;
    }
};

pub const FENCE_FLAGS = packed struct(UINT) {
    SHARED: bool = false,
    SHARED_CROSS_ADAPTER: bool = false,
    NON_MONITORED: bool = false,
    __unused: u29 = 0,
};

pub const DESCRIPTOR_HEAP_TYPE = enum(UINT) {
    CBV_SRV_UAV = 0,
    SAMPLER = 1,
    RTV = 2,
    DSV = 3,
};

pub const DESCRIPTOR_HEAP_FLAGS = packed struct(UINT) {
    SHADER_VISIBLE: bool = false,
    __unused: u31 = 0,
};

pub const DESCRIPTOR_HEAP_DESC = extern struct {
    Type: DESCRIPTOR_HEAP_TYPE,
    NumDescriptors: UINT,
    Flags: DESCRIPTOR_HEAP_FLAGS,
    NodeMask: UINT,
};

pub const DESCRIPTOR_RANGE_TYPE = enum(UINT) {
    SRV = 0,
    UAV = 1,
    CBV = 2,
    SAMPLER = 3,
};

pub const DESCRIPTOR_RANGE = extern struct {
    RangeType: DESCRIPTOR_RANGE_TYPE,
    NumDescriptors: UINT,
    BaseShaderRegister: UINT,
    RegisterSpace: UINT,
    OffsetInDescriptorsFromStart: UINT,
};

pub const ROOT_DESCRIPTOR_TABLE = extern struct {
    NumDescriptorRanges: UINT,
    pDescriptorRanges: ?[*]const DESCRIPTOR_RANGE,
};

pub const ROOT_CONSTANTS = extern struct {
    ShaderRegister: UINT,
    RegisterSpace: UINT,
    Num32BitValues: UINT,
};

pub const ROOT_DESCRIPTOR = extern struct {
    ShaderRegister: UINT,
    RegisterSpace: UINT,
};

pub const ROOT_PARAMETER_TYPE = enum(UINT) {
    DESCRIPTOR_TABLE = 0,
    @"32BIT_CONSTANTS" = 1,
    CBV = 2,
    SRV = 3,
    UAV = 4,
};

pub const SHADER_VISIBILITY = enum(UINT) {
    ALL = 0,
    VERTEX = 1,
    HULL = 2,
    DOMAIN = 3,
    GEOMETRY = 4,
    PIXEL = 5,
    AMPLIFICATION = 6,
    MESH = 7,
};

pub const ROOT_PARAMETER = extern struct {
    ParameterType: ROOT_PARAMETER_TYPE,
    u: extern union {
        DescriptorTable: ROOT_DESCRIPTOR_TABLE,
        Constants: ROOT_CONSTANTS,
        Descriptor: ROOT_DESCRIPTOR,
    },
    ShaderVisibility: SHADER_VISIBILITY,
};

pub const STATIC_BORDER_COLOR = enum(UINT) {
    TRANSPARENT_BLACK = 0,
    OPAQUE_BLACK = 1,
    OPAQUE_WHITE = 2,
};

pub const STATIC_SAMPLER_DESC = extern struct {
    Filter: FILTER,
    AddressU: TEXTURE_ADDRESS_MODE,
    AddressV: TEXTURE_ADDRESS_MODE,
    AddressW: TEXTURE_ADDRESS_MODE,
    MipLODBias: FLOAT,
    MaxAnisotropy: UINT,
    ComparisonFunc: COMPARISON_FUNC,
    BorderColor: STATIC_BORDER_COLOR,
    MinLOD: FLOAT,
    MaxLOD: FLOAT,
    ShaderRegister: UINT,
    RegisterSpace: UINT,
    ShaderVisibility: SHADER_VISIBILITY,
};

pub const ROOT_SIGNATURE_FLAGS = packed struct(UINT) {
    ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT: bool = false,
    DENY_VERTEX_SHADER_ROOT_ACCESS: bool = false,
    DENY_HULL_SHADER_ROOT_ACCESS: bool = false,
    DENY_DOMAIN_SHADER_ROOT_ACCESS: bool = false,
    DENY_GEOMETRY_SHADER_ROOT_ACCESS: bool = false,
    DENY_PIXEL_SHADER_ROOT_ACCESS: bool = false,
    ALLOW_STREAM_OUTPUT: bool = false,
    LOCAL_ROOT_SIGNATURE: bool = false,
    DENY_AMPLIFICATION_SHADER_ROOT_ACCESS: bool = false,
    DENY_MESH_SHADER_ROOT_ACCESS: bool = false,
    CBV_SRV_UAV_HEAP_DIRECTLY_INDEXED: bool = false,
    SAMPLER_HEAP_DIRECTLY_INDEXED: bool = false,
    __unused: u20 = 0,
};

pub const ROOT_SIGNATURE_DESC = extern struct {
    NumParameters: UINT,
    pParameters: ?[*]const ROOT_PARAMETER,
    NumStaticSamplers: UINT,
    pStaticSamplers: ?[*]const STATIC_SAMPLER_DESC,
    Flags: ROOT_SIGNATURE_FLAGS,
};

pub const DESCRIPTOR_RANGE_FLAGS = packed struct(UINT) {
    DESCRIPTORS_VOLATILE: bool = false, // 0x1
    DATA_VOLATILE: bool = false,
    DATA_STATIC_WHILE_SET_AT_EXECUTE: bool = false,
    DATA_STATIC: bool = false,
    __unused4: bool = false, // 0x10
    __unused5: bool = false,
    __unused6: bool = false,
    __unused7: bool = false,
    __unused8: bool = false, // 0x100
    __unused9: bool = false,
    __unused10: bool = false,
    __unused11: bool = false,
    __unused12: bool = false, // 0x1000
    __unused13: bool = false,
    __unused14: bool = false,
    __unused15: bool = false,
    DESCRIPTORS_STATIC_KEEPING_BUFFER_BOUNDS_CHECKS: bool = false, // 0x10000
    __unused: u15 = 0,
};

pub const DESCRIPTOR_RANGE_OFFSET_APPEND = 0xffffffff; // defined as -1

pub const DESCRIPTOR_RANGE1 = extern struct {
    RangeType: DESCRIPTOR_RANGE_TYPE,
    NumDescriptors: UINT,
    BaseShaderRegister: UINT,
    RegisterSpace: UINT,
    Flags: DESCRIPTOR_RANGE_FLAGS,
    OffsetInDescriptorsFromTableStart: UINT,
};

pub const ROOT_DESCRIPTOR_TABLE1 = extern struct {
    NumDescriptorRanges: UINT,
    pDescriptorRanges: ?[*]const DESCRIPTOR_RANGE1,
};

pub const ROOT_DESCRIPTOR_FLAGS = packed struct(UINT) {
    __unused0: bool = false,
    DATA_VOLATILE: bool = false,
    DATA_STATIC_WHILE_SET_AT_EXECUTE: bool = false,
    DATA_STATIC: bool = false,
    _: u28 = 0,
};

pub const ROOT_DESCRIPTOR1 = extern struct {
    ShaderRegister: UINT,
    RegisterSpace: UINT = 0,
    Flags: ROOT_DESCRIPTOR_FLAGS = .{},
};

pub const ROOT_PARAMETER1 = extern struct {
    ParameterType: ROOT_PARAMETER_TYPE,
    u: extern union {
        DescriptorTable: ROOT_DESCRIPTOR_TABLE1,
        Constants: ROOT_CONSTANTS,
        Descriptor: ROOT_DESCRIPTOR1,
    },
    ShaderVisibility: SHADER_VISIBILITY,
};

pub const ROOT_SIGNATURE_DESC1 = extern struct {
    NumParameters: UINT,
    pParameters: ?[*]const ROOT_PARAMETER1,
    NumStaticSamplers: UINT,
    pStaticSamplers: ?[*]const STATIC_SAMPLER_DESC,
    Flags: ROOT_SIGNATURE_FLAGS,

    pub fn init(parameters: []const ROOT_PARAMETER1, static_samplers: []const STATIC_SAMPLER_DESC, flags: ROOT_SIGNATURE_FLAGS) ROOT_SIGNATURE_DESC1 {
        return .{
            .NumParameters = @intCast(parameters.len),
            .pParameters = if (parameters.len > 0) parameters.ptr else null,
            .NumStaticSamplers = @intCast(static_samplers.len),
            .pStaticSamplers = if (static_samplers.len > 0) static_samplers.ptr else null,
            .Flags = flags,
        };
    }
};

pub const ROOT_SIGNATURE_VERSION = enum(UINT) {
    VERSION_1_0 = 0x1,
    VERSION_1_1 = 0x2,
};

pub const VERSIONED_ROOT_SIGNATURE_DESC = extern struct {
    Version: ROOT_SIGNATURE_VERSION,
    u: extern union {
        Desc_1_0: ROOT_SIGNATURE_DESC,
        Desc_1_1: ROOT_SIGNATURE_DESC1,
    },

    pub fn initVersion1_0(desc: ROOT_SIGNATURE_DESC) VERSIONED_ROOT_SIGNATURE_DESC {
        return .{
            .Version = .VERSION_1_0,
            .u = .{
                .Desc_1_0 = desc,
            },
        };
    }

    pub fn initVersion1_1(desc: ROOT_SIGNATURE_DESC1) VERSIONED_ROOT_SIGNATURE_DESC {
        return .{
            .Version = .VERSION_1_1,
            .u = .{
                .Desc_1_1 = desc,
            },
        };
    }
};

pub const COMMAND_LIST_TYPE = enum(UINT) {
    DIRECT = 0,
    BUNDLE = 1,
    COMPUTE = 2,
    COPY = 3,
    VIDEO_DECODE = 4,
    VIDEO_PROCESS = 5,
    VIDEO_ENCODE = 6,
};

pub const RESOURCE_BARRIER_TYPE = enum(UINT) {
    TRANSITION = 0,
    ALIASING = 1,
    UAV = 2,
};

pub const RESOURCE_TRANSITION_BARRIER = extern struct {
    pResource: *IResource,
    Subresource: UINT,
    StateBefore: RESOURCE_STATES,
    StateAfter: RESOURCE_STATES,
};

pub const RESOURCE_ALIASING_BARRIER = extern struct {
    pResourceBefore: ?*IResource,
    pResourceAfter: ?*IResource,
};

pub const RESOURCE_UAV_BARRIER = extern struct {
    pResource: ?*IResource,
};

pub const RESOURCE_BARRIER_FLAGS = packed struct(UINT) {
    BEGIN_ONLY: bool = false,
    END_ONLY: bool = false,
    __unused: u30 = 0,
};

pub const RESOURCE_BARRIER = extern struct {
    Type: RESOURCE_BARRIER_TYPE,
    Flags: RESOURCE_BARRIER_FLAGS,
    u: extern union {
        Transition: RESOURCE_TRANSITION_BARRIER,
        Aliasing: RESOURCE_ALIASING_BARRIER,
        UAV: RESOURCE_UAV_BARRIER,
    },

    pub fn initUav(resource: *IResource) RESOURCE_BARRIER {
        var v = std.mem.zeroes(@This());
        v = .{ .Type = .UAV, .Flags = .{}, .u = .{ .UAV = .{ .pResource = resource } } };
        return v;
    }
};

pub const SUBRESOURCE_DATA = extern struct {
    pData: ?[*]u8,
    RowPitch: UINT,
    SlicePitch: UINT,
};

pub const MEMCPY_DEST = extern struct {
    pData: ?[*]u8,
    RowPitch: UINT,
    SlicePitch: UINT,
};

pub const SUBRESOURCE_FOOTPRINT = extern struct {
    Format: dxgi.FORMAT,
    Width: UINT,
    Height: UINT,
    Depth: UINT,
    RowPitch: UINT,
};

pub const PLACED_SUBRESOURCE_FOOTPRINT = extern struct {
    Offset: UINT64,
    Footprint: SUBRESOURCE_FOOTPRINT,
};

pub const TEXTURE_COPY_TYPE = enum(UINT) {
    SUBRESOURCE_INDEX = 0,
    PLACED_FOOTPRINT = 1,
};

pub const TEXTURE_COPY_LOCATION = extern struct {
    pResource: *IResource,
    Type: TEXTURE_COPY_TYPE,
    u: extern union {
        PlacedFootprint: PLACED_SUBRESOURCE_FOOTPRINT,
        SubresourceIndex: UINT,
    },
};

pub const TILED_RESOURCE_COORDINATE = extern struct {
    X: UINT,
    Y: UINT,
    Z: UINT,
    Subresource: UINT,
};

pub const TILE_REGION_SIZE = extern struct {
    NumTiles: UINT,
    UseBox: BOOL,
    Width: UINT,
    Height: UINT16,
    Depth: UINT16,
};

pub const TILE_RANGE_FLAGS = packed struct(UINT) {
    NULL: bool = false,
    SKIP: bool = false,
    REUSE_SINGLE_TILE: bool = false,
    __unused: u29 = 0,
};

pub const SUBRESOURCE_TILING = extern struct {
    WidthInTiles: UINT,
    HeightInTiles: UINT16,
    DepthInTiles: UINT16,
    StartTileIndexInOverallResource: UINT,
};

pub const TILE_SHAPE = extern struct {
    WidthInTexels: UINT,
    HeightInTexels: UINT,
    DepthInTexels: UINT,
};

pub const TILE_MAPPING_FLAGS = packed struct(UINT) {
    NO_HAZARD: bool = false,
    __unused: u31 = 0,
};

pub const TILE_COPY_FLAGS = packed struct(UINT) {
    NO_HAZARD: bool = false,
    LINEAR_BUFFER_TO_SWIZZLED_TILED_RESOURCE: bool = false,
    SWIZZLED_TILED_RESOURCE_TO_LINEAR_BUFFER: bool = false,
    __unused: u29 = 0,
};

pub const VIEWPORT = extern struct {
    TopLeftX: FLOAT,
    TopLeftY: FLOAT,
    Width: FLOAT,
    Height: FLOAT,
    MinDepth: FLOAT,
    MaxDepth: FLOAT,
};

pub const RECT = windows.RECT;

pub const RESOURCE_STATES = packed struct(UINT) {
    VERTEX_AND_CONSTANT_BUFFER: bool = false, // 0x1
    INDEX_BUFFER: bool = false,
    RENDER_TARGET: bool = false,
    UNORDERED_ACCESS: bool = false,
    DEPTH_WRITE: bool = false, // 0x10
    DEPTH_READ: bool = false,
    NON_PIXEL_SHADER_RESOURCE: bool = false,
    PIXEL_SHADER_RESOURCE: bool = false,
    STREAM_OUT: bool = false, // 0x100
    INDIRECT_ARGUMENT_OR_PREDICATION: bool = false,
    COPY_DEST: bool = false,
    COPY_SOURCE: bool = false,
    RESOLVE_DEST: bool = false, // 0x1000
    RESOLVE_SOURCE: bool = false,
    __unused14: bool = false,
    __unused15: bool = false,
    VIDEO_DECODE_READ: bool = false, // 0x10000
    VIDEO_DECODE_WRITE: bool = false,
    VIDEO_PROCESS_READ: bool = false,
    VIDEO_PROCESS_WRITE: bool = false,
    __unused20: bool = false, // 0x100000
    VIDEO_ENCODE_READ: bool = false,
    RAYTRACING_ACCELERATION_STRUCTURE: bool = false,
    VIDEO_ENCODE_WRITE: bool = false,
    SHADING_RATE_SOURCE: bool = false, // 0x1000000
    __unused: u7 = 0,

    pub const COMMON = RESOURCE_STATES{};
    pub const PRESENT = RESOURCE_STATES{};
    pub const GENERIC_READ = RESOURCE_STATES{
        .VERTEX_AND_CONSTANT_BUFFER = true,
        .INDEX_BUFFER = true,
        .NON_PIXEL_SHADER_RESOURCE = true,
        .PIXEL_SHADER_RESOURCE = true,
        .INDIRECT_ARGUMENT_OR_PREDICATION = true,
        .COPY_SOURCE = true,
    };
    pub const ALL_SHADER_RESOURCE = RESOURCE_STATES{
        .NON_PIXEL_SHADER_RESOURCE = true,
        .PIXEL_SHADER_RESOURCE = true,
    };
};

pub const INDEX_BUFFER_STRIP_CUT_VALUE = enum(UINT) {
    DISABLED = 0,
    OxFFFF = 1,
    OxFFFFFFFF = 2,
};

pub const VERTEX_BUFFER_VIEW = extern struct {
    BufferLocation: GPU_VIRTUAL_ADDRESS,
    SizeInBytes: UINT,
    StrideInBytes: UINT,
};

pub const INDEX_BUFFER_VIEW = extern struct {
    BufferLocation: GPU_VIRTUAL_ADDRESS,
    SizeInBytes: UINT,
    Format: dxgi.FORMAT,
};

pub const STREAM_OUTPUT_BUFFER_VIEW = extern struct {
    BufferLocation: GPU_VIRTUAL_ADDRESS,
    SizeInBytes: UINT64,
    BufferFilledSizeLocation: GPU_VIRTUAL_ADDRESS,
};

pub const CLEAR_FLAGS = packed struct(UINT) {
    DEPTH: bool = false,
    STENCIL: bool = false,
    __unused: u30 = 0,
};

pub const DISCARD_REGION = extern struct {
    NumRects: UINT,
    pRects: *const RECT,
    FirstSubresource: UINT,
    NumSubresources: UINT,
};

pub const QUERY_HEAP_TYPE = enum(UINT) {
    OCCLUSION = 0,
    TIMESTAMP = 1,
    PIPELINE_STATISTICS = 2,
    SO_STATISTICS = 3,
};

pub const QUERY_HEAP_DESC = extern struct {
    Type: QUERY_HEAP_TYPE,
    Count: UINT,
    NodeMask: UINT,
};

pub const QUERY_TYPE = enum(UINT) {
    OCCLUSION = 0,
    BINARY_OCCLUSION = 1,
    TIMESTAMP = 2,
    PIPELINE_STATISTICS = 3,
    SO_STATISTICS_STREAM0 = 4,
    SO_STATISTICS_STREAM1 = 5,
    SO_STATISTICS_STREAM2 = 6,
    SO_STATISTICS_STREAM3 = 7,
    VIDEO_DECODE_STATISTICS = 8,
    PIPELINE_STATISTICS1 = 10,
};

pub const PREDICATION_OP = enum(UINT) {
    EQUAL_ZERO = 0,
    NOT_EQUAL_ZERO = 1,
};

pub const INDIRECT_ARGUMENT_TYPE = enum(UINT) {
    DRAW = 0,
    DRAW_INDEXED = 1,
    DISPATCH = 2,
    VERTEX_BUFFER_VIEW = 3,
    INDEX_BUFFER_VIEW = 4,
    CONSTANT = 5,
    CONSTANT_BUFFER_VIEW = 6,
    SHADER_RESOURCE_VIEW = 7,
    UNORDERED_ACCESS_VIEW = 8,
    DISPATCH_RAYS = 9,
    DISPATCH_MESH = 10,
};

pub const INDIRECT_ARGUMENT_DESC = extern struct {
    Type: INDIRECT_ARGUMENT_TYPE,
    u: extern union {
        VertexBuffer: extern struct {
            Slot: UINT,
        },
        Constant: extern struct {
            RootParameterIndex: UINT,
            DestOffsetIn32BitValues: UINT,
            Num32BitValuesToSet: UINT,
        },
        ConstantBufferView: extern struct {
            RootParameterIndex: UINT,
        },
        ShaderResourceView: extern struct {
            RootParameterIndex: UINT,
        },
        UnorderedAccessView: extern struct {
            RootParameterIndex: UINT,
        },
    },
};

pub const COMMAND_SIGNATURE_DESC = extern struct {
    ByteStride: UINT,
    NumArgumentDescs: UINT,
    pArgumentDescs: *const INDIRECT_ARGUMENT_DESC,
    NodeMask: UINT,
};

pub const PACKED_MIP_INFO = extern struct {
    NumStandardMips: UINT8,
    NumPackedMips: UINT8,
    NumTilesForPackedMips: UINT,
    StartTileIndexInOverallResource: UINT,
};

pub const COMMAND_QUEUE_FLAGS = packed struct(UINT) {
    DISABLE_GPU_TIMEOUT: bool = false,
    __unused: u31 = 0,
};

pub const COMMAND_QUEUE_PRIORITY = enum(UINT) {
    NORMAL = 0,
    HIGH = 100,
    GLOBAL_REALTIME = 10000,
};

pub const COMMAND_QUEUE_DESC = extern struct {
    Type: COMMAND_LIST_TYPE,
    Priority: INT,
    Flags: COMMAND_QUEUE_FLAGS,
    NodeMask: UINT,
};

pub const SHADER_BYTECODE = extern struct {
    pShaderBytecode: ?*const anyopaque,
    BytecodeLength: UINT64,

    pub const zero: SHADER_BYTECODE = .{
        .pShaderBytecode = null,
        .BytecodeLength = 0,
    };

    pub inline fn init(bytecode: []const u8) SHADER_BYTECODE {
        return .{
            .pShaderBytecode = bytecode.ptr,
            .BytecodeLength = bytecode.len,
        };
    }
};

pub const SO_DECLARATION_ENTRY = extern struct {
    Stream: UINT,
    SemanticName: LPCSTR,
    SemanticIndex: UINT,
    StartComponent: UINT8,
    ComponentCount: UINT8,
    OutputSlot: UINT8,
};

pub const STREAM_OUTPUT_DESC = extern struct {
    pSODeclaration: ?[*]const SO_DECLARATION_ENTRY,
    NumEntries: UINT,
    pBufferStrides: ?[*]const UINT,
    NumStrides: UINT,
    RasterizedStream: UINT,

    pub inline fn initZero() STREAM_OUTPUT_DESC {
        return std.mem.zeroes(@This());
    }
};

pub const BLEND = enum(UINT) {
    ZERO = 1,
    ONE = 2,
    SRC_COLOR = 3,
    INV_SRC_COLOR = 4,
    SRC_ALPHA = 5,
    INV_SRC_ALPHA = 6,
    DEST_ALPHA = 7,
    INV_DEST_ALPHA = 8,
    DEST_COLOR = 9,
    INV_DEST_COLOR = 10,
    SRC_ALPHA_SAT = 11,
    BLEND_FACTOR = 14,
    INV_BLEND_FACTOR = 15,
    SRC1_COLOR = 16,
    INV_SRC1_COLOR = 17,
    SRC1_ALPHA = 18,
    INV_SRC1_ALPHA = 19,
};

pub const BLEND_OP = enum(UINT) {
    ADD = 1,
    SUBTRACT = 2,
    REV_SUBTRACT = 3,
    MIN = 4,
    MAX = 5,
};

pub const COLOR_WRITE_ENABLE = packed struct(UINT) {
    RED: bool = false,
    GREEN: bool = false,
    BLUE: bool = false,
    ALPHA: bool = false,
    __unused: u28 = 0,

    pub const ALL = COLOR_WRITE_ENABLE{ .RED = true, .GREEN = true, .BLUE = true, .ALPHA = true };
};

pub const LOGIC_OP = enum(UINT) {
    CLEAR = 0,
    SET = 1,
    COPY = 2,
    COPY_INVERTED = 3,
    NOOP = 4,
    INVERT = 5,
    AND = 6,
    NAND = 7,
    OR = 8,
    NOR = 9,
    XOR = 10,
    EQUIV = 11,
    AND_REVERSE = 12,
    AND_INVERTED = 13,
    OR_REVERSE = 14,
    OR_INVERTED = 15,
};

pub const RENDER_TARGET_BLEND_DESC = extern struct {
    BlendEnable: BOOL = .FALSE,
    LogicOpEnable: BOOL = .FALSE,
    SrcBlend: BLEND = .ONE,
    DestBlend: BLEND = .ZERO,
    BlendOp: BLEND_OP = .ADD,
    SrcBlendAlpha: BLEND = .ONE,
    DestBlendAlpha: BLEND = .ZERO,
    BlendOpAlpha: BLEND_OP = .ADD,
    LogicOp: LOGIC_OP = .NOOP,
    RenderTargetWriteMask: COLOR_WRITE_ENABLE = COLOR_WRITE_ENABLE.ALL,

    pub fn initDefault() RENDER_TARGET_BLEND_DESC {
        return .{};
    }
};

pub const BLEND_DESC = extern struct {
    AlphaToCoverageEnable: BOOL = .FALSE,
    IndependentBlendEnable: BOOL = .FALSE,
    RenderTarget: [8]RENDER_TARGET_BLEND_DESC = [_]RENDER_TARGET_BLEND_DESC{.{}} ** 8,

    pub fn initDefault() BLEND_DESC {
        return .{};
    }
};

pub const RASTERIZER_DESC = extern struct {
    FillMode: FILL_MODE = .SOLID,
    CullMode: CULL_MODE = .BACK,
    FrontCounterClockwise: BOOL = .FALSE,
    DepthBias: INT = 0,
    DepthBiasClamp: FLOAT = 0.0,
    SlopeScaledDepthBias: FLOAT = 0.0,
    DepthClipEnable: BOOL = .TRUE,
    MultisampleEnable: BOOL = .FALSE,
    AntialiasedLineEnable: BOOL = .FALSE,
    ForcedSampleCount: UINT = 0,
    ConservativeRaster: CONSERVATIVE_RASTERIZATION_MODE = .OFF,

    pub fn initDefault() RASTERIZER_DESC {
        return .{};
    }
};

pub const FILL_MODE = enum(UINT) {
    WIREFRAME = 2,
    SOLID = 3,
};

pub const CULL_MODE = enum(UINT) {
    NONE = 1,
    FRONT = 2,
    BACK = 3,
};

pub const CONSERVATIVE_RASTERIZATION_MODE = enum(UINT) {
    OFF = 0,
    ON = 1,
};

pub const COMPARISON_FUNC = enum(UINT) {
    NEVER = 1,
    LESS = 2,
    EQUAL = 3,
    LESS_EQUAL = 4,
    GREATER = 5,
    NOT_EQUAL = 6,
    GREATER_EQUAL = 7,
    ALWAYS = 8,
};

pub const DEPTH_WRITE_MASK = enum(UINT) {
    ZERO = 0,
    ALL = 1,
};

pub const STENCIL_OP = enum(UINT) {
    KEEP = 1,
    ZERO = 2,
    REPLACE = 3,
    INCR_SAT = 4,
    DECR_SAT = 5,
    INVERT = 6,
    INCR = 7,
    DECR = 8,
};

pub const DEPTH_STENCILOP_DESC = extern struct {
    StencilFailOp: STENCIL_OP = .KEEP,
    StencilDepthFailOp: STENCIL_OP = .KEEP,
    StencilPassOp: STENCIL_OP = .KEEP,
    StencilFunc: COMPARISON_FUNC = .ALWAYS,

    pub fn initDefault() DEPTH_STENCILOP_DESC {
        return .{};
    }
};

pub const DEPTH_STENCIL_DESC = extern struct {
    DepthEnable: BOOL = .TRUE,
    DepthWriteMask: DEPTH_WRITE_MASK = .ALL,
    DepthFunc: COMPARISON_FUNC = .LESS,
    StencilEnable: BOOL = .FALSE,
    StencilReadMask: UINT8 = 0xff,
    StencilWriteMask: UINT8 = 0xff,
    FrontFace: DEPTH_STENCILOP_DESC = .{},
    BackFace: DEPTH_STENCILOP_DESC = .{},

    pub fn initDefault() DEPTH_STENCIL_DESC {
        return .{};
    }
};

pub const DEPTH_STENCIL_DESC1 = extern struct {
    DepthEnable: BOOL = .TRUE,
    DepthWriteMask: DEPTH_WRITE_MASK = .ALL,
    DepthFunc: COMPARISON_FUNC = .LESS,
    StencilEnable: BOOL = .FALSE,
    StencilReadMask: UINT8 = 0xff,
    StencilWriteMask: UINT8 = 0xff,
    FrontFace: DEPTH_STENCILOP_DESC = .{},
    BackFace: DEPTH_STENCILOP_DESC = .{},
    DepthBoundsTestEnable: BOOL = .FALSE,

    pub fn initDefault() DEPTH_STENCIL_DESC1 {
        return .{};
    }
};

pub const INPUT_LAYOUT_DESC = extern struct {
    pInputElementDescs: ?[*]const INPUT_ELEMENT_DESC,
    NumElements: UINT,

    pub inline fn initZero() INPUT_LAYOUT_DESC {
        return std.mem.zeroes(@This());
    }

    pub inline fn init(elements: []const INPUT_ELEMENT_DESC) INPUT_LAYOUT_DESC {
        return .{
            .pInputElementDescs = elements.ptr,
            .NumElements = @intCast(elements.len),
        };
    }
};

pub const INPUT_CLASSIFICATION = enum(UINT) {
    PER_VERTEX_DATA = 0,
    PER_INSTANCE_DATA = 1,
};

pub const APPEND_ALIGNED_ELEMENT = 0xffffffff;

pub const INPUT_ELEMENT_DESC = extern struct {
    SemanticName: LPCSTR,
    SemanticIndex: UINT,
    Format: dxgi.FORMAT,
    InputSlot: UINT,
    AlignedByteOffset: UINT,
    InputSlotClass: INPUT_CLASSIFICATION,
    InstanceDataStepRate: UINT,

    pub inline fn init(
        semanticName: LPCSTR,
        semanticIndex: UINT,
        format: dxgi.FORMAT,
        inputSlot: UINT,
        alignedByteOffset: UINT,
        inputSlotClass: INPUT_CLASSIFICATION,
        instanceDataStepRate: UINT,
    ) INPUT_ELEMENT_DESC {
        var v = std.mem.zeroes(@This());
        v = .{
            .SemanticName = semanticName,
            .SemanticIndex = semanticIndex,
            .Format = format,
            .InputSlot = inputSlot,
            .AlignedByteOffset = alignedByteOffset,
            .InputSlotClass = inputSlotClass,
            .InstanceDataStepRate = instanceDataStepRate,
        };
        return v;
    }
};

pub const CACHED_PIPELINE_STATE = extern struct {
    pCachedBlob: ?*const anyopaque,
    CachedBlobSizeInBytes: UINT64,

    pub inline fn initZero() CACHED_PIPELINE_STATE {
        return std.mem.zeroes(@This());
    }
};

pub const PIPELINE_STATE_FLAGS = packed struct(UINT) {
    TOOL_DEBUG: bool = false,
    __unused1: bool = false,
    DYNAMIC_DEPTH_BIAS: bool = false,
    DYNAMIC_INDEX_BUFFER_STRIP_CUT: bool = false,
    __unused: u28 = 0,
};

pub const GRAPHICS_PIPELINE_STATE_DESC = extern struct {
    pRootSignature: ?*IRootSignature = null,
    VS: SHADER_BYTECODE = .zero,
    PS: SHADER_BYTECODE = .zero,
    DS: SHADER_BYTECODE = .zero,
    HS: SHADER_BYTECODE = .zero,
    GS: SHADER_BYTECODE = .zero,
    StreamOutput: STREAM_OUTPUT_DESC = STREAM_OUTPUT_DESC.initZero(),
    BlendState: BLEND_DESC = .{},
    SampleMask: UINT = 0xffff_ffff,
    RasterizerState: RASTERIZER_DESC = .{},
    DepthStencilState: DEPTH_STENCIL_DESC = .{},
    InputLayout: INPUT_LAYOUT_DESC = INPUT_LAYOUT_DESC.initZero(),
    IBStripCutValue: INDEX_BUFFER_STRIP_CUT_VALUE = .DISABLED,
    PrimitiveTopologyType: PRIMITIVE_TOPOLOGY_TYPE = .UNDEFINED,
    NumRenderTargets: UINT = 0,
    RTVFormats: [8]dxgi.FORMAT = [_]dxgi.FORMAT{.UNKNOWN} ** 8,
    DSVFormat: dxgi.FORMAT = .UNKNOWN,
    SampleDesc: dxgi.SAMPLE_DESC = .{ .Count = 1, .Quality = 0 },
    NodeMask: UINT = 0,
    CachedPSO: CACHED_PIPELINE_STATE = CACHED_PIPELINE_STATE.initZero(),
    Flags: PIPELINE_STATE_FLAGS = .{},

    pub fn initDefault() GRAPHICS_PIPELINE_STATE_DESC {
        return .{};
    }
};

pub const COMPUTE_PIPELINE_STATE_DESC = extern struct {
    pRootSignature: ?*IRootSignature = null,
    CS: SHADER_BYTECODE = .zero,
    NodeMask: UINT = 0,
    CachedPSO: CACHED_PIPELINE_STATE = CACHED_PIPELINE_STATE.initZero(),
    Flags: PIPELINE_STATE_FLAGS = .{},

    pub fn initDefault() COMPUTE_PIPELINE_STATE_DESC {
        return .{};
    }
};

pub const FEATURE = enum(UINT) {
    OPTIONS = 0,
    ARCHITECTURE = 1,
    FEATURE_LEVELS = 2,
    FORMAT_SUPPORT = 3,
    MULTISAMPLE_QUALITY_LEVELS = 4,
    FORMAT_INFO = 5,
    GPU_VIRTUAL_ADDRESS_SUPPORT = 6,
    SHADER_MODEL = 7,
    OPTIONS1 = 8,
    PROTECTED_RESOURCE_SESSION_SUPPORT = 10,
    ROOT_SIGNATURE = 12,
    ARCHITECTURE1 = 16,
    OPTIONS2 = 18,
    SHADER_CACHE = 19,
    COMMAND_QUEUE_PRIORITY = 20,
    OPTIONS3 = 21,
    EXISTING_HEAPS = 22,
    OPTIONS4 = 23,
    SERIALIZATION = 24,
    CROSS_NODE = 25,
    OPTIONS5 = 27,
    DISPLAYABLE = 28,
    OPTIONS6 = 30,
    QUERY_META_COMMAND = 31,
    OPTIONS7 = 32,
    PROTECTED_RESOURCE_SESSION_TYPE_COUNT = 33,
    PROTECTED_RESOURCE_SESSION_TYPES = 34,
    OPTIONS8 = 36,
    OPTIONS9 = 37,
    OPTIONS10 = 39,
    OPTIONS11 = 40,

    pub fn Data(self: FEATURE) type {
        // enum to type https://learn.microsoft.com/en-us/windows/win32/api/d3d12/ne-d3d12-d3d12_feature#constants
        return switch (self) {
            .OPTIONS => FEATURE_DATA_D3D12_OPTIONS,
            .FORMAT_INFO => FEATURE_DATA_FORMAT_INFO,
            .SHADER_MODEL => FEATURE_DATA_SHADER_MODEL,
            .ROOT_SIGNATURE => FEATURE_DATA_ROOT_SIGNATURE,
            .OPTIONS3 => FEATURE_DATA_D3D12_OPTIONS3,
            .OPTIONS5 => FEATURE_DATA_D3D12_OPTIONS5,
            .OPTIONS7 => FEATURE_DATA_D3D12_OPTIONS7,
            else => @compileError("not implemented"),
        };
    }
};

pub const SHADER_MODEL = enum(UINT) {
    @"5_1" = 0x51,
    @"6_0" = 0x60,
    @"6_1" = 0x61,
    @"6_2" = 0x62,
    @"6_3" = 0x63,
    @"6_4" = 0x64,
    @"6_5" = 0x65,
    @"6_6" = 0x66,
    @"6_7" = 0x67,
};

pub const RESOURCE_BINDING_TIER = enum(UINT) {
    TIER_1 = 1,
    TIER_2 = 2,
    TIER_3 = 3,
};

pub const RESOURCE_HEAP_TIER = enum(UINT) {
    TIER_1 = 1,
    TIER_2 = 2,
};

pub const SHADER_MIN_PRECISION_SUPPORT = packed struct(UINT) {
    @"10_BIT": bool = false,
    @"16_BIT": bool = false,
    __unused: u30 = 0,
};

pub const TILED_RESOURCES_TIER = enum(UINT) {
    NOT_SUPPORTED = 0,
    TIER_1 = 1,
    TIER_2 = 2,
    TIER_3 = 3,
    TIER_4 = 4,
};

pub const CONSERVATIVE_RASTERIZATION_TIER = enum(UINT) {
    NOT_SUPPORTED = 0,
    TIER_1 = 1,
    TIER_2 = 2,
    TIER_3 = 3,
};

pub const CROSS_NODE_SHARING_TIER = enum(UINT) {
    NOT_SUPPORTED = 0,
    TIER_1_EMULATED = 1,
    TIER_1 = 2,
    TIER_2 = 3,
    TIER_3 = 4,
};

pub const FEATURE_DATA_D3D12_OPTIONS = extern struct {
    DoublePrecisionFloatShaderOps: BOOL,
    OutputMergerLogicOp: BOOL,
    MinPrecisionSupport: SHADER_MIN_PRECISION_SUPPORT,
    TiledResourcesTier: TILED_RESOURCES_TIER,
    ResourceBindingTier: RESOURCE_BINDING_TIER,
    PSSpecifiedStencilRefSupported: BOOL,
    TypedUAVLoadAdditionalFormats: BOOL,
    ROVsSupported: BOOL,
    ConservativeRasterizationTier: CONSERVATIVE_RASTERIZATION_TIER,
    MaxGPUVirtualAddressBitsPerResource: UINT,
    StandardSwizzle64KBSupported: BOOL,
    CrossNodeSharingTier: CROSS_NODE_SHARING_TIER,
    CrossAdapterRowMajorTextureSupported: BOOL,
    VPAndRTArrayIndexFromAnyShaderFeedingRasterizerSupportedWithoutGSEmulation: BOOL,
    ResourceHeapTier: RESOURCE_HEAP_TIER,
};

pub const FEATURE_DATA_SHADER_MODEL = extern struct {
    HighestShaderModel: SHADER_MODEL,
};

pub const FEATURE_DATA_ROOT_SIGNATURE = extern struct {
    HighestVersion: ROOT_SIGNATURE_VERSION,
};

pub const FEATURE_DATA_FORMAT_INFO = extern struct {
    Format: dxgi.FORMAT,
    PlaneCount: u8,
};

pub const RENDER_PASS_TIER = enum(UINT) {
    TIER_0 = 0,
    TIER_1 = 1,
    TIER_2 = 2,
};

pub const RAYTRACING_TIER = enum(UINT) {
    NOT_SUPPORTED = 0,
    TIER_1_0 = 10,
    TIER_1_1 = 11,
};

pub const MESH_SHADER_TIER = enum(UINT) {
    NOT_SUPPORTED = 0,
    TIER_1 = 10,
};

pub const SAMPLER_FEEDBACK_TIER = enum(UINT) {
    NOT_SUPPORTED = 0,
    TIER_0_9 = 90,
    TIER_1_0 = 100,
};

pub const FEATURE_DATA_D3D12_OPTIONS7 = extern struct {
    MeshShaderTier: MESH_SHADER_TIER,
    SamplerFeedbackTier: SAMPLER_FEEDBACK_TIER,
};

pub const COMMAND_LIST_SUPPORT_FLAGS = packed struct(UINT) {
    DIRECT: bool = false,
    BUNDLE: bool = false,
    COMPUTE: bool = false,
    COPY: bool = false,
    VIDEO_DECODE: bool = false,
    VIDEO_PROCESS: bool = false,
    VIDEO_ENCODE: bool = false,
    __unused: u25 = 0,
};

pub const VIEW_INSTANCING_TIER = enum(UINT) {
    NOT_SUPPORTED = 0,
    TIER_1 = 1,
    TIER_2 = 2,
    TIER_3 = 3,
};

pub const FEATURE_DATA_D3D12_OPTIONS3 = extern struct {
    CopyQueueTimestampQueriesSupported: BOOL,
    CastingFullyTypedFormatSupported: BOOL,
    WriteBufferImmediateSupportFlags: COMMAND_LIST_SUPPORT_FLAGS,
    ViewInstancingTier: VIEW_INSTANCING_TIER,
    BarycentricsSupported: BOOL,
};

pub const FEATURE_DATA_D3D12_OPTIONS5 = extern struct {
    SRVOnlyTiledResourceTier3: BOOL,
    RenderPassesTier: RENDER_PASS_TIER,
    RaytracingTier: RAYTRACING_TIER,
};

pub const CONSTANT_BUFFER_VIEW_DESC = extern struct {
    BufferLocation: GPU_VIRTUAL_ADDRESS,
    SizeInBytes: UINT,
};

pub inline fn encodeShader4ComponentMapping(src0: UINT, src1: UINT, src2: UINT, src3: UINT) UINT {
    return (src0 & 0x7) | ((src1 & 0x7) << 3) | ((src2 & 0x7) << (3 * 2)) | ((src3 & 0x7) << (3 * 3)) |
        (1 << (3 * 4));
}
pub const DEFAULT_SHADER_4_COMPONENT_MAPPING = encodeShader4ComponentMapping(0, 1, 2, 3);

pub const BUFFER_SRV_FLAGS = packed struct(UINT) {
    RAW: bool = false,
    __unused: u31 = 0,
};

pub const BUFFER_SRV = extern struct {
    FirstElement: UINT64,
    NumElements: UINT,
    StructureByteStride: UINT,
    Flags: BUFFER_SRV_FLAGS,
};

pub const TEX1D_SRV = extern struct {
    MostDetailedMip: UINT,
    MipLevels: UINT,
    ResourceMinLODClamp: FLOAT,
};

pub const TEX1D_ARRAY_SRV = extern struct {
    MostDetailedMip: UINT,
    MipLevels: UINT,
    FirstArraySlice: UINT,
    ArraySize: UINT,
    ResourceMinLODClamp: FLOAT,
};

pub const TEX2D_SRV = extern struct {
    MostDetailedMip: UINT,
    MipLevels: UINT,
    PlaneSlice: UINT,
    ResourceMinLODClamp: FLOAT,
};

pub const TEX2D_ARRAY_SRV = extern struct {
    MostDetailedMip: UINT,
    MipLevels: UINT,
    FirstArraySlice: UINT,
    ArraySize: UINT,
    PlaneSlice: UINT,
    ResourceMinLODClamp: FLOAT,
};

pub const TEX3D_SRV = extern struct {
    MostDetailedMip: UINT,
    MipLevels: UINT,
    ResourceMinLODClamp: FLOAT,
};

pub const TEXCUBE_SRV = extern struct {
    MostDetailedMip: UINT,
    MipLevels: UINT,
    ResourceMinLODClamp: FLOAT,
};

pub const TEXCUBE_ARRAY_SRV = extern struct {
    MostDetailedMip: UINT,
    MipLevels: UINT,
    First2DArrayFace: UINT,
    NumCubes: UINT,
    ResourceMinLODClamp: FLOAT,
};

pub const TEX2DMS_SRV = extern struct {
    UnusedField_NothingToDefine: UINT,
};

pub const TEX2DMS_ARRAY_SRV = extern struct {
    FirstArraySlice: UINT,
    ArraySize: UINT,
};

pub const SRV_DIMENSION = enum(UINT) {
    UNKNOWN = 0,
    BUFFER = 1,
    TEXTURE1D = 2,
    TEXTURE1DARRAY = 3,
    TEXTURE2D = 4,
    TEXTURE2DARRAY = 5,
    TEXTURE2DMS = 6,
    TEXTURE2DMSARRAY = 7,
    TEXTURE3D = 8,
    TEXTURECUBE = 9,
    TEXTURECUBEARRAY = 10,
};

pub const SHADER_RESOURCE_VIEW_DESC = extern struct {
    Format: dxgi.FORMAT,
    ViewDimension: SRV_DIMENSION,
    Shader4ComponentMapping: UINT,
    u: extern union {
        Buffer: BUFFER_SRV,
        Texture1D: TEX1D_SRV,
        Texture1DArray: TEX1D_ARRAY_SRV,
        Texture2D: TEX2D_SRV,
        Texture2DArray: TEX2D_ARRAY_SRV,
        Texture2DMS: TEX2DMS_SRV,
        Texture2DMSArray: TEX2DMS_ARRAY_SRV,
        Texture3D: TEX3D_SRV,
        TextureCube: TEXCUBE_SRV,
        TextureCubeArray: TEXCUBE_ARRAY_SRV,
    },

    pub fn initTypedBuffer(
        format: dxgi.FORMAT,
        first_element: UINT64,
        num_elements: UINT,
    ) SHADER_RESOURCE_VIEW_DESC {
        var desc = std.mem.zeroes(@This());
        desc = .{
            .Format = format,
            .ViewDimension = .BUFFER,
            .Shader4ComponentMapping = DEFAULT_SHADER_4_COMPONENT_MAPPING,
            .u = .{
                .Buffer = .{
                    .FirstElement = first_element,
                    .NumElements = num_elements,
                    .StructureByteStride = 0,
                    .Flags = .{},
                },
            },
        };
        return desc;
    }

    pub fn initStructuredBuffer(
        first_element: UINT64,
        num_elements: UINT,
        stride: UINT,
    ) SHADER_RESOURCE_VIEW_DESC {
        var v = std.mem.zeroes(@This());
        v = .{
            .Format = .UNKNOWN,
            .ViewDimension = .BUFFER,
            .Shader4ComponentMapping = DEFAULT_SHADER_4_COMPONENT_MAPPING,
            .u = .{
                .Buffer = .{
                    .FirstElement = first_element,
                    .NumElements = num_elements,
                    .StructureByteStride = stride,
                    .Flags = .{},
                },
            },
        };
        return v;
    }
};

pub const FILTER = enum(UINT) {
    MIN_MAG_MIP_POINT = 0,
    MIN_MAG_POINT_MIP_LINEAR = 0x1,
    MIN_POINT_MAG_LINEAR_MIP_POINT = 0x4,
    MIN_POINT_MAG_MIP_LINEAR = 0x5,
    MIN_LINEAR_MAG_MIP_POINT = 0x10,
    MIN_LINEAR_MAG_POINT_MIP_LINEAR = 0x11,
    MIN_MAG_LINEAR_MIP_POINT = 0x14,
    MIN_MAG_MIP_LINEAR = 0x15,
    ANISOTROPIC = 0x55,
    COMPARISON_MIN_MAG_MIP_POINT = 0x80,
    COMPARISON_MIN_MAG_POINT_MIP_LINEAR = 0x81,
    COMPARISON_MIN_POINT_MAG_LINEAR_MIP_POINT = 0x84,
    COMPARISON_MIN_POINT_MAG_MIP_LINEAR = 0x85,
    COMPARISON_MIN_LINEAR_MAG_MIP_POINT = 0x90,
    COMPARISON_MIN_LINEAR_MAG_POINT_MIP_LINEAR = 0x91,
    COMPARISON_MIN_MAG_LINEAR_MIP_POINT = 0x94,
    COMPARISON_MIN_MAG_MIP_LINEAR = 0x95,
    COMPARISON_ANISOTROPIC = 0xd5,
    MINIMUM_MIN_MAG_MIP_POINT = 0x100,
    MINIMUM_MIN_MAG_POINT_MIP_LINEAR = 0x101,
    MINIMUM_MIN_POINT_MAG_LINEAR_MIP_POINT = 0x104,
    MINIMUM_MIN_POINT_MAG_MIP_LINEAR = 0x105,
    MINIMUM_MIN_LINEAR_MAG_MIP_POINT = 0x110,
    MINIMUM_MIN_LINEAR_MAG_POINT_MIP_LINEAR = 0x111,
    MINIMUM_MIN_MAG_LINEAR_MIP_POINT = 0x114,
    MINIMUM_MIN_MAG_MIP_LINEAR = 0x115,
    MINIMUM_ANISOTROPIC = 0x155,
    MAXIMUM_MIN_MAG_MIP_POINT = 0x180,
    MAXIMUM_MIN_MAG_POINT_MIP_LINEAR = 0x181,
    MAXIMUM_MIN_POINT_MAG_LINEAR_MIP_POINT = 0x184,
    MAXIMUM_MIN_POINT_MAG_MIP_LINEAR = 0x185,
    MAXIMUM_MIN_LINEAR_MAG_MIP_POINT = 0x190,
    MAXIMUM_MIN_LINEAR_MAG_POINT_MIP_LINEAR = 0x191,
    MAXIMUM_MIN_MAG_LINEAR_MIP_POINT = 0x194,
    MAXIMUM_MIN_MAG_MIP_LINEAR = 0x195,
    MAXIMUM_ANISOTROPIC = 0x1d5,
};

pub const FILTER_TYPE = enum(UINT) {
    POINT = 0,
    LINEAR = 1,
};

pub const FILTER_REDUCTION_TYPE = enum(UINT) {
    STANDARD = 0,
    COMPARISON = 1,
    MINIMUM = 2,
    MAXIMUM = 3,
};

pub const TEXTURE_ADDRESS_MODE = enum(UINT) {
    WRAP = 1,
    MIRROR = 2,
    CLAMP = 3,
    BORDER = 4,
    MIRROR_ONCE = 5,
};

pub const SAMPLER_DESC = extern struct {
    Filter: FILTER,
    AddressU: TEXTURE_ADDRESS_MODE,
    AddressV: TEXTURE_ADDRESS_MODE,
    AddressW: TEXTURE_ADDRESS_MODE,
    MipLODBias: FLOAT,
    MaxAnisotropy: UINT,
    ComparisonFunc: COMPARISON_FUNC,
    BorderColor: [4]FLOAT,
    MinLOD: FLOAT,
    MaxLOD: FLOAT,
};

pub const BUFFER_UAV_FLAGS = packed struct(UINT) {
    RAW: bool = false,
    __unused: u31 = 0,
};

pub const BUFFER_UAV = extern struct {
    FirstElement: UINT64,
    NumElements: UINT,
    StructureByteStride: UINT,
    CounterOffsetInBytes: UINT64,
    Flags: BUFFER_UAV_FLAGS,
};

pub const TEX1D_UAV = extern struct {
    MipSlice: UINT,
};

pub const TEX1D_ARRAY_UAV = extern struct {
    MipSlice: UINT,
    FirstArraySlice: UINT,
    ArraySize: UINT,
};

pub const TEX2D_UAV = extern struct {
    MipSlice: UINT,
    PlaneSlice: UINT,
};

pub const TEX2D_ARRAY_UAV = extern struct {
    MipSlice: UINT,
    FirstArraySlice: UINT,
    ArraySize: UINT,
    PlaneSlice: UINT,
};

pub const TEX3D_UAV = extern struct {
    MipSlice: UINT,
    FirstWSlice: UINT,
    WSize: UINT,
};

pub const UAV_DIMENSION = enum(UINT) {
    UNKNOWN = 0,
    BUFFER = 1,
    TEXTURE1D = 2,
    TEXTURE1DARRAY = 3,
    TEXTURE2D = 4,
    TEXTURE2DARRAY = 5,
    TEXTURE3D = 8,
};

pub const UNORDERED_ACCESS_VIEW_DESC = extern struct {
    Format: dxgi.FORMAT,
    ViewDimension: UAV_DIMENSION,
    u: extern union {
        Buffer: BUFFER_UAV,
        Texture1D: TEX1D_UAV,
        Texture1DArray: TEX1D_ARRAY_UAV,
        Texture2D: TEX2D_UAV,
        Texture2DArray: TEX2D_ARRAY_UAV,
        Texture3D: TEX3D_UAV,
    },

    pub fn initTypedBuffer(
        format: dxgi.FORMAT,
        first_element: UINT64,
        num_elements: UINT,
        counter_offset: UINT64,
    ) UNORDERED_ACCESS_VIEW_DESC {
        var desc = std.mem.zeroes(@This());
        desc = .{
            .Format = format,
            .ViewDimension = .BUFFER,
            .u = .{
                .Buffer = .{
                    .FirstElement = first_element,
                    .NumElements = num_elements,
                    .StructureByteStride = 0,
                    .CounterOffsetInBytes = counter_offset,
                    .Flags = .{},
                },
            },
        };
        return desc;
    }

    pub fn initStructuredBuffer(
        first_element: UINT64,
        num_elements: UINT,
        stride: UINT,
        counter_offset: UINT64,
    ) UNORDERED_ACCESS_VIEW_DESC {
        var v = std.mem.zeroes(@This());
        v = .{
            .Format = .UNKNOWN,
            .ViewDimension = .BUFFER,
            .u = .{
                .Buffer = .{
                    .FirstElement = first_element,
                    .NumElements = num_elements,
                    .StructureByteStride = stride,
                    .CounterOffsetInBytes = counter_offset,
                    .Flags = .{},
                },
            },
        };
        return v;
    }
};

pub const BUFFER_RTV = extern struct {
    FirstElement: UINT64,
    NumElements: UINT,
};

pub const TEX1D_RTV = extern struct {
    MipSlice: UINT,
};

pub const TEX1D_ARRAY_RTV = extern struct {
    MipSlice: UINT,
    FirstArraySlice: UINT,
    ArraySize: UINT,
};

pub const TEX2D_RTV = extern struct {
    MipSlice: UINT,
    PlaneSlice: UINT,
};

pub const TEX2DMS_RTV = extern struct {
    UnusedField_NothingToDefine: UINT,
};

pub const TEX2D_ARRAY_RTV = extern struct {
    MipSlice: UINT,
    FirstArraySlice: UINT,
    ArraySize: UINT,
    PlaneSlice: UINT,
};

pub const TEX2DMS_ARRAY_RTV = extern struct {
    FirstArraySlice: UINT,
    ArraySize: UINT,
};

pub const TEX3D_RTV = extern struct {
    MipSlice: UINT,
    FirstWSlice: UINT,
    WSize: UINT,
};

pub const RTV_DIMENSION = enum(UINT) {
    UNKNOWN = 0,
    BUFFER = 1,
    TEXTURE1D = 2,
    TEXTURE1DARRAY = 3,
    TEXTURE2D = 4,
    TEXTURE2DARRAY = 5,
    TEXTURE2DMS = 6,
    TEXTURE2DMSARRAY = 7,
    TEXTURE3D = 8,
};

pub const RENDER_TARGET_VIEW_DESC = extern struct {
    Format: dxgi.FORMAT,
    ViewDimension: RTV_DIMENSION,
    u: extern union {
        Buffer: BUFFER_RTV,
        Texture1D: TEX1D_RTV,
        Texture1DArray: TEX1D_ARRAY_RTV,
        Texture2D: TEX2D_RTV,
        Texture2DArray: TEX2D_ARRAY_RTV,
        Texture2DMS: TEX2DMS_RTV,
        Texture2DMSArray: TEX2DMS_ARRAY_RTV,
        Texture3D: TEX3D_RTV,
    },
};

pub const TEX1D_DSV = extern struct {
    MipSlice: UINT,
};

pub const TEX1D_ARRAY_DSV = extern struct {
    MipSlice: UINT,
    FirstArraySlice: UINT,
    ArraySize: UINT,
};

pub const TEX2D_DSV = extern struct {
    MipSlice: UINT,
};

pub const TEX2D_ARRAY_DSV = extern struct {
    MipSlice: UINT,
    FirstArraySlice: UINT,
    ArraySize: UINT,
};

pub const TEX2DMS_DSV = extern struct {
    UnusedField_NothingToDefine: UINT,
};

pub const TEX2DMS_ARRAY_DSV = extern struct {
    FirstArraySlice: UINT,
    ArraySize: UINT,
};

pub const DSV_FLAGS = packed struct(UINT) {
    READ_ONLY_DEPTH: bool = false,
    READ_ONLY_STENCIL: bool = false,
    __unused: u30 = 0,
};

pub const DSV_DIMENSION = enum(UINT) {
    UNKNOWN = 0,
    TEXTURE1D = 1,
    TEXTURE1DARRAY = 2,
    TEXTURE2D = 3,
    TEXTURE2DARRAY = 4,
    TEXTURE2DMS = 5,
    TEXTURE2DMSARRAY = 6,
};

pub const DEPTH_STENCIL_VIEW_DESC = extern struct {
    Format: dxgi.FORMAT,
    ViewDimension: DSV_DIMENSION,
    Flags: DSV_FLAGS,
    u: extern union {
        Texture1D: TEX1D_DSV,
        Texture1DArray: TEX1D_ARRAY_DSV,
        Texture2D: TEX2D_DSV,
        Texture2DArray: TEX2D_ARRAY_DSV,
        Texture2DMS: TEX2DMS_DSV,
        Texture2DMSArray: TEX2DMS_ARRAY_DSV,
    },
};

pub const RESOURCE_ALLOCATION_INFO = extern struct {
    SizeInBytes: UINT64,
    Alignment: UINT64,
};

pub const DEPTH_STENCIL_VALUE = extern struct {
    Depth: FLOAT,
    Stencil: UINT8,
};

pub const CLEAR_VALUE = extern struct {
    Format: dxgi.FORMAT,
    u: extern union {
        Color: [4]FLOAT,
        DepthStencil: DEPTH_STENCIL_VALUE,
    },

    pub fn initColor(format: dxgi.FORMAT, in_color: [4]FLOAT) CLEAR_VALUE {
        var v = std.mem.zeroes(@This());
        v = .{
            .Format = format,
            .u = .{ .Color = in_color },
        };
        return v;
    }

    pub fn initDepthStencil(format: dxgi.FORMAT, depth: FLOAT, stencil: UINT8) CLEAR_VALUE {
        var v = std.mem.zeroes(@This());
        v = .{
            .Format = format,
            .u = .{ .DepthStencil = .{ .Depth = depth, .Stencil = stencil } },
        };
        return v;
    }
};

pub const IObject = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetPrivateData: *const fn (*IObject, *const GUID, *UINT, ?*anyopaque) callconv(.winapi) HRESULT,
        SetPrivateData: *const fn (*IObject, *const GUID, UINT, ?*const anyopaque) callconv(.winapi) HRESULT,
        SetPrivateDataInterface: *const fn (*IObject, *const GUID, ?*const IUnknown) callconv(.winapi) HRESULT,
        SetName: *const fn (*IObject, LPCWSTR) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetPrivateData(
        self: *IObject,
        guid: *const GUID,
        data_size: *UINT,
        data: ?*anyopaque,
    ) HRESULT {
        return self.vtable.GetPrivateData(self, guid, data_size, data);
    }
    pub inline fn SetPrivateData(
        self: *IObject,
        guid: *const GUID,
        data_size: UINT,
        data: ?*const anyopaque,
    ) HRESULT {
        return self.vtable.SetPrivateData(self, guid, data_size, data);
    }
    pub inline fn SetPrivateDataInterface(self: *IObject, guid: *const GUID, data: ?*const IUnknown) HRESULT {
        return self.vtable.SetPrivateDataInterface(self, guid, data);
    }
    pub inline fn SetName(self: *IObject, name: LPCWSTR) HRESULT {
        return self.vtable.SetName(self, name);
    }
    pub inline fn setNameUtf8(self: *IObject, name: []const u8) !HRESULT {
        var buf: [256]u16 = undefined;
        const len = try std.unicode.utf8ToUtf16Le(&buf, name);
        buf[len] = 0; // null terminate
        return self.SetName(@ptrCast(&buf[0]));
    }
};

pub const IDeviceChild = extern union {
    pub const VTable = extern struct {
        base: IObject.VTable,
        GetDevice: *const fn (*IDeviceChild, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,

    pub inline fn GetDevice(self: *IDeviceChild, guid: *const GUID, device: *?*anyopaque) HRESULT {
        return self.vtable.GetDevice(self, guid, device);
    }
};

pub const IPageable = extern union {
    pub const VTable = extern struct {
        base: IDeviceChild.VTable,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
};

pub const IRootSignature = extern union {
    pub const IID: GUID = .{
        .Data1 = 0xc54a6b66,
        .Data2 = 0x72df,
        .Data3 = 0x4ee8,
        .Data4 = .{ 0x8b, 0xe5, 0xa9, 0x46, 0xa1, 0x42, 0x92, 0x14 },
    };
    pub const VTable = extern struct {
        base: IDeviceChild.VTable,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
};

pub const IQueryHeap = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x0d9658ae,
        .Data2 = 0xed45,
        .Data3 = 0x469e,
        .Data4 = .{ 0xa6, 0x1d, 0x97, 0x0e, 0xc5, 0x83, 0xca, 0xb4 },
    };
    pub const VTable = extern struct {
        base: IPageable.VTable,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,
};

pub const ICommandSignature = extern union {
    pub const IID: GUID = .parse("{c36a797c-ec80-4f0a-8985-a7b2475082d1}");
    pub const VTable = extern struct {
        base: IPageable.VTable,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,
};

pub const IHeap = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x6b3b2502,
        .Data2 = 0x6e51,
        .Data3 = 0x45b3,
        .Data4 = .{ 0x90, 0xee, 0x98, 0x84, 0x26, 0x5e, 0x8d, 0xf3 },
    };
    pub const VTable = extern struct {
        base: IPageable.VTable,
        GetDesc: *const fn (*IHeap, *HEAP_DESC) callconv(.winapi) *HEAP_DESC,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,

    pub inline fn GetDesc(self: *IHeap) HEAP_DESC {
        var desc: HEAP_DESC = undefined;
        _ = self.vtable.GetDesc(self, &desc);
        return desc;
    }
};

pub const IResource = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x696442be,
        .Data2 = 0xa72e,
        .Data3 = 0x4059,
        .Data4 = .{ 0xbc, 0x79, 0x5b, 0x5c, 0x98, 0x04, 0x0f, 0xad },
    };
    pub const VTable = extern struct {
        base: IPageable.VTable,
        Map: *const fn (*IResource, UINT, ?*const RANGE, *?*anyopaque) callconv(.winapi) HRESULT,
        Unmap: *const fn (*IResource, UINT, ?*const RANGE) callconv(.winapi) void,
        GetDesc: *const fn (*IResource, *RESOURCE_DESC) callconv(.winapi) *RESOURCE_DESC,
        GetGPUVirtualAddress: *const fn (*IResource) callconv(.winapi) GPU_VIRTUAL_ADDRESS,
        WriteToSubresource: *const fn (
            *IResource,
            UINT,
            ?*const BOX,
            *const anyopaque,
            UINT,
            UINT,
        ) callconv(.winapi) HRESULT,
        ReadFromSubresource: *const fn (
            *IResource,
            *anyopaque,
            UINT,
            UINT,
            UINT,
            ?*const BOX,
        ) callconv(.winapi) HRESULT,
        GetHeapProperties: *const fn (*IResource, ?*HEAP_PROPERTIES, ?*HEAP_FLAGS) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,

    pub inline fn Map(self: *IResource, subresource: UINT, read_range: ?*const RANGE, data: *?*anyopaque) HRESULT {
        return self.vtable.Map(self, subresource, read_range, data);
    }
    pub inline fn Unmap(self: *IResource, subresource: UINT, written_range: ?*const RANGE) void {
        self.vtable.Unmap(self, subresource, written_range);
    }
    pub inline fn GetDesc(self: *IResource) RESOURCE_DESC {
        var desc: RESOURCE_DESC = undefined;
        _ = self.vtable.GetDesc(self, &desc);
        return desc;
    }
    pub inline fn GetGPUVirtualAddress(self: *IResource) GPU_VIRTUAL_ADDRESS {
        return self.vtable.GetGPUVirtualAddress(self);
    }
    pub inline fn WriteToSubresource(
        self: *IResource,
        dst_subresource: UINT,
        dst_box: ?*const BOX,
        src_data: *const anyopaque,
        src_row_pitch: UINT,
        src_depth_pitch: UINT,
    ) HRESULT {
        return self.vtable.WriteToSubresource(self, dst_subresource, dst_box, src_data, src_row_pitch, src_depth_pitch);
    }
    pub inline fn ReadFromSubresource(
        self: *IResource,
        dst_data: *anyopaque,
        dst_row_pitch: UINT,
        dst_depth_pitch: UINT,
        src_subresource: UINT,
        src_box: ?*const BOX,
    ) HRESULT {
        return self.vtable.ReadFromSubresource(self, dst_data, dst_row_pitch, dst_depth_pitch, src_subresource, src_box);
    }
    pub inline fn GetHeapProperties(self: *IResource, properties: ?*HEAP_PROPERTIES, flags: ?*HEAP_FLAGS) HRESULT {
        return self.vtable.GetHeapProperties(self, properties, flags);
    }
};

pub const IResource1 = extern union {
    pub const VTable = extern struct {
        base: IResource.VTable,
        GetProtectedResourceSession: *const fn (*IResource1, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,
    iresource: IResource,

    pub inline fn GetProtectedResourceSession(self: *IResource1, guid: *const GUID, session: *?*anyopaque) HRESULT {
        return self.vtable.GetProtectedResourceSession(self, guid, session);
    }
};

pub const ICommandAllocator = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x6102dee4,
        .Data2 = 0xaf59,
        .Data3 = 0x4b09,
        .Data4 = .{ 0xb9, 0x99, 0xb4, 0x4d, 0x73, 0xf0, 0x9b, 0x24 },
    };
    pub const VTable = extern struct {
        base: IPageable.VTable,
        Reset: *const fn (*ICommandAllocator) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,

    pub inline fn Reset(self: *ICommandAllocator) HRESULT {
        return self.vtable.Reset(self);
    }
};

pub const IFence = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x0a753dcf,
        .Data2 = 0xc4d8,
        .Data3 = 0x4b91,
        .Data4 = .{ 0xad, 0xf6, 0xbe, 0x5a, 0x60, 0xd9, 0x5a, 0x76 },
    };
    pub const VTable = extern struct {
        base: IPageable.VTable,
        GetCompletedValue: *const fn (*IFence) callconv(.winapi) UINT64,
        SetEventOnCompletion: *const fn (*IFence, UINT64, HANDLE) callconv(.winapi) HRESULT,
        Signal: *const fn (*IFence, UINT64) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,

    pub inline fn GetCompletedValue(self: *IFence) UINT64 {
        return self.vtable.GetCompletedValue(self);
    }
    pub inline fn SetEventOnCompletion(self: *IFence, value: UINT64, event: HANDLE) HRESULT {
        return self.vtable.SetEventOnCompletion(self, value, event);
    }
    pub inline fn Signal(self: *IFence, value: UINT64) HRESULT {
        return self.vtable.Signal(self, value);
    }
};

pub const IFence1 = extern union {
    pub const VTable = extern struct {
        base: IFence.VTable,
        GetCreationFlags: *const fn (*IFence1) callconv(.winapi) FENCE_FLAGS,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,
    ifence: IFence,

    pub inline fn GetCreationFlags(self: *IFence1) FENCE_FLAGS {
        return self.vtable.GetCreationFlags(self);
    }
};

pub const IPipelineState = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x765a30f3,
        .Data2 = 0xf624,
        .Data3 = 0x4c6f,
        .Data4 = .{ 0xa8, 0x28, 0xac, 0xe9, 0x48, 0x62, 0x24, 0x45 },
    };
    pub const VTable = extern struct {
        base: IPageable.VTable,
        GetCachedBlob: *const fn (*IPipelineState, **d3d.IBlob) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,

    pub inline fn GetCachedBlob(self: *IPipelineState, blob: **d3d.IBlob) HRESULT {
        return self.vtable.GetCachedBlob(self, blob);
    }
};

pub const IDescriptorHeap = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x8efb471d,
        .Data2 = 0x616c,
        .Data3 = 0x4f49,
        .Data4 = .{ 0x90, 0xf7, 0x12, 0x7b, 0xb7, 0x63, 0xfa, 0x51 },
    };
    pub const VTable = extern struct {
        base: IPageable.VTable,
        GetDesc: *const fn (*IDescriptorHeap, *DESCRIPTOR_HEAP_DESC) callconv(.winapi) *DESCRIPTOR_HEAP_DESC,
        GetCPUDescriptorHandleForHeapStart: *const fn (
            *IDescriptorHeap,
            *CPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
        GetGPUDescriptorHandleForHeapStart: *const fn (
            *IDescriptorHeap,
            *GPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,

    pub inline fn GetDesc(self: *IDescriptorHeap, desc: *DESCRIPTOR_HEAP_DESC) HRESULT {
        return self.vtable.GetDesc(self, desc);
    }
    pub inline fn GetCPUDescriptorHandleForHeapStart(self: *IDescriptorHeap, handle: *CPU_DESCRIPTOR_HANDLE) void {
        self.vtable.GetCPUDescriptorHandleForHeapStart(self, handle);
    }
    pub inline fn GetGPUDescriptorHandleForHeapStart(self: *IDescriptorHeap, handle: *GPU_DESCRIPTOR_HANDLE) void {
        self.vtable.GetGPUDescriptorHandleForHeapStart(self, handle);
    }
};

pub const ICommandList = extern union {
    pub const VTable = extern struct {
        base: IDeviceChild.VTable,
        GetType: *const fn (*ICommandList) callconv(.winapi) COMMAND_LIST_TYPE,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,

    pub inline fn GetType(self: *ICommandList) COMMAND_LIST_TYPE {
        return self.vtable.GetType(self);
    }
};

pub const IGraphicsCommandList = extern union {
    pub const IID: GUID = .parse("{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}");

    pub const VTable = extern struct {
        const T = IGraphicsCommandList;
        base: ICommandList.VTable,
        Close: *const fn (*T) callconv(.winapi) HRESULT,
        Reset: *const fn (*T, *ICommandAllocator, ?*IPipelineState) callconv(.winapi) HRESULT,
        ClearState: *const fn (*T, ?*IPipelineState) callconv(.winapi) void,
        DrawInstanced: *const fn (*T, UINT, UINT, UINT, UINT) callconv(.winapi) void,
        DrawIndexedInstanced: *const fn (*T, UINT, UINT, UINT, INT, UINT) callconv(.winapi) void,
        Dispatch: *const fn (*T, UINT, UINT, UINT) callconv(.winapi) void,
        CopyBufferRegion: *const fn (*T, *IResource, UINT64, *IResource, UINT64, UINT64) callconv(.winapi) void,
        CopyTextureRegion: *const fn (
            *T,
            *const TEXTURE_COPY_LOCATION,
            UINT,
            UINT,
            UINT,
            *const TEXTURE_COPY_LOCATION,
            ?*const BOX,
        ) callconv(.winapi) void,
        CopyResource: *const fn (*T, *IResource, *IResource) callconv(.winapi) void,
        CopyTiles: *const fn (
            *T,
            *IResource,
            *const TILED_RESOURCE_COORDINATE,
            *const TILE_REGION_SIZE,
            *IResource,
            buffer_start_offset_in_bytes: UINT64,
            TILE_COPY_FLAGS,
        ) callconv(.winapi) void,
        ResolveSubresource: *const fn (*T, *IResource, UINT, *IResource, UINT, dxgi.FORMAT) callconv(.winapi) void,
        IASetPrimitiveTopology: *const fn (*T, PRIMITIVE_TOPOLOGY) callconv(.winapi) void,
        RSSetViewports: *const fn (*T, UINT, [*]const VIEWPORT) callconv(.winapi) void,
        RSSetScissorRects: *const fn (*T, UINT, [*]const RECT) callconv(.winapi) void,
        OMSetBlendFactor: *const fn (*T, *const [4]FLOAT) callconv(.winapi) void,
        OMSetStencilRef: *const fn (*T, UINT) callconv(.winapi) void,
        SetPipelineState: *const fn (*T, ?*IPipelineState) callconv(.winapi) void,
        ResourceBarrier: *const fn (*T, UINT, [*]const RESOURCE_BARRIER) callconv(.winapi) void,
        ExecuteBundle: *const fn (*T, *IGraphicsCommandList) callconv(.winapi) void,
        SetDescriptorHeaps: *const fn (*T, UINT, [*]const *IDescriptorHeap) callconv(.winapi) void,
        SetComputeRootSignature: *const fn (*T, ?*IRootSignature) callconv(.winapi) void,
        SetGraphicsRootSignature: *const fn (*T, ?*IRootSignature) callconv(.winapi) void,
        SetComputeRootDescriptorTable: *const fn (*T, UINT, GPU_DESCRIPTOR_HANDLE) callconv(.winapi) void,
        SetGraphicsRootDescriptorTable: *const fn (*T, UINT, GPU_DESCRIPTOR_HANDLE) callconv(.winapi) void,
        SetComputeRoot32BitConstant: *const fn (*T, UINT, UINT, UINT) callconv(.winapi) void,
        SetGraphicsRoot32BitConstant: *const fn (*T, UINT, UINT, UINT) callconv(.winapi) void,
        SetComputeRoot32BitConstants: *const fn (*T, UINT, UINT, ?*const anyopaque, UINT) callconv(.winapi) void,
        SetGraphicsRoot32BitConstants: *const fn (*T, UINT, UINT, ?*const anyopaque, UINT) callconv(.winapi) void,
        SetComputeRootConstantBufferView: *const fn (*T, UINT, GPU_VIRTUAL_ADDRESS) callconv(.winapi) void,
        SetGraphicsRootConstantBufferView: *const fn (*T, UINT, GPU_VIRTUAL_ADDRESS) callconv(.winapi) void,
        SetComputeRootShaderResourceView: *const fn (*T, UINT, GPU_VIRTUAL_ADDRESS) callconv(.winapi) void,
        SetGraphicsRootShaderResourceView: *const fn (*T, UINT, GPU_VIRTUAL_ADDRESS) callconv(.winapi) void,
        SetComputeRootUnorderedAccessView: *const fn (*T, UINT, GPU_VIRTUAL_ADDRESS) callconv(.winapi) void,
        SetGraphicsRootUnorderedAccessView: *const fn (*T, UINT, GPU_VIRTUAL_ADDRESS) callconv(.winapi) void,
        IASetIndexBuffer: *const fn (*T, ?*const INDEX_BUFFER_VIEW) callconv(.winapi) void,
        IASetVertexBuffers: *const fn (*T, UINT, UINT, ?[*]const VERTEX_BUFFER_VIEW) callconv(.winapi) void,
        SOSetTargets: *const fn (*T, UINT, UINT, ?[*]const STREAM_OUTPUT_BUFFER_VIEW) callconv(.winapi) void,
        OMSetRenderTargets: *const fn (
            *T,
            UINT,
            ?[*]const CPU_DESCRIPTOR_HANDLE,
            BOOL,
            ?*const CPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
        ClearDepthStencilView: *const fn (
            *T,
            CPU_DESCRIPTOR_HANDLE,
            CLEAR_FLAGS,
            FLOAT,
            UINT8,
            UINT,
            ?[*]const RECT,
        ) callconv(.winapi) void,
        ClearRenderTargetView: *const fn (
            *T,
            CPU_DESCRIPTOR_HANDLE,
            *const [4]FLOAT,
            UINT,
            ?[*]const RECT,
        ) callconv(.winapi) void,
        ClearUnorderedAccessViewUint: *const fn (
            *T,
            GPU_DESCRIPTOR_HANDLE,
            CPU_DESCRIPTOR_HANDLE,
            *IResource,
            *const [4]UINT,
            UINT,
            ?[*]const RECT,
        ) callconv(.winapi) void,
        ClearUnorderedAccessViewFloat: *const fn (
            *T,
            GPU_DESCRIPTOR_HANDLE,
            CPU_DESCRIPTOR_HANDLE,
            *IResource,
            *const [4]FLOAT,
            UINT,
            ?[*]const RECT,
        ) callconv(.winapi) void,
        DiscardResource: *const fn (*T, *IResource, ?*const DISCARD_REGION) callconv(.winapi) void,
        BeginQuery: *const fn (*T, *IQueryHeap, QUERY_TYPE, UINT) callconv(.winapi) void,
        EndQuery: *const fn (*T, *IQueryHeap, QUERY_TYPE, UINT) callconv(.winapi) void,
        ResolveQueryData: *const fn (
            *T,
            *IQueryHeap,
            QUERY_TYPE,
            UINT,
            UINT,
            *IResource,
            UINT64,
        ) callconv(.winapi) void,
        SetPredication: *const fn (*T, ?*IResource, UINT64, PREDICATION_OP) callconv(.winapi) void,
        SetMarker: *const fn (*T, UINT, ?*const anyopaque, UINT) callconv(.winapi) void,
        BeginEvent: *const fn (*T, UINT, ?*const anyopaque, UINT) callconv(.winapi) void,
        EndEvent: *const fn (*T) callconv(.winapi) void,
        ExecuteIndirect: *const fn (
            *T,
            *ICommandSignature,
            UINT,
            *IResource,
            UINT64,
            ?*IResource,
            UINT64,
        ) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,

    pub inline fn Close(self: *IGraphicsCommandList) HRESULT {
        return self.vtable.Close(self);
    }
    pub inline fn Reset(self: *IGraphicsCommandList, allocator: *ICommandAllocator, pipeline_state: ?*IPipelineState) HRESULT {
        return self.vtable.Reset(self, allocator, pipeline_state);
    }
    pub inline fn ClearState(self: *IGraphicsCommandList, state: ?*IPipelineState) void {
        self.vtable.ClearState(self, state);
    }
    pub inline fn DrawInstanced(
        self: *IGraphicsCommandList,
        vertex_count: UINT,
        instance_count: UINT,
        start_vertex: UINT,
        start_instance: UINT,
    ) void {
        self.vtable.DrawInstanced(self, vertex_count, instance_count, start_vertex, start_instance);
    }
    pub inline fn DrawIndexedInstanced(
        self: *IGraphicsCommandList,
        index_count: UINT,
        instance_count: UINT,
        start_index: UINT,
        base_vertex: INT,
        start_instance: UINT,
    ) void {
        self.vtable.DrawIndexedInstanced(self, index_count, instance_count, start_index, base_vertex, start_instance);
    }
    pub inline fn Dispatch(self: *IGraphicsCommandList, thread_group_x: UINT, thread_group_y: UINT, thread_group_z: UINT) void {
        self.vtable.Dispatch(self, thread_group_x, thread_group_y, thread_group_z);
    }
    pub inline fn CopyBufferRegion(
        self: *IGraphicsCommandList,
        dst_resource: *IResource,
        dst_offset: UINT64,
        src_resource: *IResource,
        src_offset: UINT64,
        num_bytes: UINT64,
    ) void {
        self.vtable.CopyBufferRegion(self, dst_resource, dst_offset, src_resource, src_offset, num_bytes);
    }
    pub inline fn CopyTextureRegion(
        self: *IGraphicsCommandList,
        dst: *const TEXTURE_COPY_LOCATION,
        dst_x: UINT,
        dst_y: UINT,
        dst_z: UINT,
        src: *const TEXTURE_COPY_LOCATION,
        src_box: ?*const BOX,
    ) void {
        self.vtable.CopyTextureRegion(self, dst, dst_x, dst_y, dst_z, src, src_box);
    }
    pub inline fn CopyResource(self: *IGraphicsCommandList, dst_resource: *IResource, src_resource: *IResource) void {
        self.vtable.CopyResource(self, dst_resource, src_resource);
    }
    pub inline fn CopyTiles(
        self: *IGraphicsCommandList,
        dst_resource: *IResource,
        dst_coordinate: *const TILED_RESOURCE_COORDINATE,
        src_region: *const TILE_REGION_SIZE,
        src_resource: *IResource,
        buffer_start_offset_in_bytes: UINT64,
        flags: TILE_COPY_FLAGS,
    ) void {
        self.vtable.CopyTiles(self, dst_resource, dst_coordinate, src_region, src_resource, buffer_start_offset_in_bytes, flags);
    }
    pub inline fn ResolveSubresource(
        self: *IGraphicsCommandList,
        dst_resource: *IResource,
        dst_subresource: UINT,
        src_resource: *IResource,
        src_subresource: UINT,
        format: dxgi.FORMAT,
    ) void {
        self.vtable.ResolveSubresource(self, dst_resource, dst_subresource, src_resource, src_subresource, format);
    }
    pub inline fn IASetPrimitiveTopology(self: *IGraphicsCommandList, topology: PRIMITIVE_TOPOLOGY) void {
        self.vtable.IASetPrimitiveTopology(self, topology);
    }
    pub inline fn RSSetViewports(self: *IGraphicsCommandList, NumViewports: u32, pViewports: [*]const VIEWPORT) void {
        return self.vtable.RSSetViewports(self, NumViewports, pViewports);
    }
    pub inline fn RSSetScissorRects(self: *IGraphicsCommandList, NumRects: u32, pRects: [*]const RECT) void {
        return self.vtable.RSSetScissorRects(self, NumRects, pRects);
    }
    pub inline fn OMSetBlendFactor(self: *IGraphicsCommandList, BlendFactor: *const [4]f32) void {
        return self.vtable.OMSetBlendFactor(self, BlendFactor);
    }
    pub inline fn OMSetStencilRef(self: *IGraphicsCommandList, StencilRef: u32) void {
        return self.vtable.OMSetStencilRef(self, StencilRef);
    }
    pub inline fn SetPipelineState(self: *IGraphicsCommandList, pPipelineState: ?*IPipelineState) void {
        return self.vtable.SetPipelineState(self, pPipelineState);
    }
    pub inline fn ResourceBarrier(self: *IGraphicsCommandList, NumBarriers: u32, pBarriers: [*]const RESOURCE_BARRIER) void {
        return self.vtable.ResourceBarrier(self, NumBarriers, pBarriers);
    }
    pub inline fn ExecuteBundle(self: *IGraphicsCommandList, pCommandList: ?*IGraphicsCommandList) void {
        return self.vtable.ExecuteBundle(self, pCommandList);
    }
    pub inline fn SetDescriptorHeaps(self: *IGraphicsCommandList, NumDescriptorHeaps: u32, ppDescriptorHeaps: [*]const *IDescriptorHeap) void {
        return self.vtable.SetDescriptorHeaps(self, NumDescriptorHeaps, ppDescriptorHeaps);
    }
    pub inline fn SetComputeRootSignature(self: *IGraphicsCommandList, pRootSignature: ?*IRootSignature) void {
        return self.vtable.SetComputeRootSignature(self, pRootSignature);
    }
    pub inline fn SetGraphicsRootSignature(self: *IGraphicsCommandList, pRootSignature: ?*IRootSignature) void {
        return self.vtable.SetGraphicsRootSignature(self, pRootSignature);
    }
    pub inline fn SetComputeRootDescriptorTable(self: *IGraphicsCommandList, RootParameterIndex: u32, BaseDescriptor: GPU_DESCRIPTOR_HANDLE) void {
        return self.vtable.SetComputeRootDescriptorTable(self, RootParameterIndex, BaseDescriptor);
    }
    pub inline fn SetGraphicsRootDescriptorTable(self: *IGraphicsCommandList, RootParameterIndex: u32, BaseDescriptor: GPU_DESCRIPTOR_HANDLE) void {
        return self.vtable.SetGraphicsRootDescriptorTable(self, RootParameterIndex, BaseDescriptor);
    }
    pub inline fn SetComputeRoot32BitConstant(self: *IGraphicsCommandList, RootParameterIndex: u32, SrcData: u32, DestOffsetIn32BitValues: u32) void {
        return self.vtable.SetComputeRoot32BitConstant(self, RootParameterIndex, SrcData, DestOffsetIn32BitValues);
    }
    pub inline fn SetGraphicsRoot32BitConstant(self: *IGraphicsCommandList, RootParameterIndex: u32, SrcData: u32, DestOffsetIn32BitValues: u32) void {
        return self.vtable.SetGraphicsRoot32BitConstant(self, RootParameterIndex, SrcData, DestOffsetIn32BitValues);
    }
    pub inline fn SetComputeRoot32BitConstants(self: *IGraphicsCommandList, RootParameterIndex: u32, Num32BitValuesToSet: u32, pSrcData: ?*const anyopaque, DestOffsetIn32BitValues: u32) void {
        return self.vtable.SetComputeRoot32BitConstants(self, RootParameterIndex, Num32BitValuesToSet, pSrcData, DestOffsetIn32BitValues);
    }
    pub inline fn SetGraphicsRoot32BitConstants(self: *IGraphicsCommandList, RootParameterIndex: u32, Num32BitValuesToSet: u32, pSrcData: ?*const anyopaque, DestOffsetIn32BitValues: u32) void {
        return self.vtable.SetGraphicsRoot32BitConstants(self, RootParameterIndex, Num32BitValuesToSet, pSrcData, DestOffsetIn32BitValues);
    }
    pub inline fn SetComputeRootConstantBufferView(self: *IGraphicsCommandList, RootParameterIndex: u32, BufferLocation: u64) void {
        return self.vtable.SetComputeRootConstantBufferView(self, RootParameterIndex, BufferLocation);
    }
    pub inline fn SetGraphicsRootConstantBufferView(self: *IGraphicsCommandList, RootParameterIndex: u32, BufferLocation: u64) void {
        return self.vtable.SetGraphicsRootConstantBufferView(self, RootParameterIndex, BufferLocation);
    }
    pub inline fn SetComputeRootShaderResourceView(self: *IGraphicsCommandList, RootParameterIndex: u32, BufferLocation: u64) void {
        return self.vtable.SetComputeRootShaderResourceView(self, RootParameterIndex, BufferLocation);
    }
    pub inline fn SetGraphicsRootShaderResourceView(self: *IGraphicsCommandList, RootParameterIndex: u32, BufferLocation: u64) void {
        return self.vtable.SetGraphicsRootShaderResourceView(self, RootParameterIndex, BufferLocation);
    }
    pub inline fn SetComputeRootUnorderedAccessView(self: *IGraphicsCommandList, RootParameterIndex: u32, BufferLocation: u64) void {
        return self.vtable.SetComputeRootUnorderedAccessView(self, RootParameterIndex, BufferLocation);
    }
    pub inline fn SetGraphicsRootUnorderedAccessView(self: *IGraphicsCommandList, RootParameterIndex: u32, BufferLocation: u64) void {
        return self.vtable.SetGraphicsRootUnorderedAccessView(self, RootParameterIndex, BufferLocation);
    }
    pub inline fn IASetIndexBuffer(self: *IGraphicsCommandList, pView: ?*const INDEX_BUFFER_VIEW) void {
        return self.vtable.IASetIndexBuffer(self, pView);
    }
    pub inline fn IASetVertexBuffers(self: *IGraphicsCommandList, StartSlot: u32, NumViews: u32, pViews: ?[*]const VERTEX_BUFFER_VIEW) void {
        return self.vtable.IASetVertexBuffers(self, StartSlot, NumViews, pViews);
    }
    pub inline fn SOSetTargets(self: *IGraphicsCommandList, StartSlot: u32, NumViews: u32, pViews: ?[*]const STREAM_OUTPUT_BUFFER_VIEW) void {
        return self.vtable.SOSetTargets(self, StartSlot, NumViews, pViews);
    }
    pub inline fn OMSetRenderTargets(self: *IGraphicsCommandList, NumRenderTargetDescriptors: u32, pRenderTargetDescriptors: ?[*]const CPU_DESCRIPTOR_HANDLE, RTsSingleHandleToDescriptorRange: BOOL, pDepthStencilDescriptor: ?*const CPU_DESCRIPTOR_HANDLE) void {
        return self.vtable.OMSetRenderTargets(self, NumRenderTargetDescriptors, pRenderTargetDescriptors, RTsSingleHandleToDescriptorRange, pDepthStencilDescriptor);
    }
    pub inline fn ClearDepthStencilView(self: *IGraphicsCommandList, DepthStencilView: CPU_DESCRIPTOR_HANDLE, ClearFlags: CLEAR_FLAGS, Depth: f32, Stencil: u8, NumRects: u32, pRects: ?[*]const RECT) void {
        return self.vtable.ClearDepthStencilView(self, DepthStencilView, ClearFlags, Depth, Stencil, NumRects, pRects);
    }
    pub inline fn ClearRenderTargetView(self: *IGraphicsCommandList, RenderTargetView: CPU_DESCRIPTOR_HANDLE, ColorRGBA: *const [4]f32, NumRects: u32, pRects: ?[*]const RECT) void {
        return self.vtable.ClearRenderTargetView(self, RenderTargetView, ColorRGBA, NumRects, pRects);
    }
    pub inline fn ClearUnorderedAccessViewUint(self: *IGraphicsCommandList, ViewGPUHandleInCurrentHeap: GPU_DESCRIPTOR_HANDLE, ViewCPUHandle: CPU_DESCRIPTOR_HANDLE, pResource: ?*IResource, Values: ?*const u32, NumRects: u32, pRects: ?[*]const RECT) void {
        return self.vtable.ClearUnorderedAccessViewUint(self, ViewGPUHandleInCurrentHeap, ViewCPUHandle, pResource, Values, NumRects, pRects);
    }
    pub inline fn ClearUnorderedAccessViewFloat(self: *IGraphicsCommandList, ViewGPUHandleInCurrentHeap: GPU_DESCRIPTOR_HANDLE, ViewCPUHandle: CPU_DESCRIPTOR_HANDLE, pResource: ?*IResource, Values: ?*const f32, NumRects: u32, pRects: ?[*]const RECT) void {
        return self.vtable.ClearUnorderedAccessViewFloat(self, ViewGPUHandleInCurrentHeap, ViewCPUHandle, pResource, Values, NumRects, pRects);
    }
    pub inline fn DiscardResource(self: *IGraphicsCommandList, pResource: ?*IResource, pRegion: ?*const DISCARD_REGION) void {
        return self.vtable.DiscardResource(self, pResource, pRegion);
    }
    pub inline fn BeginQuery(self: *IGraphicsCommandList, pQueryHeap: ?*IQueryHeap, Type: QUERY_TYPE, Index: u32) void {
        return self.vtable.BeginQuery(self, pQueryHeap, Type, Index);
    }
    pub inline fn EndQuery(self: *IGraphicsCommandList, pQueryHeap: ?*IQueryHeap, Type: QUERY_TYPE, Index: u32) void {
        return self.vtable.EndQuery(self, pQueryHeap, Type, Index);
    }
    pub inline fn ResolveQueryData(self: *IGraphicsCommandList, pQueryHeap: ?*IQueryHeap, Type: QUERY_TYPE, StartIndex: u32, NumQueries: u32, pDestinationBuffer: ?*IResource, AlignedDestinationBufferOffset: u64) void {
        return self.vtable.ResolveQueryData(self, pQueryHeap, Type, StartIndex, NumQueries, pDestinationBuffer, AlignedDestinationBufferOffset);
    }
    pub inline fn SetPredication(self: *IGraphicsCommandList, pBuffer: ?*IResource, AlignedBufferOffset: u64, Operation: PREDICATION_OP) void {
        return self.vtable.SetPredication(self, pBuffer, AlignedBufferOffset, Operation);
    }
    pub inline fn SetMarker(self: *IGraphicsCommandList, Metadata: u32, pData: ?*const anyopaque, Size: u32) void {
        return self.vtable.SetMarker(self, Metadata, pData, Size);
    }
    pub inline fn BeginEvent(self: *IGraphicsCommandList, Metadata: u32, pData: ?*const anyopaque, Size: u32) void {
        return self.vtable.BeginEvent(self, Metadata, pData, Size);
    }
    pub inline fn EndEvent(self: *IGraphicsCommandList) void {
        return self.vtable.EndEvent(self);
    }
    pub inline fn ExecuteIndirect(self: *IGraphicsCommandList, pCommandSignature: ?*ICommandSignature, MaxCommandCount: u32, pArgumentBuffer: ?*IResource, ArgumentBufferOffset: u64, pCountBuffer: ?*IResource, CountBufferOffset: u64) void {
        return self.vtable.ExecuteIndirect(self, pCommandSignature, MaxCommandCount, pArgumentBuffer, ArgumentBufferOffset, pCountBuffer, CountBufferOffset);
    }
};

pub const RANGE_UINT64 = extern struct {
    Begin: UINT64,
    End: UINT64,
};

pub const SUBRESOURCE_RANGE_UINT64 = extern struct {
    Subresource: UINT,
    Range: RANGE_UINT64,
};

pub const SAMPLE_POSITION = extern struct {
    X: INT8,
    Y: INT8,
};

pub const RESOLVE_MODE = enum(UINT) {
    DECOMPRESS = 0,
    MIN = 1,
    MAX = 2,
    AVERAGE = 3,
    ENCODE_SAMPLER_FEEDBACK = 4,
    DECODE_SAMPLER_FEEDBACK = 5,
};

pub const IGraphicsCommandList1 = extern union {
    pub const IID: GUID = .parse("{553103fb-1fe7-4557-bb38-946d7d0e7ca7}");
    pub const VTable = extern struct {
        const T = IGraphicsCommandList1;
        base: IGraphicsCommandList.VTable,
        AtomicCopyBufferUINT: *const fn (
            *T,
            *IResource,
            UINT64,
            *IResource,
            UINT64,
            UINT,
            [*]const *IResource,
            [*]const SUBRESOURCE_RANGE_UINT64,
        ) callconv(.winapi) void,
        AtomicCopyBufferUINT64: *const fn (
            *T,
            *IResource,
            UINT64,
            *IResource,
            UINT64,
            UINT,
            [*]const *IResource,
            [*]const SUBRESOURCE_RANGE_UINT64,
        ) callconv(.winapi) void,
        OMSetDepthBounds: *const fn (*T, FLOAT, FLOAT) callconv(.winapi) void,
        SetSamplePositions: *const fn (*T, UINT, UINT, *SAMPLE_POSITION) callconv(.winapi) void,
        ResolveSubresourceRegion: *const fn (
            *T,
            *IResource,
            UINT,
            UINT,
            UINT,
            *IResource,
            UINT,
            *RECT,
            dxgi.FORMAT,
            RESOLVE_MODE,
        ) callconv(.winapi) void,
        SetViewInstanceMask: *const fn (*T, UINT) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,

    pub inline fn AtomicCopyBufferUINT(
        self: *IGraphicsCommandList1,
        dst_buffer: *IResource,
        dst_offset: UINT64,
        src_buffer: *IResource,
        src_offset: UINT64,
        count: UINT,
        pp_atomic_resources: [*]const *IResource,
        p_atomic_subresource_ranges: [*]const SUBRESOURCE_RANGE_UINT64,
    ) void {
        self.vtable.AtomicCopyBufferUINT(self, dst_buffer, dst_offset, src_buffer, src_offset, count, pp_atomic_resources, p_atomic_subresource_ranges);
    }
    pub inline fn AtomicCopyBufferUINT64(
        self: *IGraphicsCommandList1,
        dst_buffer: *IResource,
        dst_offset: UINT64,
        src_buffer: *IResource,
        src_offset: UINT64,
        count: UINT,
        pp_atomic_resources: [*]const *IResource,
        p_atomic_subresource_ranges: [*]const SUBRESOURCE_RANGE_UINT64,
    ) void {
        self.vtable.AtomicCopyBufferUINT64(self, dst_buffer, dst_offset, src_buffer, src_offset, count, pp_atomic_resources, p_atomic_subresource_ranges);
    }
    pub inline fn OMSetDepthBounds(self: *IGraphicsCommandList1, min: FLOAT, max: FLOAT) void {
        self.vtable.OMSetDepthBounds(self, min, max);
    }
    pub inline fn SetSamplePositions(self: *IGraphicsCommandList1, num_samples: UINT, sample_positions: *SAMPLE_POSITION) void {
        self.vtable.SetSamplePositions(self, num_samples, sample_positions);
    }
    pub inline fn ResolveSubresourceRegion(
        self: *IGraphicsCommandList1,
        dst_resource: *IResource,
        dst_subresource: UINT,
        dst_x: UINT,
        dst_y: UINT,
        src_resource: *IResource,
        src_subresource: UINT,
        src_rect: *RECT,
        format: dxgi.FORMAT,
        resolve_mode: RESOLVE_MODE,
    ) void {
        self.vtable.ResolveSubresourceRegion(self, dst_resource, dst_subresource, dst_x, dst_y, src_resource, src_subresource, src_rect, format, resolve_mode);
    }
};

pub const WRITEBUFFERIMMEDIATE_PARAMETER = extern struct {
    Dest: GPU_VIRTUAL_ADDRESS,
    Value: UINT32,
};

pub const WRITEBUFFERIMMEDIATE_MODE = enum(UINT) {
    DEFAULT = 0,
    MARKER_IN = 0x1,
    MARKER_OUT = 0x2,
};

pub const IGraphicsCommandList2 = extern union {
    pub const IID: GUID = .parse("{38C3E585-FF17-412C-9150-4FC6F9D72A28}");
    pub const VTable = extern struct {
        base: IGraphicsCommandList1.VTable,
        WriteBufferImmediate: *const fn (
            *IGraphicsCommandList2,
            UINT,
            [*]const WRITEBUFFERIMMEDIATE_PARAMETER,
            ?[*]const WRITEBUFFERIMMEDIATE_MODE,
        ) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,
    igraphicscommandlist1: IGraphicsCommandList1,

    pub inline fn WriteBufferImmediate(
        self: *IGraphicsCommandList2,
        count: UINT,
        params: [*]const WRITEBUFFERIMMEDIATE_PARAMETER,
        modes: ?[*]const WRITEBUFFERIMMEDIATE_MODE,
    ) void {
        self.vtable.WriteBufferImmediate(self, count, params, modes);
    }
};

pub const IGraphicsCommandList3 = extern union {
    pub const IID: GUID = .parse("{6FDA83A7-B84C-4E38-9AC8-C7BD22016B3D}");
    pub const VTable = extern struct {
        base: IGraphicsCommandList2.VTable,
        SetProtectedResourceSession: *const fn (
            *IGraphicsCommandList3,
            ?*IProtectedResourceSession,
        ) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,
    igraphicscommandlist1: IGraphicsCommandList1,
    igraphicscommandlist2: IGraphicsCommandList2,

    pub inline fn SetProtectedResourceSession(self: *IGraphicsCommandList3, prsession: ?*IProtectedResourceSession) void {
        self.vtable.SetProtectedResourceSession(self, prsession);
    }
};

pub const RENDER_PASS_BEGINNING_ACCESS_TYPE = enum(UINT) {
    DISCARD = 0,
    PRESERVE = 1,
    CLEAR = 2,
    NO_ACCESS = 3,
};

pub const RENDER_PASS_BEGINNING_ACCESS_CLEAR_PARAMETERS = extern struct {
    ClearValue: CLEAR_VALUE,
};

pub const RENDER_PASS_BEGINNING_ACCESS = extern struct {
    Type: RENDER_PASS_BEGINNING_ACCESS_TYPE,
    u: extern union {
        Clear: RENDER_PASS_BEGINNING_ACCESS_CLEAR_PARAMETERS,
    },
};

pub const RENDER_PASS_ENDING_ACCESS_TYPE = enum(UINT) {
    DISCARD = 0,
    PRESERVE = 1,
    RESOLVE = 2,
    NO_ACCESS = 3,
};

pub const RENDER_PASS_ENDING_ACCESS_RESOLVE_SUBRESOURCE_PARAMETERS = extern struct {
    SrcSubresource: UINT,
    DstSubresource: UINT,
    DstX: UINT,
    DstY: UINT,
    SrcRect: RECT,
};

pub const RENDER_PASS_ENDING_ACCESS_RESOLVE_PARAMETERS = extern struct {
    pSrcResource: *IResource,
    pDstResource: *IResource,
    SubresourceCount: UINT,
    pSubresourceParameters: [*]const RENDER_PASS_ENDING_ACCESS_RESOLVE_SUBRESOURCE_PARAMETERS,
    Format: dxgi.FORMAT,
    ResolveMode: RESOLVE_MODE,
    PreserveResolveSource: BOOL,
};

pub const RENDER_PASS_ENDING_ACCESS = extern struct {
    Type: RENDER_PASS_ENDING_ACCESS_TYPE,
    u: extern union {
        Resolve: RENDER_PASS_ENDING_ACCESS_RESOLVE_PARAMETERS,
    },
};

pub const RENDER_PASS_RENDER_TARGET_DESC = extern struct {
    cpuDescriptor: CPU_DESCRIPTOR_HANDLE,
    BeginningAccess: RENDER_PASS_BEGINNING_ACCESS,
    EndingAccess: RENDER_PASS_ENDING_ACCESS,
};

pub const RENDER_PASS_DEPTH_STENCIL_DESC = extern struct {
    cpuDescriptor: CPU_DESCRIPTOR_HANDLE,
    DepthBeginningAccess: RENDER_PASS_BEGINNING_ACCESS,
    StencilBeginningAccess: RENDER_PASS_BEGINNING_ACCESS,
    DepthEndingAccess: RENDER_PASS_ENDING_ACCESS,
    StencilEndingAccess: RENDER_PASS_ENDING_ACCESS,
};

pub const RENDER_PASS_FLAGS = packed struct(UINT) {
    ALLOW_UAV_WRITES: bool = false,
    SUSPENDING_PASS: bool = false,
    RESUMING_PASS: bool = false,
    __unused: u29 = 0,
};

pub const META_COMMAND_PARAMETER_TYPE = enum(UINT) {
    FLOAT = 0,
    UINT64 = 1,
    GPU_VIRTUAL_ADDRESS = 2,
    CPU_DESCRIPTOR_HANDLE_HEAP_TYPE_CBV_SRV_UAV = 3,
    GPU_DESCRIPTOR_HANDLE_HEAP_TYPE_CBV_SRV_UAV = 4,
};

pub const META_COMMAND_PARAMETER_FLAGS = packed struct(UINT) {
    INPUT: bool = false,
    OUTPUT: bool = false,
    __unused: u30 = 0,
};

pub const META_COMMAND_PARAMETER_STAGE = enum(UINT) {
    CREATION = 0,
    INITIALIZATION = 1,
    EXECUTION = 2,
};

pub const META_COMMAND_PARAMETER_DESC = extern struct {
    Name: LPCWSTR,
    Type: META_COMMAND_PARAMETER_TYPE,
    Flags: META_COMMAND_PARAMETER_FLAGS,
    RequiredResourceState: RESOURCE_STATES,
    StructureOffset: UINT,
};

pub const GRAPHICS_STATES = packed struct(UINT) {
    IA_VERTEX_BUFFERS: bool = false,
    IA_INDEX_BUFFER: bool = false,
    IA_PRIMITIVE_TOPOLOGY: bool = false,
    DESCRIPTOR_HEAP: bool = false,
    GRAPHICS_ROOT_SIGNATURE: bool = false,
    COMPUTE_ROOT_SIGNATURE: bool = false,
    RS_VIEWPORTS: bool = false,
    RS_SCISSOR_RECTS: bool = false,
    PREDICATION: bool = false,
    OM_RENDER_TARGETS: bool = false,
    OM_STENCIL_REF: bool = false,
    OM_BLEND_FACTOR: bool = false,
    PIPELINE_STATE: bool = false,
    SO_TARGETS: bool = false,
    OM_DEPTH_BOUNDS: bool = false,
    SAMPLE_POSITIONS: bool = false,
    VIEW_INSTANCE_MASK: bool = false,
    __unused: u15 = 0,
};

pub const META_COMMAND_DESC = extern struct {
    Id: GUID,
    Name: LPCWSTR,
    InitializationDirtyState: GRAPHICS_STATES,
    ExecutionDirtyState: GRAPHICS_STATES,
};

pub const IMetaCommand = extern union {
    pub const VTable = extern struct {
        base: IDeviceChild.VTable,
        GetRequiredParameterResourceSize: *const fn (
            *IMetaCommand,
            META_COMMAND_PARAMETER_STAGE,
            UINT,
        ) callconv(.winapi) UINT64,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,

    pub inline fn GetRequiredParameterResourceSize(self: *IMetaCommand, stage: META_COMMAND_PARAMETER_STAGE, parameter_index: UINT) UINT64 {
        return self.vtable.GetRequiredParameterResourceSize(self, stage, parameter_index);
    }
};

pub const STATE_SUBOBJECT_TYPE = enum(UINT) {
    STATE_OBJECT_CONFIG = 0,
    GLOBAL_ROOT_SIGNATURE = 1,
    LOCAL_ROOT_SIGNATURE = 2,
    NODE_MASK = 3,
    DXIL_LIBRARY = 5,
    EXISTING_COLLECTION = 6,
    SUBOBJECT_TO_EXPORTS_ASSOCIATION = 7,
    DXIL_SUBOBJECT_TO_EXPORTS_ASSOCIATION = 8,
    RAYTRACING_SHADER_CONFIG = 9,
    RAYTRACING_PIPELINE_CONFIG = 10,
    HIT_GROUP = 11,
    RAYTRACING_PIPELINE_CONFIG1 = 12,
    MAX_VALID,
};

pub const STATE_SUBOBJECT = extern struct {
    Type: STATE_SUBOBJECT_TYPE,
    pDesc: *const anyopaque,
};

pub const STATE_OBJECT_FLAGS = packed struct(UINT) {
    ALLOW_LOCAL_DEPENDENCIES_ON_EXTERNAL_DEFINITIONS: bool = false,
    ALLOW_EXTERNAL_DEPENDENCIES_ON_LOCAL_DEFINITIONS: bool = false,
    ALLOW_STATE_OBJECT_ADDITIONS: bool = false,
    __unused: u29 = 0,
};

pub const STATE_OBJECT_CONFIG = extern struct {
    Flags: STATE_OBJECT_FLAGS,
};

pub const GLOBAL_ROOT_SIGNATURE = extern struct {
    pGlobalRootSignature: *IRootSignature,
};

pub const LOCAL_ROOT_SIGNATURE = extern struct {
    pLocalRootSignature: *IRootSignature,
};

pub const NODE_MASK = extern struct {
    NodeMask: UINT,
};

pub const EXPORT_FLAGS = packed struct(UINT) {
    __unused: u32 = 0,
};

pub const EXPORT_DESC = extern struct {
    Name: LPCWSTR,
    ExportToRename: LPCWSTR,
    Flags: EXPORT_FLAGS,
};

pub const DXIL_LIBRARY_DESC = extern struct {
    DXILLibrary: SHADER_BYTECODE,
    NumExports: UINT,
    pExports: ?[*]EXPORT_DESC,
};

pub const EXISTING_COLLECTION_DESC = extern struct {
    pExistingCollection: *IStateObject,
    NumExports: UINT,
    pExports: [*]EXPORT_DESC,
};

pub const SUBOBJECT_TO_EXPORTS_ASSOCIATION = extern struct {
    pSubobjectToAssociate: *const STATE_SUBOBJECT,
    NumExports: UINT,
    pExports: [*]LPCWSTR,
};

pub const DXIL_SUBOBJECT_TO_EXPORTS_ASSOCIATION = extern struct {
    SubobjectToAssociate: LPCWSTR,
    NumExports: UINT,
    pExports: [*]LPCWSTR,
};

pub const HIT_GROUP_TYPE = enum(UINT) {
    TRIANGLES = 0,
    PROCEDURAL_PRIMITIVE = 0x1,
};

pub const HIT_GROUP_DESC = extern struct {
    HitGroupExport: LPCWSTR,
    Type: HIT_GROUP_TYPE,
    AnyHitShaderImport: LPCWSTR,
    ClosestHitShaderImport: LPCWSTR,
    IntersectionShaderImport: LPCWSTR,
};

pub const RAYTRACING_SHADER_CONFIG = extern struct {
    MaxPayloadSizeInBytes: UINT,
    MaxAttributeSizeInBytes: UINT,
};

pub const RAYTRACING_PIPELINE_CONFIG = extern struct {
    MaxTraceRecursionDepth: UINT,
};

pub const RAYTRACING_PIPELINE_FLAGS = packed struct(UINT) {
    __unused0: bool = false, // 0x1
    __unused1: bool = false,
    __unused2: bool = false,
    __unused3: bool = false,
    __unused4: bool = false, // 0x10
    __unused5: bool = false,
    __unused6: bool = false,
    __unused7: bool = false,
    SKIP_TRIANGLES: bool = false, // 0x100
    SKIP_PROCEDURAL_PRIMITIVES: bool = false,
    __unused: u22 = 0,
};

pub const RAYTRACING_PIPELINE_CONFIG1 = extern struct {
    MaxTraceRecursionDepth: UINT,
    Flags: RAYTRACING_PIPELINE_FLAGS,
};

pub const STATE_OBJECT_TYPE = enum(UINT) {
    COLLECTION = 0,
    RAYTRACING_PIPELINE = 3,
};

pub const STATE_OBJECT_DESC = extern struct {
    Type: STATE_OBJECT_TYPE,
    NumSubobjects: UINT,
    pSubobjects: [*]const STATE_SUBOBJECT,
};

pub const RAYTRACING_GEOMETRY_FLAGS = packed struct(UINT) {
    OPAQUE: bool = false,
    NO_DUPLICATE_ANYHIT_INVOCATION: bool = false,
    __unused: u30 = 0,
};

pub const RAYTRACING_GEOMETRY_TYPE = enum(UINT) {
    TRIANGLES = 0,
    PROCEDURAL_PRIMITIVE_AABBS = 1,
};

pub const RAYTRACING_INSTANCE_FLAGS = packed struct(UINT) {
    TRIANGLE_CULL_DISABLE: bool = false,
    TRIANGLE_FRONT_COUNTERCLOCKWISE: bool = false,
    FORCE_OPAQUE: bool = false,
    FORCE_NON_OPAQUE: bool = false,
    __unused: u28 = 0,
};

pub const GPU_VIRTUAL_ADDRESS_AND_STRIDE = extern struct {
    StartAddress: GPU_VIRTUAL_ADDRESS,
    StrideInBytes: UINT64,
};

pub const GPU_VIRTUAL_ADDRESS_RANGE = extern struct {
    StartAddress: GPU_VIRTUAL_ADDRESS,
    SizeInBytes: UINT64,
};

pub const GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE = extern struct {
    StartAddress: GPU_VIRTUAL_ADDRESS,
    SizeInBytes: UINT64,
    StrideInBytes: UINT64,
};

pub const RAYTRACING_GEOMETRY_TRIANGLES_DESC = extern struct {
    Transform3x4: GPU_VIRTUAL_ADDRESS,
    IndexFormat: dxgi.FORMAT,
    VertexFormat: dxgi.FORMAT,
    IndexCount: UINT,
    VertexCount: UINT,
    IndexBuffer: GPU_VIRTUAL_ADDRESS,
    VertexBuffer: GPU_VIRTUAL_ADDRESS_AND_STRIDE,
};

pub const RAYTRACING_AABB = extern struct {
    MinX: FLOAT,
    MinY: FLOAT,
    MinZ: FLOAT,
    MaxX: FLOAT,
    MaxY: FLOAT,
    MaxZ: FLOAT,
};

pub const RAYTRACING_GEOMETRY_AABBS_DESC = extern struct {
    AABBCount: UINT64,
    AABBs: GPU_VIRTUAL_ADDRESS_AND_STRIDE,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAGS = packed struct(UINT) {
    ALLOW_UPDATE: bool = false,
    ALLOW_COMPACTION: bool = false,
    PREFER_FAST_TRACE: bool = false,
    PREFER_FAST_BUILD: bool = false,
    MINIMIZE_MEMORY: bool = false,
    PERFORM_UPDATE: bool = false,
    __unused: u26 = 0,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_COPY_MODE = enum(UINT) {
    CLONE = 0,
    COMPACT = 0x1,
    VISUALIZATION_DECODE_FOR_TOOLS = 0x2,
    SERIALIZE = 0x3,
    DESERIALIZE = 0x4,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_TYPE = enum(UINT) {
    TOP_LEVEL = 0,
    BOTTOM_LEVEL = 0x1,
};

pub const ELEMENTS_LAYOUT = enum(UINT) {
    ARRAY = 0,
    ARRAY_OF_POINTERS = 0x1,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_TYPE = enum(UINT) {
    COMPACTED_SIZE = 0,
    TOOLS_VISUALIZATION = 0x1,
    SERIALIZATION = 0x2,
    CURRENT_SIZE = 0x3,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_DESC = extern struct {
    DestBuffer: GPU_VIRTUAL_ADDRESS,
    InfoType: RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_TYPE,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_COMPACTED_SIZE_DESC = extern struct {
    CompactedSizeInBytes: UINT64,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_TOOLS_VISUALIZATION_DESC = extern struct {
    DecodedSizeInBytes: UINT64,
};

pub const BUILD_RAYTRACING_ACCELERATION_STRUCTURE_TOOLS_VISUALIZATION_HEADER = extern struct {
    Type: RAYTRACING_ACCELERATION_STRUCTURE_TYPE,
    NumDescs: UINT,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_SERIALIZATION_DESC = extern struct {
    SerializedSizeInBytes: UINT64,
    NumBottomLevelAccelerationStructurePointers: UINT64,
};

pub const SERIALIZED_DATA_DRIVER_MATCHING_IDENTIFIER = extern struct {
    DriverOpaqueGUID: GUID,
    DriverOpaqueVersioningData: [16]BYTE,
};

pub const SERIALIZED_DATA_TYPE = enum(UINT) {
    RAYTRACING_ACCELERATION_STRUCTURE = 0,
};

pub const DRIVER_MATCHING_IDENTIFIER_STATUS = enum(UINT) {
    COMPATIBLE_WITH_DEVICE = 0,
    UNSUPPORTED_TYPE = 0x1,
    UNRECOGNIZED = 0x2,
    INCOMPATIBLE_VERSION = 0x3,
    INCOMPATIBLE_TYPE = 0x4,
};

pub const SERIALIZED_RAYTRACING_ACCELERATION_STRUCTURE_HEADER = extern struct {
    DriverMatchingIdentifier: SERIALIZED_DATA_DRIVER_MATCHING_IDENTIFIER,
    SerializedSizeInBytesIncludingHeader: UINT64,
    DeserializedSizeInBytes: UINT64,
    NumBottomLevelAccelerationStructurePointersAfterHeader: UINT64,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_CURRENT_SIZE_DESC = extern struct {
    CurrentSizeInBytes: UINT64,
};

pub const RAYTRACING_INSTANCE_DESC = extern struct {
    Transform: [3][4]FLOAT align(16),
    p: packed struct(u64) {
        InstanceID: u24,
        InstanceMask: u8,
        InstanceContributionToHitGroupIndex: u24,
        Flags: u8,
    },
    AccelerationStructure: GPU_VIRTUAL_ADDRESS,
};
comptime {
    std.debug.assert(@sizeOf(RAYTRACING_INSTANCE_DESC) == 64);
    std.debug.assert(@alignOf(RAYTRACING_INSTANCE_DESC) == 16);
}

pub const RAYTRACING_GEOMETRY_DESC = extern struct {
    Type: RAYTRACING_GEOMETRY_TYPE,
    Flags: RAYTRACING_GEOMETRY_FLAGS,
    u: extern union {
        Triangles: RAYTRACING_GEOMETRY_TRIANGLES_DESC,
        AABBs: RAYTRACING_GEOMETRY_AABBS_DESC,
    },
};

pub const BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS = extern struct {
    Type: RAYTRACING_ACCELERATION_STRUCTURE_TYPE,
    Flags: RAYTRACING_ACCELERATION_STRUCTURE_BUILD_FLAGS,
    NumDescs: UINT,
    DescsLayout: ELEMENTS_LAYOUT,
    u: extern union {
        InstanceDescs: GPU_VIRTUAL_ADDRESS,
        pGeometryDescs: [*]const RAYTRACING_GEOMETRY_DESC,
        ppGeometryDescs: [*]const *RAYTRACING_GEOMETRY_DESC,
    },
};

pub const BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC = extern struct {
    DestAccelerationStructureData: GPU_VIRTUAL_ADDRESS,
    Inputs: BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS,
    SourceAccelerationStructureData: GPU_VIRTUAL_ADDRESS,
    ScratchAccelerationStructureData: GPU_VIRTUAL_ADDRESS,
};

pub const RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO = extern struct {
    ResultDataMaxSizeInBytes: UINT64,
    ScratchDataSizeInBytes: UINT64,
    UpdateScratchDataSizeInBytes: UINT64,
};

pub const IStateObject = extern union {
    pub const IID: GUID = .parse("{47016943-fca8-4594-93ea-af258b55346d}");
    pub const VTable = extern struct {
        base: IDeviceChild.VTable,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
};

pub const IStateObjectProperties = extern union {
    pub const IID: GUID = .parse("{de5fa827-9bf9-4f26-89ff-d7f56fde3860}");
    pub const VTable = extern struct {
        const T = IStateObjectProperties;
        base: IUnknown.VTable,
        GetShaderIdentifier: *const fn (*T, LPCWSTR) callconv(.winapi) *anyopaque,
        GetShaderStackSize: *const fn (*T, LPCWSTR) callconv(.winapi) UINT64,
        GetPipelineStackSize: *const fn (*T) callconv(.winapi) UINT64,
        SetPipelineStackSize: *const fn (*T, UINT64) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetShaderIdentifier(self: *IStateObjectProperties, export_name: LPCWSTR) *anyopaque {
        return self.vtable.GetShaderIdentifier(self, export_name);
    }
    pub inline fn GetShaderStackSize(self: *IStateObjectProperties, export_name: LPCWSTR) UINT64 {
        return self.vtable.GetShaderStackSize(self, export_name);
    }
    pub inline fn GetPipelineStackSize(self: *IStateObjectProperties) UINT64 {
        return self.vtable.GetPipelineStackSize(self);
    }
    pub inline fn SetPipelineStackSize(self: *IStateObjectProperties, pipeline_stack_size_in_bytes: UINT64) void {
        self.vtable.SetPipelineStackSize(self, pipeline_stack_size_in_bytes);
    }
};

pub const DISPATCH_RAYS_DESC = extern struct {
    RayGenerationShaderRecord: GPU_VIRTUAL_ADDRESS_RANGE,
    MissShaderTable: GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE,
    HitGroupTable: GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE,
    CallableShaderTable: GPU_VIRTUAL_ADDRESS_RANGE_AND_STRIDE,
    Width: UINT,
    Height: UINT,
    Depth: UINT,
};

pub const IGraphicsCommandList4 = extern union {
    pub const IID: GUID = .parse("{8754318e-d3a9-4541-98cf-645b50dc4874}");
    pub const VTable = extern struct {
        const T = IGraphicsCommandList4;
        base: IGraphicsCommandList3.VTable,
        BeginRenderPass: *const fn (
            *T,
            UINT,
            ?[*]const RENDER_PASS_RENDER_TARGET_DESC,
            ?*const RENDER_PASS_DEPTH_STENCIL_DESC,
            RENDER_PASS_FLAGS,
        ) callconv(.winapi) void,
        EndRenderPass: *const fn (*T) callconv(.winapi) void,
        InitializeMetaCommand: *const fn (*T, *IMetaCommand, ?*const anyopaque, SIZE_T) callconv(.winapi) void,
        ExecuteMetaCommand: *const fn (*T, *IMetaCommand, ?*const anyopaque, SIZE_T) callconv(.winapi) void,
        BuildRaytracingAccelerationStructure: *const fn (
            *T,
            *const BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC,
            UINT,
            ?[*]const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_DESC,
        ) callconv(.winapi) void,
        EmitRaytracingAccelerationStructurePostbuildInfo: *const fn (
            *T,
            *const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_DESC,
            UINT,
            [*]const GPU_VIRTUAL_ADDRESS,
        ) callconv(.winapi) void,
        CopyRaytracingAccelerationStructure: *const fn (
            *T,
            GPU_VIRTUAL_ADDRESS,
            GPU_VIRTUAL_ADDRESS,
            RAYTRACING_ACCELERATION_STRUCTURE_COPY_MODE,
        ) callconv(.winapi) void,
        SetPipelineState1: *const fn (*T, *IStateObject) callconv(.winapi) void,
        DispatchRays: *const fn (*T, *const DISPATCH_RAYS_DESC) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,
    igraphicscommandlist1: IGraphicsCommandList1,
    igraphicscommandlist2: IGraphicsCommandList2,
    igraphicscommandlist3: IGraphicsCommandList3,

    pub inline fn BeginRenderPass(
        self: *IGraphicsCommandList4,
        num_render_targets: UINT,
        render_target_descs: ?[*]const RENDER_PASS_RENDER_TARGET_DESC,
        depth_stencil_desc: ?*const RENDER_PASS_DEPTH_STENCIL_DESC,
        flags: RENDER_PASS_FLAGS,
    ) void {
        self.vtable.BeginRenderPass(self, num_render_targets, render_target_descs, depth_stencil_desc, flags);
    }
    pub inline fn EndRenderPass(self: *IGraphicsCommandList4) void {
        self.vtable.EndRenderPass(self);
    }
    pub inline fn InitializeMetaCommand(self: *IGraphicsCommandList4, pMetaCommand: *IMetaCommand, pInitializationParametersData: ?*const anyopaque, InitializationParametersDataSizeInBytes: SIZE_T) void {
        self.vtable.InitializeMetaCommand(self, pMetaCommand, pInitializationParametersData, InitializationParametersDataSizeInBytes);
    }
    pub inline fn ExecuteMetaCommand(self: *IGraphicsCommandList4, pMetaCommand: *IMetaCommand, pExecutionParametersData: ?*const anyopaque, ExecutionParametersDataSizeInBytes: SIZE_T) void {
        self.vtable.ExecuteMetaCommand(self, pMetaCommand, pExecutionParametersData, ExecutionParametersDataSizeInBytes);
    }
    pub inline fn BuildRaytracingAccelerationStructure(
        self: *IGraphicsCommandList4,
        pDesc: *const BUILD_RAYTRACING_ACCELERATION_STRUCTURE_DESC,
        NumPostbuildInfoDescs: UINT,
        pPostbuildInfoDescs: ?[*]const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_DESC,
    ) void {
        self.vtable.BuildRaytracingAccelerationStructure(self, pDesc, NumPostbuildInfoDescs, pPostbuildInfoDescs);
    }
    pub inline fn EmitRaytracingAccelerationStructurePostbuildInfo(
        self: *IGraphicsCommandList4,
        pPostbuildInfoDesc: *const RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO_DESC,
        NumPostbuildInfoDescs: UINT,
        pGPUVirtualAddresses: ?[*]const GPU_VIRTUAL_ADDRESS,
    ) void {
        self.vtable.EmitRaytracingAccelerationStructurePostbuildInfo(self, pPostbuildInfoDesc, NumPostbuildInfoDescs, pGPUVirtualAddresses);
    }
    pub inline fn CopyRaytracingAccelerationStructure(
        self: *IGraphicsCommandList4,
        DestAccelerationStructureData: GPU_VIRTUAL_ADDRESS,
        SrcAccelerationStructureData: GPU_VIRTUAL_ADDRESS,
        Mode: RAYTRACING_ACCELERATION_STRUCTURE_COPY_MODE,
    ) void {
        self.vtable.CopyRaytracingAccelerationStructure(self, DestAccelerationStructureData, SrcAccelerationStructureData, Mode);
    }
    pub inline fn SetPipelineState1(self: *IGraphicsCommandList4, pState: *IPipelineState) void {
        self.vtable.SetPipelineState1(self, pState);
    }
    pub inline fn DispatchRays(self: *IGraphicsCommandList4, pDesc: *const DISPATCH_RAYS_DESC) void {
        self.vtable.DispatchRays(self, pDesc);
    }
};

pub const RS_SET_SHADING_RATE_COMBINER_COUNT = 2;

pub const SHADING_RATE = enum(UINT) {
    @"1X1" = 0,
    @"1X2" = 0x1,
    @"2X1" = 0x4,
    @"2X2" = 0x5,
    @"2X4" = 0x6,
    @"4X2" = 0x9,
    @"4X4" = 0xa,
};

pub const SHADING_RATE_COMBINER = enum(UINT) {
    PASSTHROUGH = 0,
    OVERRIDE = 1,
    COMBINER_MIN = 2,
    COMBINER_MAX = 3,
    COMBINER_SUM = 4,
};

pub const IGraphicsCommandList5 = extern union {
    pub const IID: GUID = .parse("{55050859-4024-474c-87f5-6472eaee44ea}");
    pub const VTable = extern struct {
        base: IGraphicsCommandList4.VTable,
        RSSetShadingRate: *const fn (
            *IGraphicsCommandList5,
            SHADING_RATE,
            ?*const [RS_SET_SHADING_RATE_COMBINER_COUNT]SHADING_RATE_COMBINER,
        ) callconv(.winapi) void,
        RSSetShadingRateImage: *const fn (*IGraphicsCommandList5, ?*IResource) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,
    igraphicscommandlist1: IGraphicsCommandList1,
    igraphicscommandlist2: IGraphicsCommandList2,
    igraphicscommandlist3: IGraphicsCommandList3,
    igraphicscommandlist4: IGraphicsCommandList4,

    pub inline fn RSSetShadingRate(
        self: *IGraphicsCommandList5,
        shading_rate: SHADING_RATE,
        combiners: ?*const [RS_SET_SHADING_RATE_COMBINER_COUNT]SHADING_RATE_COMBINER,
    ) void {
        self.vtable.RSSetShadingRate(self, shading_rate, combiners);
    }
    pub inline fn RSSetShadingRateImage(self: *IGraphicsCommandList5, shading_rate_image: ?*IResource) void {
        self.vtable.RSSetShadingRateImage(self, shading_rate_image);
    }
};

pub const IGraphicsCommandList6 = extern union {
    pub const IID = GUID.parse("{c3827890-e548-4cfa-96cf-5689a9370f80}");
    pub const VTable = extern struct {
        base: IGraphicsCommandList5.VTable,
        DispatchMesh: *const fn (*IGraphicsCommandList6, UINT, UINT, UINT) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,
    igraphicscommandlist1: IGraphicsCommandList1,
    igraphicscommandlist2: IGraphicsCommandList2,
    igraphicscommandlist3: IGraphicsCommandList3,
    igraphicscommandlist4: IGraphicsCommandList4,
    igraphicscommandlist5: IGraphicsCommandList5,

    pub inline fn DispatchMesh(self: *IGraphicsCommandList6, ThreadGroupCountX: UINT, ThreadGroupCountY: UINT, ThreadGroupCountZ: UINT) void {
        self.vtable.DispatchMesh(self, ThreadGroupCountX, ThreadGroupCountY, ThreadGroupCountZ);
    }
};

pub const IGraphicsCommandList7 = extern union {
    pub const IID: GUID = .parse("{dd171223-8b61-4769-90e3-160ccde4e2c1}");
    pub const VTable = extern struct {
        base: IGraphicsCommandList6.VTable,
        Barrier: *const fn (*IGraphicsCommandList7, UINT32, [*]const BARRIER_GROUP) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,
    igraphicscommandlist1: IGraphicsCommandList1,
    igraphicscommandlist2: IGraphicsCommandList2,
    igraphicscommandlist3: IGraphicsCommandList3,
    igraphicscommandlist4: IGraphicsCommandList4,
    igraphicscommandlist5: IGraphicsCommandList5,
    igraphicscommandlist6: IGraphicsCommandList6,

    pub inline fn Barrier(self: *IGraphicsCommandList7, num_barriers: UINT32, barriers: [*]const BARRIER_GROUP) void {
        self.vtable.Barrier(self, num_barriers, barriers);
    }
};

pub const IGraphicsCommandList8 = extern union {
    pub const IID: GUID = .parse("{ee936ef9-599d-4d28-938e-23c4ad05ce51}");
    pub const VTable = extern struct {
        base: IGraphicsCommandList7.VTable,
        OMSetFrontAndBackStencilRef: *const fn (*IGraphicsCommandList8, UINT, UINT) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,
    igraphicscommandlist1: IGraphicsCommandList1,
    igraphicscommandlist2: IGraphicsCommandList2,
    igraphicscommandlist3: IGraphicsCommandList3,
    igraphicscommandlist4: IGraphicsCommandList4,
    igraphicscommandlist5: IGraphicsCommandList5,
    igraphicscommandlist6: IGraphicsCommandList6,
    igraphicscommandlist7: IGraphicsCommandList7,

    pub inline fn OMSetFrontAndBackStencilRef(self: *IGraphicsCommandList8, front_stencil_ref: UINT, back_stencil_ref: UINT) void {
        self.vtable.OMSetFrontAndBackStencilRef(self, front_stencil_ref, back_stencil_ref);
    }
};

pub const IGraphicsCommandList9 = extern union {
    pub const IID: GUID = .parse("{34ed2808-ffe6-4c2b-b11a-cabd2b0c59e1}");
    pub const VTable = extern struct {
        base: IGraphicsCommandList8.VTable,
        RSSetDepthBias: *const fn (*IGraphicsCommandList9, FLOAT, FLOAT, FLOAT) callconv(.winapi) void,
        IASetIndexBufferStripCutValue: *const fn (
            *IGraphicsCommandList9,
            INDEX_BUFFER_STRIP_CUT_VALUE,
        ) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    icommandlist: ICommandList,
    igraphicscommandlist: IGraphicsCommandList,
    igraphicscommandlist1: IGraphicsCommandList1,
    igraphicscommandlist2: IGraphicsCommandList2,
    igraphicscommandlist3: IGraphicsCommandList3,
    igraphicscommandlist4: IGraphicsCommandList4,
    igraphicscommandlist5: IGraphicsCommandList5,
    igraphicscommandlist6: IGraphicsCommandList6,
    igraphicscommandlist7: IGraphicsCommandList7,
    igraphicscommandlist8: IGraphicsCommandList8,

    pub inline fn RSSetDepthBias(self: *IGraphicsCommandList9, depth_bias: FLOAT, depth_bias_clamp: FLOAT, slope_scaled_depth_bias: FLOAT) void {
        self.vtable.RSSetDepthBias(self, depth_bias, depth_bias_clamp, slope_scaled_depth_bias);
    }

    pub inline fn IASetIndexBufferStripCutValue(self: *IGraphicsCommandList9, cut_value: INDEX_BUFFER_STRIP_CUT_VALUE) void {
        self.vtable.IASetIndexBufferStripCutValue(self, cut_value);
    }
};

pub const ICommandQueue = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x0ec870a6,
        .Data2 = 0x5d7e,
        .Data3 = 0x4c22,
        .Data4 = .{ 0x8c, 0xfc, 0x5b, 0xaa, 0xe0, 0x76, 0x16, 0xed },
    };
    pub const VTable = extern struct {
        const T = ICommandQueue;
        base: IPageable.VTable,
        UpdateTileMappings: *const fn (
            *T,
            *IResource,
            UINT,
            ?[*]const TILED_RESOURCE_COORDINATE,
            ?[*]const TILE_REGION_SIZE,
            *IHeap,
            UINT,
            ?[*]const TILE_RANGE_FLAGS,
            ?[*]const UINT,
            ?[*]const UINT,
            TILE_MAPPING_FLAGS,
        ) callconv(.winapi) void,
        CopyTileMappings: *const fn (
            *T,
            *IResource,
            *const TILED_RESOURCE_COORDINATE,
            *IResource,
            *const TILED_RESOURCE_COORDINATE,
            *const TILE_REGION_SIZE,
            TILE_MAPPING_FLAGS,
        ) callconv(.winapi) void,
        ExecuteCommandLists: *const fn (*T, UINT, [*]const *ICommandList) callconv(.winapi) void,
        SetMarker: *const fn (*T, UINT, ?*const anyopaque, UINT) callconv(.winapi) void,
        BeginEvent: *const fn (*T, UINT, ?*const anyopaque, UINT) callconv(.winapi) void,
        EndEvent: *const fn (*T) callconv(.winapi) void,
        Signal: *const fn (*T, *IFence, UINT64) callconv(.winapi) HRESULT,
        Wait: *const fn (*T, *IFence, UINT64) callconv(.winapi) HRESULT,
        GetTimestampFrequency: *const fn (*T, *UINT64) callconv(.winapi) HRESULT,
        GetClockCalibration: *const fn (*T, *UINT64, *UINT64) callconv(.winapi) HRESULT,
        GetDesc: *const fn (*T, *COMMAND_QUEUE_DESC) callconv(.winapi) *COMMAND_QUEUE_DESC,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    ipageable: IPageable,

    pub inline fn UpdateTileMappings(
        self: *ICommandQueue,
        resource: *IResource,
        num_resource_regions: UINT,
        resource_region_start_coordinates: ?[*]const TILED_RESOURCE_COORDINATE,
        resource_region_sizes: ?[*]const TILE_REGION_SIZE,
        heap: *IHeap,
        num_ranges: UINT,
        range_flags: ?[*]const TILE_RANGE_FLAGS,
        heap_range_start_offsets: ?[*]const UINT,
        range_tile_counts: ?[*]const UINT,
        flags: TILE_MAPPING_FLAGS,
    ) void {
        self.vtable.UpdateTileMappings(
            self,
            resource,
            num_resource_regions,
            resource_region_start_coordinates,
            resource_region_sizes,
            heap,
            num_ranges,
            range_flags,
            heap_range_start_offsets,
            range_tile_counts,
            flags,
        );
    }
    pub inline fn CopyTileMappings(
        self: *ICommandQueue,
        dst_resource: *IResource,
        dst_region_start_coordinate: *const TILED_RESOURCE_COORDINATE,
        src_resource: *IResource,
        src_region_start_coordinate: *const TILED_RESOURCE_COORDINATE,
        region_size: *const TILE_REGION_SIZE,
        flags: TILE_MAPPING_FLAGS,
    ) void {
        self.vtable.CopyTileMappings(
            self,
            dst_resource,
            dst_region_start_coordinate,
            src_resource,
            src_region_start_coordinate,
            region_size,
            flags,
        );
    }
    pub inline fn ExecuteCommandLists(self: *ICommandQueue, num_command_lists: UINT, command_lists: [*]const *ICommandList) void {
        self.vtable.ExecuteCommandLists(self, num_command_lists, command_lists);
    }
    pub inline fn SetMarker(self: *ICommandQueue, metadata: UINT, data: ?*const anyopaque, size: UINT) void {
        self.vtable.SetMarker(self, metadata, data, size);
    }
    pub inline fn BeginEvent(self: *ICommandQueue, metadata: UINT, data: ?*const anyopaque, size: UINT) void {
        self.vtable.BeginEvent(self, metadata, data, size);
    }
    pub inline fn EndEvent(self: *ICommandQueue) void {
        self.vtable.EndEvent(self);
    }
    pub inline fn Signal(self: *ICommandQueue, fence: *IFence, value: UINT64) HRESULT {
        return self.vtable.Signal(self, fence, value);
    }
    pub inline fn Wait(self: *ICommandQueue, fence: *IFence, value: UINT64) HRESULT {
        return self.vtable.Wait(self, fence, value);
    }
    pub inline fn GetTimestampFrequency(self: *ICommandQueue, frequency: *UINT64) HRESULT {
        return self.vtable.GetTimestampFrequency(self, frequency);
    }
    pub inline fn GetClockCalibration(self: *ICommandQueue, gpu_timestamp: *UINT64, cpu_timestamp: *UINT64) HRESULT {
        return self.vtable.GetClockCalibration(self, gpu_timestamp, cpu_timestamp);
    }
    pub inline fn GetDesc(self: *ICommandQueue, desc: *COMMAND_QUEUE_DESC) *COMMAND_QUEUE_DESC {
        return self.vtable.GetDesc(self, desc);
    }
};

pub const IDevice = extern union {
    pub const IID: GUID = .parse("{189819f1-1db6-4b57-be54-1821339b85f7}");
    pub const VTable = extern struct {
        const T = IDevice;
        base: IObject.VTable,
        GetNodeCount: *const fn (*T) callconv(.winapi) UINT,
        CreateCommandQueue: *const fn (
            *T,
            *const COMMAND_QUEUE_DESC,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateCommandAllocator: *const fn (
            *T,
            COMMAND_LIST_TYPE,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateGraphicsPipelineState: *const fn (
            *T,
            *const GRAPHICS_PIPELINE_STATE_DESC,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateComputePipelineState: *const fn (
            *T,
            *const COMPUTE_PIPELINE_STATE_DESC,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateCommandList: *const fn (
            *T,
            UINT,
            COMMAND_LIST_TYPE,
            *ICommandAllocator,
            ?*IPipelineState,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CheckFeatureSupport: *const fn (*T, FEATURE, *anyopaque, UINT) callconv(.winapi) HRESULT,
        CreateDescriptorHeap: *const fn (
            *T,
            *const DESCRIPTOR_HEAP_DESC,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        GetDescriptorHandleIncrementSize: *const fn (*T, DESCRIPTOR_HEAP_TYPE) callconv(.winapi) UINT,
        CreateRootSignature: *const fn (
            *T,
            UINT,
            *const anyopaque,
            UINT64,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateConstantBufferView: *const fn (
            *T,
            ?*const CONSTANT_BUFFER_VIEW_DESC,
            CPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
        CreateShaderResourceView: *const fn (
            *T,
            ?*IResource,
            ?*const SHADER_RESOURCE_VIEW_DESC,
            CPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
        CreateUnorderedAccessView: *const fn (
            *T,
            ?*IResource,
            ?*IResource,
            ?*const UNORDERED_ACCESS_VIEW_DESC,
            CPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
        CreateRenderTargetView: *const fn (
            *T,
            ?*IResource,
            ?*const RENDER_TARGET_VIEW_DESC,
            CPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
        CreateDepthStencilView: *const fn (
            *T,
            ?*IResource,
            ?*const DEPTH_STENCIL_VIEW_DESC,
            CPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
        CreateSampler: *const fn (*T, *const SAMPLER_DESC, CPU_DESCRIPTOR_HANDLE) callconv(.winapi) void,
        CopyDescriptors: *const fn (
            *T,
            UINT,
            [*]const CPU_DESCRIPTOR_HANDLE,
            ?[*]const UINT,
            UINT,
            [*]const CPU_DESCRIPTOR_HANDLE,
            ?[*]const UINT,
            DESCRIPTOR_HEAP_TYPE,
        ) callconv(.winapi) void,
        CopyDescriptorsSimple: *const fn (
            *T,
            UINT,
            CPU_DESCRIPTOR_HANDLE,
            CPU_DESCRIPTOR_HANDLE,
            DESCRIPTOR_HEAP_TYPE,
        ) callconv(.winapi) void,
        GetResourceAllocationInfo: *const fn (
            *T,
            *RESOURCE_ALLOCATION_INFO,
            UINT,
            UINT,
            [*]const RESOURCE_DESC,
        ) callconv(.winapi) *RESOURCE_ALLOCATION_INFO,
        GetCustomHeapProperties: *const fn (
            *T,
            *HEAP_PROPERTIES,
            UINT,
            HEAP_TYPE,
        ) callconv(.winapi) *HEAP_PROPERTIES,
        CreateCommittedResource: *const fn (
            *T,
            *const HEAP_PROPERTIES,
            HEAP_FLAGS,
            *const RESOURCE_DESC,
            RESOURCE_STATES,
            ?*const CLEAR_VALUE,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateHeap: *const fn (*T, *const HEAP_DESC, *const GUID, ?*?*anyopaque) callconv(.winapi) HRESULT,
        CreatePlacedResource: *const fn (
            *T,
            *IHeap,
            UINT64,
            *const RESOURCE_DESC,
            RESOURCE_STATES,
            ?*const CLEAR_VALUE,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateReservedResource: *const fn (
            *T,
            *const RESOURCE_DESC,
            RESOURCE_STATES,
            ?*const CLEAR_VALUE,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateSharedHandle: *const fn (
            *T,
            *IDeviceChild,
            ?*const SECURITY_ATTRIBUTES,
            DWORD,
            ?LPCWSTR,
            ?*HANDLE,
        ) callconv(.winapi) HRESULT,
        OpenSharedHandle: *const fn (*T, HANDLE, *const GUID, ?*?*anyopaque) callconv(.winapi) HRESULT,
        OpenSharedHandleByName: *const fn (*T, LPCWSTR, DWORD, ?*HANDLE) callconv(.winapi) HRESULT,
        MakeResident: *const fn (*T, UINT, [*]const *IPageable) callconv(.winapi) HRESULT,
        Evict: *const fn (*T, UINT, [*]const *IPageable) callconv(.winapi) HRESULT,
        CreateFence: *const fn (*T, UINT64, FENCE_FLAGS, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
        GetDeviceRemovedReason: *const fn (*T) callconv(.winapi) HRESULT,
        GetCopyableFootprints: *const fn (
            *T,
            *const RESOURCE_DESC,
            UINT,
            UINT,
            UINT64,
            ?[*]PLACED_SUBRESOURCE_FOOTPRINT,
            ?[*]UINT,
            ?[*]UINT64,
            ?*UINT64,
        ) callconv(.winapi) void,
        CreateQueryHeap: *const fn (*T, *const QUERY_HEAP_DESC, *const GUID, ?*?*anyopaque) callconv(.winapi) HRESULT,
        SetStablePowerState: *const fn (*T, BOOL) callconv(.winapi) HRESULT,
        CreateCommandSignature: *const fn (
            *T,
            *const COMMAND_SIGNATURE_DESC,
            ?*IRootSignature,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        GetResourceTiling: *const fn (
            *T,
            *IResource,
            ?*UINT,
            ?*PACKED_MIP_INFO,
            ?*TILE_SHAPE,
            ?*UINT,
            UINT,
            [*]SUBRESOURCE_TILING,
        ) callconv(.winapi) void,
        GetAdapterLuid: *const fn (*T, *LUID) callconv(.winapi) *LUID,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,

    pub inline fn GetNodeCount(self: *IDevice) UINT {
        return self.vtable.GetNodeCount(self);
    }
    pub inline fn CreateCommandQueue(
        self: *IDevice,
        desc: *const COMMAND_QUEUE_DESC,
        riid: *const GUID,
        command_queue: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommandQueue(self, desc, riid, command_queue);
    }
    pub inline fn CreateCommandAllocator(
        self: *IDevice,
        type_: COMMAND_LIST_TYPE,
        riid: *const GUID,
        command_allocator: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommandAllocator(self, type_, riid, command_allocator);
    }
    pub inline fn CreateGraphicsPipelineState(
        self: *IDevice,
        desc: *const GRAPHICS_PIPELINE_STATE_DESC,
        riid: *const GUID,
        pipeline_state: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateGraphicsPipelineState(self, desc, riid, pipeline_state);
    }
    pub inline fn CreateComputePipelineState(
        self: *IDevice,
        desc: *const COMPUTE_PIPELINE_STATE_DESC,
        riid: *const GUID,
        pipeline_state: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateComputePipelineState(self, desc, riid, pipeline_state);
    }
    pub inline fn CreateCommandList(
        self: *IDevice,
        node_mask: UINT,
        type_: COMMAND_LIST_TYPE,
        command_allocator: *ICommandAllocator,
        initial_state: ?*IPipelineState,
        riid: *const GUID,
        command_list: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommandList(
            self,
            node_mask,
            type_,
            command_allocator,
            initial_state,
            riid,
            command_list,
        );
    }
    pub inline fn CheckFeatureSupport(self: *IDevice, feature: FEATURE, feature_data: *anyopaque, feature_data_size: UINT) HRESULT {
        return self.vtable.CheckFeatureSupport(self, feature, feature_data, feature_data_size);
    }
    pub inline fn CreateDescriptorHeap(
        self: *IDevice,
        desc: *const DESCRIPTOR_HEAP_DESC,
        riid: *const GUID,
        descriptor_heap: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateDescriptorHeap(self, desc, riid, descriptor_heap);
    }
    pub inline fn GetDescriptorHandleIncrementSize(self: *IDevice, type_: DESCRIPTOR_HEAP_TYPE) UINT {
        return self.vtable.GetDescriptorHandleIncrementSize(self, type_);
    }
    pub inline fn CreateRootSignature(
        self: *IDevice,
        node_mask: UINT,
        blob_with_root_signature: *const anyopaque,
        blob_length_in_bytes: UINT64,
        riid: *const GUID,
        root_signature: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateRootSignature(
            self,
            node_mask,
            blob_with_root_signature,
            blob_length_in_bytes,
            riid,
            root_signature,
        );
    }
    pub inline fn CreateConstantBufferView(
        self: *IDevice,
        desc: ?*const CONSTANT_BUFFER_VIEW_DESC,
        dest_descriptor: CPU_DESCRIPTOR_HANDLE,
    ) void {
        self.vtable.CreateConstantBufferView(self, desc, dest_descriptor);
    }
    pub inline fn CreateShaderResourceView(
        self: *IDevice,
        resource: ?*IResource,
        desc: ?*const SHADER_RESOURCE_VIEW_DESC,
        dest_descriptor: CPU_DESCRIPTOR_HANDLE,
    ) void {
        self.vtable.CreateShaderResourceView(self, resource, desc, dest_descriptor);
    }
    pub inline fn CreateUnorderedAccessView(
        self: *IDevice,
        resource: ?*IResource,
        counter_resource: ?*IResource,
        desc: ?*const UNORDERED_ACCESS_VIEW_DESC,
        dest_descriptor: CPU_DESCRIPTOR_HANDLE,
    ) void {
        self.vtable.CreateUnorderedAccessView(self, resource, counter_resource, desc, dest_descriptor);
    }
    pub inline fn CreateRenderTargetView(
        self: *IDevice,
        resource: ?*IResource,
        desc: ?*const RENDER_TARGET_VIEW_DESC,
        dest_descriptor: CPU_DESCRIPTOR_HANDLE,
    ) void {
        self.vtable.CreateRenderTargetView(self, resource, desc, dest_descriptor);
    }
    pub inline fn CreateDepthStencilView(
        self: *IDevice,
        resource: ?*IResource,
        desc: ?*const DEPTH_STENCIL_VIEW_DESC,
        dest_descriptor: CPU_DESCRIPTOR_HANDLE,
    ) void {
        self.vtable.CreateDepthStencilView(self, resource, desc, dest_descriptor);
    }
    pub inline fn CreateSampler(self: *IDevice, desc: *const SAMPLER_DESC, dest_descriptor: CPU_DESCRIPTOR_HANDLE) void {
        self.vtable.CreateSampler(self, desc, dest_descriptor);
    }
    pub inline fn CopyDescriptors(
        self: *IDevice,
        num_dest_descriptors: UINT,
        dest_descriptors: [*]const CPU_DESCRIPTOR_HANDLE,
        dest_descriptor_ranges: ?[*]const UINT,
        num_src_descriptors: UINT,
        src_descriptors: [*]const CPU_DESCRIPTOR_HANDLE,
        src_descriptor_ranges: ?[*]const UINT,
        type_: DESCRIPTOR_HEAP_TYPE,
    ) void {
        self.vtable.CopyDescriptors(
            self,
            num_dest_descriptors,
            dest_descriptors,
            dest_descriptor_ranges,
            num_src_descriptors,
            src_descriptors,
            src_descriptor_ranges,
            type_,
        );
    }
    pub inline fn CopyDescriptorsSimple(
        self: *IDevice,
        num_descriptors: UINT,
        dest_descriptor: CPU_DESCRIPTOR_HANDLE,
        src_descriptor: CPU_DESCRIPTOR_HANDLE,
        type_: DESCRIPTOR_HEAP_TYPE,
    ) void {
        self.vtable.CopyDescriptorsSimple(self, num_descriptors, dest_descriptor, src_descriptor, type_);
    }
    pub inline fn GetResourceAllocationInfo(
        self: *IDevice,
        result: *RESOURCE_ALLOCATION_INFO,
        num_resource_descs: UINT,
        resource_descs: [*]const RESOURCE_DESC,
    ) *RESOURCE_ALLOCATION_INFO {
        return self.vtable.GetResourceAllocationInfo(self, result, num_resource_descs, resource_descs);
    }
    pub inline fn GetCustomHeapProperties(self: *IDevice, result: *HEAP_PROPERTIES, node_mask: UINT, type_: HEAP_TYPE) *HEAP_PROPERTIES {
        return self.vtable.GetCustomHeapProperties(self, result, node_mask, type_);
    }
    pub inline fn CreateCommittedResource(
        self: *IDevice,
        heap_properties: *const HEAP_PROPERTIES,
        heap_flags: HEAP_FLAGS,
        desc: *const RESOURCE_DESC,
        initial_resource_state: RESOURCE_STATES,
        optimized_clear_value: ?*const CLEAR_VALUE,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommittedResource(
            self,
            heap_properties,
            heap_flags,
            desc,
            initial_resource_state,
            optimized_clear_value,
            riid,
            resource,
        );
    }
    pub inline fn CreateHeap(self: *IDevice, desc: *const HEAP_DESC, riid: *const GUID, heap: ?*?*anyopaque) HRESULT {
        return self.vtable.CreateHeap(self, desc, riid, heap);
    }
    pub inline fn CreatePlacedResource(
        self: *IDevice,
        heap: *IHeap,
        heap_offset: UINT64,
        desc: *const RESOURCE_DESC,
        initial_state: RESOURCE_STATES,
        optimized_clear_value: ?*const CLEAR_VALUE,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreatePlacedResource(
            self,
            heap,
            heap_offset,
            desc,
            initial_state,
            optimized_clear_value,
            riid,
            resource,
        );
    }
    pub inline fn CreateReservedResource(
        self: *IDevice,
        desc: *const RESOURCE_DESC,
        initial_state: RESOURCE_STATES,
        optimized_clear_value: ?*const CLEAR_VALUE,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateReservedResource(self, desc, initial_state, optimized_clear_value, riid, resource);
    }
    pub inline fn CreateSharedHandle(
        self: *IDevice,
        object: *IDeviceChild,
        security_attributes: ?*const SECURITY_ATTRIBUTES,
        access: DWORD,
        name: ?LPCWSTR,
        handle: ?*HANDLE,
    ) HRESULT {
        return self.vtable.CreateSharedHandle(self, object, security_attributes, access, name, handle);
    }
    pub inline fn OpenSharedHandle(self: *IDevice, handle: HANDLE, riid: *const GUID, object: ?*?*anyopaque) HRESULT {
        return self.vtable.OpenSharedHandle(self, handle, riid, object);
    }
    pub inline fn OpenSharedHandleByName(self: *IDevice, name: LPCWSTR, access: DWORD, handle: ?*HANDLE) HRESULT {
        return self.vtable.OpenSharedHandleByName(self, name, access, handle);
    }
    pub inline fn MakeResident(self: *IDevice, num_objects: UINT, objects: [*]const *IPageable) HRESULT {
        return self.vtable.MakeResident(self, num_objects, objects);
    }
    pub inline fn Evict(self: *IDevice, num_objects: UINT, objects: [*]const *IPageable) HRESULT {
        return self.vtable.Evict(self, num_objects, objects);
    }
    pub inline fn CreateFence(self: *IDevice, initial_value: UINT64, flags: FENCE_FLAGS, riid: *const GUID, fence: *?*anyopaque) HRESULT {
        return self.vtable.CreateFence(self, initial_value, flags, riid, fence);
    }
    pub inline fn GetDeviceRemovedReason(self: *IDevice) HRESULT {
        return self.vtable.GetDeviceRemovedReason(self);
    }
    pub inline fn GetCopyableFootprints(
        self: *IDevice,
        desc: *const RESOURCE_DESC,
        first_subresource: UINT,
        num_subresources: UINT,
        base_offset: UINT64,
        layouts: ?[*]PLACED_SUBRESOURCE_FOOTPRINT,
        num_rows: ?[*]UINT,
        row_size_in_bytes: ?[*]UINT64,
        total_bytes: ?*UINT64,
    ) void {
        self.vtable.GetCopyableFootprints(
            self,
            desc,
            first_subresource,
            num_subresources,
            base_offset,
            layouts,
            num_rows,
            row_size_in_bytes,
            total_bytes,
        );
    }
    pub inline fn CreateQueryHeap(self: *IDevice, desc: *const QUERY_HEAP_DESC, riid: *const GUID, query_heap: ?*?*anyopaque) HRESULT {
        return self.vtable.CreateQueryHeap(self, desc, riid, query_heap);
    }
    pub inline fn SetStablePowerState(self: *IDevice, enable: BOOL) HRESULT {
        return self.vtable.SetStablePowerState(self, enable);
    }
    pub inline fn CreateCommandSignature(
        self: *IDevice,
        desc: *const COMMAND_SIGNATURE_DESC,
        root_signature: ?*IRootSignature,
        riid: *const GUID,
        command_signature: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommandSignature(self, desc, root_signature, riid, command_signature);
    }
    pub inline fn GetResourceTiling(
        self: *IDevice,
        resource: *IResource,
        num_tiles_for_resource: ?*UINT,
        packed_mip_info: ?*PACKED_MIP_INFO,
        standard_tile_shape_for_non_packed_mips: ?*TILE_SHAPE,
        subresource_count: ?*UINT,
        first_subresource: UINT,
        subresource_tilings: [*]SUBRESOURCE_TILING,
    ) void {
        self.vtable.GetResourceTiling(
            self,
            resource,
            num_tiles_for_resource,
            packed_mip_info,
            standard_tile_shape_for_non_packed_mips,
            subresource_count,
            first_subresource,
            subresource_tilings,
        );
    }
    pub inline fn GetAdapterLuid(self: *IDevice, luid: *LUID) *LUID {
        return self.vtable.GetAdapterLuid(self, luid);
    }
};

pub const MULTIPLE_FENCE_WAIT_FLAGS = enum(UINT) {
    ALL = 0,
    ANY = 1,
};

pub const RESIDENCY_PRIORITY = enum(UINT) {
    MINIMUM = 0x28000000,
    LOW = 0x50000000,
    NORMAL = 0x78000000,
    HIGH = 0xa0010000,
    MAXIMUM = 0xc8000000,
};

pub const IDevice1 = extern union {
    pub const IID: GUID = .parse("{77acce80-638e-4e65-8895-c1f23386863e}");
    pub const VTable = extern struct {
        base: IDevice.VTable,
        CreatePipelineLibrary: *const fn (
            *IDevice1,
            *const anyopaque,
            SIZE_T,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        SetEventOnMultipleFenceCompletion: *const fn (
            *IDevice1,
            [*]const *IFence,
            [*]const UINT64,
            UINT,
            MULTIPLE_FENCE_WAIT_FLAGS,
            HANDLE,
        ) callconv(.winapi) HRESULT,
        SetResidencyPriority: *const fn (
            *IDevice1,
            UINT,
            [*]const *IPageable,
            [*]const RESIDENCY_PRIORITY,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,

    pub inline fn CreatePipelineLibrary(
        self: *IDevice1,
        pLibraryBlob: *const anyopaque,
        blobLength: SIZE_T,
        riid: *const GUID,
        ppPipelineLibrary: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreatePipelineLibrary(self, pLibraryBlob, blobLength, riid, ppPipelineLibrary);
    }
    pub inline fn SetEventOnMultipleFenceCompletion(
        self: *IDevice1,
        ppFences: [*]const *IFence,
        pFenceValues: [*]const UINT64,
        numFences: UINT,
        flags: MULTIPLE_FENCE_WAIT_FLAGS,
        hEvent: HANDLE,
    ) HRESULT {
        return self.vtable.SetEventOnMultipleFenceCompletion(self, ppFences, pFenceValues, numFences, flags, hEvent);
    }
    pub inline fn SetResidencyPriority(
        self: *IDevice1,
        numObjects: UINT,
        ppObjects: [*]const *IPageable,
        pPriorities: [*]const RESIDENCY_PRIORITY,
    ) HRESULT {
        return self.vtable.SetResidencyPriority(self, numObjects, ppObjects, pPriorities);
    }
};

pub const PIPELINE_STATE_SUBOBJECT_TYPE = enum(UINT) {
    ROOT_SIGNATURE = 0,
    VS = 1,
    PS = 2,
    DS = 3,
    HS = 4,
    GS = 5,
    CS = 6,
    STREAM_OUTPUT = 7,
    BLEND = 8,
    SAMPLE_MASK = 9,
    RASTERIZER = 10,
    DEPTH_STENCIL = 11,
    INPUT_LAYOUT = 12,
    IB_STRIP_CUT_VALUE = 13,
    PRIMITIVE_TOPOLOGY = 14,
    RENDER_TARGET_FORMATS = 15,
    DEPTH_STENCIL_FORMAT = 16,
    SAMPLE_DESC = 17,
    NODE_MASK = 18,
    CACHED_PSO = 19,
    FLAGS = 20,
    DEPTH_STENCIL1 = 21,
    VIEW_INSTANCING = 22,
    AS = 24,
    MS = 25,
    MAX_VALID,
};

pub const RT_FORMAT_ARRAY = extern struct {
    RTFormats: [8]dxgi.FORMAT,
    NumRenderTargets: UINT,
};

pub const PIPELINE_STATE_STREAM_DESC = extern struct {
    SizeInBytes: SIZE_T,
    pPipelineStateSubobjectStream: *anyopaque,
};

// NOTE(mziulek): Helper structures for defining Mesh Shaders.
pub const MESH_SHADER_PIPELINE_STATE_DESC = extern struct {
    pRootSignature: ?*IRootSignature = null,
    AS: SHADER_BYTECODE = .zero,
    MS: SHADER_BYTECODE = .zero,
    PS: SHADER_BYTECODE = .zero,
    BlendState: BLEND_DESC = .{},
    SampleMask: UINT = 0xffff_ffff,
    RasterizerState: RASTERIZER_DESC = .{},
    DepthStencilState: DEPTH_STENCIL_DESC1 = .{},
    PrimitiveTopologyType: PRIMITIVE_TOPOLOGY_TYPE = .UNDEFINED,
    NumRenderTargets: UINT = 0,
    RTVFormats: [8]dxgi.FORMAT = [_]dxgi.FORMAT{.UNKNOWN} ** 8,
    DSVFormat: dxgi.FORMAT = .UNKNOWN,
    SampleDesc: dxgi.SAMPLE_DESC = .{ .Count = 1, .Quality = 0 },
    NodeMask: UINT = 0,
    CachedPSO: CACHED_PIPELINE_STATE = CACHED_PIPELINE_STATE.initZero(),
    Flags: PIPELINE_STATE_FLAGS = .{},
};

pub const PIPELINE_MESH_STATE_STREAM = extern struct {
    Flags_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .FLAGS,
    Flags: PIPELINE_STATE_FLAGS,
    NodeMask_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .NODE_MASK,
    NodeMask: UINT,
    pRootSignature_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .ROOT_SIGNATURE,
    pRootSignature: ?*IRootSignature,
    PS_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .PS,
    PS: SHADER_BYTECODE,
    AS_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .AS,
    AS: SHADER_BYTECODE,
    MS_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .MS,
    MS: SHADER_BYTECODE,
    BlendState_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .BLEND,
    BlendState: BLEND_DESC,
    DepthStencilState_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .DEPTH_STENCIL1,
    DepthStencilState: DEPTH_STENCIL_DESC1,
    DSVFormat_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .DEPTH_STENCIL_FORMAT,
    DSVFormat: dxgi.FORMAT,
    RasterizerState_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .RASTERIZER,
    RasterizerState: RASTERIZER_DESC,
    RTVFormats_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .RENDER_TARGET_FORMATS,
    RTVFormats: RT_FORMAT_ARRAY,
    SampleDesc_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .SAMPLE_DESC,
    SampleDesc: dxgi.SAMPLE_DESC,
    SampleMask_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .SAMPLE_MASK,
    SampleMask: UINT,
    CachedPSO_type: PIPELINE_STATE_SUBOBJECT_TYPE align(8) = .CACHED_PSO,
    CachedPSO: CACHED_PIPELINE_STATE,

    pub fn init(desc: MESH_SHADER_PIPELINE_STATE_DESC) PIPELINE_MESH_STATE_STREAM {
        const stream = PIPELINE_MESH_STATE_STREAM{
            .Flags = desc.Flags,
            .NodeMask = desc.NodeMask,
            .pRootSignature = desc.pRootSignature,
            .PS = desc.PS,
            .AS = desc.AS,
            .MS = desc.MS,
            .BlendState = desc.BlendState,
            .DepthStencilState = desc.DepthStencilState,
            .DSVFormat = desc.DSVFormat,
            .RasterizerState = desc.RasterizerState,
            .RTVFormats = .{ .RTFormats = desc.RTVFormats, .NumRenderTargets = desc.NumRenderTargets },
            .SampleDesc = desc.SampleDesc,
            .SampleMask = desc.SampleMask,
            .CachedPSO = desc.CachedPSO,
        };
        return stream;
    }
};

pub const IDevice2 = extern union {
    pub const IID: GUID = .parse("{30baa41e-b15b-475c-a0bb-1af5c5b64328}");
    pub const VTable = extern struct {
        base: IDevice1.VTable,
        CreatePipelineState: *const fn (
            *IDevice2,
            *const PIPELINE_STATE_STREAM_DESC,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,

    pub inline fn CreatePipelineState(
        self: *IDevice2,
        desc: *const PIPELINE_STATE_STREAM_DESC,
        riid: *const GUID,
        pipeline_state: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreatePipelineState(self, desc, riid, pipeline_state);
    }
};

pub const RESIDENCY_FLAGS = packed struct(UINT) {
    DENY_OVERBUDGET: bool = false,
    __unused: u31 = 0,
};

pub const IDevice3 = extern union {
    pub const IID: GUID = .parse("{81dadc15-2bad-4392-93c5-101345c4aa98}");

    pub const VTable = extern struct {
        base: IDevice2.VTable,
        OpenExistingHeapFromAddress: *const fn (
            *IDevice3,
            *const anyopaque,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        OpenExistingHeapFromFileMapping: *const fn (
            *IDevice3,
            HANDLE,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        EnqueueMakeResident: *const fn (
            *IDevice3,
            RESIDENCY_FLAGS,
            UINT,
            [*]const *IPageable,
            *IFence,
            UINT64,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,

    pub inline fn OpenExistingHeapFromAddress(
        self: *IDevice3,
        pAddress: *const anyopaque,
        riid: *const GUID,
        ppvHeap: *?*anyopaque,
    ) HRESULT {
        return self.vtable.OpenExistingHeapFromAddress(self, pAddress, riid, ppvHeap);
    }
    pub inline fn OpenExistingHeapFromFileMapping(
        self: *IDevice3,
        hFileMapping: HANDLE,
        riid: *const GUID,
        ppvHeap: *?*anyopaque,
    ) HRESULT {
        return self.vtable.OpenExistingHeapFromFileMapping(self, hFileMapping, riid, ppvHeap);
    }
    pub inline fn EnqueueMakeResident(
        self: *IDevice3,
        flags: RESIDENCY_FLAGS,
        num_objects: UINT,
        pp_objects: [*]const *IPageable,
        fence_to_signal: *IFence,
        fence_value: UINT64,
    ) HRESULT {
        return self.vtable.EnqueueMakeResident(self, flags, num_objects, pp_objects, fence_to_signal, fence_value);
    }
};

pub const COMMAND_LIST_FLAGS = packed struct(UINT) {
    __unused: u32 = 0,
};

pub const RESOURCE_ALLOCATION_INFO1 = extern struct {
    Offset: UINT64,
    Alignment: UINT64,
    SizeInBytes: UINT64,
};

pub const IDevice4 = extern union {
    pub const IID: GUID = .parse("{e865df17-a9ee-46f9-a463-3098315aa2e5}");
    pub const VTable = extern struct {
        const T = IDevice4;
        base: IDevice3.VTable,
        CreateCommandList1: *const fn (
            *T,
            UINT,
            COMMAND_LIST_TYPE,
            COMMAND_LIST_FLAGS,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateProtectedResourceSession: *const fn (
            *T,
            *const PROTECTED_RESOURCE_SESSION_DESC,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateCommittedResource1: *const fn (
            *T,
            *const HEAP_PROPERTIES,
            HEAP_FLAGS,
            *const RESOURCE_DESC,
            RESOURCE_STATES,
            ?*const CLEAR_VALUE,
            ?*IProtectedResourceSession,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateHeap1: *const fn (
            *T,
            *const HEAP_DESC,
            ?*IProtectedResourceSession,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateReservedResource1: *const fn (
            *T,
            *const RESOURCE_DESC,
            RESOURCE_STATES,
            ?*const CLEAR_VALUE,
            ?*IProtectedResourceSession,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        GetResourceAllocationInfo1: *const fn (
            *T,
            *RESOURCE_ALLOCATION_INFO,
            UINT,
            UINT,
            [*]const RESOURCE_DESC,
            ?[*]RESOURCE_ALLOCATION_INFO1,
        ) callconv(.winapi) *RESOURCE_ALLOCATION_INFO,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,
    idevice3: IDevice3,

    pub inline fn CreateCommandList1(
        self: *IDevice4,
        node_mask: UINT,
        type_: COMMAND_LIST_TYPE,
        flags: COMMAND_LIST_FLAGS,
        riid: *const GUID,
        command_list: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommandList1(self, node_mask, type_, flags, riid, command_list);
    }
    pub inline fn CreateProtectedResourceSession(
        self: *IDevice4,
        desc: *const PROTECTED_RESOURCE_SESSION_DESC,
        riid: *const GUID,
        protected_session: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateProtectedResourceSession(self, desc, riid, protected_session);
    }
    pub inline fn CreateCommittedResource1(
        self: *IDevice4,
        heap_properties: *const HEAP_PROPERTIES,
        heap_flags: HEAP_FLAGS,
        desc: *const RESOURCE_DESC,
        initial_resource_state: RESOURCE_STATES,
        optimized_clear_value: ?*const CLEAR_VALUE,
        protected_session: ?*IProtectedResourceSession,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommittedResource1(
            self,
            heap_properties,
            heap_flags,
            desc,
            initial_resource_state,
            optimized_clear_value,
            protected_session,
            riid,
            resource,
        );
    }
    pub inline fn CreateHeap1(
        self: *IDevice4,
        desc: *const HEAP_DESC,
        protected_session: ?*IProtectedResourceSession,
        riid: *const GUID,
        heap: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateHeap1(self, desc, protected_session, riid, heap);
    }
    pub inline fn CreateReservedResource1(
        self: *IDevice4,
        desc: *const RESOURCE_DESC,
        initial_state: RESOURCE_STATES,
        optimized_clear_value: ?*const CLEAR_VALUE,
        protected_session: ?*IProtectedResourceSession,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateReservedResource1(
            self,
            desc,
            initial_state,
            optimized_clear_value,
            protected_session,
            riid,
            resource,
        );
    }
    pub inline fn GetResourceAllocationInfo1(
        self: *IDevice4,
        result: *RESOURCE_ALLOCATION_INFO,
        num_resource_descs: UINT,
        resource_descs: [*]const RESOURCE_DESC,
        out_resource_allocation_info1: ?[*]RESOURCE_ALLOCATION_INFO1,
    ) *RESOURCE_ALLOCATION_INFO {
        return self.vtable.GetResourceAllocationInfo1(self, result, num_resource_descs, resource_descs, out_resource_allocation_info1);
    }
};

pub const LIFETIME_STATE = enum(UINT) {
    IN_USE = 0,
    NOT_IN_USE = 1,
};

pub const ILifetimeOwner = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        LifetimeStateUpdated: *const fn (*ILifetimeOwner, LIFETIME_STATE) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn LifetimeStateUpdated(self: *ILifetimeOwner, state: LIFETIME_STATE) void {
        @as(*const ILifetimeOwner.VTable, @ptrCast(self.vtable)).LifetimeStateUpdated(@as(*ILifetimeOwner, @ptrCast(self)), state);
    }
};

pub const IDevice5 = extern union {
    pub const IID: GUID = .parse("{8b4f173b-2fea-4b80-8f58-4307191ab95d}");
    pub const VTable = extern struct {
        const T = IDevice5;
        base: IDevice4.VTable,
        CreateLifetimeTracker: *const fn (
            *T,
            *ILifetimeOwner,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        RemoveDevice: *const fn (self: *T) callconv(.winapi) void,
        EnumerateMetaCommands: *const fn (*T, *UINT, ?[*]META_COMMAND_DESC) callconv(.winapi) HRESULT,
        EnumerateMetaCommandParameters: *const fn (
            *T,
            *const GUID,
            META_COMMAND_PARAMETER_STAGE,
            ?*UINT,
            *UINT,
            ?[*]META_COMMAND_PARAMETER_DESC,
        ) callconv(.winapi) HRESULT,
        CreateMetaCommand: *const fn (
            *T,
            *const GUID,
            UINT,
            ?*const anyopaque,
            SIZE_T,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateStateObject: *const fn (
            *T,
            *const STATE_OBJECT_DESC,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        GetRaytracingAccelerationStructurePrebuildInfo: *const fn (
            *T,
            *const BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS,
            *RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO,
        ) callconv(.winapi) void,
        CheckDriverMatchingIdentifier: *const fn (
            *T,
            SERIALIZED_DATA_TYPE,
            *const SERIALIZED_DATA_DRIVER_MATCHING_IDENTIFIER,
        ) callconv(.winapi) DRIVER_MATCHING_IDENTIFIER_STATUS,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,
    idevice3: IDevice3,
    idevice4: IDevice4,

    pub inline fn CreateLifetimeTracker(
        self: *IDevice5,
        owner: *ILifetimeOwner,
        riid: *const GUID,
        lifetime_tracker: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateLifetimeTracker(self, owner, riid, lifetime_tracker);
    }
    pub inline fn RemoveDevice(self: *IDevice5) void {
        self.vtable.RemoveDevice(self);
    }
    pub inline fn EnumerateMetaCommands(self: *IDevice5, num_meta_commands: *UINT, meta_commands: ?[*]META_COMMAND_DESC) HRESULT {
        return self.vtable.EnumerateMetaCommands(self, num_meta_commands, meta_commands);
    }
    pub inline fn EnumerateMetaCommandParameters(
        self: *IDevice5,
        command_id: *const GUID,
        stage: META_COMMAND_PARAMETER_STAGE,
        num_input_parameters: ?*UINT,
        num_output_parameters: *UINT,
        output_parameters: ?[*]META_COMMAND_PARAMETER_DESC,
    ) HRESULT {
        return self.vtable.EnumerateMetaCommandParameters(
            self,
            command_id,
            stage,
            num_input_parameters,
            num_output_parameters,
            output_parameters,
        );
    }
    pub inline fn CreateMetaCommand(
        self: *IDevice5,
        command_id: *const GUID,
        node_mask: UINT,
        creation_parameters: ?*const anyopaque,
        creation_parameters_data_size: SIZE_T,
        riid: *const GUID,
        meta_command: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateMetaCommand(
            self,
            command_id,
            node_mask,
            creation_parameters,
            creation_parameters_data_size,
            riid,
            meta_command,
        );
    }
    pub inline fn CreateStateObject(
        self: *IDevice5,
        desc: *const STATE_OBJECT_DESC,
        riid: *const GUID,
        state_object: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateStateObject(self, desc, riid, state_object);
    }
    pub inline fn GetRaytracingAccelerationStructurePrebuildInfo(
        self: *IDevice5,
        desc: *const BUILD_RAYTRACING_ACCELERATION_STRUCTURE_INPUTS,
        info: *RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO,
    ) void {
        self.vtable.GetRaytracingAccelerationStructurePrebuildInfo(self, desc, info);
    }
    pub inline fn CheckDriverMatchingIdentifier(
        self: *IDevice5,
        serialized_data_type: SERIALIZED_DATA_TYPE,
        driver_matching_identifier: *const SERIALIZED_DATA_DRIVER_MATCHING_IDENTIFIER,
    ) DRIVER_MATCHING_IDENTIFIER_STATUS {
        return self.vtable.CheckDriverMatchingIdentifier(self, serialized_data_type, driver_matching_identifier);
    }
};

pub const BACKGROUND_PROCESSING_MODE = enum(UINT) {
    ALLOWED = 0,
    ALLOW_INTRUSIVE_MEASUREMENTS = 1,
    DISABLE_BACKGROUND_WORK = 2,
    DISABLE_PROFILING_BY_SYSTEM = 3,
};

pub const MEASUREMENTS_ACTION = enum(UINT) {
    KEEP_ALL = 0,
    COMMIT_RESULTS = 1,
    COMMIT_RESULTS_HIGH_PRIORITY = 2,
    DISCARD_PREVIOUS = 3,
};

pub const IDevice6 = extern union {
    pub const IID: GUID = .parse("{c70b221b-40e4-4a17-89af-025a0727a6dc}");
    pub const VTable = extern struct {
        base: IDevice5.VTable,
        SetBackgroundProcessingMode: *const fn (
            *IDevice6,
            BACKGROUND_PROCESSING_MODE,
            MEASUREMENTS_ACTION,
            ?HANDLE,
            ?*BOOL,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,
    idevice3: IDevice3,
    idevice4: IDevice4,
    idevice5: IDevice5,

    pub inline fn SetBackgroundProcessingMode(
        self: *IDevice6,
        mode: BACKGROUND_PROCESSING_MODE,
        measurements_action: MEASUREMENTS_ACTION,
        h_event_to_signal: ?HANDLE,
        out_fence_completed: ?*BOOL,
    ) HRESULT {
        return self.vtable.SetBackgroundProcessingMode(self, mode, measurements_action, h_event_to_signal, out_fence_completed);
    }
};

pub const PROTECTED_RESOURCE_SESSION_DESC1 = extern struct {
    NodeMask: UINT,
    Flags: PROTECTED_RESOURCE_SESSION_FLAGS,
    ProtectionType: GUID,
};

pub const IDevice7 = extern union {
    pub const IID: GUID = .parse("{5c014b53-68a1-4b9b-8bd1-dd6046b9358b}");
    pub const VTable = extern struct {
        base: IDevice6.VTable,
        AddToStateObject: *const fn (
            *IDevice7,
            *const STATE_OBJECT_DESC,
            *IStateObject,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateProtectedResourceSession1: *const fn (
            *IDevice7,
            *const PROTECTED_RESOURCE_SESSION_DESC1,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,
    idevice3: IDevice3,
    idevice4: IDevice4,
    idevice5: IDevice5,
    idevice6: IDevice6,

    pub inline fn AddToStateObject(
        self: *IDevice7,
        desc: *const STATE_OBJECT_DESC,
        state_object_to_add_to: *IStateObject,
        riid: *const GUID,
        new_state_object: *?*anyopaque,
    ) HRESULT {
        return self.vtable.AddToStateObject(self, desc, state_object_to_add_to, riid, new_state_object);
    }
    pub inline fn CreateProtectedResourceSession1(
        self: *IDevice7,
        desc: *const PROTECTED_RESOURCE_SESSION_DESC1,
        riid: *const GUID,
        protected_session: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateProtectedResourceSession1(self, desc, riid, protected_session);
    }
};

pub const MIP_REGION = extern struct {
    Width: UINT,
    Height: UINT,
    Depth: UINT,
};

pub const RESOURCE_DESC1 = extern struct {
    Dimension: RESOURCE_DIMENSION,
    Alignment: UINT64,
    Width: UINT64,
    Height: UINT,
    DepthOrArraySize: UINT16,
    MipLevels: UINT16,
    Format: dxgi.FORMAT,
    SampleDesc: dxgi.SAMPLE_DESC,
    Layout: TEXTURE_LAYOUT,
    Flags: RESOURCE_FLAGS,
    SamplerFeedbackMipRegion: MIP_REGION,
};

pub const IDevice8 = extern union {
    pub const IID: GUID = .parse("{9218E6BB-F944-4F7E-A75C-B1B2C7B701F3}");
    pub const VTable = extern struct {
        const T = IDevice8;
        base: IDevice7.VTable,
        GetResourceAllocationInfo2: *const fn (
            *T,
            UINT,
            UINT,
            *const RESOURCE_DESC1,
            ?[*]RESOURCE_ALLOCATION_INFO1,
        ) callconv(.winapi) RESOURCE_ALLOCATION_INFO,
        CreateCommittedResource2: *const fn (
            *T,
            *const HEAP_PROPERTIES,
            HEAP_FLAGS,
            *const RESOURCE_DESC1,
            RESOURCE_STATES,
            ?*const CLEAR_VALUE,
            ?*IProtectedResourceSession,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreatePlacedResource1: *const fn (
            *T,
            *IHeap,
            UINT64,
            *const RESOURCE_DESC1,
            RESOURCE_STATES,
            ?*const CLEAR_VALUE,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateSamplerFeedbackUnorderedAccessView: *const fn (
            *T,
            ?*IResource,
            ?*IResource,
            CPU_DESCRIPTOR_HANDLE,
        ) callconv(.winapi) void,
        GetCopyableFootprints1: *const fn (
            *T,
            *const RESOURCE_DESC1,
            UINT,
            UINT,
            UINT64,
            ?[*]PLACED_SUBRESOURCE_FOOTPRINT,
            ?[*]UINT,
            ?[*]UINT64,
            ?*UINT64,
        ) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,
    idevice3: IDevice3,
    idevice4: IDevice4,
    idevice5: IDevice5,
    idevice6: IDevice6,
    idevice7: IDevice7,

    pub inline fn GetResourceAllocationInfo2(
        self: *IDevice8,
        num_resource_descs: UINT,
        resource_descs: UINT,
        out_resource_allocation_info1: ?[*]RESOURCE_ALLOCATION_INFO1,
    ) RESOURCE_ALLOCATION_INFO {
        return self.vtable.GetResourceAllocationInfo2(self, num_resource_descs, resource_descs, out_resource_allocation_info1);
    }
    pub inline fn CreateCommittedResource2(
        self: *IDevice8,
        heap_properties: *const HEAP_PROPERTIES,
        heap_flags: HEAP_FLAGS,
        desc: *const RESOURCE_DESC1,
        initial_resource_state: RESOURCE_STATES,
        optimized_clear_value: ?*const CLEAR_VALUE,
        protected_session: ?*IProtectedResourceSession,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommittedResource2(
            self,
            heap_properties,
            heap_flags,
            desc,
            initial_resource_state,
            optimized_clear_value,
            protected_session,
            riid,
            resource,
        );
    }
    pub inline fn CreatePlacedResource1(
        self: *IDevice8,
        heap: *IHeap,
        heap_offset: UINT64,
        desc: *const RESOURCE_DESC1,
        initial_state: RESOURCE_STATES,
        optimized_clear_value: ?*const CLEAR_VALUE,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreatePlacedResource1(self, heap, heap_offset, desc, initial_state, optimized_clear_value, riid, resource);
    }
    pub inline fn CreateSamplerFeedbackUnorderedAccessView(
        self: *IDevice8,
        resource: ?*IResource,
        sampler_feedback_resource: ?*IResource,
        dest_descriptor: CPU_DESCRIPTOR_HANDLE,
    ) void {
        self.vtable.CreateSamplerFeedbackUnorderedAccessView(self, resource, sampler_feedback_resource, dest_descriptor);
    }
    pub inline fn GetCopyableFootprints1(
        self: *IDevice8,
        desc: *const RESOURCE_DESC1,
        first_subresource: UINT,
        num_subresources: UINT,
        base_offset: UINT64,
        layouts: ?[*]PLACED_SUBRESOURCE_FOOTPRINT,
        num_rows: ?[*]UINT,
        row_sizes_in_bytes: ?[*]UINT64,
        total_bytes: ?*UINT64,
    ) void {
        self.vtable.GetCopyableFootprints1(
            self,
            desc,
            first_subresource,
            num_subresources,
            base_offset,
            layouts,
            num_rows,
            row_sizes_in_bytes,
            total_bytes,
        );
    }
};

pub const SHADER_CACHE_KIND_FLAGS = packed struct(UINT) {
    IMPLICIT_D3D_CACHE_FOR_DRIVER: bool = false,
    IMPLICIT_D3D_CONVERSIONS: bool = false,
    IMPLICIT_DRIVER_MANAGED: bool = false,
    APPLICATION_MANAGED: bool = false,
    __unused: u28 = 0,
};

pub const SHADER_CACHE_CONTROL_FLAGS = packed struct(UINT) {
    DISABLE: bool = false,
    ENABLE: bool = false,
    CLEAR: bool = false,
    __unused: u29 = 0,
};

pub const SHADER_CACHE_MODE = enum(UINT) {
    MEMORY = 0,
    DISK = 1,
};

pub const SHADER_CACHE_FLAGS = packed struct(UINT) {
    DRIVER_VERSIONED: bool = false,
    USE_WORKING_DIR: bool = false,
    __unused: u30 = 0,
};

pub const SHADER_CACHE_SESSION_DESC = extern struct {
    Identifier: GUID,
    Mode: SHADER_CACHE_MODE,
    Flags: SHADER_CACHE_FLAGS,
    MaximumInMemoryCacheSizeBytes: UINT,
    MaximumInMemoryCacheEntries: UINT,
    MaximumValueFileSizeBytes: UINT,
    Version: UINT64,
};

pub const IDevice9 = extern union {
    pub const IID: GUID = .parse("{4c80e962-f032-4f60-bc9e-ebc2cfa1d83c}");
    pub const VTable = extern struct {
        base: IDevice8.VTable,
        CreateShaderCacheSession: *const fn (
            *IDevice9,
            *const SHADER_CACHE_SESSION_DESC,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        ShaderCacheControl: *const fn (
            *IDevice9,
            SHADER_CACHE_KIND_FLAGS,
            SHADER_CACHE_CONTROL_FLAGS,
        ) callconv(.winapi) HRESULT,
        CreateCommandQueue1: *const fn (
            *IDevice9,
            *const COMMAND_QUEUE_DESC,
            *const GUID,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,
    idevice3: IDevice3,
    idevice4: IDevice4,
    idevice5: IDevice5,
    idevice6: IDevice6,
    idevice7: IDevice7,
    idevice8: IDevice8,

    pub inline fn CreateShaderCacheSession(
        self: *IDevice9,
        desc: *const SHADER_CACHE_SESSION_DESC,
        riid: *const GUID,
        shader_cache_session: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateShaderCacheSession(self, desc, riid, shader_cache_session);
    }
    pub inline fn ShaderCacheControl(self: *IDevice9, kind_flags: SHADER_CACHE_KIND_FLAGS, control_flags: SHADER_CACHE_CONTROL_FLAGS) HRESULT {
        return self.vtable.ShaderCacheControl(self, kind_flags, control_flags);
    }
    pub inline fn CreateCommandQueue1(
        self: *IDevice9,
        desc: *const COMMAND_QUEUE_DESC,
        iid_queue: *const GUID,
        iid_fence: *const GUID,
        command_queue: *?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommandQueue1(self, desc, iid_queue, iid_fence, command_queue);
    }
};

pub const BARRIER_LAYOUT = enum(UINT) {
    PRESENT,
    GENERIC_READ,
    RENDER_TARGET,
    UNORDERED_ACCESS,
    DEPTH_STENCIL_WRITE,
    DEPTH_STENCIL_READ,
    SHADER_RESOURCE,
    COPY_SOURCE,
    COPY_DEST,
    RESOLVE_SOURCE,
    RESOLVE_DEST,
    SHADING_RATE_SOURCE,
    VIDEO_DECODE_READ,
    VIDEO_DECODE_WRITE,
    VIDEO_PROCESS_READ,
    VIDEO_PROCESS_WRITE,
    VIDEO_ENCODE_READ,
    VIDEO_ENCODE_WRITE,
    DIRECT_QUEUE_COMMON,
    DIRECT_QUEUE_GENERIC_READ,
    DIRECT_QUEUE_UNORDERED_ACCESS,
    DIRECT_QUEUE_SHADER_RESOURCE,
    DIRECT_QUEUE_COPY_SOURCE,
    DIRECT_QUEUE_COPY_DEST,
    COMPUTE_QUEUE_COMMON,
    COMPUTE_QUEUE_GENERIC_READ,
    COMPUTE_QUEUE_UNORDERED_ACCESS,
    COMPUTE_QUEUE_SHADER_RESOURCE,
    COMPUTE_QUEUE_COPY_SOURCE,
    COMPUTE_QUEUE_COPY_DEST,
    VIDEO_QUEUE_COMMON,
    UNDEFINED = 0xffffffff,

    pub const COMMON = .PRESENT;
};

pub const BARRIER_SYNC = packed struct(UINT) {
    ALL: bool = false, // 0x1
    DRAW: bool = false,
    INDEX_INPUT: bool = false,
    VERTEX_SHADING: bool = false,
    PIXEL_SHADING: bool = false, // 0x10
    DEPTH_STENCIL: bool = false,
    RENDER_TARGET: bool = false,
    COMPUTE_SHADING: bool = false,
    RAYTRACING: bool = false, // 0x100
    COPY: bool = false,
    RESOLVE: bool = false,
    EXECUTE_INDIRECT_OR_PREDICATION: bool = false,
    ALL_SHADING: bool = false, // 0x1000
    NON_PIXEL_SHADING: bool = false,
    EMIT_RAYTRACING_ACCELERATION_STRUCTURE_POSTBUILD_INFO: bool = false,
    CLEAR_UNORDERED_ACCESS_VIEW: bool = false,
    __unused16: bool = false, // 0x10000
    __unused17: bool = false,
    __unused18: bool = false,
    __unused19: bool = false,
    VIDEO_DECODE: bool = false, // 0x100000
    VIDEO_PROCESS: bool = false,
    VIDEO_ENCODE: bool = false,
    BUILD_RAYTRACING_ACCELERATION_STRUCTURE: bool = false,
    COPY_RAYTRACING_ACCELERATION_STRUCTURE: bool = false, // 0x1000000
    __unused25: bool = false,
    __unused26: bool = false,
    __unused27: bool = false,
    __unused28: bool = false, // 0x10000000
    __unused29: bool = false,
    __unused30: bool = false,
    SPLIT: bool = false,
};

pub const BARRIER_ACCESS = packed struct(UINT) {
    VERTEX_BUFFER: bool = false,
    CONSTANT_BUFFER: bool = false,
    INDEX_BUFFER: bool = false,
    RENDER_TARGET: bool = false,
    UNORDERED_ACCESS: bool = false,
    DEPTH_STENCIL_WRITE: bool = false,
    DEPTH_STENCIL_READ: bool = false,
    SHADER_RESOURCE: bool = false,
    STREAM_OUTPUT: bool = false,
    INDIRECT_ARGUMENT_OR_PREDICATION: bool = false,
    COPY_DEST: bool = false,
    COPY_SOURCE: bool = false,
    RESOLVE_DEST: bool = false,
    RESOLVE_SOURCE: bool = false,
    RAYTRACING_ACCELERATION_STRUCTURE_READ: bool = false,
    RAYTRACING_ACCELERATION_STRUCTURE_WRITE: bool = false,
    SHADING_RATE_SOURCE: bool = false,
    VIDEO_DECODE_READ: bool = false,
    VIDEO_DECODE_WRITE: bool = false,
    VIDEO_PROCESS_READ: bool = false,
    VIDEO_PROCESS_WRITE: bool = false,
    VIDEO_ENCODE_READ: bool = false,
    VIDEO_ENCODE_WRITE: bool = false,
    __unused23: bool = false,
    __unused24: bool = false,
    __unused25: bool = false,
    __unused26: bool = false,
    __unused27: bool = false,
    __unused28: bool = false,
    __unused29: bool = false,
    __unused30: bool = false,
    NO_ACCESS: bool = false,

    pub const COMMON: BARRIER_ACCESS = .{};
};

pub const BARRIER_TYPE = enum(UINT) {
    GLOBAL,
    TEXTURE,
    BUFFER,
};

pub const TEXTURE_BARRIER_FLAGS = packed struct(UINT) {
    DISCARD: bool = false,
    __unused: u31 = 0,
};

pub const BARRIER_SUBRESOURCE_RANGE = extern struct {
    IndexOrFirstMipLevel: UINT,
    NumMipLevels: UINT,
    FirstArraySlice: UINT,
    NumArraySlices: UINT,
    FirstPlane: UINT,
    NumPlanes: UINT,
};

pub const GLOBAL_BARRIER = extern struct {
    SyncBefore: BARRIER_SYNC,
    SyncAfter: BARRIER_SYNC,
    AccessBefore: BARRIER_ACCESS,
    AccessAfter: BARRIER_ACCESS,
};

pub const TEXTURE_BARRIER = extern struct {
    SyncBefore: BARRIER_SYNC,
    SyncAfter: BARRIER_SYNC,
    AccessBefore: BARRIER_ACCESS,
    AccessAfter: BARRIER_ACCESS,
    LayoutBefore: BARRIER_LAYOUT,
    LayoutAfter: BARRIER_LAYOUT,
    pResource: *IResource,
    Subresources: BARRIER_SUBRESOURCE_RANGE,
    Flags: TEXTURE_BARRIER_FLAGS,
};

pub const BUFFER_BARRIER = extern struct {
    SyncBefore: BARRIER_SYNC,
    SyncAfter: BARRIER_SYNC,
    AccessBefore: BARRIER_ACCESS,
    AccessAfter: BARRIER_ACCESS,
    pResource: *IResource,
    Offset: UINT64,
    Size: UINT64,
};

pub const BARRIER_GROUP = extern struct {
    Type: BARRIER_TYPE,
    NumBarriers: UINT32,
    u: extern union {
        pGlobalBarriers: [*]const GLOBAL_BARRIER,
        pTextureBarriers: [*]const TEXTURE_BARRIER,
        pBufferBarriers: [*]const BUFFER_BARRIER,
    },
};

pub const IDevice10 = extern union {
    pub const IID: GUID = .parse("{517f8718-aa66-49f9-b02b-a7ab89c06031}");
    pub const VTable = extern struct {
        base: IDevice9.VTable,
        CreateCommittedResource3: *const fn (
            *IDevice10,
            *const HEAP_PROPERTIES,
            HEAP_FLAGS,
            *const RESOURCE_DESC1,
            BARRIER_LAYOUT,
            ?*const CLEAR_VALUE,
            ?*IProtectedResourceSession,
            UINT32,
            ?[*]dxgi.FORMAT,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreatePlacedResource2: *const fn (
            *IDevice10,
            *IHeap,
            UINT64,
            *const RESOURCE_DESC1,
            BARRIER_LAYOUT,
            ?*const CLEAR_VALUE,
            UINT32,
            ?[*]dxgi.FORMAT,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        CreateReservedResource2: *const fn (
            *IDevice10,
            *const RESOURCE_DESC,
            BARRIER_LAYOUT,
            ?*const CLEAR_VALUE,
            ?*IProtectedResourceSession,
            UINT32,
            ?[*]dxgi.FORMAT,
            *const GUID,
            ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,
    idevice3: IDevice3,
    idevice4: IDevice4,
    idevice5: IDevice5,
    idevice6: IDevice6,
    idevice7: IDevice7,
    idevice8: IDevice8,
    idevice9: IDevice9,

    pub inline fn CreateCommittedResource3(
        self: *IDevice10,
        heap_properties: *const HEAP_PROPERTIES,
        heap_flags: HEAP_FLAGS,
        desc: *const RESOURCE_DESC1,
        initial_layout: BARRIER_LAYOUT,
        optimized_clear_value: ?*const CLEAR_VALUE,
        protected_session: ?*IProtectedResourceSession,
        num_optimized_clear_value_formats: UINT32,
        optimized_clear_value_formats: ?[*]dxgi.FORMAT,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateCommittedResource3(
            self,
            heap_properties,
            heap_flags,
            desc,
            initial_layout,
            optimized_clear_value,
            protected_session,
            num_optimized_clear_value_formats,
            optimized_clear_value_formats,
            riid,
            resource,
        );
    }
    pub inline fn CreatePlacedResource2(
        self: *IDevice10,
        heap: *IHeap,
        heap_offset: UINT64,
        desc: *const RESOURCE_DESC1,
        initial_layout: BARRIER_LAYOUT,
        optimized_clear_value: ?*const CLEAR_VALUE,
        num_optimized_clear_value_formats: UINT32,
        optimized_clear_value_formats: ?[*]dxgi.FORMAT,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreatePlacedResource2(
            self,
            heap,
            heap_offset,
            desc,
            initial_layout,
            optimized_clear_value,
            num_optimized_clear_value_formats,
            optimized_clear_value_formats,
            riid,
            resource,
        );
    }
    pub inline fn CreateReservedResource2(
        self: *IDevice10,
        desc: *const RESOURCE_DESC,
        initial_layout: BARRIER_LAYOUT,
        optimized_clear_value: ?*const CLEAR_VALUE,
        protected_session: ?*IProtectedResourceSession,
        num_optimized_clear_value_formats: UINT32,
        optimized_clear_value_formats: ?[*]dxgi.FORMAT,
        riid: *const GUID,
        resource: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateReservedResource2(
            self,
            desc,
            initial_layout,
            optimized_clear_value,
            protected_session,
            num_optimized_clear_value_formats,
            optimized_clear_value_formats,
            riid,
            resource,
        );
    }
};

pub const SAMPLER_FLAGS = packed struct(UINT) {
    UINT_BORDER_COLOR: bool = false,
    __unused: u31 = 0,
};

pub const SAMPLER_DESC2 = extern struct {
    Filter: FILTER,
    AddressU: TEXTURE_ADDRESS_MODE,
    AddressV: TEXTURE_ADDRESS_MODE,
    AddressW: TEXTURE_ADDRESS_MODE,
    MipLODBias: FLOAT,
    MaxAnisotropy: UINT,
    ComparisonFunc: COMPARISON_FUNC,
    u: extern union {
        FloatBorderColor: [4]FLOAT,
        UintBorderColor: [4]UINT,
    },
    MinLOD: FLOAT,
    MaxLOD: FLOAT,
    Flags: SAMPLER_FLAGS,
};

pub const IDevice11 = extern union {
    pub const IID: GUID = .parse("{5405c344-d457-444e-b4dd-2366e45aee39}");
    pub const VTable = extern struct {
        base: IDevice10.VTable,
        CreateSampler2: *const fn (*IDevice11, *const SAMPLER_DESC2, CPU_DESCRIPTOR_HANDLE) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,
    idevice1: IDevice1,
    idevice2: IDevice2,
    idevice3: IDevice3,
    idevice4: IDevice4,
    idevice5: IDevice5,
    idevice6: IDevice6,
    idevice7: IDevice7,
    idevice8: IDevice8,
    idevice9: IDevice9,
    idevice10: IDevice10,

    pub inline fn CreateSampler2(self: *IDevice11, desc: *const SAMPLER_DESC2, dest_descriptor: CPU_DESCRIPTOR_HANDLE) void {
        self.vtable.CreateSampler2(self, desc, dest_descriptor);
    }
};

pub const PROTECTED_SESSION_STATUS = enum(UINT) {
    OK = 0,
    INVALID = 1,
};

pub const IProtectedSession = extern union {
    pub const VTable = extern struct {
        base: IDeviceChild.VTable,
        GetStatusFence: *const fn (*IProtectedSession, *const GUID, ?*?*anyopaque) callconv(.winapi) HRESULT,
        GetSessionStatus: *const fn (*IProtectedSession) callconv(.winapi) PROTECTED_SESSION_STATUS,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,

    pub inline fn GetStatusFence(self: *IProtectedSession, riid: *const GUID, fence: ?*?*anyopaque) HRESULT {
        return self.vtable.GetStatusFence(self, riid, fence);
    }
    pub inline fn GetSessionStatus(self: *IProtectedSession) PROTECTED_SESSION_STATUS {
        return self.vtable.GetSessionStatus(self);
    }
};

pub const PROTECTED_RESOURCE_SESSION_FLAGS = packed struct(UINT) {
    __unused: u32 = 0,
};

pub const PROTECTED_RESOURCE_SESSION_DESC = extern struct {
    NodeMask: UINT,
    Flags: PROTECTED_RESOURCE_SESSION_FLAGS,
};

pub const IProtectedResourceSession = extern union {
    pub const VTable = extern struct {
        base: IProtectedSession.VTable,
        GetDesc: *const fn (
            *IProtectedResourceSession,
            *PROTECTED_RESOURCE_SESSION_DESC,
        ) callconv(.winapi) *PROTECTED_RESOURCE_SESSION_DESC,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevicechild: IDeviceChild,
    iprotectedsession: IProtectedSession,

    pub inline fn GetDesc(self: *IProtectedResourceSession, desc: *PROTECTED_RESOURCE_SESSION_DESC) *PROTECTED_RESOURCE_SESSION_DESC {
        return self.vtable.GetDesc(self, desc);
    }
};

extern "d3d12" fn D3D12GetDebugInterface(*const GUID, ?*?*anyopaque) callconv(.winapi) HRESULT;

extern "d3d12" fn D3D12CreateDevice(
    ?*IUnknown,
    d3d.FEATURE_LEVEL,
    *const GUID,
    ?*?*anyopaque,
) callconv(.winapi) HRESULT;

extern "d3d12" fn D3D12SerializeVersionedRootSignature(
    *const VERSIONED_ROOT_SIGNATURE_DESC,
    ?*?*d3d.IBlob,
    ?*?*d3d.IBlob,
) callconv(.winapi) HRESULT;

pub const CreateDevice = D3D12CreateDevice;
pub const GetDebugInterface = D3D12GetDebugInterface;
pub const SerializeVersionedRootSignature = D3D12SerializeVersionedRootSignature;

pub const DEBUG_FEATURE = packed struct(UINT) {
    ALLOW_BEHAVIOR_CHANGING_DEBUG_AIDS: bool = false,
    CONSERVATIVE_RESOURCE_STATE_TRACKING: bool = false,
    DISABLE_VIRTUALIZED_BUNDLES_VALIDATION: bool = false,
    EMULATE_WINDOWS7: bool = false,
    __unused: u28 = 0,
};

pub const RLDO_FLAGS = packed struct(UINT) {
    SUMMARY: bool = false,
    DETAIL: bool = false,
    IGNORE_INTERNAL: bool = false,
    ALL: bool = false,
    __unused: u28 = 0,
};

pub const IDebugDevice = extern union {
    pub const IID: GUID = .parse("{3febd6dd-4973-4787-8194-e45f9e28923e}");
    pub const VTable = extern struct {
        const T = IDebugDevice;
        base: IUnknown.VTable,
        SetFeatureMask: *const fn (*T, DEBUG_FEATURE) callconv(.winapi) HRESULT,
        GetFeatureMask: *const fn (*T) callconv(.winapi) DEBUG_FEATURE,
        ReportLiveDeviceObjects: *const fn (*T, RLDO_FLAGS) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn SetFeatureMask(self: *IDebugDevice, mask: DEBUG_FEATURE) HRESULT {
        return self.vtable.SetFeatureMask(self, mask);
    }
    pub inline fn GetFeatureMask(self: *IDebugDevice) DEBUG_FEATURE {
        return self.vtable.GetFeatureMask(self);
    }
    pub inline fn ReportLiveDeviceObjects(self: *IDebugDevice, flags: RLDO_FLAGS) HRESULT {
        return self.vtable.ReportLiveDeviceObjects(self, flags);
    }
};

pub const FEATURE_DATA_FORMAT_SUPPORT = extern struct {
    Format: dxgi.FORMAT,
    Support1: FORMAT_SUPPORT1,
    Support2: FORMAT_SUPPORT2,
};

pub const FORMAT_SUPPORT1 = enum(u32) {
    NONE = 0,
    BUFFER = 0x1,
    IA_VERTEX_BUFFER = 0x2,
    IA_INDEX_BUFFER = 0x4,
    SO_BUFFER = 0x8,
    TEXTURE1D = 0x10,
    TEXTURE2D = 0x20,
    TEXTURE3D = 0x40,
    TEXTURECUBE = 0x80,
    SHADER_LOAD = 0x100,
    SHADER_SAMPLE = 0x200,
    SHADER_SAMPLE_COMPARISON = 0x400,
    SHADER_SAMPLE_MONO_TEXT = 0x800,
    MIP = 0x1000,
    RENDER_TARGET = 0x4000,
    BLENDABLE = 0x8000,
    DEPTH_STENCIL = 0x10000,
    MULTISAMPLE_RESOLVE = 0x40000,
    DISPLAY = 0x80000,
    CAST_WITHIN_BIT_LAYOUT = 0x100000,
    MULTISAMPLE_RENDERTARGET = 0x200000,
    MULTISAMPLE_LOAD = 0x400000,
    SHADER_GATHER = 0x800000,
    BACK_BUFFER_CAST = 0x1000000,
    TYPED_UNORDERED_ACCESS_VIEW = 0x2000000,
    SHADER_GATHER_COMPARISON = 0x4000000,
    DECODER_OUTPUT = 0x8000000,
    VIDEO_PROCESSOR_OUTPUT = 0x10000000,
    VIDEO_PROCESSOR_INPUT = 0x20000000,
    VIDEO_ENCODER = 0x40000000,
    _,
};

pub const FORMAT_SUPPORT2 = enum(u32) {
    NONE = 0,
    UAV_ATOMIC_ADD = 0x1,
    UAV_ATOMIC_BITWISE_OPS = 0x2,
    UAV_ATOMIC_COMPARE_STORE_OR_COMPARE_EXCHANGE = 0x4,
    UAV_ATOMIC_EXCHANGE = 0x8,
    UAV_ATOMIC_SIGNED_MIN_OR_MAX = 0x10,
    UAV_ATOMIC_UNSIGNED_MIN_OR_MAX = 0x20,
    UAV_TYPED_LOAD = 0x40,
    UAV_TYPED_STORE = 0x80,
    OUTPUT_MERGER_LOGIC_OP = 0x100,
    TILED = 0x200,
    MULTIPLANE_OVERLAY = 0x4000,
    SAMPLER_FEEDBACK,
    DISPLAYABLE,
    _,
};

// Error return codes from:
// https://docs.microsoft.com/en-us/windows/win32/direct3d12/d3d12-graphics-reference-returnvalues
pub const ERROR_ADAPTER_NOT_FOUND = @as(HRESULT, @bitCast(@as(c_ulong, 0x887E0001)));
pub const ERROR_DRIVER_VERSION_MISMATCH = @as(HRESULT, @bitCast(@as(c_ulong, 0x887E0002)));

// Error set corresponding to the above error return codes
// pub const Error = error{
//     ADAPTER_NOT_FOUND,
//     DRIVER_VERSION_MISMATCH,
// };
