const std = @import("std");
const rl = @import("raylib");

/// keep this separate from raylib to avoid ambiguous symbols
const ray = struct {
    usingnamespace @cImport({
        @cInclude("raygui.h");
    });
};

const utils = @import("utils");

const AppType = @import("challenges").AppType;
const App = utils.App(AppType);
const AppData = utils.AppData;

const V2 = utils.V2;
const V3 = utils.V3;

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

pub fn drawRectangle(p: V2, size: V2, colour: u32) void {
    rl.drawRectangleV(.{ .x = p[0], .y = p[1] }, .{ .x = size[0], .y = size[1] }, rl.Color.fromInt(colour));
}

pub fn textFormat(text: []const u8, args: anytype) []const u8 {
    return rl.textFormat(text[0.. :0], args);
}

// shader
pub fn loadShaderFromMemory(vsCode: [:0]const u8, fsCode: [:0]const u8) ?utils.Shader {
    const shader = rl.loadShaderFromMemory(vsCode, fsCode) catch |err| {
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

pub fn isKeyReleased(key: c_int) bool {
    return rl.isKeyReleased(@enumFromInt(key));
}

pub fn isKeyDown(key: c_int) bool {
    return rl.isKeyDown(@enumFromInt(key));
}

pub fn getFrameTime() f32 {
    return rl.getFrameTime();
}

// Math API functions
pub fn checkCollisionCircleRec(center: V2, radius: f32, rec: utils.Rect) bool {
    return rl.checkCollisionCircleRec(
        .{ .x = center[0], .y = center[1] },
        radius,
        .{
            .x = rec.p[0],
            .y = rec.p[1],
            .width = rec.size[0],
            .height = rec.size[1],
        },
    );
}

pub fn checkCollisionPointRec(point: V2, rec: utils.Rect) bool {
    return rl.checkCollisionPointRec(.{ .x = point[0], .y = point[1] }, .{
        .x = rec.p[0],
        .y = rec.p[1],
        .width = rec.size[0],
        .height = rec.size[1],
    });
}

// Utility functions
pub inline fn kiloBytes(comptime value: comptime_int) comptime_int {
    return 1024 * value;
}
pub inline fn megaBytes(comptime value: comptime_int) comptime_int {
    return 1024 * kiloBytes(value);
}

const LibraryManager = struct {
    map: std.AutoHashMap(AppType, std.DynLib),

    pub fn init(allocator: std.mem.Allocator) !LibraryManager {
        var result = LibraryManager{
            .map = std.AutoHashMap(AppType, std.DynLib).init(allocator),
        };

        inline for (@typeInfo(AppType).@"enum".fields) |enum_field| {
            const lib = try std.DynLib.open(enum_field.name ++ ".dll");
            try result.map.put(@enumFromInt(enum_field.value), lib);
        }

        return result;
    }

    pub fn get(self: LibraryManager, key: AppType) ?std.DynLib {
        return self.map.get(key);
    }

    pub fn deinit(self: *LibraryManager) void {
        inline for (@typeInfo(AppType).@"enum".fields) |enum_field| {
            var lib = self.map.get(@enumFromInt(enum_field.value)).?;
            lib.close();
        }

        self.map.deinit();
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------

    const size = megaBytes(2);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const memoryBlock = try allocator.alignedAlloc(u8, 16, size);

    var app_data = AppData{
        .fba = std.heap.FixedBufferAllocator.init(@as([*]u8, @ptrCast(memoryBlock))[0..size]),

        .draw_api = .{
            .clearBackground = clearBackground,

            .drawCircle = drawCircle,
            .drawLine = drawLine,
            .drawText = drawText,
            .drawCube = drawCube,
            .drawRectangle = drawRectangle,

            // shader
            .loadShaderFromMemory = loadShaderFromMemory,
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
            .getFrameTime = getFrameTime,
            .getMousePosition = getMousePosition,
            .isKeyReleased = isKeyReleased,
            .isKeyDown = isKeyDown,

            // collision
            .checkCollisionCircleRec = checkCollisionCircleRec,
            .checkCollisionPointRec = checkCollisionPointRec,
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

    var libs_map = try LibraryManager.init(allocator);
    defer libs_map.deinit();

    var starfield = libs_map.get(.starfield).?;
    var app = App{
        .setup = starfield.lookup(App.SetupFn, "setup").?,
        .update = starfield.lookup(App.CommonFn, "update").?,
        .render = starfield.lookup(App.CommonFn, "render").?,
        .cleanup = starfield.lookup(App.CleanUpFn, "cleanup").?,
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

        if (app.tag != app.prev_tag) {
            app.prev_tag = app.tag;

            app.cleanup(&app_data);
            app_data.fba.reset();

            var lib = libs_map.get(app.tag).?;

            app.setup = lib.lookup(App.SetupFn, "setup").?;
            app.update = lib.lookup(App.CommonFn, "update").?;
            app.render = lib.lookup(App.CommonFn, "render").?;
            app.cleanup = lib.lookup(App.CleanUpFn, "cleanup").?;

            app.setup(&app_data, view.bounds.width, view.bounds.height);
        }
    }
}
