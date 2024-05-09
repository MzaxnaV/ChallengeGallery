const std = @import("std");

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 800;

    const starfield = @import("challenges/starfield.zig");

    const config = .{ .stars = 100 };

    return starfield.run(screenWidth, screenHeight, @TypeOf(config), config);
}
