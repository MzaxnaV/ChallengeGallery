const std = @import("std");
const rl = @import("raylib");

/// keep this separate from raylib to avoid ambiguous symbols
const ray = struct {
    usingnamespace @cImport({
        @cInclude("raygui.h");
    });
};

const utils = @import("utils");
const V2 = utils.V2;
const V3 = utils.V3;
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
        }
    }
};

// Raylib API functions
pub fn clearBackground(color: u32) void {
    rl.clearBackground(rl.Color.fromInt(color));
}

// shape
pub fn drawCircle(p: V2, radius: f32, color: u32) void {
    rl.drawCircleV(.{ .x = p[0], .y = p[1] }, radius, rl.Color.fromInt(color));
}

pub fn drawLine(start: V2, end: V2, color: u32) void {
    rl.drawLineV(.{ .x = start[0], .y = start[1] }, .{ .x = end[0], .y = end[1] }, rl.Color.fromInt(color));
}

pub fn drawText(text: [:0]const u8, p: V2, fontSize: i32, color: u32) void {
    rl.drawText(text[0.. :0], @intFromFloat(p[0]), @intFromFloat(p[1]), fontSize, rl.Color.fromInt(color));
}

pub fn drawCube(p: V3, size: V3, colour: u32) void {
    rl.drawCube(.{ .x = p[0], .y = p[1], .z = p[2] }, size[0], size[0], size[0], rl.Color.fromInt(colour));
}

pub fn textFormat(text: []const u8, args: anytype) []const u8 {
    return rl.textFormat(text[0.. :0], args);
}

// shader
pub fn loadShader(vsFileName: [:0]const u8, fsFileName: [:0]const u8) ?utils.Shader {
    const shader = rl.loadShader(vsFileName, fsFileName) catch |err| {
        std.debug.print("Failed to load Shader: {}\n", .{err});
        return null;
    };

    return @bitCast(shader);
}

pub fn unloadShader(shader: utils.Shader) void {
    return rl.unloadShader(@bitCast(shader));
}

pub fn getShaderLocation(shader: utils.Shader, uniformName: [:0]const u8) c_int {
    return rl.getShaderLocation(@bitCast(shader), uniformName);
}

pub fn setShaderValue(shader: utils.Shader, locIndex: c_int, value: *const anyopaque, uniformType: c_int) void {
    rl.setShaderValue(@bitCast(shader), locIndex, value, @enumFromInt(uniformType));
}

pub fn beginShaderMode(shader: utils.Shader) void {
    rl.beginShaderMode(@bitCast(shader));
}

pub fn endShaderMode() void {
    rl.endShaderMode();
}

// camera
pub fn beginMode3D(camera: utils.Camera3D) void {
    rl.beginMode3D(@bitCast(camera));
}

pub fn endMode3D() void {
    rl.endMode3D();
}

pub fn updateCamera(camera: *utils.Camera3D, camera_mode: c_int) void {
    rl.updateCamera(@ptrCast(camera), @enumFromInt(camera_mode));
}

// Input API functions
pub fn getMousePosition() V2 {
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

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const memoryBlock = try arena.allocator().alignedAlloc(u8, 16, size);

    var app_data = utils.AppData{
        .fba = std.heap.FixedBufferAllocator.init(@as([*]u8, @ptrCast(memoryBlock))[0..size]),

        .draw_api = .{
            .clearBackground = clearBackground,

            .drawCircle = drawCircle,
            .drawLine = drawLine,
            .drawText = drawText,
            .drawCube = drawCube,
            .loadShader = loadShader,

            // shader
            .unloadShader = unloadShader,
            .getShaderLocation = getShaderLocation,
            .beginShaderMode = beginShaderMode,
            .endShaderMode = endShaderMode,
            .setShaderValue = setShaderValue,

            // camera
            .beginMode3D = beginMode3D,
            .endMode3D = endMode3D,
            .updateCamera = updateCamera,
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

    var lib_m = try std.DynLib.open("menger_sponge.zig.dll");
    defer lib_m.close();

    var lib_s = try std.DynLib.open("starfield.zig.dll");
    defer lib_s.close();

    var app_tag = utils.AppType.starfield;
    const App = utils.App();

    var app = App{
        .tag = app_tag,
        .setup = lib_m.lookup(App.SetupFn, "setup").?,
        .update = lib_m.lookup(App.CommonFn, "update").?,
        .render = lib_m.lookup(App.CommonFn, "render").?,
        .cleanup = lib_m.lookup(App.CleanUpFn, "cleanup").?,
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
    defer app.cleanup(&app_data);

    const render_texture = try rl.loadRenderTexture(view.bounds.width, view.bounds.height);
    defer rl.unloadRenderTexture(render_texture); // Unload render texture

    // Main game loop
    //--------------------------------------------------------------------------------------
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        app.update(&app_data);

        {
            render_texture.begin();
            rl.clearBackground(rl.Color.black);

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

        if (app.tag != app_tag) {
            app_tag = app.tag;

            app.cleanup(&app_data);
            app_data.fba.reset();

            var lib = switch (app.tag) {
                .menger_sponge => lib_m,
                .starfield => lib_s,
            };

            app.setup = lib.lookup(App.SetupFn, "setup").?;
            app.update = lib.lookup(App.CommonFn, "update").?;
            app.render = lib.lookup(App.CommonFn, "render").?;
            app.cleanup = lib.lookup(App.CleanUpFn, "cleanup").?;

            app.setup(&app_data, view.bounds.width, view.bounds.height);
        }
    }
}
