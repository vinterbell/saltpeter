const std = @import("std");
const std_windows = std.os.windows;

pub const LUID = extern struct {
    LowPart: DWORD,
    HighPart: LONG,

    pub const zero: LUID = .{
        .LowPart = 0,
        .HighPart = 0,
    };
};
pub const S_OK = std_windows.S_OK;
pub const E_POINTER = std_windows.E_POINTER;
pub const E_NOINTERFACE = std_windows.E_NOINTERFACE;
pub const E_FAIL = std_windows.E_FAIL;
pub const E_OUTOFMEMORY = std_windows.E_OUTOFMEMORY;
pub const E_FILE_NOT_FOUND: HRESULT = 2;
pub const E_INVALIDARG: HRESULT = 87;
pub const BOOLEAN = std_windows.BOOLEAN;
pub const BYTE = std_windows.BYTE;
pub const CHAR = std_windows.CHAR;
pub const UCHAR = std_windows.UCHAR;
pub const WCHAR = std_windows.WCHAR;
pub const FLOAT = std_windows.FLOAT;
pub const HCRYPTPROV = std_windows.HCRYPTPROV;
pub const ATOM = std_windows.ATOM;
pub const WPARAM = std_windows.WPARAM;
pub const LPARAM = std_windows.LPARAM;
pub const LRESULT = std_windows.LRESULT;
pub const HRESULT = std_windows.HRESULT;
pub const HBRUSH = std_windows.HBRUSH;
pub const HCURSOR = std_windows.HCURSOR;
pub const HICON = std_windows.HICON;
pub const HINSTANCE = std_windows.HINSTANCE;
pub const HMENU = std_windows.HMENU;
pub const HMODULE = std_windows.HMODULE;
pub const HWND = std_windows.HWND;
pub const HDC = std_windows.HDC;
pub const HGLRC = std_windows.HGLRC;
pub const FARPROC = std_windows.FARPROC;
pub const INT = std_windows.INT;
pub const SIZE_T = std_windows.SIZE_T;
pub const UINT = std_windows.UINT;
pub const USHORT = std_windows.USHORT;
pub const SHORT = std_windows.SHORT;
pub const ULONG = std_windows.ULONG;
pub const LONG = std_windows.LONG;
pub const WORD = std_windows.WORD;
pub const DWORD = std_windows.DWORD;
pub const ULONGLONG = std_windows.ULONGLONG;
pub const LONGLONG = std_windows.LONGLONG;
pub const LARGE_INTEGER = std_windows.LARGE_INTEGER;
pub const ULARGE_INTEGER = std_windows.ULARGE_INTEGER;
pub const LPCSTR = std_windows.LPCSTR;
pub const LPCVOID = std_windows.LPCVOID;
pub const LPSTR = std_windows.LPSTR;
pub const LPVOID = std_windows.LPVOID;
pub const LPWSTR = std_windows.LPWSTR;
pub const LPCWSTR = std_windows.LPCWSTR;
pub const PVOID = std_windows.PVOID;
pub const PWSTR = std_windows.PWSTR;
pub const PSTR = LPSTR;
pub const BSTR = std_windows.BSTR;
pub const PCWSTR = std_windows.PCWSTR;
pub const HANDLE = std_windows.HANDLE;
pub const GUID = std_windows.GUID;
pub const NTSTATUS = std_windows.NTSTATUS;
pub const CRITICAL_SECTION = std_windows.CRITICAL_SECTION;
pub const SECURITY_ATTRIBUTES = std_windows.SECURITY_ATTRIBUTES;
pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,

    pub const zero: RECT = .{
        .left = 0,
        .top = 0,
        .right = 0,
        .bottom = 0,
    };

    pub fn to(self: RECT) std_windows.RECT {
        return @bitCast(self);
    }

    pub fn from(self: std_windows.RECT) RECT {
        return @bitCast(self);
    }
};
pub const POINT = std_windows.POINT;
pub const BOOL = enum(std_windows.BOOL) {
    FALSE = std_windows.FALSE,
    TRUE = std_windows.TRUE,

    pub fn to(self: BOOL) std_windows.BOOL {
        return @bitCast(self);
    }

    pub fn from(self: std_windows.BOOL) BOOL {
        return @bitCast(self);
    }

    pub fn fromBool(value: bool) BOOL {
        return if (value) .TRUE else .FALSE;
    }

    pub fn truthy(self: BOOL) bool {
        return self == .TRUE;
    }
};
pub const UINT_MAX: UINT = 4294967295;
pub const ULONG_PTR = usize;
pub const LONG_PTR = isize;
pub const DWORD_PTR = ULONG_PTR;
pub const DWORD64 = u64;
pub const ULONG64 = u64;
pub const HLOCAL = HANDLE;
pub const LANGID = c_ushort;

pub fn isEqualIID(riid1: *const GUID, riid2: *const GUID) bool {
    return riid1.Data1 == riid2.Data1 and
        riid1.Data2 == riid2.Data2 and
        riid1.Data3 == riid2.Data3 and
        std.mem.eql(u8, riid1.Data4[0..8], riid2.Data4[0..8]);
}

pub const FILETIME = extern struct {
    dwLowDateTime: u32,
    dwHighDateTime: u32,
};

