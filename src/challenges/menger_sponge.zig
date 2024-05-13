const std = @import("std");

const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
    usingnamespace @import("rlgl");
};

const utils = @import("utils");

//----------------------------------------------------------------------------------
// Consts
//----------------------------------------------------------------------------------

pub const config = .{
    .title = "Menger-Sponge",
    .depth = 2,
};

/// Max dynamic lights supported by shader
const MAX_LIGHTS = 4;

const loc_vector_view = @intFromEnum(rl.ShaderLocationIndex.shader_loc_vector_view);

const uniform_int = @intFromEnum(rl.ShaderUniformDataType.shader_uniform_int);
const uniform_vec3 = @intFromEnum(rl.ShaderUniformDataType.shader_uniform_vec3);
const uniform_vec4 = @intFromEnum(rl.ShaderUniformDataType.shader_uniform_vec4);
const uniform_ivec4 = @intFromEnum(rl.ShaderUniformDataType.shader_uniform_ivec4);

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

const Sponge = struct {
    p: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    size: f32 = 1,
    depth: u32 = 0,
    subdivBoxes: ?[]Sponge = null,

    fn draw(self: @This()) void {
        if (self.depth == 0) {
            rl.drawCube(self.p, self.size, self.size, self.size, rl.Color.white);
        }

        if (self.subdivBoxes) |boxes| {
            for (boxes) |b| {
                b.draw();
            }
        }
    }

    fn generate(self: *Sponge, allocator: std.mem.Allocator, comptime depth: comptime_int) anyerror!void {
        comptime {
            if (depth > 4) {
                @compileError("Depth should be less than 4");
            }
        }

        self.depth = depth;
        if (depth > 0) {
            self.subdivBoxes = try allocator.alloc(Sponge, 27);

            var index: u32 = 0;
            var x: f32 = 0;
            while (x < 3) : (x += 1) {
                var y: f32 = 0;
                while (y < 3) : (y += 1) {
                    var z: f32 = 0;
                    while (z < 3) : (z += 1) {
                        const newSize = self.size / 3;
                        self.subdivBoxes.?[index].p = rl.Vector3.init(
                            self.p.x + (x - 1) * newSize,
                            self.p.y + (y - 1) * newSize,
                            self.p.z + (z - 1) * newSize,
                        );
                        self.subdivBoxes.?[index].size = newSize;
                        self.subdivBoxes.?[index].depth = depth;
                        if (@abs(x - 1) + @abs(y - 1) + @abs(z - 1) > 1) {
                            try self.subdivBoxes.?[index].generate(allocator, depth - 1);
                        } else {
                            self.subdivBoxes.?[index].subdivBoxes = null;
                        }

                        index += 1;
                    }
                }
            }
        } else {
            self.subdivBoxes = null;
        }
    }
};

/// Light type
const LightType = enum(c_int) {
    LIGHT_DIRECTIONAL = 0,
    LIGHT_POINT,
};

/// Light data
const Light = extern struct {
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

//----------------------------------------------------------------------------------
// Globals
//----------------------------------------------------------------------------------

var g: struct {
    camera: rl.Camera3D = undefined,
    sponge: Sponge = undefined,
    shader: rl.Shader = undefined,
    lightsCount: u32 = 0,
    lights: [MAX_LIGHTS]Light = undefined,
} = .{};

// ---------------------------------------------------------------------------------
// local functions
//----------------------------------------------------------------------------------

/// Create a light and get shader locations
fn createLight(lightType: LightType, position: rl.Vector3, target: rl.Vector3, color: rl.Color, shader: rl.Shader) ?Light {
    var light: ?Light = undefined;

    if (g.lightsCount < MAX_LIGHTS) {
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
            .enabledLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].enabled", .{g.lightsCount})),
            .typeLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].type", .{g.lightsCount})),
            .positionLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].position", .{g.lightsCount})),
            .targetLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].target", .{g.lightsCount})),
            .colorLoc = rl.getShaderLocation(shader, rl.textFormat("lights[%i].color", .{g.lightsCount})),
            .attenuationLoc = 0,
        };

        updateLightValues(shader, light.?);

        g.lightsCount += 1;
    }

    return light;
}

/// Send light properties to shader.
/// NOTE: Light shader locations should be available
fn updateLightValues(shader: rl.Shader, light: Light) void {

    // Send to shader light enabled state and type
    rl.setShaderValue(shader, light.enabledLoc, &light.enabled, uniform_int);
    rl.setShaderValue(shader, light.typeLoc, &light.type, uniform_int);

    // Send to shader light position values
    rl.setShaderValue(shader, light.positionLoc, &light.position, uniform_vec3);

    // Send to shader light target position values
    rl.setShaderValue(shader, light.targetLoc, &light.target, uniform_vec3);

    // Send to shader light color values
    rl.setShaderValue(shader, light.colorLoc, &light.color, uniform_vec4);
}

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

pub fn setup(allocator: std.mem.Allocator, comptime _: comptime_int, comptime _: comptime_int) anyerror!void {
    g.sponge = Sponge{};
    try g.sponge.generate(allocator, config.depth);

    g.camera = rl.Camera3D{
        .position = rl.Vector3.init(2, 2, 3),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = rl.CameraProjection.camera_perspective,
    };

    g.shader = rl.loadShader("assets/shaders/lighting.vs", "assets/shaders/lighting.fs");
    g.shader.locs[loc_vector_view] = rl.getShaderLocation(g.shader, "viewPos");

    const ambientloc = rl.getShaderLocation(g.shader, "ambient");
    rl.setShaderValue(g.shader, ambientloc, &rl.Vector4.init(0.1, 0.1, 0.1, 1), uniform_ivec4);

    g.lights = .{
        createLight(.LIGHT_POINT, rl.Vector3.init(-2, 1, -2), rl.vector3Zero(), rl.Color.yellow, g.shader).?,
        createLight(.LIGHT_POINT, rl.Vector3.init(2, 1, 2), rl.vector3Zero(), rl.Color.red, g.shader).?,
        createLight(.LIGHT_POINT, rl.Vector3.init(-2, 1, 2), rl.vector3Zero(), rl.Color.green, g.shader).?,
        createLight(.LIGHT_POINT, rl.Vector3.init(2, 1, -2), rl.vector3Zero(), rl.Color.blue, g.shader).?,
    };
}

pub fn update() void {
    rl.updateCamera(&g.camera, rl.CameraMode.camera_orbital);
}

pub fn cleanup() void {
    rl.unloadShader(g.shader);
}

pub fn render() void {
    rl.beginMode3D(g.camera);
    defer rl.endMode3D();

    {
        rl.beginShaderMode(g.shader);
        defer rl.endShaderMode();

        g.sponge.draw();
    }
}
