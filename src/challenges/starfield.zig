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
    .title = "Startfield",
    .stars = 100,
    .speed_max = 50,
};

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

pub const State = struct {
    render_texture: rl.RenderTexture2D,
    stars: []Star,
    camera: Camera,
    speedMax: f32 = 0,
    speed: f32 = 0,
};

/// 2D perspective camera
const Camera = struct {
    /// world camera position
    p: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    /// virtual screen size
    viewport: rl.Vector2,
    fov: f32,

    fn worldToScreen(self: @This(), worldP: rl.Vector3) rl.Vector2 {
        const relative = rl.vector3Subtract(worldP, self.p);

        const scaleFactor = self.fov / (self.fov + relative.z);

        const result = rl.Vector2{
            .x = self.viewport.x / 2 + relative.x * scaleFactor,
            .y = self.viewport.y / 2 + relative.y * scaleFactor,
        };

        return result;
    }
};

const Star = struct {
    p: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    pz: f32 = 0,

    fn update(self: *Star, speed: f32, viewport: rl.Vector2) void {
        self.pz = self.p.z;
        self.p.z -= speed;
        if (self.p.z <= 1) {
            self.p.x = utils.randomFloat(-viewport.x, viewport.x);
            self.p.y = utils.randomFloat(-viewport.y, viewport.y);
            self.p.z = utils.randomFloat(1, viewport.x);

            self.pz = self.p.z;
        }
    }

    fn draw(self: @This(), camera: Camera) void {
        const radius = rl.remap(self.p.z, 1, camera.viewport.x, 16, 0);

        const screenP = camera.worldToScreen(self.p);
        rl.drawCircle(
            @intFromFloat(screenP.x),
            @intFromFloat(screenP.y),
            radius,
            rl.Color.white,
        );

        const prevScreenP = camera.worldToScreen(.{ .x = self.p.x, .y = self.p.y, .z = self.pz });
        rl.drawLine(
            @intFromFloat(prevScreenP.x),
            @intFromFloat(prevScreenP.y),
            @intFromFloat(screenP.x),
            @intFromFloat(screenP.y),
            rl.Color.white,
        );
    }
};

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

pub fn setup(allocator: std.mem.Allocator, width: i32, height: i32) anyerror!*State {
    var state: *State = try allocator.create(State);
    state.render_texture = rl.loadRenderTexture(width, height);

    state.stars = try allocator.alloc(Star, config.stars);
    state.camera = .{ .fov = 120, .viewport = rl.Vector2.init(@floatFromInt(width), @floatFromInt(height)) };
    state.speedMax = config.speed_max;

    for (state.stars) |*s| {
        s.p.x = utils.randomFloat(@floatFromInt(-width), @floatFromInt(width));
        s.p.y = utils.randomFloat(@floatFromInt(-height), @floatFromInt(height));
        s.p.z = utils.randomFloat(1, @floatFromInt(width));

        s.pz = s.p.z;
    }

    return state;
}

pub fn update(state: *State) void {
    const mouse = rl.getMousePosition();

    state.speed = rl.remap(mouse.x, 0, state.camera.viewport.x, 0, state.speedMax);

    for (state.stars) |*s| {
        s.update(state.speed, state.camera.viewport);
    }
}

pub fn render(state: *State) void {
    rl.clearBackground(rl.Color.black);

    rl.drawText(rl.textFormat("Speed: %.02f", .{state.speed}), 10, 40, 20, rl.Color.gold);

    for (state.stars) |s| {
        s.draw(state.camera);
    }
}

pub fn cleanup(state: *State) void {
    rl.unloadRenderTexture(state.render_texture);
}
