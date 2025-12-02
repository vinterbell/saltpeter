const std = @import("std");

const win32 = @import("win32.zig");
const d3dcommon = @import("d3dcommon.zig");

const GUID = win32.GUID;
const IUnknown = win32.IUnknown;
const IBlob = d3dcommon.IBlob;
const IMalloc = win32.IMalloc;
const IStream = win32.IStream;
const BSTR = win32.BSTR;
const HRESULT = win32.HRESULT;
const BOOL = win32.BOOL;
const PWSTR = win32.PWSTR;
const PSTR = win32.PSTR;

pub const CLSID_Compiler: GUID = .parse("{73e22d93-e6ce-47f3-b5bf-f0664f39c1b0}");
pub const CLSID_Linker: GUID = .parse("{ef6a8087-b0ea-4d56-9e45-d07e1a8b7806}");
pub const CLSID_DiaDataSource: GUID = .parse("{cd1f6b73-2ab0-484d-8edc-ebe7a43ca09f}");
pub const CLSID_CompilerArgs: GUID = .parse("{3e56ae82-224d-470f-a1a1-fe3016ee9f9d}");
pub const CLSID_Library: GUID = .parse("{6245d6af-66e0-48fd-80b4-4d271796748c}");
pub const CLSID_Utils = CLSID_Library;
pub const CLSID_Validator: GUID = .parse("{8ca3e215-f728-4cf3-8cdd-88af917587a1}");
pub const CLSID_Assembler: GUID = .parse("{d728db68-f903-4f80-94cd-dccf76ec7151}");
pub const CLSID_ContainerReflection: GUID = .parse("{b9f54489-55b8-400c-ba3a-1675e4728b91}");
pub const CLSID_Optimizer: GUID = .parse("{ae2cd79f-cc22-453f-9b6b-b124e7a5204c}");
pub const CLSID_ContainerBuilder: GUID = .parse("{94134294-411f-4574-b4d0-8741e25240d2}");
pub const CLSID_PdbUtils: GUID = .parse("{54621dfb-f2ce-457e-ae8c-ec355faeec7c}");

pub const ARG_DEBUG = "-Zi";
pub const ARG_SKIP_VALIDATION = "-Vd";
pub const ARG_SKIP_OPTIMIZATIONS = "-Od";
pub const ARG_PACK_MATRIX_ROW_MAJOR = "-Zpr";
pub const ARG_PACK_MATRIX_COLUMN_MAJOR = "-Zpc";
pub const ARG_AVOID_FLOW_CONTROL = "-Gfa";
pub const ARG_PREFER_FLOW_CONTROL = "-Gfp";
pub const ARG_ENABLE_STRICTNESS = "-Ges";
pub const ARG_ENABLE_BACKWARDS_COMPATIBILITY = "-Gec";
pub const ARG_IEEE_STRICTNESS = "-Gis";
pub const ARG_OPTIMIZATION_LEVEL0 = "-O0";
pub const ARG_OPTIMIZATION_LEVEL1 = "-O1";
pub const ARG_OPTIMIZATION_LEVEL2 = "-O2";
pub const ARG_OPTIMIZATION_LEVEL3 = "-O3";
pub const ARG_WARNINGS_ARE_ERRORS = "-WX";
pub const ARG_RESOURCES_MAY_ALIAS = "-res_may_alias";
pub const ARG_ALL_RESOURCES_BOUND = "-all_resources_bound";
pub const ARG_DEBUG_NAME_FOR_SOURCE = "-Zss";
pub const ARG_DEBUG_NAME_FOR_BINARY = "-Zsb";
pub const EXTRA_OUTPUT_NAME_STDOUT = "*stdout*";
pub const EXTRA_OUTPUT_NAME_STDERR = "*stderr*";

pub const CreateInstanceProc = *const fn (
    rclsid: *const win32.GUID,
    riid: *const win32.GUID,
    ppv: ?*?*anyopaque,
) callconv(.winapi) win32.HRESULT;
pub const CreateInstance2Proc = *const fn (
    pMalloc: *IMalloc,
    rclsid: *const win32.GUID,
    riid: *const win32.GUID,
    ppv: ?*?*anyopaque,
) callconv(.winapi) win32.HRESULT;

pub const CreateInstanceProcName = "DxcCreateInstance";
pub const CreateInstance2ProcName = "DxcCreateInstance2";

pub const CP = enum(u32) {
    ACP = 0,
    UTF16 = 1200,
    UTF8 = 65001,
};

pub const IBlobEncoding = extern union {
    pub const IID: win32.GUID = .parse("{7241d424-2646-4191-97c0-98e96e42fc68}");
    pub const VTable = extern struct {
        base: IBlob.VTable,
        GetEncoding: *const fn (
            self: *const IBlobEncoding,
            pKnown: ?*BOOL,
            pCodePage: ?*CP,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iblob: IBlob,
    iunknown: IUnknown,
    pub inline fn GetEncoding(self: *const IBlobEncoding, pKnown: ?*BOOL, pCodePage: ?*CP) HRESULT {
        return self.vtable.GetEncoding(self, pKnown, pCodePage);
    }
};

pub const IBlobUtf16 = extern union {
    pub const IID: GUID = .parse("{a3f84eab-0faa-497e-a39c-ee6ed60b2d84}");
    pub const VTable = extern struct {
        base: IBlobEncoding.VTable,
        GetStringPointer: *const fn (
            self: *const IBlobUtf16,
        ) callconv(.winapi) ?PWSTR,
        GetStringLength: *const fn (
            self: *const IBlobUtf16,
        ) callconv(.winapi) usize,
    };
    vtable: *const VTable,
    iblob_encoding: IBlobEncoding,
    iblob: IBlob,
    iunknown: IUnknown,

    pub inline fn GetStringPointer(self: *const IBlobUtf16) ?PWSTR {
        return self.vtable.GetStringPointer(self);
    }
    pub inline fn GetStringLength(self: *const IBlobUtf16) usize {
        return self.vtable.GetStringLength(self);
    }

    pub fn getSlice(self: *IBlobUtf16) []const u16 {
        const ptr: [*]const u16 = @ptrCast(self.GetStringPointer());
        const size: usize = self.GetStringLength();
        return ptr[0..size];
    }
};

pub const IBlobUtf8 = extern union {
    pub const IID: GUID = .parse("{3da636c9-ba71-4024-a301-30cbf125305b}");
    pub const VTable = extern struct {
        base: IBlobEncoding.VTable,
        GetStringPointer: *const fn (
            self: *const IBlobUtf8,
        ) callconv(.winapi) ?PSTR,
        GetStringLength: *const fn (
            self: *const IBlobUtf8,
        ) callconv(.winapi) usize,
    };
    vtable: *const VTable,
    iblob_encoding: IBlobEncoding,
    iblob: IBlob,
    iunknown: IUnknown,
    pub inline fn GetStringPointer(self: *const IBlobUtf8) ?PSTR {
        return self.vtable.GetStringPointer(self);
    }
    pub inline fn GetStringLength(self: *const IBlobUtf8) usize {
        return self.vtable.GetStringLength(self);
    }
    pub inline fn getSlice(self: *IBlobUtf8) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self.GetStringPointer());
        const size: usize = self.GetStringLength();
        return ptr[0..size];
    }
};

