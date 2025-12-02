const WindowState = struct {
    hwnd: win32.HWND,
    style_options: StyleOptions,
    previous_placement: win32.WINDOWPLACEMENT = undefined,

    platform_window: platform.Window = undefined,

    pub fn fromPlatformWindow(window: *platform.Window) *WindowState {
        return @fieldParentPtr("platform_window", window);
    }

    pub fn toPlatformWindow(state: *WindowState) *platform.Window {
        return &state.platform_window;
    }

    pub fn init(self: *WindowState, options: platform.WindowOptions) !void {
        single_init.call();

        const instance = win32.GetModuleHandleW(null);
        var rect: win32.RECT = .{
            .left = 0,
            .top = 0,
            .right = @intCast(options.width),
            .bottom = @intCast(options.height),
        };

        const style: u32 = getStyle(.{ .resizable = options.resizable, .fullscreen = options.fullscreen });
        _ = win32.AdjustWindowRectEx(&rect, style, .FALSE, 0);

        var title_buf: [256]u16 = undefined;
        const len = std.unicode.utf8ToUtf16Le(&title_buf, options.title) catch @panic("utf");
        title_buf[len] = 0;
        const title_slice = title_buf[0..len :0];

        const hwnd = win32.CreateWindowExW(
            0,
            class_name,
            title_slice.ptr,
            style,
            win32.CW_USEDEFAULT,
            win32.CW_USEDEFAULT,
            rect.right - rect.left,
            rect.bottom - rect.top,
            null,
            null,
            @ptrCast(instance.?),
            null,
        );
        if (hwnd == null) {
            return error.Unknown;
        }

        _ = win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, self);
        _ = win32.SetTimer(hwnd, 1, 16, null);
        // _ = win32.SetWindowPos(hwnd, win32.HWND_TOPMOST, 0, 0, 0, 0, .{ .NOSIZE = true, .NOMOVE = true });

        self.* = .{
            .hwnd = hwnd.?,
            .style_options = .{
                .resizable = options.resizable,
                .fullscreen = options.fullscreen,
            },
            .platform_window = .{
                .vtable = &.{
                    .deinit = impl.deinitWindow,
                    .setTitle = impl.setWindowTitle,
                    .setFullscreen = impl.setWindowFullscreen,
                },
                .window_handle = @ptrCast(self.hwnd),
            },
        };
    }

    pub fn deinit(self: *WindowState) void {
        _ = win32.DestroyWindow(self.hwnd);
    }

    pub fn setWindowTitle(self: *WindowState, title: []const u8) platform.Error!void {
        var title_buf: [256]u16 = undefined;
        const len = std.unicode.utf8ToUtf16Le(&title_buf, title) catch return error.OutOfMemory;
        title_buf[len] = 0;
        const title_slice = title_buf[0..len :0];
        if (win32.SetWindowTextW(self.hwnd, title_slice.ptr) == .FALSE) {
            return error.Unknown;
        }
    }

    pub fn setWindowFullscreen(self: *WindowState, fullscreen: bool) platform.Error!void {
        self.style_options.fullscreen = fullscreen;
        const style = getStyle(self.style_options);
        if (win32.SetWindowLongW(self.hwnd, ._STYLE, @bitCast(style)) == 0) {
            return error.Unknown;
        }
        if (fullscreen) {
            self.previous_placement.length = @sizeOf(win32.WINDOWPLACEMENT);
            _ = win32.GetWindowPlacement(self.hwnd, &self.previous_placement);

            const monitor = win32.MonitorFromWindow(self.hwnd, .NEAREST);
            var monitor_info: win32.MONITORINFO = .{
                .cbSize = @sizeOf(win32.MONITORINFO),
                .rcWork = undefined,
                .rcMonitor = undefined,
                .dwFlags = 0,
            };
            _ = win32.GetMonitorInfoW(monitor, &monitor_info);
            if (win32.SetWindowPos(
                self.hwnd,
                null,
                monitor_info.rcMonitor.left,
                monitor_info.rcMonitor.top,
                monitor_info.rcMonitor.right - monitor_info.rcMonitor.left,
                monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top,
                .{
                    .NOZORDER = true,
                    .DRAWFRAME = true, // FRAMECHANGED
                },
            ) == .FALSE) {
                return error.Unknown;
            }
        } else {
            _ = win32.SetWindowPlacement(self.hwnd, &self.previous_placement);
        }
    }
};

const class_name = win32.L("baron");
var single_init = std.once(struct {
    fn do() void {
        if (win32.SetProcessDPIAware() == .FALSE) {
            @panic("Failed to set process DPI aware");
        }
        const instance = win32.GetModuleHandleW(null);
        const class: win32.WNDCLASSEXW = .{
            .lpfnWndProc = windowProc,
            .lpszClassName = class_name,
            .hInstance = @ptrCast(instance.?),
            .hIcon = null,
            .hCursor = win32.LoadCursorW(null, win32.IDC_ARROW),
            .hbrBackground = null,
            .lpszMenuName = null,
            .style = win32.CS_HREDRAW | win32.CS_VREDRAW,
            .hIconSm = null,
        };
        if (win32.RegisterClassExW(&class) == 0) {
            @panic("Failed to register window class");
        }
    }
}.do);

