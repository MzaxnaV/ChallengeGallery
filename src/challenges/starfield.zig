const std = @import("std");

const utils = @import("utils");
//----------------------------------------------------------------------------------
// Consts & Globals
//----------------------------------------------------------------------------------

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

const Vector2 = utils.Vector2;
const Vector3 = utils.Vector3;
const Colours = utils.Colours;

pub const State = struct {
    stars: []Star,
    camera: Camera,
    speedMax: f32 = 0,
    speed: f32 = 0,
};

/// 2D perspective camera
const Camera = struct {
    /// world camera position
    p: Vector3 = @splat(0),
    /// virtual screen size
    viewport: Vector2,
    fov: f32,

    fn worldToScreen(self: @This(), worldP: Vector3) Vector2 {
        const relative = worldP - self.p;

        const scaleFactor = self.fov / (self.fov + relative[2]);

        const result = Vector2{
            self.viewport[0] / 2 + relative[0] * scaleFactor,
            self.viewport[1] / 2 + relative[1] * scaleFactor,
        };

        return result;
    }
};

const Star = struct {
    p: Vector3 = .{ 0, 0, 0 },
    pz: f32 = 0,

    fn update(self: *Star, speed: f32, viewport: Vector2) void {
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

export fn setup(app_data: *utils.AppData, width: i32, height: i32) callconv(.C) void {
    const stars_len = 100;
    const speed_max = 50;

    var fba = std.heap.FixedBufferAllocator.init(app_data.storage[0..app_data.storage_size]);
    const allocator = fba.allocator();

    const state: *State = allocator.create(State) catch |err| {
        std.debug.print("Failed to create State: {}\n", .{err});
        return;
    };

    state.stars = allocator.alloc(Star, stars_len) catch |err| {
        std.debug.print("Failed to create State: {}\n", .{err});
        return;
    };
    state.camera = .{
        .fov = 120,
        .viewport = Vector2{ @floatFromInt(width), @floatFromInt(height) },
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

export fn update(app_data: *const utils.AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.storage));

    const mouse = app_data.input_api.getMousePosition();

    state.speed = utils.remap(mouse[0], 0, state.camera.viewport[0], 0, state.speedMax);

    for (state.stars) |*s| {
        s.update(state.speed, state.camera.viewport);
    }
}

export fn render(app_data: *const utils.AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.storage));

    const draw_api = app_data.draw_api;

    draw_api.clearBackground(Colours.black);

    var buff: [32]u8 = [1]u8{0} ** 32;

    _ = std.fmt.bufPrint(buff[0..], "Speed: {d:.2}", .{state.speed}) catch |err| {
        std.debug.print("Failed to format string: {}\n", .{err});
        return;
    };

    draw_api.drawText(buff[0 .. buff.len - 1 :0], .{ 10, 40 }, 20, Colours.gold);

    for (state.stars) |s| {
        s.draw(draw_api, state.camera);
    }

    draw_api.drawCircle(.{ 600, 600 }, 10, 0xff00ffff);
}
