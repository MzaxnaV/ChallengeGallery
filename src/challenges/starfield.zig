const rl = struct {
    usingnamespace @import("raylib");
};

const utils = @import("utils");
const bufPrint = @import("std").fmt.bufPrint;

const star = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pz: f32 = 0,

    fn update(self: *star, speed: f32, comptime width: comptime_int, comptime height: comptime_int) void {
        self.pz = self.z;
        self.z -= speed;
        if (self.z <= 1) {
            self.x = utils.randomFloat(-width, width);
            self.y = utils.randomFloat(-height, height);
            self.z = utils.randomFloat(1, width);

            self.pz = self.z;
        }
    }

    fn draw(self: @This(), cameraX: f32, cameraY: f32, cameraZ: f32, fov: f32, comptime width: comptime_int, comptime height: comptime_int) void {
        const relativeX = self.x - cameraX;
        const relativeY = self.y - cameraY;
        const relativeZ = self.z - cameraZ;

        const scaleFactor = fov / (fov + relativeZ);

        // const sx: i32 = @intFromFloat(utils.map((self.x - width / 2) / self.z, 0, 1, 0, width) + width / 2);
        // const sy: i32 = @intFromFloat(utils.map((self.y - height / 2) / self.z, 0, 1, 0, height) + height / 2);

        const sx: i32 = @intFromFloat(width / 2 + relativeX * scaleFactor);
        const sy: i32 = @intFromFloat(height / 2 + relativeY * scaleFactor);

        const relativePZ = self.pz - cameraZ;
        const scaleFactorP = fov / (fov + relativePZ);

        // const px: i32 = @intFromFloat(utils.map((self.x - width / 2) / self.pz, 0, 1, 0, width) + width / 2);
        // const py: i32 = @intFromFloat(utils.map((self.y - height / 2) / self.pz, 0, 1, 0, height) + height / 2);

        const px: i32 = @intFromFloat(width / 2 + relativeX * scaleFactorP);
        const py: i32 = @intFromFloat(height / 2 + relativeY * scaleFactorP);

        const r = utils.map(self.z, 1, width, 16, 0);

        rl.drawCircle(sx, sy, r, rl.Color.white);
        rl.drawLine(px, py, sx, sy, rl.Color.white);
    }
};

pub fn run(comptime width: comptime_int, comptime height: comptime_int, comptime T: type, comptime config: T) anyerror!void {
    var stars: [config.stars]star = [1]star{star{}} ** config.stars;

    rl.initWindow(width, height, "Starfield");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    for (stars[0..]) |*s| {
        s.x = utils.randomFloat(-width, width);
        s.y = utils.randomFloat(-height, height);
        s.z = utils.randomFloat(1, width);

        s.pz = s.z;
    }

    var text_buffer: [100]u8 = [1]u8{0} ** 100;

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        const mouse = rl.getMousePosition();

        const speed = utils.map(mouse.x, 0, width, 0, 50);

        const formatted_text = try bufPrint(text_buffer[0..], "Speed: {d:.2}", .{speed});
        text_buffer[formatted_text.len] = 0;

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
            // Simulate camera at position (0, 0, 0) with a field of view of 100
            const cameraX: f32 = 0;
            const cameraY: f32 = 0;
            const cameraZ: f32 = 0;
            const fov: f32 = 120;

            s.draw(cameraX, cameraY, cameraZ, fov, width, height);
        }

        //----------------------------------------------------------------------------------
    }
}
