const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
    usingnamespace @import("rlgl");
};

const utils = @import("utils");
const std = @import("std");

/// Max dynamic lights supported by shader
pub const MAX_LIGHTS = 4;

pub var lightsCount: u32 = 0;

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

const box = struct {
    p: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    size: f32 = 1,
    depth: u32 = 0,
    subdivBox: ?[]box = null,

    fn draw(self: @This()) void {
        if (self.depth == 0) {
            rl.drawCube(self.p, self.size, self.size, self.size, rl.Color.white);
        }

        if (self.subdivBox) |boxes| {
            for (boxes) |b| {
                b.draw();
            }
        }
    }

    fn generate(self: *box, allocator: std.mem.Allocator, comptime depth: comptime_int) anyerror!void {
        comptime {
            if (depth > 4) {
                @compileError("Depth should be less than 4");
            }
        }

        self.depth = depth;
        if (depth > 0) {
            self.subdivBox = try allocator.alloc(box, 27);

            var index: u32 = 0;
            var x: f32 = 0;
            while (x < 3) : (x += 1) {
                var y: f32 = 0;
                while (y < 3) : (y += 1) {
                    var z: f32 = 0;
                    while (z < 3) : (z += 1) {
                        const newSize = self.size / 3;
                        self.subdivBox.?[index].p = rl.Vector3.init(
                            self.p.x + (x - 1) * newSize,
                            self.p.y + (y - 1) * newSize,
                            self.p.z + (z - 1) * newSize,
                        );
                        self.subdivBox.?[index].size = newSize;
                        self.subdivBox.?[index].depth = depth;
                        if (@abs(x - 1) + @abs(y - 1) + @abs(z - 1) > 1) {
                            try self.subdivBox.?[index].generate(allocator, depth - 1);
                        } else {
                            self.subdivBox.?[index].subdivBox = null;
                        }

                        index += 1;
                    }
                }
            }
        } else {
            self.subdivBox = null;
        }
    }
};

/// Light data
pub const Light = extern struct {
    enabled: bool,
    type: LightType,
    position: [3]f32,
    target: [3]f32,
    color: [4]f32,
    attenuation: f32,

    // Shader locations
    enabledLoc: c_int,
    typeLoc: c_int,
    positionLoc: c_int,
    targetLoc: c_int,
    colorLoc: c_int,
    attenuationLoc: c_int,
};

/// Light type
pub const LightType = enum(c_int) {
    LIGHT_DIRECTIONAL = 0,
    LIGHT_POINT,
};

/// Create a light and get shader locations
pub fn CreateLight(lightType: LightType, position: rl.Vector3, target: rl.Vector3, color: rl.Color, shader: rl.Shader) ?Light {
    var light: ?Light = undefined;

    if (lightsCount < MAX_LIGHTS) {
        light = Light{
            .enabled = true,
            .type = lightType,
            .position = .{ position.x, position.y, position.z },
            .target = .{ target.x, target.y, target.z },
            .color = .{
                @as(f32, @floatFromInt(color.r)) / 255.0,
                @as(f32, @floatFromInt(color.g)) / 255.0,
                @as(f32, @floatFromInt(color.b)) / 255.0,
                @as(f32, @floatFromInt(color.a)) / 255.0,
            },
            .attenuation = 0,

            // NOTE: Lighting shader naming must be the provided ones
            .enabledLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].enabled", .{lightsCount})),
            .typeLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].type", .{lightsCount})),
            .positionLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].position", .{lightsCount})),
            .targetLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].target", .{lightsCount})),
            .colorLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].color", .{lightsCount})),
            .attenuationLoc = 0,
        };

        UpdateLightValues(shader, light.?);

        lightsCount += 1;
    }

    return light;
}

/// Send light properties to shader.
/// NOTE: Light shader locations should be available
pub fn UpdateLightValues(shader: rl.Shader, light: Light) void {

    // Send to shader light enabled state and type
    rl.setShaderValue(shader, light.enabledLoc, &light.enabled, @intFromEnum(rl.ShaderUniformDataType.shader_uniform_int));
    rl.setShaderValue(shader, light.typeLoc, &light.type, @intFromEnum(rl.ShaderUniformDataType.shader_uniform_int));

    // Send to shader light position values
    rl.setShaderValue(shader, light.positionLoc, &light.position, @intFromEnum(rl.ShaderUniformDataType.shader_uniform_vec3));

    // Send to shader light target position values
    rl.setShaderValue(shader, light.targetLoc, &light.target, @intFromEnum(rl.ShaderUniformDataType.shader_uniform_vec3));

    // Send to shader light color values
    rl.setShaderValue(shader, light.colorLoc, &light.color, @intFromEnum(rl.ShaderUniformDataType.shader_uniform_vec4));
}

pub fn run(comptime width: comptime_int, comptime height: comptime_int, comptime T: type, comptime _: T) anyerror!void {
    var object = box{};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try object.generate(allocator, 2);

    rl.initWindow(width, height, "Menger-Sponge");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(2, 2, 3),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = rl.CameraProjection.camera_perspective,
    };

    const shader: rl.Shader = rl.loadShader("assets/shaders/lighting.vs", "assets/shaders/lighting.fs");
    shader.locs[@intFromEnum(rl.ShaderLocationIndex.shader_loc_vector_view)] = rl.getShaderLocation(shader, "viewPos");

    const ambientloc = rl.getShaderLocation(shader, "ambient");
    rl.setShaderValue(shader, ambientloc, &rl.Vector4.init(0.1, 0.1, 0.1, 1), @intFromEnum(rl.ShaderUniformDataType.shader_uniform_ivec4));

    var lights: [MAX_LIGHTS]Light = undefined;

    lights[0] = CreateLight(.LIGHT_POINT, rl.Vector3.init(-2, 1, -2), rl.vector3Zero(), rl.Color.yellow, shader).?;
    lights[1] = CreateLight(.LIGHT_POINT, rl.Vector3.init(2, 1, 2), rl.vector3Zero(), rl.Color.red, shader).?;
    lights[2] = CreateLight(.LIGHT_POINT, rl.Vector3.init(-2, 1, 2), rl.vector3Zero(), rl.Color.green, shader).?;
    lights[3] = CreateLight(.LIGHT_POINT, rl.Vector3.init(2, 1, -2), rl.vector3Zero(), rl.Color.blue, shader).?;

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        rl.updateCamera(&camera, rl.CameraMode.camera_orbital);

        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.gray);

        {
            rl.beginMode3D(camera);
            defer rl.endMode3D();

            {
                rl.beginShaderMode(shader);
                defer rl.endShaderMode();

                object.draw();
            }
        }

        //----------------------------------------------------------------------------------
    }
}