pub fn initWindow(allocator: std.mem.Allocator, options: platform.WindowOptions) platform.Error!*platform.Window {
    const state = try allocator.create(WindowState);
    errdefer allocator.destroy(state);
    try state.init(options);
    return state.toPlatformWindow();
}

const impl = struct {
    pub fn deinitWindow(window: *platform.Window, allocator: std.mem.Allocator) void {
        const state: *WindowState = .fromPlatformWindow(window);
        state.deinit();
        allocator.destroy(state);
    }

    pub fn setWindowTitle(window: *platform.Window, title: []const u8) platform.Error!void {
        const state: *WindowState = .fromPlatformWindow(window);
        return state.setWindowTitle(title);
    }

    pub fn setWindowFullscreen(window: *platform.Window, fullscreen: bool) platform.Error!void {
        const state: *WindowState = .fromPlatformWindow(window);
        return state.setWindowFullscreen(fullscreen);
    }
};

pub fn processEvents() void {
    var msg: win32.MSG = undefined;
    while (win32.PeekMessageW(&msg, null, 0, 0, win32.PM_REMOVE) == .TRUE) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }
}

const fullscreen_flags: u32 = win32.WS_POPUP | win32.WS_GROUP | win32.WS_VISIBLE;
const resizable_flags: u32 = win32.WS_THICKFRAME | win32.WS_TABSTOP;
const normal_flags: u32 = win32.WS_CAPTION | win32.WS_OVERLAPPED | win32.WS_SYSMENU | win32.WS_GROUP | win32.WS_VISIBLE;

const StyleOptions = struct {
    resizable: bool,
    fullscreen: bool,
};

fn getStyle(options: StyleOptions) u32 {
    if (options.fullscreen) return fullscreen_flags;
    var style: u32 = normal_flags;
    if (options.resizable) {
        style |= resizable_flags;
    }
    return style;
}

fn windowProc(hwnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    const state: *WindowState = @ptrCast(@alignCast(win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA) orelse
        return win32.DefWindowProcW(hwnd, msg, wParam, lParam)));

    const platform_window: *platform.Window = &state.platform_window;

    switch (msg) {
        win32.WM_DESTROY, win32.WM_CLOSE => {
            platform_window.should_close = true;
            return 0;
        },
        win32.WM_KEYDOWN => {
            const key = vkToKey(wParam);
            platform_window.input.keyDown(key);
            return 0;
        },
        win32.WM_KEYUP => {
            const key = vkToKey(wParam);
            platform_window.input.keyUp(key);
            return 0;
        },
        win32.WM_SETFOCUS => {
            return 0;
        },
        win32.WM_KILLFOCUS => {
            platform_window.input.focusLost();
            return 0;
        },
        win32.WM_SIZE => {
            const width = win32.LOWORD(@intCast(lParam));
            const height = win32.HIWORD(@intCast(lParam));
            _ = win32.InvalidateRect(hwnd, null, .FALSE);
            platform_window.resize = .{ .width = @intCast(width), .height = @intCast(height) };
            return 0;
        },
        // win32.WM_PAINT => {},
        win32.WM_PAINT, win32.WM_TIMER => {
            // if (platform_window.tick) |t| {
            //     t(platform_window);
            // }
        },
        else => {},
    }

    return win32.DefWindowProcW(hwnd, msg, wParam, lParam);
}

fn vkToKey(vk: usize) platform.Key {
    return switch (vk) {
        win32.VK_F1 => .f1,
        win32.VK_F2 => .f2,
        win32.VK_F3 => .f3,
        win32.VK_F4 => .f4,
        win32.VK_F5 => .f5,
        win32.VK_F6 => .f6,
        win32.VK_F7 => .f7,
        win32.VK_F8 => .f8,
        win32.VK_F9 => .f9,
        win32.VK_F10 => .f10,
        win32.VK_F11 => .f11,
        win32.VK_F12 => .f12,
        win32.VK_SPACE => .space,
        win32.VK_LEFT => .left,
        win32.VK_RIGHT => .right,
        win32.VK_UP => .up,
        win32.VK_DOWN => .down,
        win32.VK_RETURN => .enter,
        win32.VK_NUMPAD0 => .kp_0,
        win32.VK_NUMPAD1 => .kp_1,
        win32.VK_NUMPAD2 => .kp_2,
        win32.VK_NUMPAD3 => .kp_3,
        win32.VK_NUMPAD4 => .kp_4,
        win32.VK_NUMPAD5 => .kp_5,
        win32.VK_NUMPAD6 => .kp_6,
        win32.VK_NUMPAD7 => .kp_7,
        win32.VK_NUMPAD8 => .kp_8,
        win32.VK_NUMPAD9 => .kp_9,
        win32.VK_BACK => .backspace,
        win32.VK_TAB => .tab,
        win32.VK_ESCAPE => .escape,
        win32.VK_SHIFT, win32.VK_LSHIFT => .left_shift,
        win32.VK_RSHIFT => .right_shift,
        // ascii range
        0x30...0x39, 0x41...0x5A => @enumFromInt(vk),
        else => .unknown,
    };
}

// is in the 8 bits after the first 16 of the lParam
fn extractScancode(lParam: win32.LPARAM) u8 {
    return @intCast((lParam >> 16) & 0xFF);
}

const std = @import("std");
const platform = @import("root.zig");

const win32 = @import("../windows/root.zig").win32;
