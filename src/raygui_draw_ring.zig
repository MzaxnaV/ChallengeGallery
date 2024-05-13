const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
};

/// keep this separate from raylib to avoid ambiguous symbols
const ray = struct {
    usingnamespace @cImport({
        @cInclude("raygui.h");
    });
};

pub fn run(comptime width: comptime_int, comptime height: comptime_int) anyerror!void {
    rl.initWindow(width, height, "RayGui");
    defer rl.closeWindow(); // Close window and OpenGL context

    const center = rl.Vector2.init(
        @as(f32, @floatFromInt(rl.getScreenWidth() - 300)) / 2.0,
        @as(f32, @floatFromInt(rl.getScreenHeight())) / 2.0,
    );

    var innerRadius: f32 = 80.0;
    var outerRadius: f32 = 190.0;

    var startAngle: f32 = 0.0;
    var endAngle: f32 = 360.0;
    var segments: f32 = 0.0;

    var drawRing = true;
    var drawRingLines = false;
    var drawCircleLines = true;

    rl.setTargetFPS(60);

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);
        rl.drawLine(500, 0, 500, rl.getScreenHeight(), rl.fade(rl.Color.light_gray, 0.6));
        rl.drawRectangle(500, 0, rl.getScreenWidth() - 500, rl.getScreenHeight(), rl.fade(rl.Color.light_gray, 0.3));

        if (drawRing) {
            rl.drawRing(center, innerRadius, outerRadius, startAngle, endAngle, @intFromFloat(segments), rl.fade(rl.Color.maroon, 0.3));
        }

        if (drawRingLines) {
            rl.drawRingLines(center, innerRadius, outerRadius, startAngle, endAngle, @intFromFloat(segments), rl.fade(rl.Color.black, 0.4));
        }

        if (drawCircleLines) {
            rl.drawCircleSectorLines(center, innerRadius, startAngle, endAngle, @intFromFloat(segments), rl.fade(rl.Color.black, 0.4));
        }

        // Draw Gui Controls
        //----------------------------------------------------------------------------------
        _ = ray.GuiSliderBar(ray.Rectangle{ .x = 600, .y = 40, .width = 120, .height = 20 }, "StartAngle", null, &startAngle, -450, 450);
        _ = ray.GuiSliderBar(ray.Rectangle{ .x = 600, .y = 70, .width = 120, .height = 20 }, "EndAngle", null, &endAngle, -450, 450);

        _ = ray.GuiSliderBar(ray.Rectangle{ .x = 600, .y = 140, .width = 120, .height = 20 }, "InnerRadius", null, &innerRadius, 0, 100);
        _ = ray.GuiSliderBar(ray.Rectangle{ .x = 600, .y = 170, .width = 120, .height = 20 }, "OuterRadius", null, &outerRadius, 0, 200);

        _ = ray.GuiSliderBar(ray.Rectangle{ .x = 600, .y = 240, .width = 120, .height = 20 }, "Segments", null, &segments, 0, 100);

        _ = ray.GuiCheckBox(ray.Rectangle{ .x = 600, .y = 320, .width = 20, .height = 20 }, "Draw Ring", &drawRing);
        _ = ray.GuiCheckBox(ray.Rectangle{ .x = 600, .y = 350, .width = 20, .height = 20 }, "Draw RingLines", &drawRingLines);
        _ = ray.GuiCheckBox(ray.Rectangle{ .x = 600, .y = 380, .width = 20, .height = 20 }, "Draw CircleLines", &drawCircleLines);

        //----------------------------------------------------------------------------------
    }
}
