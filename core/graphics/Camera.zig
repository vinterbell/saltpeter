const Camera = @This();

view: linalg.Mat,

mode: Projection,
width: u32,
height: u32,

aspect_ratio: f32,
near_plane: f32,
far_plane: f32,

// perspective specific
fov_y: f32,

// orthographic specific
/// width of world units
ortho_width: f32,

view_matrix: [16]f32,
projection_matrix: [16]f32,
view_projection_matrix: [16]f32,
projection_dirty: bool,

pub const Projection = enum {
    perspective,
    orthographic,
};

pub fn initPerspective(fov_y: f32, width: u32, height: u32, near_plane: f32, far_plane: f32) Camera {
    var c: Camera = .{
        .view = linalg.identity(),
        .mode = .perspective,
        .width = width,
        .height = height,

        .aspect_ratio = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
        .near_plane = near_plane,
        .far_plane = far_plane,

        .fov_y = fov_y,

        .ortho_width = 10.0,

        .view_matrix = undefined,
        .projection_matrix = undefined,
        .view_projection_matrix = undefined,
        .projection_dirty = true,
    };

    c.update();
    return c;
}

pub fn initOrthographic(ortho_width: f32, width: u32, height: u32, near_plane: f32, far_plane: f32) Camera {
    var c: Camera = .{
        .view = linalg.identity(),
        .mode = .orthographic,
        .width = width,
        .height = height,

        .aspect_ratio = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
        .near_plane = near_plane,
        .far_plane = far_plane,

        .fov_y = 70.0 * (std.math.pi / 180.0),

        .ortho_width = ortho_width,

        .view_matrix = undefined,
        .projection_matrix = undefined,
        .view_projection_matrix = undefined,
        .projection_dirty = true,
    };

    c.update();
    return c;
}

pub fn setView(self: *Camera, view: linalg.Mat) void {
    self.view = view;
    self.view_matrix = linalg.matToArr(self.view);
}

pub fn setWidthHeight(self: *Camera, width: u32, height: u32) void {
    self.width = width;
    self.height = height;
    self.aspect_ratio = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
    self.projection_dirty = true;
}

pub fn setOrthoWidth(self: *Camera, ortho_width: f32) void {
    self.ortho_width = ortho_width;
    if (self.mode == .orthographic) {
        self.projection_dirty = true;
    }
}

/// in radians
pub fn setFovY(self: *Camera, fov_y: f32) void {
    self.fov_y = fov_y;
    if (self.mode == .perspective) {
        self.projection_dirty = true;
    }
}

fn recalculateProjectionMatrix(self: Camera) [16]f32 {
    switch (self.mode) {
        .perspective => {
            return linalg.matToArr(linalg.perspectiveFovLh(
                self.fov_y,
                self.aspect_ratio,
                self.near_plane,
                self.far_plane,
            ));
        },
        .orthographic => {
            const half_width = self.ortho_width * 0.5;
            const half_height = half_width / self.aspect_ratio;
            return linalg.matToArr(linalg.orthographicOffCenterLh(
                -half_width,
                half_width,
                -half_height,
                half_height,
                self.near_plane,
                self.far_plane,
            ));
        },
    }
}

fn update(self: *Camera) void {
    self.view_matrix = linalg.matToArr(self.view);
    defer self.projection_dirty = false;
    if (self.projection_dirty) {
        self.projection_matrix = recalculateProjectionMatrix(@as(Camera, self.*));
    }
    if (self.projection_dirty) {
        self.view_projection_matrix = linalg.matToArr(linalg.mul(
            linalg.matFromArr(self.view_matrix),
            linalg.matFromArr(self.projection_matrix),
        ));
    }
}

const std = @import("std");
const linalg = @import("../math/linalg.zig");
