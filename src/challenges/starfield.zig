const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
};

const utils = @import("utils");

//----------------------------------------------------------------------------------
// Consts
//----------------------------------------------------------------------------------

pub const title = "Startfield";

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

const Camera = struct {
    p: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    fov: f32,
};

const Star = struct {
    p: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    pz: f32 = 0,

    fn update(self: *Star, speed: f32, width: f32, height: f32) void {
        self.pz = self.p.z;
        self.p.z -= speed;
        if (self.p.z <= 1) {
            self.p.x = utils.randomFloat(-width, width);
            self.p.y = utils.randomFloat(-height, height);
            self.p.z = utils.randomFloat(1, width);

            self.pz = self.p.z;
        }
    }

    fn draw(self: @This(), camera: Camera, width: f32, height: f32) void {
        const relative = rl.vector3Subtract(self.p, camera.p);

        const scaleFactor = camera.fov / (camera.fov + relative.z);

        const sx: i32 = @intFromFloat(width / 2 + relative.x * scaleFactor);
        const sy: i32 = @intFromFloat(height / 2 + relative.y * scaleFactor);

        const relativePZ = self.pz - camera.p.z;
        const scaleFactorP = camera.fov / (camera.fov + relativePZ);

        const pSX: i32 = @intFromFloat(width / 2 + relative.x * scaleFactorP);
        const pSY: i32 = @intFromFloat(height / 2 + relative.y * scaleFactorP);

        const r = utils.map(self.p.z, 1, width, 16, 0);

        rl.drawCircle(sx, sy, r, rl.Color.white);
        rl.drawLine(pSX, pSY, sx, sy, rl.Color.white);
    }
};

//----------------------------------------------------------------------------------
// Globals
//----------------------------------------------------------------------------------

var g: struct {
    stars: []Star = undefined,
    camera: Camera = undefined,
    width: f32 = 0,
    height: f32 = 0,
    speedMax: f32 = 0,
    speed: f32 = 0,
} = .{};

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

pub fn setup(comptime width: comptime_int, comptime height: comptime_int, config: anytype) anyerror!void {
    g.stars = try config.allocator.alloc(Star, config.stars);
    g.camera = .{ .fov = 120 };
    g.width = width;
    g.speedMax = config.speed_max;

    for (g.stars) |*s| {
        s.p.x = utils.randomFloat(-width, width);
        s.p.y = utils.randomFloat(-height, height);
        s.p.z = utils.randomFloat(1, width);

        s.pz = s.p.z;
    }
}

pub fn update() void {
    const mouse = rl.getMousePosition();

    g.speed = utils.map(mouse.x, 0, g.width, 0, g.speedMax);

    for (g.stars) |*s| {
        s.update(g.speed, g.width, g.height);
    }
}

pub fn render() void {
    rl.drawText(rl.textFormat("Speed: %d.02", .{g.speed}), 20, 20, 20, rl.Color.gold);

    for (g.stars) |s| {
        s.draw(g.camera, g.width, g.height);
    }
}

pub fn cleanup() void {}