pub const IUnknown = extern union {
    pub const IID: GUID = .parse("{00000000-0000-0000-c000-000000000046}");
    pub const VTable = extern struct {
        QueryInterface: *const fn (
            self: *const IUnknown,
            riid: *const GUID,
            ppvObject: **anyopaque,
        ) callconv(.winapi) HRESULT,
        AddRef: *const fn (
            self: *const IUnknown,
        ) callconv(.winapi) u32,
        Release: *const fn (
            self: *const IUnknown,
        ) callconv(.winapi) u32,
    };
    vtable: *const VTable,
    pub inline fn QueryInterface(self: *const IUnknown, iid: *const GUID, ppvObject: **anyopaque) HRESULT {
        return self.vtable.QueryInterface(self, iid, ppvObject);
    }
    pub inline fn AddRef(self: *const IUnknown) u32 {
        return self.vtable.AddRef(self);
    }
    pub inline fn Release(self: *const IUnknown) u32 {
        return self.vtable.Release(self);
    }
};

pub fn uuidof(comptime T: type) GUID {
    return T.IID;
}

pub fn riid(comptime T: type) *const GUID {
    return &T.IID;
}

// win32 api functions
pub const ERROR_SUCCESS = @as(LONG, 0);
pub const ERROR_DEVICE_NOT_CONNECTED = @as(LONG, 1167);
pub const ERROR_EMPTY = @as(LONG, 4306);

pub const SEVERITY_SUCCESS = 0;
pub const SEVERITY_ERROR = 1;

pub fn MAKE_HRESULT(severity: LONG, facility: LONG, value: LONG) HRESULT {
    return @as(HRESULT, (severity << 31) | (facility << 16) | value);
}

pub const CW_USEDEFAULT = @as(i32, @bitCast(@as(u32, 0x80000000)));

pub const MINMAXINFO = extern struct {
    ptReserved: POINT,
    ptMaxSize: POINT,
    ptMaxPosition: POINT,
    ptMinTrackSize: POINT,
    ptMaxTrackSize: POINT,
};

pub extern "user32" fn SetProcessDPIAware() callconv(.winapi) BOOL;

pub extern "user32" fn GetClientRect(HWND, *RECT) callconv(.winapi) BOOL;

pub extern "user32" fn SetWindowTextW(hWnd: ?HWND, lpString: LPCWSTR) callconv(.winapi) BOOL;

pub extern "user32" fn GetAsyncKeyState(vKey: c_int) callconv(.winapi) SHORT;

pub extern "user32" fn GetKeyState(vKey: c_int) callconv(.winapi) SHORT;

pub extern "user32" fn LoadCursorW(hInstance: ?HINSTANCE, lpCursorName: ResourceNamePtrW) callconv(.winapi) ?HCURSOR;

pub const TME_LEAVE = 0x00000002;

pub const TRACKMOUSEEVENT = extern struct {
    cbSize: DWORD,
    dwFlags: DWORD,
    hwndTrack: ?HWND,
    dwHoverTime: DWORD,
};
pub extern "user32" fn TrackMouseEvent(event: *TRACKMOUSEEVENT) callconv(.winapi) BOOL;

pub extern "user32" fn SetCapture(hWnd: ?HWND) callconv(.winapi) ?HWND;

pub extern "user32" fn GetCapture() callconv(.winapi) ?HWND;

pub extern "user32" fn ReleaseCapture() callconv(.winapi) BOOL;

pub extern "user32" fn GetForegroundWindow() callconv(.winapi) ?HWND;

pub extern "user32" fn IsChild(hWndParent: ?HWND, hWnd: ?HWND) callconv(.winapi) BOOL;

pub extern "user32" fn GetCursorPos(point: *POINT) callconv(.winapi) BOOL;

pub extern "user32" fn ScreenToClient(hWnd: ?HWND, lpPoint: *POINT) callconv(.winapi) BOOL;

pub extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(.winapi) ATOM;

pub extern "user32" fn GetWindowLongPtrW(hWnd: ?HWND, nIndex: INT) callconv(.winapi) ?*anyopaque;

pub extern "user32" fn SetWindowLongPtrW(hWnd: ?HWND, nIndex: INT, dwNewLong: ?*anyopaque) callconv(.winapi) LONG_PTR;

pub extern "user32" fn AdjustWindowRectEx(
    lpRect: *RECT,
    dwStyle: DWORD,
    bMenu: BOOL,
    dwExStyle: DWORD,
) callconv(.winapi) BOOL;

pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: ?LPCWSTR,
    lpWindowName: ?LPCWSTR,
    dwStyle: DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWindParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: HINSTANCE,
    lpParam: ?LPVOID,
) callconv(.winapi) ?HWND;

pub extern "user32" fn DestroyWindow(hWnd: HWND) BOOL;

pub extern "user32" fn MoveWindow(
    hWnd: HWND,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    bRepaint: BOOL,
) callconv(.winapi) BOOL;

pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;

pub extern "user32" fn DefWindowProcW(
    hWnd: HWND,
    Msg: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

pub const PM_NOREMOVE = 0x0000;
pub const PM_REMOVE = 0x0001;
pub const PM_NOYIELD = 0x0002;

pub extern "user32" fn PeekMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: UINT,
    wMsgFilterMax: UINT,
    wRemoveMsg: UINT,
) callconv(.winapi) BOOL;

pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;

pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;

pub extern "user32" fn SetTimer(
    hWnd: ?HWND,
    nIDEvent: usize,
    uElapse: UINT,
    lpTimerFunc: ?*const fn (
        hwnd: ?HWND,
        uMsg: UINT,
        idEvent: usize,
        dwTime: DWORD,
    ) callconv(.winapi) void,
) callconv(.winapi) usize;

pub extern "user32" fn ShowWindow(hWnd: ?HWND, nCmdShow: SHOW_WINDOW_CMD) callconv(.winapi) BOOL;

