const backend = switch (builtin.os.tag) {
    .windows => @import("platform_windows.zig"),
    else => @compileError("Unsupported platform"),
};

pub fn processEvents() void {
    backend.processEvents();
}

pub const WindowInput = struct {
    keys_down: std.EnumSet(Key) = .initEmpty(),
    keys_up: std.EnumSet(Key) = .initEmpty(),
    keys_held: std.EnumSet(Key) = .initEmpty(),

    mouse_x: i32 = 0,
    mouse_y: i32 = 0,
    mouse_buttons_down: std.EnumSet(MouseButton) = .initEmpty(),
    mouse_buttons_up: std.EnumSet(MouseButton) = .initEmpty(),
    mouse_buttons_held: std.EnumSet(MouseButton) = .initEmpty(),

    pub fn clear(self: *WindowInput) void {
        self.keys_down = .initEmpty();
        self.keys_up = .initEmpty();
        self.mouse_buttons_down = .initEmpty();
        self.mouse_buttons_up = .initEmpty();
    }

    pub fn focusLost(self: *WindowInput) void {
        self.keys_up = self.keys_held;
        self.keys_down = .initEmpty();
        self.keys_held = .initEmpty();
        self.mouse_buttons_up = self.mouse_buttons_held;
        self.mouse_buttons_down = .initEmpty();
        self.mouse_buttons_held = .initEmpty();
    }

    pub fn keyDown(self: *WindowInput, key: Key) void {
        if (self.keys_held.contains(key)) {
            return;
        }
        self.keys_down.insert(key);
        self.keys_held.insert(key);
    }

    pub fn keyUp(self: *WindowInput, key: Key) void {
        if (!self.keys_held.contains(key)) {
            return;
        }
        self.keys_up.insert(key);
        self.keys_held.remove(key);
    }
};

pub const Window = struct {
    const QueuedSet = struct {
        fullscreen: ?bool = null,
        title: ?[]const u8 = null,
    };

    input: WindowInput = .{},
    back_input: WindowInput = .{},
    queued_set: QueuedSet = .{},

    should_close: bool = false,

    window_handle: ?*anyopaque = null,
    user_data: ?*anyopaque = null,
    resize: ?Resize = null,
    tick: ?Tick = null,

    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (window: *Window, allocator: std.mem.Allocator) void,
        setTitle: *const fn (window: *Window, title: []const u8) Error!void,
        setFullscreen: *const fn (window: *Window, fullscreen: bool) Error!void,
    };

    pub fn create(allocator: std.mem.Allocator, options: WindowOptions) Error!*Window {
        return backend.initWindow(allocator, options);
    }

    pub fn destroy(self: *Window, allocator: std.mem.Allocator) void {
        self.vtable.deinit(self, allocator);
    }

    pub fn setTitle(self: *Window, title: []const u8) Error!void {
        // try self.vtable.setTitle(self, title);
        self.queued_set.title = title;
    }

    pub fn setFullscreen(self: *Window, fullscreen: bool) Error!void {
        // try self.vtable.setFullscreen(self, fullscreen);
        self.queued_set.fullscreen = fullscreen;
    }

    pub fn popResize(self: *Window) ?Resize {
        defer self.resize = null;
        return self.resize;
    }

    /// to be called before each frame
    pub fn preUpdate(self: *Window) void {
        self.input.clear();
    }

    /// to be called after each frame
    pub fn postUpdate(self: *Window) !void {
        if (self.queued_set.title) |title| {
            try self.vtable.setTitle(self, title);
            self.queued_set.title = null;
        }
        if (self.queued_set.fullscreen) |fullscreen| {
            try self.vtable.setFullscreen(self, fullscreen);
            self.queued_set.fullscreen = null;
        }
        self.back_input = self.input;
    }
};

pub const Resize = struct {
    width: u32,
    height: u32,
};

pub const Tick = *const fn (state: *Window) void;

pub const Error = error{
    OutOfMemory,
    Unknown,
};

pub const WindowOptions = struct {
    width: u32,
    height: u32,
    title: []const u8,
    resizable: bool,
    fullscreen: bool,
};

pub const Key = enum(u32) {
    unknown = 0,
    // printable
    space = 32,
    // '
    apostrophe = 39,
    // ,
    comma = 44,
    // -
    minus = 45,
    // .
    period = 46,
    // /
    slash = 47,
    @"0" = 48,
    @"1" = 49,
    @"2" = 50,
    @"3" = 51,
    @"4" = 52,
    @"5" = 53,
    @"6" = 54,
    @"7" = 55,
    @"8" = 56,
    @"9" = 57,
    // ;
    semicolon = 59,
    // =
    equal = 61,
    A = 'A',
    B = 'B',
    C = 'C',
    D = 'D',
    E = 'E',
    F = 'F',
    G = 'G',
    H = 'H',
    I = 'I',
    J = 'J',
    K = 'K',
    L = 'L',
    M = 'M',
    N = 'N',
    O = 'O',
    P = 'P',
    Q = 'Q',
    R = 'R',
    S = 'S',
    T = 'T',
    U = 'U',
    V = 'V',
    W = 'W',
    X = 'X',
    Y = 'Y',
    Z = 'Z',
    // [
    left_bracket = 91,
    // \
    backslash = 92,
    // ]
    right_bracket = 93,
    // `
    grave_accent = 96,
    // non-US #1
    world_1 = 161,
    // non-US #2
    world_2 = 162,
    // function keys
    escape = 256,
    enter = 257,
    tab = 258,
    backspace = 259,
    insert = 260,
    delete = 261,
    right = 262,
    left = 263,
    down = 264,
    up = 265,
    page_up = 266,
    page_down = 267,
    home = 268,
    end = 269,
    caps_lock = 280,
    scroll_lock = 281,
    num_lock = 282,
    print_screen = 283,
    pause = 284,
    f1 = 290,
    f2 = 291,
    f3 = 292,
    f4 = 293,
    f5 = 294,
    f6 = 295,
    f7 = 296,
    f8 = 297,
    f9 = 298,
    f10 = 299,
    f11 = 300,
    f12 = 301,
    f13 = 302,
    f14 = 303,
    f15 = 304,
    f16 = 305,
    f17 = 306,
    f18 = 307,
    f19 = 308,
    f20 = 309,
    f21 = 310,
    f22 = 311,
    f23 = 312,
    f24 = 313,
    f25 = 314,
    kp_0 = 320,
    kp_1 = 321,
    kp_2 = 322,
    kp_3 = 323,
    kp_4 = 324,
    kp_5 = 325,
    kp_6 = 326,
    kp_7 = 327,
    kp_8 = 328,
    kp_9 = 329,
    kp_decimal = 330,
    kp_divide = 331,
    kp_multiply = 332,
    kp_subtract = 333,
    kp_add = 334,
    kp_enter = 335,
    kp_equal = 336,
    left_shift = 340,
    left_control = 341,
    left_alt = 342,
    left_super = 343,
    right_shift = 344,
    right_control = 345,
    right_alt = 346,
    right_super = 347,
    menu = 348,
};

pub const MouseButton = enum(u8) {
    left = 0,
    right = 1,
    middle = 2,
    side = 3,
    extra = 4,
    forward = 5,
    back = 6,
};

const std = @import("std");
const builtin = @import("builtin");
