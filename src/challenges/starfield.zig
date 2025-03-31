const std = @import("std");

const utils = @import("utils");

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

const V2 = utils.V2;
const V3 = utils.V3;
const Colours = utils.Colours;
const AppData = utils.AppData;

pub const State = struct {
    stars: []Star,
    camera: Camera,
    speedMax: f32 = 0,
    speed: f32 = 0,
};

/// 2D perspective camera
const Camera = struct {
    /// world camera position
    p: V3 = @splat(0),
    /// virtual screen size
    viewport: V2,
    fov: f32,

    fn worldToScreen(self: @This(), worldP: V3) V2 {
        const relative = worldP - self.p;

        const scaleFactor = self.fov / (self.fov + relative[2]);

        const result = V2{
            self.viewport[0] / 2 + relative[0] * scaleFactor,
            self.viewport[1] / 2 + relative[1] * scaleFactor,
        };

        return result;
    }
};

const Star = struct {
    p: V3 = .{ 0, 0, 0 },
    pz: f32 = 0,

    fn update(self: *Star, speed: f32, viewport: V2) void {
        self.pz = self.p[2];
        self.p[2] -= speed;
        if (self.p[2] <= 1) {
            self.p = .{
                utils.randomFloat(-viewport[0], viewport[0]),
                utils.randomFloat(-viewport[1], viewport[1]),
                utils.randomFloat(1, viewport[0]),
            };

            self.pz = self.p[2];
        }
    }

    fn draw(self: @This(), api: utils.DrawAPI, camera: Camera) void {
        const radius = utils.remap(self.p[2], 1, camera.viewport[0], 16, 0);

        const screenP = camera.worldToScreen(self.p);
        api.drawCircle(screenP, radius, Colours.white);

        const prevScreenP = camera.worldToScreen(.{ self.p[0], self.p[1], self.pz });
        api.drawLine(prevScreenP, screenP, Colours.white);
    }
};

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

export fn setup(app_data: *AppData, width: i32, height: i32) callconv(.C) void {
    const stars_len = 100;
    const speed_max = 50;

    const allocator = app_data.fba.allocator();

    const state: *State = allocator.create(State) catch |err| {
        std.debug.print("Failed to create State: {}\n", .{err});
        return;
    };

    state.stars = allocator.alloc(Star, stars_len) catch |err| {
        std.debug.print("Failed to create stars: {}\n", .{err});
        return;
    };
    state.camera = .{
        .fov = 120,
        .viewport = V2{ @floatFromInt(width), @floatFromInt(height) },
    };
    state.speedMax = speed_max;

    for (state.stars) |*s| {
        s.p = .{
            utils.randomFloat(-state.camera.viewport[0], state.camera.viewport[0]),
            utils.randomFloat(-state.camera.viewport[1], state.camera.viewport[1]),
            utils.randomFloat(1, state.camera.viewport[0]),
        };

        s.pz = s.p[2];
    }
}

export fn update(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));

    const mouse = app_data.input_api.getMousePosition();

    state.speed = utils.remap(mouse[0], 0, state.camera.viewport[0], 0, state.speedMax);

    for (state.stars) |*s| {
        s.update(state.speed, state.camera.viewport);
    }
}

export fn render(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));
    const draw_api = app_data.draw_api;

    draw_api.clearBackground(Colours.bg);

    var buff: [32]u8 = [1]u8{0} ** 32;

    const text = std.fmt.bufPrintZ(buff[0..], "Speed: {d:.2}", .{state.speed}) catch |err| {
        std.debug.print("Failed to format string: {}\n", .{err});
        return;
    };

    draw_api.drawText(text, .{ 10, 40 }, 20, Colours.gold);

    for (state.stars) |s| {
        s.draw(draw_api, state.camera);
    }

    draw_api.drawCircle(.{ 600, 600 }, 10, 0xff00ffff);
}

export fn cleanup(app_data: *AppData) callconv(.C) void {
    const allocator = app_data.fba.allocator();
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));

    allocator.free(state.stars);
    allocator.destroy(state);
}
