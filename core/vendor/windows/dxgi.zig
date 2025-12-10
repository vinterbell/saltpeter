const std = @import("std");

const win32 = @import("win32.zig");
const UINT = win32.UINT;
const UINT64 = win32.UINT64;
const DWORD = win32.DWORD;
const FLOAT = win32.FLOAT;
const BOOL = win32.BOOL;
const GUID = win32.GUID;
const IUnknown = win32.IUnknown;
const HRESULT = win32.HRESULT;
const WCHAR = win32.WCHAR;
const RECT = win32.RECT;
const INT = win32.INT;
const BYTE = win32.BYTE;
const HMONITOR = win32.HMONITOR;
const LARGE_INTEGER = win32.LARGE_INTEGER;
const HWND = win32.HWND;
const SIZE_T = win32.SIZE_T;
const LUID = win32.LUID;
const HANDLE = win32.HANDLE;
const POINT = win32.POINT;

pub const FORMAT = enum(UINT) {
    UNKNOWN = 0,
    R32G32B32A32_TYPELESS = 1,
    R32G32B32A32_FLOAT = 2,
    R32G32B32A32_UINT = 3,
    R32G32B32A32_SINT = 4,
    R32G32B32_TYPELESS = 5,
    R32G32B32_FLOAT = 6,
    R32G32B32_UINT = 7,
    R32G32B32_SINT = 8,
    R16G16B16A16_TYPELESS = 9,
    R16G16B16A16_FLOAT = 10,
    R16G16B16A16_UNORM = 11,
    R16G16B16A16_UINT = 12,
    R16G16B16A16_SNORM = 13,
    R16G16B16A16_SINT = 14,
    R32G32_TYPELESS = 15,
    R32G32_FLOAT = 16,
    R32G32_UINT = 17,
    R32G32_SINT = 18,
    R32G8X24_TYPELESS = 19,
    D32_FLOAT_S8X24_UINT = 20,
    R32_FLOAT_X8X24_TYPELESS = 21,
    X32_TYPELESS_G8X24_UINT = 22,
    R10G10B10A2_TYPELESS = 23,
    R10G10B10A2_UNORM = 24,
    R10G10B10A2_UINT = 25,
    R11G11B10_FLOAT = 26,
    R8G8B8A8_TYPELESS = 27,
    R8G8B8A8_UNORM = 28,
    R8G8B8A8_UNORM_SRGB = 29,
    R8G8B8A8_UINT = 30,
    R8G8B8A8_SNORM = 31,
    R8G8B8A8_SINT = 32,
    R16G16_TYPELESS = 33,
    R16G16_FLOAT = 34,
    R16G16_UNORM = 35,
    R16G16_UINT = 36,
    R16G16_SNORM = 37,
    R16G16_SINT = 38,
    R32_TYPELESS = 39,
    D32_FLOAT = 40,
    R32_FLOAT = 41,
    R32_UINT = 42,
    R32_SINT = 43,
    R24G8_TYPELESS = 44,
    D24_UNORM_S8_UINT = 45,
    R24_UNORM_X8_TYPELESS = 46,
    X24_TYPELESS_G8_UINT = 47,
    R8G8_TYPELESS = 48,
    R8G8_UNORM = 49,
    R8G8_UINT = 50,
    R8G8_SNORM = 51,
    R8G8_SINT = 52,
    R16_TYPELESS = 53,
    R16_FLOAT = 54,
    D16_UNORM = 55,
    R16_UNORM = 56,
    R16_UINT = 57,
    R16_SNORM = 58,
    R16_SINT = 59,
    R8_TYPELESS = 60,
    R8_UNORM = 61,
    R8_UINT = 62,
    R8_SNORM = 63,
    R8_SINT = 64,
    A8_UNORM = 65,
    R1_UNORM = 66,
    R9G9B9E5_SHAREDEXP = 67,
    R8G8_B8G8_UNORM = 68,
    G8R8_G8B8_UNORM = 69,
    BC1_TYPELESS = 70,
    BC1_UNORM = 71,
    BC1_UNORM_SRGB = 72,
    BC2_TYPELESS = 73,
    BC2_UNORM = 74,
    BC2_UNORM_SRGB = 75,
    BC3_TYPELESS = 76,
    BC3_UNORM = 77,
    BC3_UNORM_SRGB = 78,
    BC4_TYPELESS = 79,
    BC4_UNORM = 80,
    BC4_SNORM = 81,
    BC5_TYPELESS = 82,
    BC5_UNORM = 83,
    BC5_SNORM = 84,
    B5G6R5_UNORM = 85,
    B5G5R5A1_UNORM = 86,
    B8G8R8A8_UNORM = 87,
    B8G8R8X8_UNORM = 88,
    R10G10B10_XR_BIAS_A2_UNORM = 89,
    B8G8R8A8_TYPELESS = 90,
    B8G8R8A8_UNORM_SRGB = 91,
    B8G8R8X8_TYPELESS = 92,
    B8G8R8X8_UNORM_SRGB = 93,
    BC6H_TYPELESS = 94,
    BC6H_UF16 = 95,
    BC6H_SF16 = 96,
    BC7_TYPELESS = 97,
    BC7_UNORM = 98,
    BC7_UNORM_SRGB = 99,
    AYUV = 100,
    Y410 = 101,
    Y416 = 102,
    NV12 = 103,
    P010 = 104,
    P016 = 105,
    @"420_OPAQUE" = 106,
    YUY2 = 107,
    Y210 = 108,
    Y216 = 109,
    NV11 = 110,
    AI44 = 111,
    IA44 = 112,
    P8 = 113,
    A8P8 = 114,
    B4G4R4A4_UNORM = 115,
    P208 = 130,
    V208 = 131,
    V408 = 132,
    SAMPLER_FEEDBACK_MIN_MIP_OPAQUE = 189,
    SAMPLER_FEEDBACK_MIP_REGION_USED_OPAQUE = 190,

    pub fn pixelSizeInBits(format: FORMAT) u32 {
        return switch (format) {
            .R32G32B32A32_TYPELESS,
            .R32G32B32A32_FLOAT,
            .R32G32B32A32_UINT,
            .R32G32B32A32_SINT,
            => 128,

            .R32G32B32_TYPELESS,
            .R32G32B32_FLOAT,
            .R32G32B32_UINT,
            .R32G32B32_SINT,
            => 96,

            .R16G16B16A16_TYPELESS,
            .R16G16B16A16_FLOAT,
            .R16G16B16A16_UNORM,
            .R16G16B16A16_UINT,
            .R16G16B16A16_SNORM,
            .R16G16B16A16_SINT,
            .R32G32_TYPELESS,
            .R32G32_FLOAT,
            .R32G32_UINT,
            .R32G32_SINT,
            .R32G8X24_TYPELESS,
            .D32_FLOAT_S8X24_UINT,
            .R32_FLOAT_X8X24_TYPELESS,
            .X32_TYPELESS_G8X24_UINT,
            .Y416,
            .Y210,
            .Y216,
            => 64,

            .R10G10B10A2_TYPELESS,
            .R10G10B10A2_UNORM,
            .R10G10B10A2_UINT,
            .R11G11B10_FLOAT,
            .R8G8B8A8_TYPELESS,
            .R8G8B8A8_UNORM,
            .R8G8B8A8_UNORM_SRGB,
            .R8G8B8A8_UINT,
            .R8G8B8A8_SNORM,
            .R8G8B8A8_SINT,
            .R16G16_TYPELESS,
            .R16G16_FLOAT,
            .R16G16_UNORM,
            .R16G16_UINT,
            .R16G16_SNORM,
            .R16G16_SINT,
            .R32_TYPELESS,
            .D32_FLOAT,
            .R32_FLOAT,
            .R32_UINT,
            .R32_SINT,
            .R24G8_TYPELESS,
            .D24_UNORM_S8_UINT,
            .R24_UNORM_X8_TYPELESS,
            .X24_TYPELESS_G8_UINT,
            .R9G9B9E5_SHAREDEXP,
            .R8G8_B8G8_UNORM,
            .G8R8_G8B8_UNORM,
            .B8G8R8A8_UNORM,
            .B8G8R8X8_UNORM,
            .R10G10B10_XR_BIAS_A2_UNORM,
            .B8G8R8A8_TYPELESS,
            .B8G8R8A8_UNORM_SRGB,
            .B8G8R8X8_TYPELESS,
            .B8G8R8X8_UNORM_SRGB,
            .AYUV,
            .Y410,
            .YUY2,
            => 32,

            .P010,
            .P016,
            .V408,
            => 24,

            .R8G8_TYPELESS,
            .R8G8_UNORM,
            .R8G8_UINT,
            .R8G8_SNORM,
            .R8G8_SINT,
            .R16_TYPELESS,
            .R16_FLOAT,
            .D16_UNORM,
            .R16_UNORM,
            .R16_UINT,
            .R16_SNORM,
            .R16_SINT,
            .B5G6R5_UNORM,
            .B5G5R5A1_UNORM,
            .A8P8,
            .B4G4R4A4_UNORM,
            => 16,

            .P208,
            .V208,
            => 16,

            .@"420_OPAQUE",
            .NV11,
            .NV12,
            => 12,

            .R8_TYPELESS,
            .R8_UNORM,
            .R8_UINT,
            .R8_SNORM,
            .R8_SINT,
            .A8_UNORM,
            .AI44,
            .IA44,
            .P8,
            => 8,

            .BC2_TYPELESS,
            .BC2_UNORM,
            .BC2_UNORM_SRGB,
            .BC3_TYPELESS,
            .BC3_UNORM,
            .BC3_UNORM_SRGB,
            .BC5_TYPELESS,
            .BC5_UNORM,
            .BC5_SNORM,
            .BC6H_TYPELESS,
            .BC6H_UF16,
            .BC6H_SF16,
            .BC7_TYPELESS,
            .BC7_UNORM,
            .BC7_UNORM_SRGB,
            => 8,

            .R1_UNORM => 1,

            .BC1_TYPELESS,
            .BC1_UNORM,
            .BC1_UNORM_SRGB,
            .BC4_TYPELESS,
            .BC4_UNORM,
            .BC4_SNORM,
            => 4,

            .UNKNOWN,
            .SAMPLER_FEEDBACK_MIP_REGION_USED_OPAQUE,
            .SAMPLER_FEEDBACK_MIN_MIP_OPAQUE,
            => unreachable,
        };
    }

    pub fn isDepthStencil(format: FORMAT) bool {
        return switch (format) {
            .R32G8X24_TYPELESS,
            .D32_FLOAT_S8X24_UINT,
            .R32_FLOAT_X8X24_TYPELESS,
            .X32_TYPELESS_G8X24_UINT,
            .D32_FLOAT,
            .R24G8_TYPELESS,
            .D24_UNORM_S8_UINT,
            .R24_UNORM_X8_TYPELESS,
            .X24_TYPELESS_G8_UINT,
            .D16_UNORM,
            => true,

            else => false,
        };
    }
};

