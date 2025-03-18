const std = @import("std");

const rl = @import("raylib");

/// keep this separate from raylib to avoid ambiguous symbols
const ray = struct {
    usingnamespace @cImport({
        @cInclude("raygui.h");
    });
};

const AppType = enum(u32) {
    starfield,
    menger_sponge,
    snake,
    purple_rain,
    space_invaders,

    fn getType(self: @This()) type {
        return switch (self) {
            .starfield => @import("challenges/starfield.zig"),
            .menger_sponge => @import("challenges/menger_sponge.zig"),
            .snake => @import("challenges/snake.zig"),
            .purple_rain => @import("challenges/purple_rain.zig"),
            .space_invaders => @import("challenges/space_invaders.zig"),
        };
    }

    fn getList() [:0]const u8 {
        const type_info = @typeInfo(@This());

        comptime var list = type_info.@"enum".fields[0].name;
        inline for (type_info.@"enum".fields[1..]) |field| {
            list = list ++ ";" ++ field.name;
        }

        return list;
    }
};

fn App(comptime tag: AppType) type {
    const app = tag.getType();

    const SetupFn = *const fn (allocator: std.mem.Allocator, width: i32, height: i32) anyerror!*app.State;
    const CommonFn = *const fn (state: *app.State) void;
    const String = [:0]const u8;

    return struct {
        tag: AppType = tag,
        setup: SetupFn = app.setup,
        update: CommonFn = app.update,
        /// draws to a render texture
        render: CommonFn = app.render,
        cleanup: CommonFn = app.cleanup,
        title: String = app.config.title,
    };
}

const View = struct {
    bounds: rl.Rectangle,
    padding: f32,

    fn draw(self: @This(), texture: rl.Texture2D) void {
        rl.drawRectangleLinesEx(
            .{
                .x = self.padding + self.bounds.x,
                .y = self.padding + self.bounds.y,
                .width = self.bounds.width + 2 * self.padding,
                .height = self.bounds.height + 2 * self.padding,
            },
            1,
            rl.Color.gray,
        );

        rl.drawTextureRec(texture, .{
            .x = self.bounds.x,
            .y = self.bounds.y,
            .width = self.bounds.width,
            .height = -self.bounds.height,
        }, .{ .x = 2 * self.padding, .y = 2 * self.padding }, rl.Color.white);
    }
};

const List = struct {
    bounds: rl.Rectangle,
    padding: f32,
    mode: bool = false,
    active: *AppType,
    list: [:0]const u8,

    fn draw(self: *List) void {
        rl.drawRectangleLinesEx(
            .{
                .x = self.padding + self.bounds.x,
                .y = self.padding + self.bounds.y,
                .width = self.bounds.width + 2 * self.padding,
                .height = self.bounds.height + 2 * self.padding,
            },
            1,
            rl.Color.gray,
        );

        if (ray.GuiDropdownBox(.{
            .x = self.padding * 2 + self.bounds.x,
            .y = self.padding * 2 + self.bounds.y,
            .width = self.bounds.width,
            .height = 24,
        }, self.list, @ptrCast(self.active), self.mode) != 0) {
            self.mode = !self.mode;

            if (!self.mode) {
                // TODO: initiate app change, won't work as there's no way to do dynamic imports.
                // Make challenges as dynamic libs and manually load libraries instead.
                // app.* = App.init(self.active);
            }
        }
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const screenWidth = 900;
    const screenHeight = 620;
    const padding = 5;
    const gap = 5;

    const view = View{
        .bounds = .{ .x = 0, .y = 0, .width = 600, .height = screenHeight - 4 * padding },
        .padding = padding,
    };

    var app = App(.starfield){};

    var list = List{
        .bounds = .{
            .x = view.bounds.width + 3 * view.padding,
            .y = 0,
            .width = screenWidth - (view.bounds.width + 4 * view.padding) - gap - 2 * padding,
            .height = screenHeight - 4 * padding,
        },
        .active = &app.tag,
        .list = AppType.getList(),
        .padding = padding,
    };

    rl.initWindow(screenWidth, screenHeight, app.title);
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);

    const state = try app.setup(arena.allocator(), view.bounds.width, view.bounds.height);
    defer app.cleanup(state);

    // Main game loop
    //--------------------------------------------------------------------------------------
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        app.update(state);

        {
            state.render_texture.begin();
            defer state.render_texture.end();
            app.render(state);
        }

        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.ray_white);

            list.draw();
            view.draw(state.render_texture.texture);

            rl.drawFPS(20, 20);
        }
    }
}