pub const MB_OK = 0x00000000;
pub const MB_ICONHAND = 0x00000010;
pub const MB_ICONERROR = MB_ICONHAND;

pub extern "user32" fn MessageBoxW(
    hWnd: ?HWND,
    lpText: LPCWSTR,
    lpCaption: LPCWSTR,
    uType: UINT,
) callconv(.winapi) i32;

pub const KNOWNFOLDERID = GUID;

pub const FOLDERID_LocalAppData = GUID.parse("{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}");
pub const FOLDERID_ProgramFiles = GUID.parse("{905e63b6-c1bf-494e-b29c-65b732d3d21a}");

pub const KF_FLAG_DEFAULT = 0;
pub const KF_FLAG_NO_APPCONTAINER_REDIRECTION = 65536;
pub const KF_FLAG_CREATE = 32768;
pub const KF_FLAG_DONT_VERIFY = 16384;
pub const KF_FLAG_DONT_UNEXPAND = 8192;
pub const KF_FLAG_NO_ALIAS = 4096;
pub const KF_FLAG_INIT = 2048;
pub const KF_FLAG_DEFAULT_PATH = 1024;
pub const KF_FLAG_NOT_PARENT_RELATIVE = 512;
pub const KF_FLAG_SIMPLE_IDLIST = 256;
pub const KF_FLAG_ALIAS_ONLY = -2147483648;

pub extern "shell32" fn SHGetKnownFolderPath(
    rfid: *const KNOWNFOLDERID,
    dwFlags: DWORD,
    hToken: ?HANDLE,
    ppszPath: *[*:0]WCHAR,
) callconv(.winapi) HRESULT;

pub const WS_BORDER = 0x00800000;
pub const WS_OVERLAPPED = 0x00000000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_DLGFRAME = 0x00400000;
pub const WS_CAPTION = WS_BORDER | WS_DLGFRAME;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_GROUP = WS_MINIMIZEBOX;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_TABSTOP = WS_MAXIMIZEBOX;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME |
    WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
pub const WS_VISIBLE = 0x10000000;
pub const WS_POPUP = 0x80000000;

pub const WM_MOUSEMOVE = 0x0200;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_LBUTTONDBLCLK = 0x0203;
pub const WM_RBUTTONDOWN = 0x0204;
pub const WM_RBUTTONUP = 0x0205;
pub const WM_RBUTTONDBLCLK = 0x0206;
pub const WM_MBUTTONDOWN = 0x0207;
pub const WM_MBUTTONUP = 0x0208;
pub const WM_MBUTTONDBLCLK = 0x0209;
pub const WM_MOUSEWHEEL = 0x020A;
pub const WM_MOUSELEAVE = 0x02A3;
pub const WM_INPUT = 0x00FF;
pub const WM_KEYDOWN = 0x0100;
pub const WM_KEYUP = 0x0101;
pub const WM_CHAR = 0x0102;
pub const WM_SYSKEYDOWN = 0x0104;
pub const WM_SYSKEYUP = 0x0105;
pub const WM_SETFOCUS = 0x0007;
pub const WM_KILLFOCUS = 0x0008;
pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_MOVE = 0x0003;
pub const WM_SIZE = 0x0005;
pub const WM_ACTIVATE = 0x0006;
pub const WM_ENABLE = 0x000A;
pub const WM_PAINT = 0x000F;
pub const WM_TIMER = 0x0113;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_GETMINMAXINFO = 0x0024;

pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?LPCWSTR) callconv(.winapi) ?HMODULE;

pub extern "kernel32" fn LoadLibraryW(lpLibFileName: LPCWSTR) callconv(.winapi) ?HMODULE;

pub extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: LPCSTR) callconv(.winapi) ?FARPROC;

pub extern "kernel32" fn FreeLibrary(hModule: HMODULE) callconv(.winapi) BOOL;

pub extern "kernel32" fn ExitProcess(exit_code: UINT) callconv(.winapi) noreturn;

pub const PTHREAD_START_ROUTINE = *const fn (LPVOID) callconv(.C) DWORD;
pub const LPTHREAD_START_ROUTINE = PTHREAD_START_ROUTINE;

pub extern "kernel32" fn CreateThread(
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    dwStackSize: SIZE_T,
    lpStartAddress: LPTHREAD_START_ROUTINE,
    lpParameter: ?LPVOID,
    dwCreationFlags: DWORD,
    lpThreadId: ?*DWORD,
) callconv(.winapi) ?HANDLE;

pub extern "kernel32" fn CreateEventExW(
    lpEventAttributes: ?*SECURITY_ATTRIBUTES,
    lpName: LPCWSTR,
    dwFlags: DWORD,
    dwDesiredAccess: DWORD,
) callconv(.winapi) ?HANDLE;

pub extern "kernel32" fn InitializeCriticalSection(lpCriticalSection: *CRITICAL_SECTION) callconv(.winapi) void;
pub extern "kernel32" fn EnterCriticalSection(lpCriticalSection: *CRITICAL_SECTION) callconv(.winapi) void;
pub extern "kernel32" fn LeaveCriticalSection(lpCriticalSection: *CRITICAL_SECTION) callconv(.winapi) void;
pub extern "kernel32" fn DeleteCriticalSection(lpCriticalSection: *CRITICAL_SECTION) callconv(.winapi) void;

pub extern "kernel32" fn Sleep(dwMilliseconds: DWORD) void;

pub extern "ntdll" fn RtlGetVersion(lpVersionInformation: *OSVERSIONINFOW) callconv(.winapi) NTSTATUS;

