const std = @import("std");

const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
    usingnamespace @import("rlgl");
};

const DEBUG = false;
const raygui_draw_ring = @import("raygui_draw_ring.zig");

const starfield = @import("challenges/starfield.zig");
const menger_sponge = @import("challenges/menger_sponge.zig");

pub fn main() anyerror!void {
    if (DEBUG) {
        return raygui_draw_ring.run(800, 500);
    }

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 800;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const config = .{
        .allocator = arena.allocator(),
        .stars = 100,
        .speed_max = 50,
    };

    const app: struct {
        setup: *const fn (comptime width: comptime_int, comptime height: comptime_int, config: @TypeOf(config)) anyerror!void,
        update: *const fn () void,
        render: *const fn () void,
        cleanup: *const fn () void,
        title: [:0]const u8,
    } = .{
        // Select the app
        .setup = menger_sponge.setup,
        .update = menger_sponge.update,
        .render = menger_sponge.render,
        .cleanup = menger_sponge.cleanup,
        .title = menger_sponge.title,
    };

    rl.initWindow(screenWidth, screenHeight, app.title);
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);

    try app.setup(screenWidth, screenHeight, config);
    defer app.cleanup();

    // Main game loop
    //--------------------------------------------------------------------------------------
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        app.update();

        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.gray);

            app.render();
        }
    }
}
