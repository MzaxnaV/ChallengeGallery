const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
};

const utils = @import("utils");
const bufPrint = @import("std").fmt.bufPrint;

const camera = struct {
    p: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    fov: f32,
};

const star = struct {
    p: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    pz: f32 = 0,

    fn update(self: *star, speed: f32, comptime width: comptime_int, comptime height: comptime_int) void {
        self.pz = self.p.z;
        self.p.z -= speed;
        if (self.p.z <= 1) {
            self.p.x = utils.randomFloat(-width, width);
            self.p.y = utils.randomFloat(-height, height);
            self.p.z = utils.randomFloat(1, width);

            self.pz = self.p.z;
        }
    }

    fn draw(self: @This(), cam: camera, comptime width: comptime_int, comptime height: comptime_int) void {
        const relative = rl.vector3Subtract(self.p, cam.p);

        const scaleFactor = cam.fov / (cam.fov + relative.z);

        const sx: i32 = @intFromFloat(width / 2 + relative.x * scaleFactor);
        const sy: i32 = @intFromFloat(height / 2 + relative.y * scaleFactor);

        const relativePZ = self.pz - cam.p.z;
        const scaleFactorP = cam.fov / (cam.fov + relativePZ);

        const pSX: i32 = @intFromFloat(width / 2 + relative.x * scaleFactorP);
        const pSY: i32 = @intFromFloat(height / 2 + relative.y * scaleFactorP);

        const r = utils.map(self.p.z, 1, width, 16, 0);

        rl.drawCircle(sx, sy, r, rl.Color.white);
        rl.drawLine(pSX, pSY, sx, sy, rl.Color.white);
    }
};

pub fn run(comptime width: comptime_int, comptime height: comptime_int, comptime T: type, comptime config: T) anyerror!void {
    var stars: [config.stars]star = [1]star{star{}} ** config.stars;

    rl.initWindow(width, height, "Starfield");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);

    for (stars[0..]) |*s| {
        s.p.x = utils.randomFloat(-width, width);
        s.p.y = utils.randomFloat(-height, height);
        s.p.z = utils.randomFloat(1, width);

        s.pz = s.p.z;
    }

    var text_buffer: [100]u8 = [1]u8{0} ** 100;

    const cam: camera = .{ .fov = 120 };

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        const mouse = rl.getMousePosition();

        const speed = utils.map(mouse.x, 0, width, 0, config.speed_max);

        const formatted_text = try bufPrint(text_buffer[0..], "Speed: {d:.2}", .{speed});
        text_buffer[formatted_text.len] = 0; // Set sentinel value

        for (stars[0..]) |*s| {
            s.update(speed, width, height);
        }

        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        rl.drawText(text_buffer[0..formatted_text.len :0], 20, 20, 20, rl.Color.gold);

        for (stars) |s| {
            s.draw(cam, width, height);
        }

        //----------------------------------------------------------------------------------
    }
}
