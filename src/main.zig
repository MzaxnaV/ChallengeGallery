const std = @import("std");

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 800;

    // const starfield = @import("challenges/starfield.zig");
    const menger_sponge = @import("challenges/menger_sponge.zig");

    const config = .{
        .stars = 100,
        .speed_max = 50,
    };

    return menger_sponge.run(screenWidth, screenHeight, @TypeOf(config), config);
}