pub const WNDPROC = *const fn (hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;

pub const MSG = extern struct {
    hWnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?LPCWSTR,
    lpszClassName: LPCWSTR,
    hIconSm: ?HICON,
};

pub const CS_HREDRAW = 0x0002;
pub const CS_VREDRAW = 0x0001;

pub const OSVERSIONINFOW = extern struct {
    dwOSVersionInfoSize: ULONG,
    dwMajorVersion: ULONG,
    dwMinorVersion: ULONG,
    dwBuildNumber: ULONG,
    dwPlatformId: ULONG,
    szCSDVersion: [128]WCHAR,
};

pub const INT8 = i8;
pub const UINT8 = u8;
pub const UINT16 = c_ushort;
pub const UINT32 = c_uint;
pub const UINT64 = c_ulonglong;
pub const HMONITOR = HANDLE;
pub const REFERENCE_TIME = c_longlong;

pub const VT_UI4 = 19;
pub const VT_I8 = 20;
pub const VT_UI8 = 21;
pub const VT_INT = 22;
pub const VT_UINT = 23;

pub const VARTYPE = u16;

pub const PROPVARIANT = extern struct {
    vt: VARTYPE,
    wReserved1: WORD = 0,
    wReserved2: WORD = 0,
    wReserved3: WORD = 0,
    u: extern union {
        intVal: i32,
        uintVal: u32,
        hVal: i64,
    },
    decVal: u64 = 0,
};
comptime {
    std.debug.assert(@sizeOf(PROPVARIANT) == 24);
}

pub const WHEEL_DELTA = 120;

pub inline fn GET_WHEEL_DELTA_WPARAM(wparam: WPARAM) i16 {
    return @as(i16, @bitCast(@as(u16, @intCast((wparam >> 16) & 0xffff))));
}

pub inline fn GET_X_LPARAM(lparam: LPARAM) i32 {
    return @as(i32, @intCast(@as(i16, @bitCast(@as(u16, @intCast(lparam & 0xffff))))));
}

pub inline fn GET_Y_LPARAM(lparam: LPARAM) i32 {
    return @as(i32, @intCast(@as(i16, @bitCast(@as(u16, @intCast((lparam >> 16) & 0xffff))))));
}

pub inline fn LOWORD(dword: DWORD) WORD {
    return @as(WORD, @bitCast(@as(u16, @intCast(dword & 0xffff))));
}

pub inline fn HIWORD(dword: DWORD) WORD {
    return @as(WORD, @bitCast(@as(u16, @intCast((dword >> 16) & 0xffff))));
}

const ResourceNamePtrW = [*:0]align(1) const WCHAR;
pub fn makeIntResourceW(id: u16) ResourceNamePtrW {
    return @ptrFromInt(@as(usize, id));
}

pub const IDC_ARROW = makeIntResourceW(32512);
pub const IDC_IBEAM = makeIntResourceW(32513);
pub const IDC_WAIT = makeIntResourceW(32514);
pub const IDC_CROSS = makeIntResourceW(32515);
pub const IDC_UPARROW = makeIntResourceW(32516);
pub const IDC_SIZENWSE = makeIntResourceW(32642);
pub const IDC_SIZENESW = makeIntResourceW(32643);
pub const IDC_SIZEWE = makeIntResourceW(32644);
pub const IDC_SIZENS = makeIntResourceW(32645);
pub const IDC_SIZEALL = makeIntResourceW(32646);
pub const IDC_NO = makeIntResourceW(32648);
pub const IDC_HAND = makeIntResourceW(32649);
pub const IDC_APPSTARTING = makeIntResourceW(32650);
pub const IDC_HELP = makeIntResourceW(32651);
pub const IDC_PIN = makeIntResourceW(32671);
pub const IDC_PERSON = makeIntResourceW(32672);

pub const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub const GWLP_USERDATA = -21;

pub const VK_LBUTTON = 0x01;
pub const VK_RBUTTON = 0x02;
pub const VK_TAB = 0x09;
pub const VK_ESCAPE = 0x1B;
pub const VK_LEFT = 0x25;
pub const VK_UP = 0x26;
pub const VK_RIGHT = 0x27;
pub const VK_DOWN = 0x28;
pub const VK_PRIOR = 0x21;
pub const VK_NEXT = 0x22;
pub const VK_END = 0x23;
pub const VK_HOME = 0x24;
pub const VK_DELETE = 0x2E;
pub const VK_BACK = 0x08;
pub const VK_RETURN = 0x0D;
pub const VK_CONTROL = 0x11;
pub const VK_SHIFT = 0x10;
pub const VK_MENU = 0x12;
pub const VK_SPACE = 0x20;
pub const VK_INSERT = 0x2D;
pub const VK_LSHIFT = 0xA0;
pub const VK_RSHIFT = 0xA1;
pub const VK_LCONTROL = 0xA2;
pub const VK_RCONTROL = 0xA3;
pub const VK_LMENU = 0xA4;
pub const VK_RMENU = 0xA5;
pub const VK_LWIN = 0x5B;
pub const VK_RWIN = 0x5C;
pub const VK_APPS = 0x5D;
pub const VK_OEM_1 = 0xBA;
pub const VK_OEM_PLUS = 0xBB;
pub const VK_OEM_COMMA = 0xBC;
pub const VK_OEM_MINUS = 0xBD;
pub const VK_OEM_PERIOD = 0xBE;
pub const VK_OEM_2 = 0xBF;
pub const VK_OEM_3 = 0xC0;
pub const VK_OEM_4 = 0xDB;
pub const VK_OEM_5 = 0xDC;
pub const VK_OEM_6 = 0xDD;
pub const VK_OEM_7 = 0xDE;
pub const VK_CAPITAL = 0x14;
pub const VK_SCROLL = 0x91;
pub const VK_NUMLOCK = 0x90;
pub const VK_SNAPSHOT = 0x2C;
pub const VK_PAUSE = 0x13;
pub const VK_NUMPAD0 = 0x60;
pub const VK_NUMPAD1 = 0x61;
pub const VK_NUMPAD2 = 0x62;
pub const VK_NUMPAD3 = 0x63;
pub const VK_NUMPAD4 = 0x64;
pub const VK_NUMPAD5 = 0x65;
pub const VK_NUMPAD6 = 0x66;
pub const VK_NUMPAD7 = 0x67;
pub const VK_NUMPAD8 = 0x68;
pub const VK_NUMPAD9 = 0x69;
pub const VK_MULTIPLY = 0x6A;
pub const VK_ADD = 0x6B;
pub const VK_SEPARATOR = 0x6C;
pub const VK_SUBTRACT = 0x6D;
pub const VK_DECIMAL = 0x6E;
pub const VK_DIVIDE = 0x6F;
pub const VK_F1 = 0x70;
pub const VK_F2 = 0x71;
pub const VK_F3 = 0x72;
pub const VK_F4 = 0x73;
pub const VK_F5 = 0x74;
pub const VK_F6 = 0x75;
pub const VK_F7 = 0x76;
pub const VK_F8 = 0x77;
pub const VK_F9 = 0x78;
pub const VK_F10 = 0x79;
pub const VK_F11 = 0x7A;
pub const VK_F12 = 0x7B;

pub const MONITOR_FROM_FLAGS = enum(u32) {
    NEAREST = 2,
    NULL = 0,
    PRIMARY = 1,
};

pub extern "user32" fn MonitorFromWindow(
    hwnd: ?HWND,
    dwFlags: MONITOR_FROM_FLAGS,
) callconv(.winapi) ?HMONITOR;

pub const MONITORINFO = extern struct {
    cbSize: u32,
    rcMonitor: RECT,
    rcWork: RECT,
    dwFlags: u32,
};

pub extern "user32" fn GetMonitorInfoW(
    hMonitor: ?HMONITOR,
    lpmi: ?*MONITORINFO,
) callconv(.winapi) BOOL;

pub const SET_WINDOW_POS_FLAGS = packed struct(u32) {
    NOSIZE: bool = false,
    NOMOVE: bool = false,
    NOZORDER: bool = false,
    NOREDRAW: bool = false,
    NOACTIVATE: bool = false,
    DRAWFRAME: bool = false,
    SHOWWINDOW: bool = false,
    HIDEWINDOW: bool = false,
    NOCOPYBITS: bool = false,
    NOOWNERZORDER: bool = false,
    NOSENDCHANGING: bool = false,
    _11: bool = false,
    _12: bool = false,
    DEFERERASE: bool = false,
    ASYNCWINDOWPOS: bool = false,
    _15: bool = false,
    _16: bool = false,
    _17: bool = false,
    _18: bool = false,
    _19: bool = false,
    _20: bool = false,
    _21: bool = false,
    _22: bool = false,
    _23: bool = false,
    _24: bool = false,
    _25: bool = false,
    _26: bool = false,
    _27: bool = false,
    _28: bool = false,
    _29: bool = false,
    _30: bool = false,
    _31: bool = false,
    // FRAMECHANGED (bit index 5) conflicts with DRAWFRAME
    // NOREPOSITION (bit index 9) conflicts with NOOWNERZORDER
};

pub extern "user32" fn SetWindowPos(
    hWnd: ?HWND,
    hWndInsertAfter: ?HWND,
    X: i32,
    Y: i32,
    cx: i32,
    cy: i32,
    uFlags: SET_WINDOW_POS_FLAGS,
) callconv(.winapi) BOOL;

pub const HWND_TOPMOST: ?HWND = @ptrFromInt(std.math.maxInt(usize));

pub const WINDOW_LONG_PTR_INDEX = enum(i32) {
    _EXSTYLE = -20,
    P_HINSTANCE = -6,
    P_HWNDPARENT = -8,
    P_ID = -12,
    _STYLE = -16,
    P_USERDATA = -21,
    P_WNDPROC = -4,
    _,
    pub const _HINSTANCE = .P_HINSTANCE;
    pub const _ID = .P_ID;
    pub const _USERDATA = .P_USERDATA;
    pub const _WNDPROC = .P_WNDPROC;
    pub const _HWNDPARENT = .P_HWNDPARENT;
    pub fn tagName(self: WINDOW_LONG_PTR_INDEX) ?[:0]const u8 {
        return switch (self) {
            ._EXSTYLE => "_EXSTYLE",
            .P_HINSTANCE => "P_HINSTANCE",
            .P_HWNDPARENT => "P_HWNDPARENT",
            .P_ID => "P_ID",
            ._STYLE => "_STYLE",
            .P_USERDATA => "P_USERDATA",
            .P_WNDPROC => "P_WNDPROC",
            else => null,
        };
    }
    pub const format = if (@import("builtin").zig_version.order(.{ .major = 0, .minor = 15, .patch = 0 }) == .lt)
        formatLegacy
    else
        formatNew;
    fn formatLegacy(
        self: WINDOW_LONG_PTR_INDEX,
        comptime fmt: []const u8,
        options: @import("std").fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}({})", .{ self.value.tagName() orelse "?", @intFromEnum(self.value) });
    }
    fn formatNew(self: WINDOW_LONG_PTR_INDEX, writer: *@import("std").Io.Writer) @import("std").Io.Writer.Error!void {
        try writer.print("{s}({})", .{ self.value.tagName() orelse "?", @intFromEnum(self.value) });
    }
};