pub const RATIONAL = extern struct {
    Numerator: UINT,
    Denominator: UINT,

    pub const zero: RATIONAL = .{
        .Numerator = 0,
        .Denominator = 1,
    };

    pub fn fraction(numerator: UINT, denominator: UINT) RATIONAL {
        return .{
            .Numerator = numerator,
            .Denominator = denominator,
        };
    }
};

// The following values are used with SAMPLE_DESC::Quality:
pub const STANDARD_MULTISAMPLE_QUALITY_PATTERN = 0xffffffff;
pub const CENTER_MULTISAMPLE_QUALITY_PATTERN = 0xfffffffe;

pub const SAMPLE_DESC = extern struct {
    Count: UINT,
    Quality: UINT,

    pub const zero: SAMPLE_DESC = .{
        .Count = 0,
        .Quality = 0,
    };

    pub const default: SAMPLE_DESC = .{
        .Count = 1,
        .Quality = 0,
    };
};

pub const COLOR_SPACE_TYPE = enum(UINT) {
    RGB_FULL_G22_NONE_P709 = 0,
    RGB_FULL_G10_NONE_P709 = 1,
    RGB_STUDIO_G22_NONE_P709 = 2,
    RGB_STUDIO_G22_NONE_P2020 = 3,
    RESERVED = 4,
    YCBCR_FULL_G22_NONE_P709_X601 = 5,
    YCBCR_STUDIO_G22_LEFT_P601 = 6,
    YCBCR_FULL_G22_LEFT_P601 = 7,
    YCBCR_STUDIO_G22_LEFT_P709 = 8,
    YCBCR_FULL_G22_LEFT_P709 = 9,
    YCBCR_STUDIO_G22_LEFT_P2020 = 10,
    YCBCR_FULL_G22_LEFT_P2020 = 11,
    RGB_FULL_G2084_NONE_P2020 = 12,
    YCBCR_STUDIO_G2084_LEFT_P2020 = 13,
    RGB_STUDIO_G2084_NONE_P2020 = 14,
    YCBCR_STUDIO_G22_TOPLEFT_P2020 = 15,
    YCBCR_STUDIO_G2084_TOPLEFT_P2020 = 16,
    RGB_FULL_G22_NONE_P2020 = 17,
    YCBCR_STUDIO_GHLG_TOPLEFT_P2020 = 18,
    YCBCR_FULL_GHLG_TOPLEFT_P2020 = 19,
    RGB_STUDIO_G24_NONE_P709 = 20,
    RGB_STUDIO_G24_NONE_P2020 = 21,
    YCBCR_STUDIO_G24_LEFT_P709 = 22,
    YCBCR_STUDIO_G24_LEFT_P2020 = 23,
    YCBCR_STUDIO_G24_TOPLEFT_P2020 = 24,
    CUSTOM = 0xFFFFFFFF,
};

pub const CPU_ACCESS = enum(UINT) {
    NONE = 0,
    DYNAMIC = 1,
    READ_WRITE = 2,
    SCRATCH = 3,
    FIELD = 15,
};

pub const RGB = extern struct {
    Red: FLOAT,
    Green: FLOAT,
    Blue: FLOAT,

    pub const zero: RGB = .{
        .Red = 0.0,
        .Green = 0.0,
        .Blue = 0.0,
    };
};

pub const D3DCOLORVALUE = extern struct {
    r: FLOAT,
    g: FLOAT,
    b: FLOAT,
    a: FLOAT,

    pub const zero: D3DCOLORVALUE = .{
        .r = 0.0,
        .g = 0.0,
        .b = 0.0,
        .a = 0.0,
    };
};

pub const RGBA = D3DCOLORVALUE;

pub const GAMMA_CONTROL = extern struct {
    Scale: RGB,
    Offset: RGB,
    GammaCurve: [1025]RGB,

    pub const zero: GAMMA_CONTROL = .{
        .Scale = .zero,
        .Offset = .zero,
        .GammaCurve = @splat(0),
    };
};

pub const GAMMA_CONTROL_CAPABILITIES = extern struct {
    ScaleAndOffsetSupported: BOOL,
    MaxConvertedValue: FLOAT,
    MinConvertedValue: FLOAT,
    NumGammaControlPoints: UINT,
    ControlPointPositions: [1025]FLOAT,

    pub const zero: GAMMA_CONTROL_CAPABILITIES = .{
        .ScaleAndOffsetSupported = .FALSE,
        .MaxConvertedValue = 0.0,
        .MinConvertedValue = 0.0,
        .NumGammaControlPoints = 0,
        .ControlPointPositions = @splat(0),
    };
};

pub const MODE_SCANLINE_ORDER = enum(UINT) {
    UNSPECIFIED = 0,
    PROGRESSIVE = 1,
    UPPER_FIELD_FIRST = 2,
    LOWER_FIELD_FIRST = 3,
};

pub const MODE_SCALING = enum(UINT) {
    UNSPECIFIED = 0,
    CENTERED = 1,
    STRETCHED = 2,
};

pub const MODE_ROTATION = enum(UINT) {
    UNSPECIFIED = 0,
    IDENTITY = 1,
    ROTATE90 = 2,
    ROTATE180 = 3,
    ROTATE270 = 4,
};

pub const MODE_DESC = extern struct {
    Width: UINT,
    Height: UINT,
    RefreshRate: RATIONAL,
    Format: FORMAT,
    ScanlineOrdering: MODE_SCANLINE_ORDER,
    Scaling: MODE_SCALING,

    pub const zero: MODE_DESC = .{
        .Width = 0,
        .Height = 0,
        .RefreshRate = .zero,
        .Format = .UNKNOWN,
        .ScanlineOrdering = .UNSPECIFIED,
        .Scaling = .UNSPECIFIED,
    };
};

pub const USAGE = packed struct(UINT) {
    __unused0: bool = false,
    __unused1: bool = false,
    __unused2: bool = false,
    __unused3: bool = false,
    SHADER_INPUT: bool = false,
    RENDER_TARGET_OUTPUT: bool = false,
    BACK_BUFFER: bool = false,
    SHARED: bool = false,
    READ_ONLY: bool = false,
    DISCARD_ON_PRESENT: bool = false,
    UNORDERED_ACCESS: bool = false,
    __unused: u21 = 0,
};

pub const FRAME_STATISTICS = extern struct {
    PresentCount: UINT,
    PresentRefreshCount: UINT,
    SyncRefreshCount: UINT,
    SyncQPCTime: LARGE_INTEGER,
    SyncGPUTime: LARGE_INTEGER,

    pub const zero: FRAME_STATISTICS = .{
        .PresentCount = 0,
        .PresentRefreshCount = 0,
        .SyncRefreshCount = 0,
        .SyncQPCTime = 0,
        .SyncGPUTime = 0,
    };
};

