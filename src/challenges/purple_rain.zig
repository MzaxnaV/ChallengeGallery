const std = @import("std");

const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
};

const utils = @import("utils");

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
    render_texture: rl.RenderTexture2D = undefined,
    rain: []Drop,
    boundary: rl.Vector2,
};

const Drop = struct {
    p: rl.Vector2,
    speed: rl.Vector2,
    nearness: f32,
    len: f32,

    fn update(self: *Drop, state: *State) void {
        self.speed.y += 0.05;
        self.p = rl.vector2Add(self.p, self.speed);

        if (self.p.y > state.boundary.y) {
            self.p.y = utils.randomFloat(-250, 0);
            self.speed.y = rl.remap(self.nearness, 0, 20, 4, 10);
        }

        self.p.x = @mod(self.p.x, state.boundary.x);
    }

    fn draw(self: @This()) void {
        const thickness = rl.remap(self.nearness, 0, 20, 1, 5);
        rl.drawRectangle(
            @intFromFloat(self.p.x),
            @intFromFloat(self.p.y),
            @intFromFloat(thickness),
            @intFromFloat(self.len),
            rl.Color.white,
        );
    }
};

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

pub fn setup(allocator: std.mem.Allocator, comptime width: comptime_int, comptime height: comptime_int) anyerror!*State {
    const state: *State = &(try allocator.alloc(State, 1))[0];

    state.* = State{
        .render_texture = rl.loadRenderTexture(width, height),
        .rain = try allocator.alloc(Drop, config.drops),
        .boundary = rl.Vector2.init(width, height),
    };

    const x_speed = utils.randomFloat(-1, 1);

    for (state.rain) |*drop| {
        drop.p = utils.randomVector2(0, width, 0, height);
        drop.nearness = utils.randomFloat(0, 20);
        drop.len = rl.remap(drop.nearness, 0, 20, 10, 20);
        drop.speed = .{ .x = x_speed, .y = rl.remap(drop.nearness, 0, 20, 1, 10) };
    }

    return state;
}

pub fn update(state: *State) void {
    for (state.rain) |*drop| {
        drop.update(state);
    }
}

pub fn render(state: *State) void {
    rl.clearBackground(rl.Color.black);

    for (state.rain) |*drop| {
        drop.draw();
    }
}

pub fn cleanup(state: *State) void {
    rl.unloadRenderTexture(state.render_texture);
}