pub extern "user32" fn SetWindowLongW(
    hWnd: ?HWND,
    nIndex: WINDOW_LONG_PTR_INDEX,
    dwNewLong: LONG,
) callconv(.winapi) i32;

pub extern "user32" fn GetWindowLongW(hWnd: ?HWND, nIndex: WINDOW_LONG_PTR_INDEX) callconv(.winapi) i32;

pub const SHOW_WINDOW_CMD = packed struct(u32) {
    SHOWNORMAL: u1 = 0,
    SHOWMINIMIZED: u1 = 0,
    SHOWNOACTIVATE: u1 = 0,
    SHOWNA: u1 = 0,
    SMOOTHSCROLL: u1 = 0,
    _5: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
    // NORMAL (bit index 0) conflicts with SHOWNORMAL
    // PARENTCLOSING (bit index 0) conflicts with SHOWNORMAL
    // OTHERZOOM (bit index 1) conflicts with SHOWMINIMIZED
    // OTHERUNZOOM (bit index 2) conflicts with SHOWNOACTIVATE
    // SCROLLCHILDREN (bit index 0) conflicts with SHOWNORMAL
    // INVALIDATE (bit index 1) conflicts with SHOWMINIMIZED
    // ERASE (bit index 2) conflicts with SHOWNOACTIVATE
};
pub const SW_FORCEMINIMIZE = SHOW_WINDOW_CMD{
    .SHOWNORMAL = 1,
    .SHOWMINIMIZED = 1,
    .SHOWNA = 1,
};
pub const SW_HIDE = SHOW_WINDOW_CMD{};
pub const SW_MAXIMIZE = SHOW_WINDOW_CMD{
    .SHOWNORMAL = 1,
    .SHOWMINIMIZED = 1,
};
pub const SW_MINIMIZE = SHOW_WINDOW_CMD{
    .SHOWMINIMIZED = 1,
    .SHOWNOACTIVATE = 1,
};
pub const SW_RESTORE = SHOW_WINDOW_CMD{
    .SHOWNORMAL = 1,
    .SHOWNA = 1,
};
pub const SW_SHOW = SHOW_WINDOW_CMD{
    .SHOWNORMAL = 1,
    .SHOWNOACTIVATE = 1,
};
pub const SW_SHOWDEFAULT = SHOW_WINDOW_CMD{
    .SHOWMINIMIZED = 1,
    .SHOWNA = 1,
};
pub const SW_SHOWMAXIMIZED = SHOW_WINDOW_CMD{
    .SHOWNORMAL = 1,
    .SHOWMINIMIZED = 1,
};
pub const SW_SHOWMINIMIZED = SHOW_WINDOW_CMD{ .SHOWMINIMIZED = 1 };
pub const SW_SHOWMINNOACTIVE = SHOW_WINDOW_CMD{
    .SHOWNORMAL = 1,
    .SHOWMINIMIZED = 1,
    .SHOWNOACTIVATE = 1,
};
pub const SW_SHOWNA = SHOW_WINDOW_CMD{ .SHOWNA = 1 };
pub const SW_SHOWNOACTIVATE = SHOW_WINDOW_CMD{ .SHOWNOACTIVATE = 1 };
pub const SW_SHOWNORMAL = SHOW_WINDOW_CMD{ .SHOWNORMAL = 1 };
pub const SW_NORMAL = SHOW_WINDOW_CMD{ .SHOWNORMAL = 1 };
pub const SW_MAX = SHOW_WINDOW_CMD{
    .SHOWNORMAL = 1,
    .SHOWMINIMIZED = 1,
    .SHOWNA = 1,
};
pub const SW_PARENTCLOSING = SHOW_WINDOW_CMD{ .SHOWNORMAL = 1 };
pub const SW_OTHERZOOM = SHOW_WINDOW_CMD{ .SHOWMINIMIZED = 1 };
pub const SW_PARENTOPENING = SHOW_WINDOW_CMD{
    .SHOWNORMAL = 1,
    .SHOWMINIMIZED = 1,
};
pub const SW_OTHERUNZOOM = SHOW_WINDOW_CMD{ .SHOWNOACTIVATE = 1 };
pub const SW_SCROLLCHILDREN = SHOW_WINDOW_CMD{ .SHOWNORMAL = 1 };
pub const SW_INVALIDATE = SHOW_WINDOW_CMD{ .SHOWMINIMIZED = 1 };
pub const SW_ERASE = SHOW_WINDOW_CMD{ .SHOWNOACTIVATE = 1 };
pub const SW_SMOOTHSCROLL = SHOW_WINDOW_CMD{ .SMOOTHSCROLL = 1 };

