const std = @import("std");
const rl = @import("raylib");

/// keep this separate from raylib to avoid ambiguous symbols
const ray = struct {
    usingnamespace @cImport({
        @cInclude("raygui.h");
    });
};

const utils = @import("utils");
const Vector2 = utils.Vector2;
const RaylibAPI = utils.RaylibAPI;
const AppType = utils.AppType;

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

// Raylib API functions
pub fn clearBackground(color: u32) void {
    rl.clearBackground(rl.Color.fromInt(color));
}

pub fn drawCircle(p: Vector2, radius: f32, color: u32) void {
    rl.drawCircleV(.{ .x = p[0], .y = p[1] }, radius, rl.Color.fromInt(color));
}

pub fn drawLine(start: Vector2, end: Vector2, color: u32) void {
    rl.drawLineV(.{ .x = start[0], .y = start[1] }, .{ .x = end[0], .y = end[1] }, rl.Color.fromInt(color));
}

pub fn drawText(text: [:0]const u8, p: Vector2, fontSize: i32, color: u32) void {
    rl.drawText(text[0.. :0], @intFromFloat(p[0]), @intFromFloat(p[1]), fontSize, rl.Color.fromInt(color));
}

pub fn textFormat(text: []const u8, args: anytype) []const u8 {
    return rl.textFormat(text[0.. :0], args);
}

// Input API functions
pub fn getMousePosition() Vector2 {
    const mouseP = rl.getMousePosition();
    return .{ mouseP.x, mouseP.y };
}

// Utility functions
pub inline fn kiloBytes(comptime value: comptime_int) comptime_int {
    return 1024 * value;
}
pub inline fn megaBytes(comptime value: comptime_int) comptime_int {
    return 1024 * kiloBytes(value);
}

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------

    const size = megaBytes(2);
    const memoryBlock = try std.os.windows.VirtualAlloc(null, size, std.os.windows.MEM_RESERVE | std.os.windows.MEM_COMMIT, std.os.windows.PAGE_READWRITE);

    var app_data = utils.AppData{
        .storage_size = size,
        .storage = @ptrCast(memoryBlock),

        .draw_api = .{
            .clearBackground = clearBackground,
            .drawCircle = drawCircle,
            .drawLine = drawLine,
            .drawText = drawText,
        },
        .input_api = .{
            .getMousePosition = getMousePosition,
        },
    };

    const screenWidth = 900;
    const screenHeight = 620;
    const padding = 5;
    const gap = 5;

    const view = View{
        .bounds = .{ .x = 0, .y = 0, .width = 600, .height = screenHeight - 4 * padding },
        .padding = padding,
    };

    var lib = try std.DynLib.open("starfield.dll");
    defer lib.close(); // Close the library when done

    const App = utils.App(.starfield);

    var app = App{
        .setup = lib.lookup(App.SetupFn, "setup").?,
        .update = lib.lookup(App.CommonFn, "update").?,
        .render = lib.lookup(App.CommonFn, "render").?,
    };

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

    rl.initWindow(screenWidth, screenHeight, "Challenge Gallery");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);

    app.setup(&app_data, view.bounds.width, view.bounds.height);
    const render_texture = try rl.loadRenderTexture(view.bounds.width, view.bounds.height);
    defer rl.unloadRenderTexture(render_texture); // Unload render texture

    // Main game loop
    //--------------------------------------------------------------------------------------
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        app.update(&app_data);

        {
            render_texture.begin();
            defer render_texture.end();
            app.render(&app_data);
        }

        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.ray_white);

            list.draw();
            view.draw(render_texture.texture);

            rl.drawFPS(20, 20);
        }
    }
}