pub const MAPPED_RECT = extern struct {
    Pitch: INT,
    pBits: *BYTE,
};

pub const ADAPTER_DESC = extern struct {
    Description: [128]WCHAR,
    VendorId: UINT,
    DeviceId: UINT,
    SubSysId: UINT,
    Revision: UINT,
    DedicatedVideoMemory: SIZE_T,
    DedicatedSystemMemory: SIZE_T,
    SharedSystemMemory: SIZE_T,
    AdapterLuid: LUID,

    pub const zero: ADAPTER_DESC = .{
        .Description = @splat(0),
        .VendorId = 0,
        .DeviceId = 0,
        .SubSysId = 0,
        .Revision = 0,
        .DedicatedVideoMemory = 0,
        .DedicatedSystemMemory = 0,
        .SharedSystemMemory = 0,
        .AdapterLuid = LUID{ .LowPart = 0, .HighPart = 0 },
    };
};

pub const OUTPUT_DESC = extern struct {
    DeviceName: [32]WCHAR,
    DesktopCoordinates: RECT,
    AttachedToDesktop: BOOL,
    Rotation: MODE_ROTATION,
    Monitor: HMONITOR,

    pub const zero: OUTPUT_DESC = .{
        .DeviceName = @splat(0),
        .DesktopCoordinates = .zero,
        .AttachedToDesktop = .FALSE,
        .Rotation = .UNSPECIFIED,
    };
};

pub const SHARED_RESOURCE = extern struct {
    Handle: HANDLE,
};

pub const RESOURCE_PRIORITY = enum(UINT) {
    MINIMUM = 0x28000000,
    LOW = 0x50000000,
    NORMAL = 0x78000000,
    HIGH = 0xa0000000,
    MAXIMUM = 0xc8000000,
};

pub const RESIDENCY = enum(UINT) {
    FULLY_RESIDENT = 1,
    RESIDENT_IN_SHARED_MEMORY = 2,
    EVICTED_TO_DISK = 3,
};

pub const SURFACE_DESC = extern struct {
    Width: UINT,
    Height: UINT,
    Format: FORMAT,
    SampleDesc: SAMPLE_DESC,

    pub const zero: SURFACE_DESC = .{
        .Width = 0,
        .Height = 0,
        .Format = .UNKNOWN,
        .SampleDesc = SAMPLE_DESC.zero,
    };
};

pub const SWAP_EFFECT = enum(UINT) {
    DISCARD = 0,
    SEQUENTIAL = 1,
    FLIP_SEQUENTIAL = 3,
    FLIP_DISCARD = 4,
};

pub const SWAP_CHAIN_FLAG = packed struct(UINT) {
    NONPREROTATED: bool = false,
    ALLOW_MODE_SWITCH: bool = false,
    GDI_COMPATIBLE: bool = false,
    RESTRICTED_CONTENT: bool = false,
    RESTRICT_SHARED_RESOURCE_DRIVER: bool = false,
    DISPLAY_ONLY: bool = false,
    FRAME_LATENCY_WAITABLE_OBJECT: bool = false,
    FOREGROUND_LAYER: bool = false,
    FULLSCREEN_VIDEO: bool = false,
    YUV_VIDEO: bool = false,
    HW_PROTECTED: bool = false,
    ALLOW_TEARING: bool = false,
    RESTRICTED_TO_ALL_HOLOGRAPHIC_DISPLAYS: bool = false,
    __unused: u19 = 0,
};

pub const SWAP_CHAIN_DESC = extern struct {
    BufferDesc: MODE_DESC,
    SampleDesc: SAMPLE_DESC,
    BufferUsage: USAGE,
    BufferCount: UINT,
    OutputWindow: HWND,
    Windowed: BOOL,
    SwapEffect: SWAP_EFFECT,
    Flags: SWAP_CHAIN_FLAG,

    pub const zero: SWAP_CHAIN_DESC = .{
        .BufferDesc = .zero,
        .SampleDesc = .zero,
        .BufferUsage = .zero,
        .BufferCount = 0,
        .OutputWindow = null,
        .Windowed = .FALSE,
        .SwapEffect = .DISCARD,
    };
};

pub const IObject = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        SetPrivateData: *const fn (
            self: *const IObject,
            Name: ?*const GUID,
            DataSize: u32,
            pData: ?*const anyopaque,
        ) callconv(.winapi) HRESULT,
        SetPrivateDataInterface: *const fn (
            self: *const IObject,
            Name: ?*const GUID,
            pUnknown: ?*IUnknown,
        ) callconv(.winapi) HRESULT,
        GetPrivateData: *const fn (
            self: *const IObject,
            Name: ?*const GUID,
            pDataSize: ?*u32,
            pData: ?*anyopaque,
        ) callconv(.winapi) HRESULT,
        GetParent: *const fn (
            self: *const IObject,
            riid: ?*const GUID,
            ppParent: **anyopaque,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    IUnknown: IUnknown,

    pub inline fn SetPrivateData(self: *const IObject, Name: ?*const GUID, DataSize: u32, pData: ?*const anyopaque) HRESULT {
        return self.vtable.SetPrivateData(self, Name, DataSize, pData);
    }

    pub inline fn SetPrivateDataInterface(self: *const IObject, Name: ?*const GUID, pUnknown: ?*IUnknown) HRESULT {
        return self.vtable.SetPrivateDataInterface(self, Name, pUnknown);
    }

    pub inline fn GetPrivateData(self: *const IObject, Name: ?*const GUID, pDataSize: ?*u32, pData: ?*anyopaque) HRESULT {
        return self.vtable.GetPrivateData(self, Name, pDataSize, pData);
    }

    pub inline fn GetParent(self: *const IObject, riid: ?*const GUID, ppParent: **anyopaque) HRESULT {
        return self.vtable.GetParent(self, riid, ppParent);
    }

    const WKPDID_D3DDebugObjectName: GUID = .{
        .Data1 = 0x429b8c22,
        .Data2 = 0x9188,
        .Data3 = 0x4b0c,
        .Data4 = .{ 0x87, 0x42, 0xac, 0xb0, 0xbf, 0x85, 0xc2, 0x00 },
    };

    pub inline fn setNameUtf8(self: *IObject, name: []const u8) !HRESULT {
        var buf: [256]u16 = undefined;
        const len = try std.unicode.utf8ToUtf16Le(&buf, name);
        buf[len] = 0; // null terminate
        return self.SetPrivateData(&WKPDID_D3DDebugObjectName, @intCast(len), @ptrCast(&buf[0]));
    }
};