pub const WINDOWPLACEMENT = extern struct {
    length: u32,
    flags: WINDOWPLACEMENT_FLAGS,
    showCmd: SHOW_WINDOW_CMD,
    ptMinPosition: POINT,
    ptMaxPosition: POINT,
    rcNormalPosition: RECT,
};

pub const WINDOWPLACEMENT_FLAGS = packed struct(u32) {
    SETMINPOSITION: u1 = 0,
    RESTORETOMAXIMIZED: u1 = 0,
    ASYNCWINDOWPLACEMENT: u1 = 0,
    _3: u1 = 0,
    _4: u1 = 0,
    _5: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};

pub extern "user32" fn GetWindowPlacement(
    hWnd: ?HWND,
    lpwndpl: ?*WINDOWPLACEMENT,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetWindowPlacement(
    hWnd: ?HWND,
    lpwndpl: ?*const WINDOWPLACEMENT,
) callconv(.winapi) BOOL;

pub const HRGN = HANDLE;
pub extern "gdi32" fn CreateRectRgn(
    nLeftRect: i32,
    nTopRect: i32,
    nRightRect: i32,
    nBottomRect: i32,
) callconv(.winapi) HRGN;
pub extern "gdi32" fn DeleteObject(hObject: HANDLE) callconv(.winapi) BOOL;

pub extern "user32" fn RedrawWindow(
    hWnd: ?HWND,
    lprcUpdate: ?*const RECT,
    hrgnUpdate: ?HRGN,
    flags: DWORD,
) callconv(.winapi) BOOL;

pub const RDW_INVALIDATE: DWORD = 0x0001;
pub const RDW_INTERNALPAINT: DWORD = 0x0002;
pub const RDW_ERASE: DWORD = 0x0004;

pub const RDW_VALIDATE: DWORD = 0x0008;
pub const RDW_NOINTERNALPAINT: DWORD = 0x0010;
pub const RDW_NOERASE: DWORD = 0x0020;

pub const RDW_NOCHILDREN: DWORD = 0x0040;
pub const RDW_ALLCHILDREN: DWORD = 0x0080;

pub const RDW_UPDATENOW: DWORD = 0x0100;
pub const RDW_ERASENOW: DWORD = 0x0200;

pub const RDW_FRAME: DWORD = 0x0400;
pub const RDW_NOFRAME: DWORD = 0x0800;

// error reporting
pub fn hresultMessage(buf: []u8, hr: HRESULT) ![]u8 {
    var buf_wstr: [614:0]WCHAR = undefined;
    const len = FormatMessageW(
        std_windows.FORMAT_MESSAGE_FROM_SYSTEM | std_windows.FORMAT_MESSAGE_IGNORE_INSERTS,
        null,
        hr,
        MAKELANGID(std_windows.LANG.NEUTRAL, std_windows.SUBLANG.DEFAULT),
        &buf_wstr,
        buf_wstr.len,
        null,
    );

    _ = try std.unicode.utf16LeToUtf8(buf, buf_wstr[0..len]);
    return buf[0..len];
}

pub extern "kernel32" fn FormatMessageW(
    dwFlags: DWORD,
    lpSource: ?LPCVOID,
    dwMessageId: c_long,
    dwLanguageId: DWORD,
    lpBuffer: LPWSTR,
    nSize: DWORD,
    Arguments: ?*std_windows.va_list,
) callconv(.winapi) DWORD;

pub fn MAKELANGID(p: c_ushort, s: c_ushort) LANGID {
    return (s << 10) | p;
}

const HresultFormatData = struct {
    hr: HRESULT,
    kind: Kind,

    pub const Kind = enum { code_message, only_message, only_code };
};

fn formatHresultMessage(data: HresultFormatData, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    var buf: [614]u8 = undefined;
    const msg = hresultMessage(&buf, data.hr) catch return error.WriteFailed;
    var needs_separator = false;
    if (data.kind == .code_message or data.kind == .only_code) {
        try writer.printInt(data.hr, 16, .lower, .{});
        needs_separator = true;
    }
    if (data.kind == .code_message) {
        if (needs_separator) {
            try writer.writeAll(" - ");
        }
        needs_separator = true;
        try writer.writeAll(msg);
    }
}

///
pub fn fmtHresult(
    hr: HRESULT,
    kind: HresultFormatData.Kind,
) std.fmt.Alt(HresultFormatData, formatHresultMessage) {
    return .{ .data = .{ .hr = hr, .kind = kind } };
}

pub extern "user32" fn ValidateRect(hWnd: ?HWND, lpRect: ?*const RECT) callconv(.winapi) BOOL;

pub extern "user32" fn InvalidateRect(hWnd: ?HWND, lpRect: ?*const RECT, bErase: BOOL) callconv(.winapi) BOOL;

pub const IMalloc = extern union {
    pub const IID: GUID = .parse("{00000002-0000-0000-c000-000000000046}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Alloc: *const fn (*IMalloc, SIZE_T) callconv(.winapi) void,
        Realloc: *const fn (*IMalloc, ?*anyopaque, SIZE_T) callconv(.winapi) void,
        Free: *const fn (*IMalloc, ?*anyopaque) callconv(.winapi) void,
        GetSize: *const fn (*IMalloc, ?*anyopaque) callconv(.winapi) SIZE_T,
        DidAlloc: *const fn (*IMalloc, ?*anyopaque) callconv(.winapi) i32,
        HeapMinimize: *const fn (*IMalloc) callconv(.winapi) void,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn Alloc(self: *IMalloc, size: SIZE_T) ?*anyopaque {
        return self.vtable.Alloc(self, size);
    }

    pub inline fn Free(self: *IMalloc, p: ?*anyopaque) void {
        self.vtable.Free(self, p);
    }

    pub inline fn GetSize(self: *IMalloc, p: ?*anyopaque) SIZE_T {
        return self.vtable.GetSize(self, p);
    }

    pub inline fn DidAlloc(self: *IMalloc, p: ?*anyopaque) i32 {
        return self.vtable.DidAlloc(self, p);
    }

    pub inline fn HeapMinimize(self: *IMalloc) void {
        self.vtable.HeapMinimize(self);
    }
};

pub const ISequentialStream = extern union {
    pub const IID: GUID = .parse("{0c733a30-2a1c-11ce-ade5-00aa0044773d}");
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Read: *const fn (
            self: *const ISequentialStream,
            pv: ?*anyopaque,
            cb: u32,
            pcbRead: ?*u32,
        ) callconv(.winapi) HRESULT,
        Write: *const fn (
            self: *const ISequentialStream,
            pv: ?*const anyopaque,
            cb: u32,
            pcbWritten: ?*u32,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    iunknown: IUnknown,

    pub inline fn Read(self: *const ISequentialStream, pv: ?*anyopaque, cb: u32, pcbRead: ?*u32) HRESULT {
        return self.vtable.Read(self, pv, cb, pcbRead);
    }

    pub inline fn Write(self: *const ISequentialStream, pv: ?*const anyopaque, cb: u32, pcbWritten: ?*u32) HRESULT {
        return self.vtable.Write(self, pv, cb, pcbWritten);
    }
};

pub const STATSTG = extern struct {
    pwcsName: ?PWSTR,
    type: u32,
    cbSize: ULARGE_INTEGER,
    mtime: FILETIME,
    ctime: FILETIME,
    atime: FILETIME,
    grfMode: u32,
    grfLocksSupported: u32,
    clsid: GUID,
    grfStateBits: u32,
    reserved: u32,
};

pub const STGC = packed struct(u32) {
    OVERWRITE: u1 = 0,
    ONLYIFCURRENT: u1 = 0,
    DANGEROUSLYCOMMITMERELYTODISKCACHE: u1 = 0,
    CONSOLIDATE: u1 = 0,
    _4: u1 = 0,
    _5: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};

pub const STREAM_SEEK = enum(u32) {
    SET = 0,
    CUR = 1,
    END = 2,
};

pub const IStream = extern union {
    pub const IID: GUID = .parse("{0000000c-0000-0000-c000-000000000046}");
    pub const VTable = extern struct {
        base: ISequentialStream.VTable,
        Seek: *const fn (
            self: *const IStream,
            dlibMove: LARGE_INTEGER,
            dwOrigin: STREAM_SEEK,
            plibNewPosition: ?*ULARGE_INTEGER,
        ) callconv(.winapi) HRESULT,
        SetSize: *const fn (
            self: *const IStream,
            libNewSize: ULARGE_INTEGER,
        ) callconv(.winapi) HRESULT,
        CopyTo: *const fn (
            self: *const IStream,
            pstm: ?*IStream,
            cb: ULARGE_INTEGER,
            pcbRead: ?*ULARGE_INTEGER,
            pcbWritten: ?*ULARGE_INTEGER,
        ) callconv(.winapi) HRESULT,
        Commit: *const fn (
            self: *const IStream,
            grfCommitFlags: STGC,
        ) callconv(.winapi) HRESULT,
        Revert: *const fn (
            self: *const IStream,
        ) callconv(.winapi) HRESULT,
        LockRegion: *const fn (
            self: *const IStream,
            libOffset: ULARGE_INTEGER,
            cb: ULARGE_INTEGER,
            dwLockType: u32,
        ) callconv(.winapi) HRESULT,
        UnlockRegion: *const fn (
            self: *const IStream,
            libOffset: ULARGE_INTEGER,
            cb: ULARGE_INTEGER,
            dwLockType: u32,
        ) callconv(.winapi) HRESULT,
        Stat: *const fn (
            self: *const IStream,
            pstatstg: ?*STATSTG,
            grfStatFlag: u32,
        ) callconv(.winapi) HRESULT,
        Clone: *const fn (
            self: *const IStream,
            ppstm: ?*?*IStream,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    isequential_stream: ISequentialStream,
    iunknown: IUnknown,

    pub inline fn Seek(self: *const IStream, dlibMove: LARGE_INTEGER, dwOrigin: STREAM_SEEK, plibNewPosition: ?*ULARGE_INTEGER) HRESULT {
        return self.vtable.Seek(self, dlibMove, dwOrigin, plibNewPosition);
    }
    pub inline fn SetSize(self: *const IStream, libNewSize: ULARGE_INTEGER) HRESULT {
        return self.vtable.SetSize(self, libNewSize);
    }
    pub inline fn CopyTo(self: *const IStream, pstm: ?*IStream, cb: ULARGE_INTEGER, pcbRead: ?*ULARGE_INTEGER, pcbWritten: ?*ULARGE_INTEGER) HRESULT {
        return self.vtable.CopyTo(self, pstm, cb, pcbRead, pcbWritten);
    }
    pub inline fn Commit(self: *const IStream, grfCommitFlags: STGC) HRESULT {
        return self.vtable.Commit(self, grfCommitFlags);
    }
    pub inline fn Revert(self: *const IStream) HRESULT {
        return self.vtable.Revert(self);
    }
    pub inline fn LockRegion(self: *const IStream, libOffset: ULARGE_INTEGER, cb: ULARGE_INTEGER, dwLockType: u32) HRESULT {
        return self.vtable.LockRegion(self, libOffset, cb, dwLockType);
    }
    pub inline fn UnlockRegion(self: *const IStream, libOffset: ULARGE_INTEGER, cb: ULARGE_INTEGER, dwLockType: u32) HRESULT {
        return self.vtable.UnlockRegion(self, libOffset, cb, dwLockType);
    }
    pub inline fn Stat(self: *const IStream, pstatstg: ?*STATSTG, grfStatFlag: u32) HRESULT {
        return self.vtable.Stat(self, pstatstg, grfStatFlag);
    }
    pub inline fn Clone(self: *const IStream, ppstm: ?*?*IStream) HRESULT {
        return self.vtable.Clone(self, ppstm);
    }
};
