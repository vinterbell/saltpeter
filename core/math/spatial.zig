pub const Rect = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    pub fn init(x: i32, y: i32, width: u32, height: u32) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }
};

pub const Viewport = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32 = 0.0,
    max_depth: f32 = 1.0,

    pub fn init(x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) Viewport {
        return .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .min_depth = min_depth,
            .max_depth = max_depth,
        };
    }
};
