const std = @import("std");

const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
    usingnamespace @import("rlgl");
};

const DEBUG = false;
const raygui_draw_ring = @import("raygui_draw_ring.zig");

const AppType = enum {
    starfield,
    menger_sponge,
    snake,

    fn getType(self: @This()) type {
        return switch (self) {
            .starfield => @import("challenges/starfield.zig"),
            .menger_sponge => @import("challenges/menger_sponge.zig"),
            .snake => @import("challenges/snake.zig"),
        };
    }
};

fn App(comptime tag: AppType) type {
    const app = tag.getType();

    const SetupFn = *const fn (allocator: std.mem.Allocator, comptime width: comptime_int, comptime height: comptime_int) anyerror!void;
    const EmptyFn = *const fn () void;
    const String = [:0]const u8;

    return struct {
        const setup: SetupFn = app.setup;
        const update: EmptyFn = app.update;
        /// called between `rl.beginDrawing()` and `rl.endDrawing()`
        const render: EmptyFn = app.render;
        const cleanup: EmptyFn = app.cleanup;
        const title: String = app.config.title;
    };
}

pub fn main() anyerror!void {
    if (DEBUG) {
        return raygui_draw_ring.run(800, 500);
    }

    // Initialization
    //--------------------------------------------------------------------------------------

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const screenWidth = 800;
    const screenHeight = 800;

    const app = App(.menger_sponge);

    rl.initWindow(screenWidth, screenHeight, app.title);
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);

    try app.setup(arena.allocator(), screenWidth, screenHeight);
    defer app.cleanup();

    // Main game loop
    //--------------------------------------------------------------------------------------
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        app.update();

        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.black);

            app.render();
        }
    }
}