pub const IDeviceSubObject = extern union {
    pub const VTable = extern struct {
        base: IObject.VTable,
        GetDevice: *const fn (*IDeviceSubObject, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,

    pub inline fn GetDevice(
        self: *const IDeviceSubObject,
        guid: *const GUID,
        parent: *?*anyopaque,
    ) HRESULT {
        return self.vtable.GetDevice(self, guid, parent);
    }
};

pub const IResource = extern union {
    pub const VTable = extern struct {
        base: IDeviceSubObject.VTable,
        GetSharedHandle: *const fn (*IResource, *HANDLE) callconv(.winapi) HRESULT,
        GetUsage: *const fn (*IResource, *USAGE) callconv(.winapi) HRESULT,
        SetEvictionPriority: *const fn (*IResource, UINT) callconv(.winapi) HRESULT,
        GetEvictionPriority: *const fn (*IResource, *UINT) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice_sub_object: IDeviceSubObject,

    pub inline fn GetSharedHandle(self: *IResource, handle: *HANDLE) HRESULT {
        return self.vtable.GetSharedHandle(self, handle);
    }
    pub inline fn GetUsage(self: *IResource, usage: *USAGE) HRESULT {
        return self.vtable.GetUsage(self, usage);
    }
    pub inline fn SetEvictionPriority(self: *IResource, priority: UINT) HRESULT {
        return self.vtable.SetEvictionPriority(self, priority);
    }
    pub inline fn GetEvictionPriority(self: *IResource, priority: *UINT) HRESULT {
        return self.vtable.GetEvictionPriority(self, priority);
    }
};

pub const IKeyedMutex = extern union {
    pub const VTable = extern struct {
        base: IDeviceSubObject.VTable,
        AcquireSync: *const fn (*IKeyedMutex, UINT64, DWORD) callconv(.winapi) HRESULT,
        ReleaseSync: *const fn (*IKeyedMutex, UINT64) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice_sub_object: IDeviceSubObject,

    pub inline fn AcquireSync(self: *IKeyedMutex, key: UINT64, milliseconds: DWORD) HRESULT {
        return self.vtable.AcquireSync(self, key, milliseconds);
    }
    pub inline fn ReleaseSync(self: *IKeyedMutex, key: UINT64) HRESULT {
        return self.vtable.ReleaseSync(self, key);
    }
};

pub const MAP_FLAG = packed struct(UINT) {
    READ: bool = false,
    WRITE: bool = false,
    DISCARD: bool = false,
    __unused: u29 = 0,
};

pub const ISurface = extern union {
    pub const IID: GUID = .{
        .Data1 = 0xcafcb56c,
        .Data2 = 0x6ac3,
        .Data3 = 0x4889,
        .Data4 = .{ 0xbf, 0x47, 0x9e, 0x23, 0xbb, 0xd2, 0x60, 0xec },
    };
    pub const VTable = extern struct {
        base: IDeviceSubObject.VTable,
        GetDesc: *const fn (*ISurface, *SURFACE_DESC) callconv(.winapi) HRESULT,
        Map: *const fn (*ISurface, *MAPPED_RECT, MAP_FLAG) callconv(.winapi) HRESULT,
        Unmap: *const fn (*ISurface) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice_sub_object: IDeviceSubObject,

    pub inline fn GetDesc(self: *ISurface, desc: *SURFACE_DESC) HRESULT {
        return self.vtable.GetDesc(self, desc);
    }
    pub inline fn Map(self: *ISurface, locked_rect: *MAPPED_RECT, flags: MAP_FLAG) HRESULT {
        return self.vtable.Map(self, locked_rect, flags);
    }
    pub inline fn Unmap(self: *ISurface) HRESULT {
        return self.vtable.Unmap(self);
    }
};

pub const IAdapter = extern union {
    pub const VTable = extern struct {
        base: IObject.VTable,
        EnumOutputs: *const fn (*IAdapter, UINT, *?*IOutput) callconv(.winapi) HRESULT,
        GetDesc: *const fn (*IAdapter, *ADAPTER_DESC) callconv(.winapi) HRESULT,
        CheckInterfaceSupport: *const fn (*IAdapter, *const GUID, *LARGE_INTEGER) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,

    pub inline fn EnumOutputs(self: *IAdapter, index: UINT, output: *?*IOutput) HRESULT {
        return self.vtable.EnumOutputs(self, index, output);
    }
    pub inline fn GetDesc(self: *IAdapter, desc: *ADAPTER_DESC) HRESULT {
        return self.vtable.GetDesc(self, desc);
    }
    pub inline fn CheckInterfaceSupport(self: *IAdapter, guid: *const GUID, umd_ver: *LARGE_INTEGER) HRESULT {
        return self.vtable.CheckInterfaceSupport(self, guid, umd_ver);
    }
};

pub const ENUM_MODES = packed struct(UINT) {
    INTERLACED: bool = false,
    SCALING: bool = false,
    STEREO: bool = false,
    DISABLED_STEREO: bool = false,
    __unused: u28 = 0,
};

pub const IOutput = extern union {
    pub const VTable = extern struct {
        base: IObject.VTable,
        GetDesc: *const fn (self: *IOutput, desc: *OUTPUT_DESC) callconv(.winapi) HRESULT,
        GetDisplayModeList: *const fn (*IOutput, FORMAT, ENUM_MODES, *UINT, ?*MODE_DESC) callconv(.winapi) HRESULT,
        FindClosestMatchingMode: *const fn (
            *IOutput,
            *const MODE_DESC,
            *MODE_DESC,
            ?*IUnknown,
        ) callconv(.winapi) HRESULT,
        WaitForVBlank: *const fn (*IOutput) callconv(.winapi) HRESULT,
        TakeOwnership: *const fn (*IOutput, *IUnknown, BOOL) callconv(.winapi) HRESULT,
        ReleaseOwnership: *const fn (*IOutput) callconv(.winapi) void,
        GetGammaControlCapabilities: *const fn (*IOutput, *GAMMA_CONTROL_CAPABILITIES) callconv(.winapi) HRESULT,
        SetGammaControl: *const fn (*IOutput, *const GAMMA_CONTROL) callconv(.winapi) HRESULT,
        GetGammaControl: *const fn (*IOutput, *GAMMA_CONTROL) callconv(.winapi) HRESULT,
        SetDisplaySurface: *const fn (*IOutput, *ISurface) callconv(.winapi) HRESULT,
        GetDisplaySurfaceData: *const fn (*IOutput, *ISurface) callconv(.winapi) HRESULT,
        GetFrameStatistics: *const fn (*IOutput, *FRAME_STATISTICS) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,

    pub inline fn GetDesc(self: *IOutput, desc: *OUTPUT_DESC) HRESULT {
        return self.vtable.GetDesc(self, desc);
    }

    pub inline fn GetDisplayModeList(self: *IOutput, enum_format: FORMAT, flags: ENUM_MODES, num_nodes: *UINT, desc: ?*MODE_DESC) HRESULT {
        return self.vtable.GetDisplayModeList(self, enum_format, flags, num_nodes, desc);
    }

    pub inline fn FindClosestMatchingMode(self: *IOutput, mode_to_match: *const MODE_DESC, closest_match: *MODE_DESC, concerned_device: ?*IUnknown) HRESULT {
        return self.vtable.FindClosestMatchingMode(self, mode_to_match, closest_match, concerned_device);
    }

    pub inline fn WaitForVBlank(self: *IOutput) HRESULT {
        return self.vtable.WaitForVBlank(self);
    }

    pub inline fn TakeOwnership(self: *IOutput, device: *IUnknown, exclusive: BOOL) HRESULT {
        return self.vtable.TakeOwnership(self, device, exclusive);
    }

    pub inline fn ReleaseOwnership(self: *IOutput) void {
        self.vtable.ReleaseOwnership(self);
    }

    pub inline fn GetGammaControlCapabilities(self: *IOutput, gamma_caps: *GAMMA_CONTROL_CAPABILITIES) HRESULT {
        return self.vtable.GetGammaControlCapabilities(self, gamma_caps);
    }

    pub inline fn SetGammaControl(self: *IOutput, array: *const GAMMA_CONTROL) HRESULT {
        return self.vtable.SetGammaControl(self, array);
    }

    pub inline fn GetGammaControl(self: *IOutput, array: *GAMMA_CONTROL) HRESULT {
        return self.vtable.GetGammaControl(self, array);
    }

    pub inline fn SetDisplaySurface(self: *IOutput, scanout_surface: *ISurface) HRESULT {
        return self.vtable.SetDisplaySurface(self, scanout_surface);
    }

    pub inline fn GetDisplaySurfaceData(self: *IOutput, scanout_surface: *ISurface) HRESULT {
        return self.vtable.GetDisplaySurfaceData(self, scanout_surface);
    }

    pub inline fn GetFrameStatistics(self: *IOutput, frame_stats: *FRAME_STATISTICS) HRESULT {
        return self.vtable.GetFrameStatistics(self, frame_stats);
    }
};

pub const MAX_SWAP_CHAIN_BUFFERS = 16;

pub const PRESENT_FLAG = packed struct(UINT) {
    TEST: bool = false,
    DO_NOT_SEQUENCE: bool = false,
    RESTART: bool = false,
    DO_NOT_WAIT: bool = false,
    STEREO_PREFER_RIGHT: bool = false,
    STEREO_TEMPORARY_MONO: bool = false,
    RESTRICT_TO_OUTPUT: bool = false,
    __unused7: bool = false,
    USE_DURATION: bool = false,
    ALLOW_TEARING: bool = false,
    __unused: u22 = 0,
};

pub const SWAP_CHAIN_COLOR_SPACE_SUPPORT_FLAG_PRESENT = 0x1;

pub const ISwapChain = extern union {
    pub const VTable = extern struct {
        base: IDeviceSubObject.VTable,
        Present: *const fn (*ISwapChain, UINT, PRESENT_FLAG) callconv(.winapi) HRESULT,
        GetBuffer: *const fn (*ISwapChain, u32, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
        SetFullscreenState: *const fn (*ISwapChain, ?*IOutput) callconv(.winapi) HRESULT,
        GetFullscreenState: *const fn (*ISwapChain, ?*BOOL, ?*?*IOutput) callconv(.winapi) HRESULT,
        GetDesc: *const fn (*ISwapChain, *SWAP_CHAIN_DESC) callconv(.winapi) HRESULT,
        ResizeBuffers: *const fn (*ISwapChain, UINT, UINT, UINT, FORMAT, SWAP_CHAIN_FLAG) callconv(.winapi) HRESULT,
        ResizeTarget: *const fn (*ISwapChain, *const MODE_DESC) callconv(.winapi) HRESULT,
        GetContainingOutput: *const fn (*ISwapChain, *?*IOutput) callconv(.winapi) HRESULT,
        GetFrameStatistics: *const fn (*ISwapChain, *FRAME_STATISTICS) callconv(.winapi) HRESULT,
        GetLastPresentCount: *const fn (*ISwapChain, *UINT) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice_sub_object: IDeviceSubObject,

    pub inline fn Present(self: *ISwapChain, sync_interval: UINT, flags: PRESENT_FLAG) HRESULT {
        return self.vtable.Present(self, sync_interval, flags);
    }

    pub inline fn GetBuffer(self: *ISwapChain, index: u32, guid: *const GUID, surface: *?*anyopaque) HRESULT {
        return self.vtable.GetBuffer(self, index, guid, surface);
    }

    pub inline fn SetFullscreenState(self: *ISwapChain, target: ?*IOutput) HRESULT {
        return self.vtable.SetFullscreenState(self, target);
    }

    pub inline fn GetFullscreenState(self: *ISwapChain, fullscreen: ?*BOOL, target: ?*?*IOutput) HRESULT {
        return self.vtable.GetFullscreenState(self, fullscreen, target);
    }

    pub inline fn GetDesc(self: *ISwapChain, desc: *SWAP_CHAIN_DESC) HRESULT {
        return self.vtable.GetDesc(self, desc);
    }

    pub inline fn ResizeBuffers(
        self: *ISwapChain,
        count: UINT,
        width: UINT,
        height: UINT,
        format: FORMAT,
        flags: SWAP_CHAIN_FLAG,
    ) HRESULT {
        return self.vtable.ResizeBuffers(self, count, width, height, format, flags);
    }

    pub inline fn ResizeTarget(self: *ISwapChain, params: *const MODE_DESC) HRESULT {
        return self.vtable.ResizeTarget(self, params);
    }

    pub inline fn GetContainingOutput(self: *ISwapChain, output: *?*IOutput) HRESULT {
        return self.vtable.GetContainingOutput(self, output);
    }

    pub inline fn GetFrameStatistics(self: *ISwapChain, stats: *FRAME_STATISTICS) HRESULT {
        return self.vtable.GetFrameStatistics(self, stats);
    }

    pub inline fn GetLastPresentCount(self: *ISwapChain, count: *UINT) HRESULT {
        return self.vtable.GetLastPresentCount(self, count);
    }
};

pub const MWA_FLAGS = packed struct(UINT) {
    NO_WINDOW_CHANGES: bool = false,
    NO_ALT_ENTER: bool = false,
    NO_PRINT_SCREEN: bool = false,
    __unused: u29 = 0,
};

pub const IFactory = extern union {
    pub const VTable = extern struct {
        base: IObject.VTable,
        EnumAdapters: *const fn (*IFactory, UINT, *?*IAdapter) callconv(.winapi) HRESULT,
        MakeWindowAssociation: *const fn (*IFactory, HWND, MWA_FLAGS) callconv(.winapi) HRESULT,
        GetWindowAssociation: *const fn (*IFactory, *HWND) callconv(.winapi) HRESULT,
        CreateSwapChain: *const fn (*IFactory, *IUnknown, *SWAP_CHAIN_DESC, *?*ISwapChain) callconv(.winapi) HRESULT,
        CreateSoftwareAdapter: *const fn (*IFactory, *?*IAdapter) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,

    pub inline fn EnumAdapters(self: *IFactory, index: UINT, adapter: *?*IAdapter) HRESULT {
        return self.vtable.EnumAdapters(self, index, adapter);
    }

    pub inline fn MakeWindowAssociation(self: *IFactory, hwnd: HWND, flags: MWA_FLAGS) HRESULT {
        return self.vtable.MakeWindowAssociation(self, hwnd, flags);
    }

    pub inline fn GetWindowAssociation(self: *IFactory, hwnd: *HWND) HRESULT {
        return self.vtable.GetWindowAssociation(self, hwnd);
    }

    pub inline fn CreateSwapChain(self: *IFactory, device: *IUnknown, desc: *SWAP_CHAIN_DESC, swap_chain: *?*ISwapChain) HRESULT {
        return self.vtable.CreateSwapChain(self, device, desc, swap_chain);
    }

    pub inline fn CreateSoftwareAdapter(self: *IFactory, adapter: *?*IAdapter) HRESULT {
        return self.vtable.CreateSoftwareAdapter(self, adapter);
    }
};

pub const IDevice = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x54ec77fa,
        .Data2 = 0x1377,
        .Data3 = 0x44e6,
        .Data4 = .{ 0x8c, 0x32, 0x88, 0xfd, 0x5f, 0x44, 0xc8, 0x4c },
    };
    pub const VTable = extern struct {
        base: IObject.VTable,
        GetAdapter: *const fn (self: *IDevice, adapter: *?*IAdapter) callconv(.winapi) HRESULT,
        CreateSurface: *const fn (
            *IDevice,
            *const SURFACE_DESC,
            UINT,
            USAGE,
            ?*const SHARED_RESOURCE,
            *?*ISurface,
        ) callconv(.winapi) HRESULT,
        QueryResourceResidency: *const fn (
            *IDevice,
            *const *IUnknown,
            [*]RESIDENCY,
            UINT,
        ) callconv(.winapi) HRESULT,
        SetGPUThreadPriority: *const fn (self: *IDevice, priority: INT) callconv(.winapi) HRESULT,
        GetGPUThreadPriority: *const fn (self: *IDevice, priority: *INT) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,

    pub inline fn GetAdapter(self: *IDevice, adapter: *?*IAdapter) HRESULT {
        return self.vtable.GetAdapter(self, adapter);
    }

    pub inline fn CreateSurface(self: *IDevice, desc: *const SURFACE_DESC, numSurfaces: UINT, usage: USAGE, sharedResource: *?*const SHARED_RESOURCE, surface: *?*ISurface) HRESULT {
        return self.vtable.CreateSurface(self, desc, numSurfaces, usage, sharedResource, surface);
    }

    pub inline fn QueryResourceResidency(self: *IDevice, resources: *const *IUnknown, residency: [*]RESIDENCY, numResources: UINT) HRESULT {
        return self.vtable.QueryResourceResidency(self, resources, residency, numResources);
    }

    pub inline fn SetGPUThreadPriority(self: *IDevice, priority: INT) HRESULT {
        return self.vtable.SetGPUThreadPriority(self, priority);
    }

    pub inline fn GetGPUThreadPriority(self: *IDevice, priority: *INT) HRESULT {
        return self.vtable.GetGPUThreadPriority(self, priority);
    }
};

pub const ADAPTER_FLAGS = packed struct(UINT) {
    REMOTE: bool = false,
    SOFTWARE: bool = false,
    __unused: u30 = 0,
};

pub const ADAPTER_DESC1 = extern struct {
    Description: [128]WCHAR,
    VendorId: UINT,
    DeviceId: UINT,
    SubSysId: UINT,
    Revision: UINT,
    DedicatedVideoMemory: SIZE_T,
    DedicatedSystemMemory: SIZE_T,
    SharedSystemMemory: SIZE_T,
    AdapterLuid: LUID,
    Flags: ADAPTER_FLAGS,

    pub const zero: ADAPTER_DESC1 = ADAPTER_DESC1{
        .Description = @splat(0),
        .VendorId = 0,
        .DeviceId = 0,
        .SubSysId = 0,
        .Revision = 0,
        .DedicatedVideoMemory = 0,
        .DedicatedSystemMemory = 0,
        .SharedSystemMemory = 0,
        .AdapterLuid = .zero,
        .Flags = .{},
    };
};

pub const GRAPHICS_PREEMPTION_GRANULARITY = enum(UINT) {
    DMA_BUFFER_BOUNDARY = 0,
    PRIMITIVE_BOUNDARY = 1,
    TRIANGLE_BOUNDARY = 2,
    PIXEL_BOUNDARY = 3,
    INSTRUCTION_BOUNDARY = 4,
};

pub const COMPUTE_PREEMPTION_GRANULARITY = enum(UINT) {
    DMA_BUFFER_BOUNDARY = 0,
    PRIMITIVE_BOUNDARY = 1,
    TRIANGLE_BOUNDARY = 2,
    PIXEL_BOUNDARY = 3,
    INSTRUCTION_BOUNDARY = 4,
};

pub const ADAPTER_DESC2 = extern struct {
    Description: [128]WCHAR,
    VendorId: UINT,
    DeviceId: UINT,
    SubSysId: UINT,
    Revision: UINT,
    DedicatedVideoMemory: SIZE_T,
    DedicatedSystemMemory: SIZE_T,
    SharedSystemMemory: SIZE_T,
    AdapterLuid: LUID,
    Flags: ADAPTER_FLAGS,
    GraphicsPreemptionGranularity: GRAPHICS_PREEMPTION_GRANULARITY,
    ComputePreemptionGranularity: COMPUTE_PREEMPTION_GRANULARITY,

    pub const zero: ADAPTER_DESC2 = .{
        .Description = @splat(0),
        .VendorId = 0,
        .DeviceId = 0,
        .SubSysId = 0,
        .Revision = 0,
        .DedicatedVideoMemory = 0,
        .DedicatedSystemMemory = 0,
        .SharedSystemMemory = 0,
        .AdapterLuid = .zero,
        .Flags = .{},
        .GraphicsPreemptionGranularity = .DMA_BUFFER_BOUNDARY,
        .ComputePreemptionGranularity = .DMA_BUFFER_BOUNDARY,
    };
};

pub const IFactory1 = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x770aae78,
        .Data2 = 0xf26f,
        .Data3 = 0x4dba,
        .Data4 = .{ 0xa8, 0x29, 0x25, 0x3c, 0x83, 0xd1, 0xb3, 0x87 },
    };
    pub const VTable = extern struct {
        base: IFactory.VTable,
        EnumAdapters1: *const fn (*IFactory1, UINT, *?*IAdapter1) callconv(.winapi) HRESULT,
        IsCurrent: *const fn (*IFactory1) callconv(.winapi) BOOL,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    ifactory: IFactory,

    pub inline fn EnumAdapters1(self: *IFactory1, index: UINT, adapter: *?*IAdapter1) HRESULT {
        return self.vtable.EnumAdapters1(self, index, adapter);
    }

    pub inline fn IsCurrent(self: *const IFactory1) BOOL {
        return self.vtable.IsCurrent(self);
    }
};

pub const IFactory2 = extern union {
    pub const VTable = extern struct {
        base: IFactory1.VTable,
        IsWindowedStereoEnabled: *anyopaque,
        CreateSwapChainForHwnd: *const fn (
            this: *IFactory2,
            queue: *win32.IUnknown,
            hwnd: win32.HWND,
            desc: *const SWAP_CHAIN_DESC1,
            fullscreen_desc: ?*SWAP_CHAIN_FULLSCREEN_DESC,
            output: ?*IOutput,
            swapchain: *?*ISwapChain1,
        ) callconv(.c) win32.HRESULT,
        CreateSwapChainForCoreWindow: *anyopaque,
        GetSharedResourceAdapterLuid: *anyopaque,
        RegisterStereoStatusWindow: *anyopaque,
        RegisterStereoStatusEvent: *anyopaque,
        UnregisterStereoStatus: *anyopaque,
        RegisterOcclusionStatusWindow: *anyopaque,
        RegisterOcclusionStatusEvent: *anyopaque,
        UnregisterOcclusionStatus: *anyopaque,
        CreateSwapChainForComposition: *anyopaque,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    ifactory: IFactory,
    ifactory1: IFactory1,

    pub inline fn CreateSwapChainForHwnd(
        self: *IFactory2,
        queue: *win32.IUnknown,
        hwnd: win32.HWND,
        desc: *const SWAP_CHAIN_DESC1,
        fullscreen_desc: ?*SWAP_CHAIN_FULLSCREEN_DESC,
        output: ?*IOutput,
        swapchain: *?*ISwapChain1,
    ) win32.HRESULT {
        return self.vtable.CreateSwapChainForHwnd(
            self,
            queue,
            hwnd,
            desc,
            fullscreen_desc,
            output,
            swapchain,
        );
    }
};

pub const IFactory3 = extern union {
    pub const VTable = extern struct {
        base: IFactory2.VTable,
        GetCreationFlags: *anyopaque,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    ifactory: IFactory,
    ifactory1: IFactory1,
    ifactory2: IFactory2,
};

pub const IFactory4 = extern union {
    pub const VTable = extern struct {
        base: IFactory3.VTable,
        EnumAdapterByLuid: *anyopaque,
        EnumWarpAdapter: *anyopaque,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    ifactory: IFactory,
    ifactory1: IFactory1,
    ifactory2: IFactory2,
    ifactory3: IFactory3,
};

pub const FEATURE = enum(UINT) {
    PRESENT_ALLOW_TEARING = 0,
};

pub const IFactory5 = extern union {
    pub const IID: GUID = .parse("{7632e1f5-ee65-4dca-87fd-84cd75f8838d}");
    pub const VTable = extern struct {
        base: IFactory4.VTable,
        CheckFeatureSupport: *const fn (*IFactory5, FEATURE, *anyopaque, UINT) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    ifactory: IFactory,
    ifactory1: IFactory1,
    ifactory2: IFactory2,
    ifactory3: IFactory3,
    ifactory4: IFactory4,

    pub inline fn CheckFeatureSupport(
        self: *IFactory5,
        feature: FEATURE,
        feature_support_data: *anyopaque,
        feature_support_data_size: UINT,
    ) HRESULT {
        return self.vtable.CheckFeatureSupport(
            self,
            feature,
            feature_support_data,
            feature_support_data_size,
        );
    }
};

pub const GPU_PREFERENCE = enum(UINT) {
    UNSPECIFIED,
    MINIMUM,
    HIGH_PERFORMANCE,
};

pub const IFactory6 = extern union {
    pub const IID: GUID = .parse("{c1b6694f-ff09-44a9-b03c-77900a0a1d17}");
    pub const VTable = extern struct {
        base: IFactory5.VTable,
        EnumAdapterByGpuPreference: *const fn (
            *IFactory6,
            UINT,
            GPU_PREFERENCE,
            *const GUID,
            *?*anyopaque,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    ifactory: IFactory,
    ifactory1: IFactory1,
    ifactory2: IFactory2,
    ifactory3: IFactory3,
    ifactory4: IFactory4,
    ifactory5: IFactory5,

    pub inline fn EnumAdapterByGpuPreference(
        self: *IFactory6,
        adapter_index: UINT,
        gpu_preference: GPU_PREFERENCE,
        riid: *const GUID,
        adapter: *?*anyopaque,
    ) HRESULT {
        return self.vtable.EnumAdapterByGpuPreference(
            self,
            adapter_index,
            gpu_preference,
            riid,
            adapter,
        );
    }
};

pub const IAdapter1 = extern union {
    pub const IID: GUID = .parse("{29038f61-3839-4626-91fd-086879011a05}");
    pub const VTable = extern struct {
        base: IAdapter.VTable,
        GetDesc1: *const fn (*IAdapter1, *ADAPTER_DESC1) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    iadapter: IAdapter,

    pub inline fn GetDesc1(self: *IAdapter1, desc: *ADAPTER_DESC1) HRESULT {
        return self.vtable.GetDesc1(self, desc);
    }
};

pub const IAdapter2 = extern union {
    pub const IID: GUID = .parse("{0AA1AE0A-FA0E-4B84-8644-E05FF8E5ACB5}");
    pub const VTable = extern struct {
        base: IAdapter1.VTable,
        GetDesc2: *const fn (*IAdapter2, *ADAPTER_DESC2) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    iadapter: IAdapter,
    iadapter1: IAdapter1,

    pub inline fn GetDesc2(self: *IAdapter2, desc: *ADAPTER_DESC2) HRESULT {
        return self.vtable.GetDesc2(self, desc);
    }
};

pub const MEMORY_SEGMENT_GROUP = enum(UINT) {
    LOCAL = 0,
    NON_LOCAL = 1,
};

pub const QUERY_VIDEO_MEMORY_INFO = extern struct {
    Budget: UINT64,
    CurrentUsage: UINT64,
    AvailableForReservation: UINT64,
    CurrentReservation: UINT64,
};

pub const IAdapter3 = extern union {
    pub const IID: GUID = .parse("{645967A4-1392-4310-A798-8053CE3E93FD}");
    pub const VTable = extern struct {
        base: IAdapter2.VTable,
        RegisterHardwareContentProtectionTeardownStatusEvent: *const fn (*IAdapter3, HANDLE, *DWORD) callconv(.winapi) HRESULT,
        UnregisterHardwareContentProtectionTeardownStatus: *const fn (*IAdapter3, DWORD) callconv(.winapi) void,
        QueryVideoMemoryInfo: *const fn (*IAdapter3, UINT, MEMORY_SEGMENT_GROUP, *QUERY_VIDEO_MEMORY_INFO) callconv(.winapi) HRESULT,
        SetVideoMemoryReservation: *const fn (*IAdapter3, UINT, MEMORY_SEGMENT_GROUP, UINT64) callconv(.winapi) HRESULT,
        RegisterVideoMemoryBudgetChangeNotificationEvent: *const fn (*IAdapter3, HANDLE, *DWORD) callconv(.winapi) HRESULT,
        UnregisterVideoMemoryBudgetChangeNotification: *const fn (*IAdapter3, DWORD) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    iadapter: IAdapter,
    iadapter1: IAdapter1,
    iadapter2: IAdapter2,

    pub inline fn RegisterHardwareContentProtectionTeardownStatusEvent(self: *IAdapter3, hEvent: HANDLE, pdwCookie: *DWORD) HRESULT {
        return self.vtable.RegisterHardwareContentProtectionTeardownStatusEvent(self, hEvent, pdwCookie);
    }
    pub inline fn UnregisterHardwareContentProtectionTeardownStatus(self: *IAdapter3, dwCookie: DWORD) void {
        self.vtable.UnregisterHardwareContentProtectionTeardownStatus(self, dwCookie);
    }
    pub inline fn QueryVideoMemoryInfo(self: *IAdapter3, nodeIndex: UINT, memorySegmentGroup: MEMORY_SEGMENT_GROUP, videoMemoryInfo: *QUERY_VIDEO_MEMORY_INFO) HRESULT {
        return self.vtable.QueryVideoMemoryInfo(self, nodeIndex, memorySegmentGroup, videoMemoryInfo);
    }
    pub inline fn SetVideoMemoryReservation(self: *IAdapter3, nodeIndex: UINT, memorySegmentGroup: MEMORY_SEGMENT_GROUP, reservation: UINT64) HRESULT {
        return self.vtable.SetVideoMemoryReservation(self, nodeIndex, memorySegmentGroup, reservation);
    }
    pub inline fn RegisterVideoMemoryBudgetChangeNotificationEvent(self: *IAdapter3, hEvent: HANDLE, pdwCookie: *DWORD) HRESULT {
        return self.vtable.RegisterVideoMemoryBudgetChangeNotificationEvent(self, hEvent, pdwCookie);
    }
    pub inline fn UnregisterVideoMemoryBudgetChangeNotification(self: *IAdapter3, dwCookie: DWORD) void {
        self.vtable.UnregisterVideoMemoryBudgetChangeNotification(self, dwCookie);
    }
};

pub const IDevice1 = extern union {
    pub const VTable = extern struct {
        base: IDevice.VTable,
        SetMaximumFrameLatency: *const fn (self: *IDevice1, max_latency: UINT) callconv(.winapi) HRESULT,
        GetMaximumFrameLatency: *const fn (self: *IDevice1, max_latency: *UINT) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice: IDevice,

    pub inline fn SetMaximumFrameLatency(self: *IDevice1, max_latency: UINT) HRESULT {
        return self.vtable.SetMaximumFrameLatency(self, max_latency);
    }
    pub inline fn GetMaximumFrameLatency(self: *IDevice1, max_latency: *UINT) HRESULT {
        return self.vtable.GetMaximumFrameLatency(self, max_latency);
    }
};

pub const CREATE_FACTORY_DEBUG = 0x1;
pub extern "dxgi" fn CreateDXGIFactory2(UINT, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT;
extern "dxgi" fn DXGIGetDebugInterface1(UINT, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT;
pub const GetDebugInterface1 = DXGIGetDebugInterface1;

pub const SCALING = enum(UINT) {
    STRETCH = 0,
    NONE = 1,
    ASPECT_RATIO_STRETCH = 2,
};

pub const ALPHA_MODE = enum(UINT) {
    UNSPECIFIED = 0,
    PREMULTIPLIED = 1,
    STRAIGHT = 2,
    IGNORE = 3,
};

pub const SWAP_CHAIN_DESC1 = extern struct {
    Width: UINT,
    Height: UINT,
    Format: FORMAT,
    Stereo: BOOL,
    SampleDesc: SAMPLE_DESC,
    BufferUsage: USAGE,
    BufferCount: UINT,
    Scaling: SCALING,
    SwapEffect: SWAP_EFFECT,
    AlphaMode: ALPHA_MODE,
    Flags: SWAP_CHAIN_FLAG,

    pub const zero: SWAP_CHAIN_DESC1 = .{
        .Width = 0,
        .Height = 0,
        .Format = .UNKNOWN,
        .Stereo = .FALSE,
        .SampleDesc = .default,
        .BufferUsage = .{},
        .BufferCount = 0,
        .Scaling = .STRETCH,
        .SwapEffect = .DISCARD,
        .AlphaMode = .UNSPECIFIED,
        .Flags = .{},
    };
};

pub const SWAP_CHAIN_FULLSCREEN_DESC = extern struct {
    RefreshRate: RATIONAL,
    ScanlineOrdering: MODE_SCANLINE_ORDER,
    Scaling: MODE_SCALING,
    Windowed: BOOL,

    pub const zero: SWAP_CHAIN_FULLSCREEN_DESC = .{
        .RefreshRate = .fraction(0, 1),
        .ScanlineOrdering = .UNSPECIFIED,
        .Scaling = .STRETCH,
        .Windowed = .FALSE,
    };
};

pub const PRESENT_PARAMETERS = extern struct {
    DirtyRectsCount: UINT,
    pDirtyRects: ?[*]RECT,
    pScrollRect: *RECT,
    pScrollOffset: *POINT,
};

pub const ISwapChain1 = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x790a45f7,
        .Data2 = 0x0d41,
        .Data3 = 0x4876,
        .Data4 = .{ 0x98, 0x3a, 0x0a, 0x55, 0xcf, 0xe6, 0xf4, 0xaa },
    };
    pub const VTable = extern struct {
        base: ISwapChain.VTable,
        GetDesc1: *const fn (*ISwapChain1, *SWAP_CHAIN_DESC1) callconv(.winapi) HRESULT,
        GetFullscreenDesc: *const fn (*ISwapChain1, *SWAP_CHAIN_FULLSCREEN_DESC) callconv(.winapi) HRESULT,
        GetHwnd: *const fn (*ISwapChain1, *HWND) callconv(.winapi) HRESULT,
        GetCoreWindow: *const fn (*ISwapChain1, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
        Present1: *const fn (*ISwapChain1, UINT, PRESENT_FLAG, *const PRESENT_PARAMETERS) callconv(.winapi) HRESULT,
        IsTemporaryMonoSupported: *const fn (*ISwapChain1) callconv(.winapi) BOOL,
        GetRestrictToOutput: *const fn (*ISwapChain1, *?*IOutput) callconv(.winapi) HRESULT,
        SetBackgroundColor: *const fn (*ISwapChain1, *const RGBA) callconv(.winapi) HRESULT,
        GetBackgroundColor: *const fn (*ISwapChain1, *RGBA) callconv(.winapi) HRESULT,
        SetRotation: *const fn (*ISwapChain1, MODE_ROTATION) callconv(.winapi) HRESULT,
        GetRotation: *const fn (*ISwapChain1, *MODE_ROTATION) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice_sub_object: IDeviceSubObject,
    iswap_chain: ISwapChain,

    pub inline fn GetDesc1(self: *ISwapChain1, desc: *SWAP_CHAIN_DESC1) HRESULT {
        return self.vtable.GetDesc1(self, desc);
    }
    pub inline fn GetFullscreenDesc(self: *ISwapChain1, desc: *SWAP_CHAIN_FULLSCREEN_DESC) HRESULT {
        return self.vtable.GetFullscreenDesc(self, desc);
    }
    pub inline fn GetHwnd(self: *ISwapChain1, hwnd: *HWND) HRESULT {
        return self.vtable.GetHwnd(self, hwnd);
    }
    pub inline fn GetCoreWindow(self: *ISwapChain1, refiid: *const GUID, ppUnk: *?*anyopaque) HRESULT {
        return self.vtable.GetCoreWindow(self, refiid, ppUnk);
    }
    pub inline fn Present1(self: *ISwapChain1, sync_interval: UINT, present_flags: PRESENT_FLAG, p_present_parameters: *const PRESENT_PARAMETERS) HRESULT {
        return self.vtable.Present1(self, sync_interval, present_flags, p_present_parameters);
    }
    pub inline fn IsTemporaryMonoSupported(self: *ISwapChain1) BOOL {
        return self.vtable.IsTemporaryMonoSupported(self);
    }
    pub inline fn GetRestrictToOutput(self: *ISwapChain1, pOutput: *?*IOutput) HRESULT {
        return self.vtable.GetRestrictToOutput(self, pOutput);
    }
    pub inline fn SetBackgroundColor(self: *ISwapChain1, pColor: *const RGBA) HRESULT {
        return self.vtable.SetBackgroundColor(self, pColor);
    }
    pub inline fn GetBackgroundColor(self: *ISwapChain1, pColor: *const RGBA) HRESULT {
        return self.vtable.GetBackgroundColor(self, pColor);
    }
    pub inline fn SetRotation(self: *ISwapChain1, rotation: MODE_ROTATION) HRESULT {
        return self.vtable.SetRotation(self, rotation);
    }
    pub inline fn GetRotation(self: *ISwapChain1, rotation: *MODE_ROTATION) HRESULT {
        return self.vtable.GetRotation(self, rotation);
    }
};

pub const MATRIX_3X2_F = extern struct {
    _11: FLOAT,
    _12: FLOAT,
    _21: FLOAT,
    _22: FLOAT,
    _31: FLOAT,
    _32: FLOAT,

    pub const zero: MATRIX_3X2_F = .{
        ._11 = 0.0,
        ._12 = 0.0,
        ._21 = 0.0,
        ._22 = 0.0,
        ._31 = 0.0,
        ._32 = 0.0,
    };
};

pub const ISwapChain2 = extern union {
    pub const IID: GUID = .{
        .Data1 = 0xa8be2ac4,
        .Data2 = 0x199f,
        .Data3 = 0x4946,
        .Data4 = .{ 0xb3, 0x31, 0x79, 0x59, 0x9f, 0xb9, 0x8d, 0xe7 },
    };
    pub const VTable = extern struct {
        base: ISwapChain1.VTable,
        SetSourceSize: *const fn (*ISwapChain2, UINT, UINT) callconv(.winapi) HRESULT,
        GetSourceSize: *const fn (*ISwapChain2, *UINT, *UINT) callconv(.winapi) HRESULT,
        SetMaximumFrameLatency: *const fn (*ISwapChain2, UINT) callconv(.winapi) HRESULT,
        GetMaximumFrameLatency: *const fn (*ISwapChain2, *UINT) callconv(.winapi) HRESULT,
        GetFrameLatencyWaitableObject: *const fn (*ISwapChain2) callconv(.winapi) HANDLE,
        SetMatrixTransform: *const fn (*ISwapChain2, *const MATRIX_3X2_F) callconv(.winapi) HRESULT,
        GetMatrixTransform: *const fn (*ISwapChain2, *MATRIX_3X2_F) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice_sub_object: IDeviceSubObject,
    iswap_chain: ISwapChain,
    iswap_chain1: ISwapChain1,

    pub inline fn SetSourceSize(self: *ISwapChain2, width: UINT, height: UINT) HRESULT {
        return self.vtable.SetSourceSize(self, width, height);
    }
    pub inline fn GetSourceSize(self: *ISwapChain2, width: *UINT, height: *UINT) HRESULT {
        return self.vtable.GetSourceSize(self, width, height);
    }
    pub inline fn SetMaximumFrameLatency(self: *ISwapChain2, max_latency: UINT) HRESULT {
        return self.vtable.SetMaximumFrameLatency(self, max_latency);
    }
    pub inline fn GetMaximumFrameLatency(self: *ISwapChain2, max_latency: *UINT) HRESULT {
        return self.vtable.GetMaximumFrameLatency(self, max_latency);
    }
    pub inline fn GetFrameLatencyWaitableObject(self: *ISwapChain2) HANDLE {
        return self.vtable.GetFrameLatencyWaitableObject(self);
    }
    pub inline fn SetMatrixTransform(self: *ISwapChain2, pMatrix: *const MATRIX_3X2_F) HRESULT {
        return self.vtable.SetMatrixTransform(self, pMatrix);
    }
    pub inline fn GetMatrixTransform(self: *ISwapChain2, pMatrix: *MATRIX_3X2_F) HRESULT {
        return self.vtable.GetMatrixTransform(self, pMatrix);
    }
};

pub const ISwapChain3 = extern union {
    pub const IID: GUID = .{
        .Data1 = 0x94d99bdb,
        .Data2 = 0xf1f8,
        .Data3 = 0x4ab0,
        .Data4 = .{ 0xb2, 0x36, 0x7d, 0xa0, 0x17, 0x0e, 0xda, 0xb1 },
    };
    pub const VTable = extern struct {
        base: ISwapChain2.VTable,
        GetCurrentBackBufferIndex: *const fn (*ISwapChain3) callconv(.winapi) UINT,
        CheckColorSpaceSupport: *const fn (*ISwapChain3, COLOR_SPACE_TYPE, *UINT) callconv(.winapi) HRESULT,
        SetColorSpace1: *const fn (*ISwapChain3, COLOR_SPACE_TYPE) callconv(.winapi) HRESULT,
        ResizeBuffers1: *const fn (
            *ISwapChain3,
            UINT,
            UINT,
            UINT,
            FORMAT,
            UINT,
            [*]const UINT,
            [*]const *IUnknown,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iobject: IObject,
    idevice_sub_object: IDeviceSubObject,
    iswap_chain: ISwapChain,
    iswap_chain1: ISwapChain1,
    iswap_chain2: ISwapChain2,

    pub inline fn GetCurrentBackBufferIndex(self: *ISwapChain3) UINT {
        return self.vtable.GetCurrentBackBufferIndex(self);
    }
    pub inline fn CheckColorSpaceSupport(self: *ISwapChain3, color_space: COLOR_SPACE_TYPE, color_space_support: *UINT) HRESULT {
        return self.vtable.CheckColorSpaceSupport(self, color_space, color_space_support);
    }
    pub inline fn SetColorSpace1(self: *ISwapChain3, color_space: COLOR_SPACE_TYPE) HRESULT {
        return self.vtable.SetColorSpace1(self, color_space);
    }
    pub inline fn ResizeBuffers1(self: *ISwapChain3, buffer_count: UINT, width: UINT, height: UINT, new_format: FORMAT, swap_chain_flags: UINT, pCreationNodeMask: [*]const UINT, ppPresentQueue: [*]const *IUnknown) HRESULT {
        return self.vtable.ResizeBuffers1(self, buffer_count, width, height, new_format, swap_chain_flags, pCreationNodeMask, ppPresentQueue);
    }
};

// // Status return codes as defined here: https://docs.microsoft.com/en-us/windows/windows/direct3ddxgi/dxgi-status
pub const STATUS_OCCLUDED: HRESULT = @bitCast(@as(c_ulong, 0x087A0001));
pub const STATUS_MODE_CHANGED: HRESULT = @bitCast(@as(c_ulong, 0x087A0007));
pub const STATUS_MODE_CHANGE_IN_PROGRESS: HRESULT = @bitCast(@as(c_ulong, 0x087A0008));

// // Return codes as defined here: https://docs.microsoft.com/en-us/windows/windows/direct3ddxgi/dxgi-error
pub const ERROR_ACCESS_DENIED: HRESULT = @bitCast(@as(c_ulong, 0x887A002B));
pub const ERROR_ACCESS_LOST: HRESULT = @bitCast(@as(c_ulong, 0x887A0026));
pub const ERROR_ALREADY_EXISTS: HRESULT = @bitCast(@as(c_ulong, 0x887A0036));
pub const ERROR_CANNOT_PROTECT_CONTENT: HRESULT = @bitCast(@as(c_ulong, 0x887A002A));
pub const ERROR_DEVICE_HUNG: HRESULT = @bitCast(@as(c_ulong, 0x887A0006));
pub const ERROR_DEVICE_REMOVED: HRESULT = @bitCast(@as(c_ulong, 0x887A0005));
pub const ERROR_DEVICE_RESET: HRESULT = @bitCast(@as(c_ulong, 0x887A0007));
pub const ERROR_DRIVER_INTERNAL_ERROR: HRESULT = @bitCast(@as(c_ulong, 0x887A0020));
pub const ERROR_FRAME_STATISTICS_DISJOINT: HRESULT = @bitCast(@as(c_ulong, 0x887A000B));
pub const ERROR_GRAPHICS_VIDPN_SOURCE_IN_USE: HRESULT = @bitCast(@as(c_ulong, 0x887A000C));
pub const ERROR_INVALID_CALL: HRESULT = @bitCast(@as(c_ulong, 0x887A0001));
pub const ERROR_MORE_DATA: HRESULT = @bitCast(@as(c_ulong, 0x887A0003));
pub const ERROR_NAME_ALREADY_EXISTS: HRESULT = @bitCast(@as(c_ulong, 0x887A002C));
pub const ERROR_NONEXCLUSIVE: HRESULT = @bitCast(@as(c_ulong, 0x887A0021));
pub const ERROR_NOT_CURRENTLY_AVAILABLE: HRESULT = @bitCast(@as(c_ulong, 0x887A0022));
pub const ERROR_NOT_FOUND: HRESULT = @bitCast(@as(c_ulong, 0x887A0002));
pub const ERROR_REMOTE_CLIENT_DISCONNECTED: HRESULT = @bitCast(@as(c_ulong, 0x887A0023));
pub const ERROR_REMOTE_OUTOFMEMORY: HRESULT = @bitCast(@as(c_ulong, 0x887A0024));
pub const ERROR_RESTRICT_TO_OUTPUT_STALE: HRESULT = @bitCast(@as(c_ulong, 0x887A0029));
pub const ERROR_SDK_COMPONENT_MISSING: HRESULT = @bitCast(@as(c_ulong, 0x887A002D));
pub const ERROR_SESSION_DISCONNECTED: HRESULT = @bitCast(@as(c_ulong, 0x887A0028));
pub const ERROR_UNSUPPORTED: HRESULT = @bitCast(@as(c_ulong, 0x887A0004));
pub const ERROR_WAIT_TIMEOUT: HRESULT = @bitCast(@as(c_ulong, 0x887A0027));
pub const ERROR_WAS_STILL_DRAWING: HRESULT = @bitCast(@as(c_ulong, 0x887A000A));