pub const IIncludeHandler = extern union {
    pub const IID: GUID = .parse("{7f61fc7d-950d-467f-b3e3-3c02fb49187c}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        LoadSource: *const fn (
            self: *const IIncludeHandler,
            pFilename: ?[*:0]const u16,
            ppIncludeSource: ?**IBlob,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn LoadSource(self: *const IIncludeHandler, pFilename: ?[*:0]const u16, ppIncludeSource: ?**IBlob) HRESULT {
        return self.vtable.LoadSource(self, pFilename, ppIncludeSource);
    }
};

pub const Buffer = extern struct {
    Ptr: ?*const anyopaque,
    Size: usize,
    Encoding: CP,
};

pub const Define = extern struct {
    Name: ?[*:0]const u16,
    Value: ?[*:0]const u16,
};

pub const ICompilerArgs = extern union {
    pub const IID: GUID = .parse("{73effe2a-70dc-45f8-9690-eff64c02429d}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetArguments: *const fn (
            self: *const ICompilerArgs,
        ) callconv(.winapi) ?*?PWSTR,
        GetCount: *const fn (
            self: *const ICompilerArgs,
        ) callconv(.winapi) u32,
        AddArguments: *const fn (
            self: *const ICompilerArgs,
            pArguments: ?[*]?PWSTR,
            argCount: u32,
        ) callconv(.winapi) HRESULT,
        AddArgumentsUTF8: *const fn (
            self: *const ICompilerArgs,
            pArguments: ?[*]?PSTR,
            argCount: u32,
        ) callconv(.winapi) HRESULT,
        AddDefines: *const fn (
            self: *const ICompilerArgs,
            pDefines: [*]const Define,
            defineCount: u32,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetArguments(self: *const ICompilerArgs) ?*?PWSTR {
        return self.vtable.GetArguments(self);
    }
    pub inline fn GetCount(self: *const ICompilerArgs) u32 {
        return self.vtable.GetCount(self);
    }
    pub inline fn AddArguments(self: *const ICompilerArgs, pArguments: ?[*]?PWSTR, argCount: u32) HRESULT {
        return self.vtable.AddArguments(self, pArguments, argCount);
    }
    pub inline fn AddArgumentsUTF8(self: *const ICompilerArgs, pArguments: ?[*]?PSTR, argCount: u32) HRESULT {
        return self.vtable.AddArgumentsUTF8(self, pArguments, argCount);
    }
    pub inline fn AddDefines(self: *const ICompilerArgs, pDefines: [*]const Define, defineCount: u32) HRESULT {
        return self.vtable.AddDefines(self, pDefines, defineCount);
    }
};

pub const ILibrary = extern union {
    pub const VTable = extern struct {
        pub const IID: GUID = .parse("{e5204dc7-d18c-4c3c-bdfb-851673980fe7}");
        base: IUnknown.VTable,
        SetMalloc: *const fn (
            self: *const ILibrary,
            pMalloc: ?*IMalloc,
        ) callconv(.winapi) HRESULT,
        CreateBlobFromBlob: *const fn (
            self: *const ILibrary,
            pBlob: ?*IBlob,
            offset: u32,
            length: u32,
            ppResult: **IBlob,
        ) callconv(.winapi) HRESULT,
        CreateBlobFromFile: *const fn (
            self: *const ILibrary,
            pFileName: ?[*:0]const u16,
            codePage: ?*CP,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        CreateBlobWithEncodingFromPinned: *const fn (
            self: *const ILibrary,
            pText: ?*const anyopaque,
            size: u32,
            codePage: CP,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        CreateBlobWithEncodingOnHeapCopy: *const fn (
            self: *const ILibrary,
            pText: ?*const anyopaque,
            size: u32,
            codePage: CP,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        CreateBlobWithEncodingOnMalloc: *const fn (
            self: *const ILibrary,
            pText: ?*const anyopaque,
            pIMalloc: ?*IMalloc,
            size: u32,
            codePage: CP,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        CreateIncludeHandler: *const fn (
            self: *const ILibrary,
            ppResult: **IIncludeHandler,
        ) callconv(.winapi) HRESULT,
        CreateStreamFromBlobReadOnly: *const fn (
            self: *const ILibrary,
            pBlob: ?*IBlob,
            ppStream: **IStream,
        ) callconv(.winapi) HRESULT,
        GetBlobAsUtf8: *const fn (
            self: *const ILibrary,
            pBlob: ?*IBlob,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        GetBlobAsUtf16: *const fn (
            self: *const ILibrary,
            pBlob: ?*IBlob,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn SetMalloc(
        self: *const ILibrary,
        pMalloc: ?*IMalloc,
    ) HRESULT {
        return self.vtable.SetMalloc(self, pMalloc);
    }
    pub inline fn CreateBlobFromBlob(
        self: *const ILibrary,
        pBlob: ?*IBlob,
        offset: u32,
        length: u32,
        ppResult: **IBlob,
    ) HRESULT {
        return self.vtable.CreateBlobFromBlob(self, pBlob, offset, length, ppResult);
    }
    pub inline fn CreateBlobFromFile(
        self: *const ILibrary,
        pFileName: ?[*:0]const u16,
        codePage: ?*CP,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.CreateBlobFromFile(self, pFileName, codePage, pBlobEncoding);
    }
    pub inline fn CreateBlobWithEncodingFromPinned(
        self: *const ILibrary,
        pText: ?*const anyopaque,
        size: u32,
        codePage: CP,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.CreateBlobWithEncodingFromPinned(self, pText, size, codePage, pBlobEncoding);
    }
    pub inline fn CreateBlobWithEncodingOnHeapCopy(
        self: *const ILibrary,
        pText: ?*const anyopaque,
        size: u32,
        codePage: CP,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.CreateBlobWithEncodingOnHeapCopy(
            self,
            pText,
            size,
            codePage,
            pBlobEncoding,
        );
    }
    pub inline fn CreateBlobWithEncodingOnMalloc(
        self: *const ILibrary,
        pText: ?*const anyopaque,
        pIMalloc: ?*IMalloc,
        size: u32,
        codePage: CP,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.CreateBlobWithEncodingOnMalloc(
            self,
            pText,
            pIMalloc,
            size,
            codePage,
            pBlobEncoding,
        );
    }
    pub inline fn CreateIncludeHandler(
        self: *const ILibrary,
        ppResult: **IIncludeHandler,
    ) HRESULT {
        return self.vtable.CreateIncludeHandler(self, ppResult);
    }
    pub inline fn CreateStreamFromBlobReadOnly(
        self: *const ILibrary,
        pBlob: ?*IBlob,
        ppStream: **IStream,
    ) HRESULT {
        return self.vtable.CreateStreamFromBlobReadOnly(self, pBlob, ppStream);
    }
    pub inline fn GetBlobAsUtf8(
        self: *const ILibrary,
        pBlob: ?*IBlob,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.GetBlobAsUtf8(self, pBlob, pBlobEncoding);
    }
    pub inline fn GetBlobAsUtf16(
        self: *const ILibrary,
        pBlob: ?*IBlob,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.GetBlobAsUtf16(self, pBlob, pBlobEncoding);
    }
};

pub const IOperationResult = extern union {
    pub const IID: GUID = .parse("{cedb484a-d4e9-445a-b991-ca21ca157dc2}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetStatus: *const fn (
            self: *const IOperationResult,
            pStatus: ?*HRESULT,
        ) callconv(.winapi) HRESULT,
        GetResult: *const fn (
            self: *const IOperationResult,
            ppResult: ?**IBlob,
        ) callconv(.winapi) HRESULT,
        GetErrorBuffer: *const fn (
            self: *const IOperationResult,
            ppErrors: ?**IBlobEncoding,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetStatus(self: *const IOperationResult, pStatus: ?*HRESULT) HRESULT {
        return self.vtable.GetStatus(self, pStatus);
    }
    pub inline fn GetResult(self: *const IOperationResult, ppResult: ?**IBlob) HRESULT {
        return self.vtable.GetResult(self, ppResult);
    }
    pub inline fn GetErrorBuffer(self: *const IOperationResult, ppErrors: ?**IBlobEncoding) HRESULT {
        return self.vtable.GetErrorBuffer(self, ppErrors);
    }
};

pub const ICompiler = extern union {
    pub const IID: GUID = .parse("{8c210bf3-011f-4422-8d70-6f9acb8db617}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Compile: *const fn (
            self: *const ICompiler,
            pSource: ?*IBlob,
            pSourceName: ?[*:0]const u16,
            pEntryPoint: ?[*:0]const u16,
            pTargetProfile: ?[*:0]const u16,
            pArguments: ?[*]?PWSTR,
            argCount: u32,
            pDefines: [*]const Define,
            defineCount: u32,
            pIncludeHandler: ?*IIncludeHandler,
            ppResult: **IOperationResult,
        ) callconv(.winapi) HRESULT,
        Preprocess: *const fn (
            self: *const ICompiler,
            pSource: ?*IBlob,
            pSourceName: ?[*:0]const u16,
            pArguments: ?[*]?PWSTR,
            argCount: u32,
            pDefines: [*]const Define,
            defineCount: u32,
            pIncludeHandler: ?*IIncludeHandler,
            ppResult: **IOperationResult,
        ) callconv(.winapi) HRESULT,
        Disassemble: *const fn (
            self: *const ICompiler,
            pSource: ?*IBlob,
            ppDisassembly: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    pub inline fn Compile(
        self: *const ICompiler,
        pSource: ?*IBlob,
        pSourceName: ?[*:0]const u16,
        pEntryPoint: ?[*:0]const u16,
        pTargetProfile: ?[*:0]const u16,
        pArguments: ?[*]?PWSTR,
        argCount: u32,
        pDefines: [*]const Define,
        defineCount: u32,
        pIncludeHandler: ?*IIncludeHandler,
        ppResult: **IOperationResult,
    ) HRESULT {
        return self.vtable.Compile(
            self,
            pSource,
            pSourceName,
            pEntryPoint,
            pTargetProfile,
            pArguments,
            argCount,
            pDefines,
            defineCount,
            pIncludeHandler,
            ppResult,
        );
    }
    pub inline fn Preprocess(
        self: *const ICompiler,
        pSource: ?*IBlob,
        pSourceName: ?[*:0]const u16,
        pArguments: ?[*]?PWSTR,
        argCount: u32,
        pDefines: [*]const Define,
        defineCount: u32,
        pIncludeHandler: ?*IIncludeHandler,
        ppResult: **IOperationResult,
    ) HRESULT {
        return self.vtable.Preprocess(
            self,
            pSource,
            pSourceName,
            pArguments,
            argCount,
            pDefines,
            defineCount,
            pIncludeHandler,
            ppResult,
        );
    }
    pub inline fn Disassemble(self: *const ICompiler, pSource: ?*IBlob, ppDisassembly: **IBlobEncoding) HRESULT {
        return self.vtable.Disassemble(self, pSource, ppDisassembly);
    }
};

pub const ICompiler2 = extern union {
    pub const IID: GUID = .parse("{a005a9d9-b8bb-4594-b5c9-0e633bec4d37}");
    pub const VTable = extern struct {
        base: ICompiler.VTable,
        CompileWithDebug: *const fn (
            self: *const ICompiler2,
            pSource: ?*IBlob,
            pSourceName: ?[*:0]const u16,
            pEntryPoint: ?[*:0]const u16,
            pTargetProfile: ?[*:0]const u16,
            pArguments: ?[*]?PWSTR,
            argCount: u32,
            pDefines: [*]const Define,
            defineCount: u32,
            pIncludeHandler: ?*IIncludeHandler,
            ppResult: **IOperationResult,
            ppDebugBlobName: ?*?PWSTR,
            ppDebugBlob: ?**IBlob,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    icompiler: ICompiler,
    iunknown: IUnknown,

    pub inline fn CompileWithDebug(
        self: *const ICompiler2,
        pSource: ?*IBlob,
        pSourceName: ?[*:0]const u16,
        pEntryPoint: ?[*:0]const u16,
        pTargetProfile: ?[*:0]const u16,
        pArguments: ?[*]?PWSTR,
        argCount: u32,
        pDefines: [*]const Define,
        defineCount: u32,
        pIncludeHandler: ?*IIncludeHandler,
        ppResult: **IOperationResult,
        ppDebugBlobName: ?*?PWSTR,
        ppDebugBlob: ?**IBlob,
    ) HRESULT {
        return self.vtable.CompileWithDebug(
            self,
            pSource,
            pSourceName,
            pEntryPoint,
            pTargetProfile,
            pArguments,
            argCount,
            pDefines,
            defineCount,
            pIncludeHandler,
            ppResult,
            ppDebugBlobName,
            ppDebugBlob,
        );
    }
};

pub const ILinker = extern union {
    pub const IID: GUID = .parse("{f1b5be2a-62dd-4327-a1c2-42ac1e1e78e6}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        RegisterLibrary: *const fn (
            self: *const ILinker,
            pLibName: ?[*:0]const u16,
            pLib: ?*IBlob,
        ) callconv(.winapi) HRESULT,
        Link: *const fn (
            self: *const ILinker,
            pEntryName: ?[*:0]const u16,
            pTargetProfile: ?[*:0]const u16,
            pLibNames: [*]const ?[*:0]const u16,
            libCount: u32,
            pArguments: ?[*]const ?[*:0]const u16,
            argCount: u32,
            ppResult: **IOperationResult,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn RegisterLibrary(self: *const ILinker, pLibName: ?[*:0]const u16, pLib: ?*IBlob) HRESULT {
        return self.vtable.RegisterLibrary(self, pLibName, pLib);
    }
    pub inline fn Link(
        self: *const ILinker,
        pEntryName: ?[*:0]const u16,
        pTargetProfile: ?[*:0]const u16,
        pLibNames: [*]const ?[*:0]const u16,
        libCount: u32,
        pArguments: ?[*]const ?[*:0]const u16,
        argCount: u32,
        ppResult: **IOperationResult,
    ) HRESULT {
        return self.vtable.Link(
            self,
            pEntryName,
            pTargetProfile,
            pLibNames,
            libCount,
            pArguments,
            argCount,
            ppResult,
        );
    }
};

pub const IUtils = extern union {
    pub const IID: GUID = .parse("{4605c4cb-2019-492a-ada4-65f20bb7d67f}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        CreateBlobFromBlob: *const fn (
            self: *const IUtils,
            pBlob: ?*IBlob,
            offset: u32,
            length: u32,
            ppResult: **IBlob,
        ) callconv(.winapi) HRESULT,
        CreateBlobFromPinned: *const fn (
            self: *const IUtils,
            pData: ?*const anyopaque,
            size: u32,
            codePage: CP,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        MoveToBlob: *const fn (
            self: *const IUtils,
            pData: ?*const anyopaque,
            pIMalloc: ?*IMalloc,
            size: u32,
            codePage: CP,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        CreateBlob: *const fn (
            self: *const IUtils,
            pData: ?*const anyopaque,
            size: u32,
            codePage: CP,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        LoadFile: *const fn (
            self: *const IUtils,
            pFileName: ?[*:0]const u16,
            pCodePage: ?*CP,
            pBlobEncoding: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        CreateReadOnlyStreamFromBlob: *const fn (
            self: *const IUtils,
            pBlob: ?*IBlob,
            ppStream: **IStream,
        ) callconv(.winapi) HRESULT,
        CreateDefaultIncludeHandler: *const fn (
            self: *const IUtils,
            ppResult: **IIncludeHandler,
        ) callconv(.winapi) HRESULT,
        GetBlobAsUtf8: *const fn (
            self: *const IUtils,
            pBlob: ?*IBlob,
            pBlobEncoding: **IBlobUtf8,
        ) callconv(.winapi) HRESULT,
        GetBlobAsUtf16: *const fn (
            self: *const IUtils,
            pBlob: ?*IBlob,
            pBlobEncoding: **IBlobUtf16,
        ) callconv(.winapi) HRESULT,
        GetDxilContainerPart: *const fn (
            self: *const IUtils,
            pShader: ?*const Buffer,
            DxcPart: u32,
            ppPartData: ?*?*anyopaque,
            pPartSizeInBytes: ?*u32,
        ) callconv(.winapi) HRESULT,
        CreateReflection: *const fn (
            self: *const IUtils,
            pData: ?*const Buffer,
            iid: ?*const GUID,
            ppvReflection: ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        BuildArguments: *const fn (
            self: *const IUtils,
            pSourceName: ?[*:0]const u16,
            pEntryPoint: ?[*:0]const u16,
            pTargetProfile: ?[*:0]const u16,
            pArguments: ?[*]?PWSTR,
            argCount: u32,
            pDefines: [*]const Define,
            defineCount: u32,
            ppArgs: **ICompilerArgs,
        ) callconv(.winapi) HRESULT,
        GetPDBContents: *const fn (
            self: *const IUtils,
            pPDBBlob: ?*IBlob,
            ppHash: **IBlob,
            ppContainer: **IBlob,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    pub inline fn CreateBlobFromBlob(
        self: *const IUtils,
        pBlob: ?*IBlob,
        offset: u32,
        length: u32,
        ppResult: **IBlob,
    ) HRESULT {
        return self.vtable.CreateBlobFromBlob(
            self,
            pBlob,
            offset,
            length,
            ppResult,
        );
    }
    pub inline fn CreateBlobFromPinned(
        self: *const IUtils,
        pData: ?*const anyopaque,
        size: u32,
        codePage: CP,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.CreateBlobFromPinned(
            self,
            pData,
            size,
            codePage,
            pBlobEncoding,
        );
    }
    pub inline fn MoveToBlob(
        self: *const IUtils,
        pData: ?*const anyopaque,
        pIMalloc: ?*IMalloc,
        size: u32,
        codePage: CP,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.MoveToBlob(
            self,
            pData,
            pIMalloc,
            size,
            codePage,
            pBlobEncoding,
        );
    }
    pub inline fn CreateBlob(
        self: *const IUtils,
        pData: ?*const anyopaque,
        size: u32,
        codePage: CP,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.CreateBlob(
            self,
            pData,
            size,
            codePage,
            pBlobEncoding,
        );
    }
    pub inline fn LoadFile(
        self: *const IUtils,
        pFileName: ?[*:0]const u16,
        pCodePage: ?*CP,
        pBlobEncoding: **IBlobEncoding,
    ) HRESULT {
        return self.vtable.LoadFile(
            self,
            pFileName,
            pCodePage,
            pBlobEncoding,
        );
    }
    pub inline fn CreateReadOnlyStreamFromBlob(
        self: *const IUtils,
        pBlob: ?*IBlob,
        ppStream: **IStream,
    ) HRESULT {
        return self.vtable.CreateReadOnlyStreamFromBlob(
            self,
            pBlob,
            ppStream,
        );
    }
    pub inline fn CreateDefaultIncludeHandler(
        self: *const IUtils,
        ppResult: **IIncludeHandler,
    ) HRESULT {
        return self.vtable.CreateDefaultIncludeHandler(self, ppResult);
    }
    pub inline fn GetBlobAsUtf8(
        self: *const IUtils,
        pBlob: ?*IBlob,
        pBlobEncoding: **IBlobUtf8,
    ) HRESULT {
        return self.vtable.GetBlobAsUtf8(self, pBlob, pBlobEncoding);
    }
    pub inline fn GetBlobAsUtf16(
        self: *const IUtils,
        pBlob: ?*IBlob,
        pBlobEncoding: **IBlobUtf16,
    ) HRESULT {
        return self.vtable.GetBlobAsUtf16(self, pBlob, pBlobEncoding);
    }
    pub inline fn GetDxilContainerPart(
        self: *const IUtils,
        pShader: ?*const Buffer,
        DxcPart: u32,
        ppPartData: ?*?*anyopaque,
        pPartSizeInBytes: ?*u32,
    ) HRESULT {
        return self.vtable.GetDxilContainerPart(
            self,
            pShader,
            DxcPart,
            ppPartData,
            pPartSizeInBytes,
        );
    }
    pub inline fn CreateReflection(
        self: *const IUtils,
        pData: ?*const Buffer,
        iid: ?*const GUID,
        ppvReflection: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.CreateReflection(
            self,
            pData,
            iid,
            ppvReflection,
        );
    }
    pub inline fn BuildArguments(
        self: *const IUtils,
        pSourceName: ?[*:0]const u16,
        pEntryPoint: ?[*:0]const u16,
        pTargetProfile: ?[*:0]const u16,
        pArguments: ?[*]?PWSTR,
        argCount: u32,
        pDefines: [*]const Define,
        defineCount: u32,
        ppArgs: **ICompilerArgs,
    ) HRESULT {
        return self.vtable.BuildArguments(
            self,
            pSourceName,
            pEntryPoint,
            pTargetProfile,
            pArguments,
            argCount,
            pDefines,
            defineCount,
            ppArgs,
        );
    }
    pub inline fn GetPDBContents(
        self: *const IUtils,
        pPDBBlob: ?*IBlob,
        ppHash: **IBlob,
        ppContainer: **IBlob,
    ) HRESULT {
        return self.vtable.GetPDBContents(
            self,
            pPDBBlob,
            ppHash,
            ppContainer,
        );
    }
};

pub const OUT_KIND = enum(i32) {
    NONE = 0,
    OBJECT = 1,
    ERRORS = 2,
    PDB = 3,
    SHADER_HASH = 4,
    DISASSEMBLY = 5,
    HLSL = 6,
    TEXT = 7,
    REFLECTION = 8,
    ROOT_SIGNATURE = 9,
    EXTRA_OUTPUTS = 10,
    FORCE_DWORD = -1,
};

pub const IResult = extern union {
    pub const IID: GUID = .parse("{58346cda-dde7-4497-9461-6f87af5e0659}");
    pub const VTable = extern struct {
        base: IOperationResult.VTable,
        HasOutput: *const fn (
            self: *const IResult,
            dxcOutKind: OUT_KIND,
        ) callconv(.winapi) BOOL,
        GetOutput: *const fn (
            self: *const IResult,
            dxcOutKind: OUT_KIND,
            iid: ?*const GUID,
            ppvObject: ?**anyopaque,
            ppOutputName: ?*?*IBlobUtf16,
        ) callconv(.winapi) HRESULT,
        GetNumOutputs: *const fn (
            self: *const IResult,
        ) callconv(.winapi) u32,
        GetOutputByIndex: *const fn (
            self: *const IResult,
            Index: u32,
        ) callconv(.winapi) OUT_KIND,
        PrimaryOutput: *const fn (
            self: *const IResult,
        ) callconv(.winapi) OUT_KIND,
    };
    vtable: *const VTable,
    ioperation_result: IOperationResult,
    iunknown: IUnknown,

    pub inline fn HasOutput(self: *const IResult, dxcOutKind: OUT_KIND) BOOL {
        return self.vtable.HasOutput(self, dxcOutKind);
    }
    pub inline fn GetOutput(
        self: *const IResult,
        dxcOutKind: OUT_KIND,
        iid: ?*const GUID,
        ppvObject: ?**anyopaque,
        ppOutputName: ?*?*IBlobUtf16,
    ) HRESULT {
        return self.vtable.GetOutput(
            self,
            dxcOutKind,
            iid,
            ppvObject,
            ppOutputName,
        );
    }
    pub inline fn GetNumOutputs(self: *const IResult) u32 {
        return self.vtable.GetNumOutputs(self);
    }
    pub inline fn GetOutputByIndex(self: *const IResult, Index: u32) OUT_KIND {
        return self.vtable.GetOutputByIndex(self, Index);
    }
    pub inline fn PrimaryOutput(self: *const IResult) OUT_KIND {
        return self.vtable.PrimaryOutput(self);
    }
};

pub const IExtraOutputs = extern union {
    pub const IID: GUID = .parse("{319b37a2-a5c2-494a-a5de-4801b2faf989}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetOutputCount: *const fn (
            self: *const IExtraOutputs,
        ) callconv(.winapi) u32,
        GetOutput: *const fn (
            self: *const IExtraOutputs,
            uIndex: u32,
            iid: ?*const GUID,
            ppvObject: ?**anyopaque,
            ppOutputType: ?**IBlobUtf16,
            ppOutputName: ?**IBlobUtf16,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetOutputCount(self: *const IExtraOutputs) u32 {
        return self.vtable.GetOutputCount(self);
    }
    pub inline fn GetOutput(
        self: *const IExtraOutputs,
        uIndex: u32,
        iid: ?*const GUID,
        ppvObject: ?**anyopaque,
        ppOutputType: ?**IBlobUtf16,
        ppOutputName: ?**IBlobUtf16,
    ) HRESULT {
        return self.vtable.GetOutput(
            self,
            uIndex,
            iid,
            ppvObject,
            ppOutputType,
            ppOutputName,
        );
    }
};

pub const ICompiler3 = extern union {
    pub const IID: GUID = .parse("{228b4687-5a6a-4730-900c-9702b2203f54}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Compile: *const fn (
            self: *const ICompiler3,
            pSource: ?*const Buffer,
            pArguments: ?[*]?PWSTR,
            argCount: u32,
            pIncludeHandler: ?*IIncludeHandler,
            riid: ?*const GUID,
            ppResult: ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
        Disassemble: *const fn (
            self: *const ICompiler3,
            pObject: ?*const Buffer,
            riid: ?*const GUID,
            ppResult: ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn Compile(
        self: *const ICompiler3,
        pSource: ?*const Buffer,
        pArguments: ?[*]?PWSTR,
        argCount: u32,
        pIncludeHandler: ?*IIncludeHandler,
        riid: ?*const GUID,
        ppResult: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.Compile(
            self,
            pSource,
            pArguments,
            argCount,
            pIncludeHandler,
            riid,
            ppResult,
        );
    }
    pub inline fn Disassemble(
        self: *const ICompiler3,
        pObject: ?*const Buffer,
        riid: ?*const GUID,
        ppResult: ?*?*anyopaque,
    ) HRESULT {
        return self.vtable.Disassemble(
            self,
            pObject,
            riid,
            ppResult,
        );
    }
};

pub const ValidatorFlags = packed struct(u32) {
    in_place_edit: bool,
    root_signature_only: bool,
    module_only: bool,
    _: u29 = 0,

    pub const default: ValidatorFlags = .{
        .in_place_edit = false,
        .root_signature_only = false,
        .module_only = false,
    };
};

pub const IValidator = extern union {
    pub const IID: GUID = .parse("{a6e82bd2-1fd7-4826-9811-2857e797f49a}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Validate: *const fn (
            self: *const IValidator,
            pShader: ?*IBlob,
            Flags: ValidatorFlags,
            ppResult: **IOperationResult,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn Validate(self: *const IValidator, pShader: ?*IBlob, Flags: ValidatorFlags, ppResult: **IOperationResult) HRESULT {
        return self.vtable.Validate(self, pShader, Flags, ppResult);
    }
};

pub const IValidator2 = extern union {
    pub const IID: GUID = .parse("{458e1fd1-b1b2-4750-a6e1-9c10f03bed92}");
    pub const VTable = extern struct {
        base: IValidator.VTable,
        ValidateWithDebug: *const fn (
            self: *const IValidator2,
            pShader: ?*IBlob,
            Flags: u32,
            pOptDebugBitcode: ?*Buffer,
            ppResult: **IOperationResult,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    ivalidator: IValidator,

    pub inline fn ValidateWithDebug(
        self: *const IValidator2,
        pShader: ?*IBlob,
        Flags: u32,
        pOptDebugBitcode: ?*Buffer,
        ppResult: **IOperationResult,
    ) HRESULT {
        return self.vtable.ValidateWithDebug(
            self,
            pShader,
            Flags,
            pOptDebugBitcode,
            ppResult,
        );
    }
};

pub const IContainerBuilder = extern union {
    pub const IID: GUID = .parse("{334b1f50-2292-4b35-99a1-25588d8c17fe}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Load: *const fn (
            self: *const IContainerBuilder,
            pDxilContainerHeader: ?*IBlob,
        ) callconv(.winapi) HRESULT,
        AddPart: *const fn (
            self: *const IContainerBuilder,
            fourCC: u32,
            pSource: ?*IBlob,
        ) callconv(.winapi) HRESULT,
        RemovePart: *const fn (
            self: *const IContainerBuilder,
            fourCC: u32,
        ) callconv(.winapi) HRESULT,
        SerializeContainer: *const fn (
            self: *const IContainerBuilder,
            ppResult: ?*?*IOperationResult,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn Load(self: *const IContainerBuilder, pDxilContainerHeader: ?*IBlob) HRESULT {
        return self.vtable.Load(self, pDxilContainerHeader);
    }
    pub inline fn AddPart(self: *const IContainerBuilder, fourCC: u32, pSource: ?*IBlob) HRESULT {
        return self.vtable.AddPart(self, fourCC, pSource);
    }
    pub inline fn RemovePart(self: *const IContainerBuilder, fourCC: u32) HRESULT {
        return self.vtable.RemovePart(self, fourCC);
    }
    pub inline fn SerializeContainer(self: *const IContainerBuilder, ppResult: ?*?*IOperationResult) HRESULT {
        return self.vtable.SerializeContainer(self, ppResult);
    }
};

pub const IAssembler = extern union {
    pub const IID: GUID = .parse("{091f7a26-1c1f-4948-904b-e6e3a8a771d5}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        AssembleToContainer: *const fn (
            self: *const IAssembler,
            pShader: ?*IBlob,
            ppResult: **IOperationResult,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn AssembleToContainer(self: *const IAssembler, pShader: ?*IBlob, ppResult: **IOperationResult) HRESULT {
        return self.vtable.AssembleToContainer(self, pShader, ppResult);
    }
};

pub const IContainerReflection = extern union {
    pub const IID: GUID = .parse("{d2c21b26-8350-4bdc-976a-331ce6f4c54c}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Load: *const fn (
            self: *const IContainerReflection,
            pContainer: ?*IBlob,
        ) callconv(.winapi) HRESULT,
        GetPartCount: *const fn (
            self: *const IContainerReflection,
            pResult: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetPartKind: *const fn (
            self: *const IContainerReflection,
            idx: u32,
            pResult: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetPartContent: *const fn (
            self: *const IContainerReflection,
            idx: u32,
            ppResult: **IBlob,
        ) callconv(.winapi) HRESULT,
        FindFirstPartKind: *const fn (
            self: *const IContainerReflection,
            kind: u32,
            pResult: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetPartReflection: *const fn (
            self: *const IContainerReflection,
            idx: u32,
            iid: ?*const GUID,
            ppvObject: ?*?*anyopaque,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn Load(self: *const IContainerReflection, pContainer: ?*IBlob) HRESULT {
        return self.vtable.Load(self, pContainer);
    }
    pub inline fn GetPartCount(self: *const IContainerReflection, pResult: ?*u32) HRESULT {
        return self.vtable.GetPartCount(self, pResult);
    }
    pub inline fn GetPartKind(self: *const IContainerReflection, idx: u32, pResult: ?*u32) HRESULT {
        return self.vtable.GetPartKind(self, idx, pResult);
    }
    pub inline fn GetPartContent(self: *const IContainerReflection, idx: u32, ppResult: **IBlob) HRESULT {
        return self.vtable.GetPartContent(self, idx, ppResult);
    }
    pub inline fn FindFirstPartKind(self: *const IContainerReflection, kind: u32, pResult: ?*u32) HRESULT {
        return self.vtable.FindFirstPartKind(self, kind, pResult);
    }
    pub inline fn GetPartReflection(self: *const IContainerReflection, idx: u32, iid: ?*const GUID, ppvObject: ?*?*anyopaque) HRESULT {
        return self.vtable.GetPartReflection(self, idx, iid, ppvObject);
    }
};

pub const IOptimizerPass = extern union {
    pub const IID: GUID = .parse("{ae2cd79f-cc22-453f-9b6b-b124e7a5204c}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetOptionName: *const fn (
            self: *const IOptimizerPass,
            ppResult: *PWSTR,
        ) callconv(.winapi) HRESULT,
        GetDescription: *const fn (
            self: *const IOptimizerPass,
            ppResult: *PWSTR,
        ) callconv(.winapi) HRESULT,
        GetOptionArgCount: *const fn (
            self: *const IOptimizerPass,
            pCount: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetOptionArgName: *const fn (
            self: *const IOptimizerPass,
            argIndex: u32,
            ppResult: *PWSTR,
        ) callconv(.winapi) HRESULT,
        GetOptionArgDescription: *const fn (
            self: *const IOptimizerPass,
            argIndex: u32,
            ppResult: *PWSTR,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetOptionName(self: *const IOptimizerPass, ppResult: *PWSTR) HRESULT {
        return self.vtable.GetOptionName(self, ppResult);
    }
    pub inline fn GetDescription(self: *const IOptimizerPass, ppResult: *PWSTR) HRESULT {
        return self.vtable.GetDescription(self, ppResult);
    }
    pub inline fn GetOptionArgCount(self: *const IOptimizerPass, pCount: ?*u32) HRESULT {
        return self.vtable.GetOptionArgCount(self, pCount);
    }
    pub inline fn GetOptionArgName(self: *const IOptimizerPass, argIndex: u32, ppResult: *PWSTR) HRESULT {
        return self.vtable.GetOptionArgName(self, argIndex, ppResult);
    }
    pub inline fn GetOptionArgDescription(self: *const IOptimizerPass, argIndex: u32, ppResult: *PWSTR) HRESULT {
        return self.vtable.GetOptionArgDescription(self, argIndex, ppResult);
    }
};

pub const IOptimizer = extern union {
    pub const IID: GUID = .parse("{25740e2e-9cba-401b-9119-4fb42f39f270}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetAvailablePassCount: *const fn (
            self: *const IOptimizer,
            pCount: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetAvailablePass: *const fn (
            self: *const IOptimizer,
            index: u32,
            ppResult: **IOptimizerPass,
        ) callconv(.winapi) HRESULT,
        RunOptimizer: *const fn (
            self: *const IOptimizer,
            pBlob: ?*IBlob,
            ppOptions: [*]?PWSTR,
            optionCount: u32,
            pOutputModule: **IBlob,
            ppOutputText: ?**IBlobEncoding,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetAvailablePassCount(self: *const IOptimizer, pCount: ?*u32) HRESULT {
        return self.vtable.GetAvailablePassCount(self, pCount);
    }
    pub inline fn GetAvailablePass(
        self: *const IOptimizer,
        index: u32,
        ppResult: **IOptimizerPass,
    ) HRESULT {
        return self.vtable.GetAvailablePass(
            self,
            index,
            ppResult,
        );
    }
    pub inline fn RunOptimizer(
        self: *const IOptimizer,
        pBlob: ?*IBlob,
        ppOptions: [*]?PWSTR,
        optionCount: u32,
        pOutputModule: **IBlob,
        ppOutputText: ?**IBlobEncoding,
    ) HRESULT {
        return self.vtable.RunOptimizer(
            self,
            pBlob,
            ppOptions,
            optionCount,
            pOutputModule,
            ppOutputText,
        );
    }
};

pub const VersionInfoFlags = packed struct(u32) {
    debug: bool,
    internal: bool,
    _: u30 = 0,
};

pub const IVersionInfo = extern union {
    pub const IID: GUID = .parse("{b04f5b50-2059-4f12-a8ff-a1e0cde1cc7e}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetVersion: *const fn (
            self: *const IVersionInfo,
            pMajor: ?*u32,
            pMinor: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetFlags: *const fn (
            self: *const IVersionInfo,
            pFlags: ?*VersionInfoFlags,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetVersion(self: *const IVersionInfo, pMajor: ?*u32, pMinor: ?*u32) HRESULT {
        return self.vtable.GetVersion(self, pMajor, pMinor);
    }
    pub inline fn GetFlags(self: *const IVersionInfo, pFlags: ?*VersionInfoFlags) HRESULT {
        return self.vtable.GetFlags(self, pFlags);
    }
};

pub const IVersionInfo2 = extern union {
    pub const IID: GUID = .parse("{fb6904c4-42f0-4b62-9c46-983af7da7c83}");

    pub const VTable = extern struct {
        base: IVersionInfo.VTable,
        GetCommitInfo: *const fn (
            self: *const IVersionInfo2,
            pCommitCount: ?*u32,
            pCommitHash: ?*?*i8,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,
    iversioninfo: IVersionInfo,

    pub inline fn GetCommitInfo(self: *const IVersionInfo2, pCommitCount: ?*u32, pCommitHash: ?*?*i8) HRESULT {
        return self.vtable.GetCommitInfo(self, pCommitCount, pCommitHash);
    }
};

pub const IVersionInfo3 = extern union {
    pub const IID: GUID = .parse("{5e13e843-9d25-473c-9ad2-03b2d0b44b1e}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetCustomVersionString: *const fn (
            self: *const IVersionInfo3,
            pVersionString: ?*?*i8,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn GetCustomVersionString(self: *const IVersionInfo3, pVersionString: ?*?*i8) HRESULT {
        return self.vtable.GetCustomVersionString(self, pVersionString);
    }
};

pub const ArgPair = extern struct {
    pName: ?[*:0]const u16,
    pValue: ?[*:0]const u16,
};

pub const IPdbUtils = extern union {
    pub const IID = .parse("{e6c9647e-9d6a-4c3b-b94c-524b5a6c343d}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Load: *const fn (
            self: *const IPdbUtils,
            pPdbOrDxil: ?*IBlob,
        ) callconv(.winapi) HRESULT,
        GetSourceCount: *const fn (
            self: *const IPdbUtils,
            pCount: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetSource: *const fn (
            self: *const IPdbUtils,
            uIndex: u32,
            ppResult: **IBlobEncoding,
        ) callconv(.winapi) HRESULT,
        GetSourceName: *const fn (
            self: *const IPdbUtils,
            uIndex: u32,
            pResult: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        GetFlagCount: *const fn (
            self: *const IPdbUtils,
            pCount: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetFlag: *const fn (
            self: *const IPdbUtils,
            uIndex: u32,
            pResult: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        GetArgCount: *const fn (
            self: *const IPdbUtils,
            pCount: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetArg: *const fn (
            self: *const IPdbUtils,
            uIndex: u32,
            pResult: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        GetArgPairCount: *const fn (
            self: *const IPdbUtils,
            pCount: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetArgPair: *const fn (
            self: *const IPdbUtils,
            uIndex: u32,
            pName: ?*?BSTR,
            pValue: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        GetDefineCount: *const fn (
            self: *const IPdbUtils,
            pCount: ?*u32,
        ) callconv(.winapi) HRESULT,
        GetDefine: *const fn (
            self: *const IPdbUtils,
            uIndex: u32,
            pResult: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        GetTargetProfile: *const fn (
            self: *const IPdbUtils,
            pResult: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        GetEntryPoint: *const fn (
            self: *const IPdbUtils,
            pResult: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        GetMainFileName: *const fn (
            self: *const IPdbUtils,
            pResult: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        GetHash: *const fn (
            self: *const IPdbUtils,
            ppResult: **IBlob,
        ) callconv(.winapi) HRESULT,
        GetName: *const fn (
            self: *const IPdbUtils,
            pResult: ?*?BSTR,
        ) callconv(.winapi) HRESULT,
        IsFullPDB: *const fn (
            self: *const IPdbUtils,
        ) callconv(.winapi) BOOL,
        GetFullPDB: *const fn (
            self: *const IPdbUtils,
            ppFullPDB: **IBlob,
        ) callconv(.winapi) HRESULT,
        GetVersionInfo: *const fn (
            self: *const IPdbUtils,
            ppVersionInfo: **IVersionInfo,
        ) callconv(.winapi) HRESULT,
        SetCompiler: *const fn (
            self: *const IPdbUtils,
            pCompiler: ?*ICompiler3,
        ) callconv(.winapi) HRESULT,
        CompileForFullPDB: *const fn (
            self: *const IPdbUtils,
            ppResult: **IResult,
        ) callconv(.winapi) HRESULT,
        OverrideArgs: *const fn (
            self: *const IPdbUtils,
            pArgPairs: ?*ArgPair,
            uNumArgPairs: u32,
        ) callconv(.winapi) HRESULT,
        OverrideRootSignature: *const fn (
            self: *const IPdbUtils,
            pRootSignature: ?[*:0]const u16,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn Load(self: *const IPdbUtils, pPdbOrDxil: ?*IBlob) HRESULT {
        return self.vtable.Load(self, pPdbOrDxil);
    }
    pub inline fn GetSourceCount(self: *const IPdbUtils, pCount: ?*u32) HRESULT {
        return self.vtable.GetSourceCount(self, pCount);
    }
    pub inline fn GetSource(self: *const IPdbUtils, uIndex: u32, ppResult: **IBlobEncoding) HRESULT {
        return self.vtable.GetSource(self, uIndex, ppResult);
    }
    pub inline fn GetSourceName(self: *const IPdbUtils, uIndex: u32, pResult: ?*?BSTR) HRESULT {
        return self.vtable.GetSourceName(self, uIndex, pResult);
    }
    pub inline fn GetFlagCount(self: *const IPdbUtils, pCount: ?*u32) HRESULT {
        return self.vtable.GetFlagCount(self, pCount);
    }
    pub inline fn GetFlag(self: *const IPdbUtils, uIndex: u32, pResult: ?*?BSTR) HRESULT {
        return self.vtable.GetFlag(self, uIndex, pResult);
    }
    pub inline fn GetArgCount(self: *const IPdbUtils, pCount: ?*u32) HRESULT {
        return self.vtable.GetArgCount(self, pCount);
    }
    pub inline fn GetArg(self: *const IPdbUtils, uIndex: u32, pResult: ?*?BSTR) HRESULT {
        return self.vtable.GetArg(self, uIndex, pResult);
    }
    pub inline fn GetArgPairCount(self: *const IPdbUtils, pCount: ?*u32) HRESULT {
        return self.vtable.GetArgPairCount(self, pCount);
    }
    pub inline fn GetArgPair(self: *const IPdbUtils, uIndex: u32, pName: ?*?BSTR, pValue: ?*?BSTR) HRESULT {
        return self.vtable.GetArgPair(self, uIndex, pName, pValue);
    }
    pub inline fn GetDefineCount(self: *const IPdbUtils, pCount: ?*u32) HRESULT {
        return self.vtable.GetDefineCount(self, pCount);
    }
    pub inline fn GetDefine(self: *const IPdbUtils, uIndex: u32, pResult: ?*?BSTR) HRESULT {
        return self.vtable.GetDefine(self, uIndex, pResult);
    }
    pub inline fn GetTargetProfile(self: *const IPdbUtils, pResult: ?*?BSTR) HRESULT {
        return self.vtable.GetTargetProfile(self, pResult);
    }
    pub inline fn GetEntryPoint(self: *const IPdbUtils, pResult: ?*?BSTR) HRESULT {
        return self.vtable.GetEntryPoint(self, pResult);
    }
    pub inline fn GetMainFileName(self: *const IPdbUtils, pResult: ?*?BSTR) HRESULT {
        return self.vtable.GetMainFileName(self, pResult);
    }
    pub inline fn GetHash(self: *const IPdbUtils, ppResult: **IBlob) HRESULT {
        return self.vtable.GetHash(self, ppResult);
    }
    pub inline fn GetName(self: *const IPdbUtils, pResult: ?*?BSTR) HRESULT {
        return self.vtable.GetName(self, pResult);
    }
    pub inline fn IsFullPDB(self: *const IPdbUtils) BOOL {
        return self.vtable.IsFullPDB(self);
    }
    pub inline fn GetFullPDB(self: *const IPdbUtils, ppFullPDB: **IBlob) HRESULT {
        return self.vtable.GetFullPDB(self, ppFullPDB);
    }
    pub inline fn GetVersionInfo(self: *const IPdbUtils, ppVersionInfo: **IVersionInfo) HRESULT {
        return self.vtable.GetVersionInfo(self, ppVersionInfo);
    }
    pub inline fn SetCompiler(self: *const IPdbUtils, pCompiler: ?*ICompiler3) HRESULT {
        return self.vtable.SetCompiler(self, pCompiler);
    }
    pub inline fn CompileForFullPDB(self: *const IPdbUtils, ppResult: **IResult) HRESULT {
        return self.vtable.CompileForFullPDB(self, ppResult);
    }
    pub inline fn OverrideArgs(self: *const IPdbUtils, pArgPairs: ?*ArgPair, uNumArgPairs: u32) HRESULT {
        return self.vtable.OverrideArgs(self, pArgPairs, uNumArgPairs);
    }
    pub inline fn OverrideRootSignature(self: *const IPdbUtils, pRootSignature: ?[*:0]const u16) HRESULT {
        return self.vtable.OverrideRootSignature(self, pRootSignature);
    }
};
