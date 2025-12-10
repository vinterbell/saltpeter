const win32 = @import("win32.zig");
const IUnknown = win32.IUnknown;
const UINT = win32.UINT;
const SIZE_T = win32.SIZE_T;
const LPCSTR = win32.LPCSTR;
const GUID = win32.GUID;

pub const PRIMITIVE_TOPOLOGY = enum(UINT) {
    UNDEFINED = 0,
    POINTLIST = 1,
    LINELIST = 2,
    LINESTRIP = 3,
    TRIANGLELIST = 4,
    TRIANGLESTRIP = 5,
    LINELIST_ADJ = 10,
    LINESTRIP_ADJ = 11,
    TRIANGLELIST_ADJ = 12,
    TRIANGLESTRIP_ADJ = 13,
    CONTROL_POINT_PATCHLIST = 33,
    @"2_CONTROL_POINT_PATCHLIST" = 34,
    @"3_CONTROL_POINT_PATCHLIST" = 35,
    @"4_CONTROL_POINT_PATCHLIST" = 36,
    @"5_CONTROL_POINT_PATCHLIST" = 37,
    @"6_CONTROL_POINT_PATCHLIST" = 38,
    @"7_CONTROL_POINT_PATCHLIST" = 39,
    @"8_CONTROL_POINT_PATCHLIST" = 40,
    @"9_CONTROL_POINT_PATCHLIST" = 41,
    @"10_CONTROL_POINT_PATCHLIST" = 42,
    @"11_CONTROL_POINT_PATCHLIST" = 43,
    @"12_CONTROL_POINT_PATCHLIST" = 44,
    @"13_CONTROL_POINT_PATCHLIST" = 45,
    @"14_CONTROL_POINT_PATCHLIST" = 46,
    @"15_CONTROL_POINT_PATCHLIST" = 47,
    @"16_CONTROL_POINT_PATCHLIST" = 48,
    @"17_CONTROL_POINT_PATCHLIST" = 49,
    @"18_CONTROL_POINT_PATCHLIST" = 50,
    @"19_CONTROL_POINT_PATCHLIST" = 51,
    @"20_CONTROL_POINT_PATCHLIST" = 52,
    @"21_CONTROL_POINT_PATCHLIST" = 53,
    @"22_CONTROL_POINT_PATCHLIST" = 54,
    @"23_CONTROL_POINT_PATCHLIST" = 55,
    @"24_CONTROL_POINT_PATCHLIST" = 56,
    @"25_CONTROL_POINT_PATCHLIST" = 57,
    @"26_CONTROL_POINT_PATCHLIST" = 58,
    @"27_CONTROL_POINT_PATCHLIST" = 59,
    @"28_CONTROL_POINT_PATCHLIST" = 60,
    @"29_CONTROL_POINT_PATCHLIST" = 61,
    @"30_CONTROL_POINT_PATCHLIST" = 62,
    @"31_CONTROL_POINT_PATCHLIST" = 63,
    @"32_CONTROL_POINT_PATCHLIST" = 64,
};

pub const FEATURE_LEVEL = enum(UINT) {
    @"1_0_CORE" = 0x1000,
    @"9_1" = 0x9100,
    @"9_2" = 0x9200,
    @"9_3" = 0x9300,
    @"10_0" = 0xa000,
    @"10_1" = 0xa100,
    @"11_0" = 0xb000,
    @"11_1" = 0xb100,
    @"12_0" = 0xc000,
    @"12_1" = 0xc100,
    @"12_2" = 0xc200,
};

pub const DRIVER_TYPE = enum(UINT) {
    UNKNOWN = 0,
    HARDWARE = 1,
    REFERENCE = 2,
    NULL = 3,
    SOFTWARE = 4,
    WARP = 5,
};

pub const SHADER_MACRO = extern struct {
    Name: LPCSTR,
    Definition: LPCSTR,

    pub const zero: SHADER_MACRO = .{
        .Name = null,
        .Definition = null,
    };
};

pub const INCLUDE_TYPE = enum(UINT) {
    INCLUDE_LOCAL = 0,
    INCLUDE_SYSTEM = 1,
};

pub const IBlob = extern union {
    pub const IID: GUID = .parse("{8BA5FB08-5195-40e2-AC58-0D989C3A0102}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetBufferPointer: *const fn (*IBlob) callconv(.winapi) *anyopaque,
        GetBufferSize: *const fn (*IBlob) callconv(.winapi) SIZE_T,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetBufferPointer(self: *IBlob) *anyopaque {
        return self.vtable.GetBufferPointer(self);
    }

    pub inline fn GetBufferSize(self: *IBlob) SIZE_T {
        return self.vtable.GetBufferSize(self);
    }

    pub fn getSlice(self: *IBlob) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self.GetBufferPointer());
        const size: usize = self.GetBufferSize();
        return ptr[0..size];
    }
};

pub const IInclude = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Open: *const fn (*IInclude, INCLUDE_TYPE, LPCSTR, *anyopaque, **anyopaque, *UINT) callconv(.winapi) void,
        Close: *const fn (*IInclude, *anyopaque) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn Open(
        self: *const IInclude,
        includeType: INCLUDE_TYPE,
        fileName: LPCSTR,
        parentData: *anyopaque,
        data: **anyopaque,
        bytes: *UINT,
    ) void {
        self.vtable.Open(self, includeType, fileName, parentData, data, bytes);
    }

    pub inline fn Close(self: *const IInclude, data: *anyopaque) void {
        self.vtable.Close(self, data);
    }
};
