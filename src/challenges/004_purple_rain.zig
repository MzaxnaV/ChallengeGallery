const std = @import("std");

const utils = @import("utils");
const AppData = utils.AppData;
const RenderAPI = utils.RenderAPI;

const V2 = utils.V2;

//----------------------------------------------------------------------------------
// Consts
//----------------------------------------------------------------------------------

pub const config = .{
    .title = "Purple Rain",
    .drops = 200,
};

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

pub const State = struct {
    rain: []Drop,
    boundary: V2,
};

const Drop = struct {
    p: V2,
    speed: V2,
    nearness: f32,
    len: f32,

    fn update(self: *Drop, state: *State) void {
        self.speed += .{ 0, 0.05 };
        self.p += self.speed;

        if (self.p[1] > state.boundary[1]) {
            self.p[1] = utils.randomFloat(-250, 0);
            self.speed[1] = utils.remap(self.nearness, 0, 20, 4, 10);
        }

        self.p[0] = @mod(self.p[0], state.boundary[0]);
    }

    fn draw(self: @This(), api: RenderAPI) void {
        const thickness = utils.remap(self.nearness, 0, 20, 1, 5);
        api.drawRectangle(self.p, .{ thickness, self.len }, utils.Colours.white);
    }
};

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

export fn setup(app_data: *AppData, width: i32, height: i32) callconv(.C) void {
    const allocator = app_data.fba.allocator();

    const state: *State = allocator.create(State) catch |err| {
        std.debug.print("Failed to create State: {}\n", .{err});
        return;
    };

    state.* = State{
        .rain = allocator.alloc(Drop, config.drops) catch |err| {
            std.debug.print("Failed to create rain drops: {}\n", .{err});
            return;
        },
        .boundary = .{ @floatFromInt(width), @floatFromInt(height) },
    };

    const x_speed = utils.randomFloat(-1, 1);

    for (state.rain) |*drop| {
        drop.p = utils.randomV(f32, 0, @floatFromInt(width), 0, @floatFromInt(height));
        drop.nearness = utils.randomFloat(0, 20);
        drop.len = utils.remap(drop.nearness, 0, 20, 10, 20);
        drop.speed = .{ x_speed, utils.remap(drop.nearness, 0, 20, 1, 10) };
    }
}

export fn update(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));
    for (state.rain) |*drop| {
        drop.update(state);
    }
}

export fn render(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));
    const draw_api = app_data.draw_api;

    draw_api.clearBackground(utils.Colours.bg);

    for (state.rain) |*drop| {
        drop.draw(draw_api);
    }
}

export fn cleanup(app_data: *AppData) callconv(.C) void {
    const allocator = app_data.fba.allocator();
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));

    allocator.free(state.rain);

    allocator.destroy(state);
}
