const std = @import("std");

const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
};

//----------------------------------------------------------------------------------
// Consts
//----------------------------------------------------------------------------------

pub const config = .{
    .title = "Snake",
    .scl = 20,
};

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

pub fn setup(_: std.mem.Allocator, comptime _: comptime_int, comptime _: comptime_int) anyerror!void {}

pub fn update() void {}

pub fn render() void {}

pub fn cleanup() void {}
