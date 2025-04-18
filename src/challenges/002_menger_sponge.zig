const std = @import("std");

const utils = @import("utils");
const AppData = utils.AppData;

//----------------------------------------------------------------------------------
// Config
//----------------------------------------------------------------------------------

const config = .{
    .depth = 2,
};

//----------------------------------------------------------------------------------
// Raylib related structs
//----------------------------------------------------------------------------------

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
};

/// Max dynamic lights supported by shader
const MAX_LIGHTS = 4;

const loc_vector_view = 11; // SHADER_LOC_VECTOR_VIEW

const uniform_int = 4; // SHADER_UNIFORM_INT
const uniform_vec3 = 2; // SHADER_UNIFORM_VEC3
const uniform_vec4 = 3; // SHADER_UNIFORM_VEC4

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

const V2 = utils.V2;
const V3 = utils.V3;
const V4 = utils.V4;
const Colours = utils.Colours;

// Raylib
const Camera3D = utils.Camera3D;
const Shader = utils.Shader;

const CameraMode = enum(c_int) {
    CAMERA_CUSTOM = 0,
    CAMERA_FREE,
    CAMERA_ORBITAL,
    CAMERA_FIRST_PERSON,
    CAMERA_THIRD_PERSON,
};

const CameraProjection = enum(c_int) {
    camera_perspective = 0,
    camera_orthographic,
};

pub const State = struct {
    camera: Camera3D,
    sponge: Sponge = Sponge{},
    shader: Shader,
    lightsCount: u32 = 0,
    lights: [MAX_LIGHTS]Light,
};

const Sponge = struct {
    p: V3 = V3{ 0, 0, 0 },
    size: f32 = 1,
    depth: u32 = 0,
    subdivBoxes: ?[]Sponge = null,

    fn draw(self: @This(), api: utils.RenderAPI) void {
        if (self.depth == 0) {
            api.drawCube(self.p, .{ self.size, self.size, self.size }, Colours.white);
        }

        if (self.subdivBoxes) |boxes| {
            for (boxes) |b| {
                b.draw(api);
            }
        }
    }

    fn cleanup(self: *Sponge, allocator: std.mem.Allocator, depth: u32) void {
        if (depth > 0) {
            self.cleanup(allocator, depth - 1);
        }

        if (self.subdivBoxes) |_| {
            allocator.free(self.subdivBoxes.?);
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
                        self.subdivBoxes.?[index].p = self.p + V3{ (x - 1) * newSize, (y - 1) * newSize, (z - 1) * newSize };

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

// ---------------------------------------------------------------------------------
// local functions
//----------------------------------------------------------------------------------

/// Create a light and get shader locations
fn createLight(api: utils.RenderAPI, state: *State, lightType: LightType, position: V3, target: V3, colour: V4, shader: Shader) ?Light {
    var light: ?Light = null;

    if (state.lightsCount < MAX_LIGHTS) {
        var buff: [512]u8 = [1]u8{0} ** 512;
        var written: usize = 0;

        const lights_enabled_txt = std.fmt.bufPrintZ(buff[written..], "lights[{}].enabled", .{state.lightsCount}) catch |err| {
            std.debug.print("Failed to format string: {}\n", .{err});
            return null;
        };
        written += lights_enabled_txt.len + 1;

        const lights_type_txt = std.fmt.bufPrintZ(buff[written..], "lights[{}].type", .{state.lightsCount}) catch |err| {
            std.debug.print("Failed to format string: {}\n", .{err});
            return null;
        };
        written += lights_type_txt.len + 1;

        const lights_position_txt = std.fmt.bufPrintZ(buff[written..], "lights[{}].position", .{state.lightsCount}) catch |err| {
            std.debug.print("Failed to format string: {}\n", .{err});
            return null;
        };
        written += lights_position_txt.len + 1;

        const lights_target_txt = std.fmt.bufPrintZ(buff[written..], "lights[{}].target", .{state.lightsCount}) catch |err| {
            std.debug.print("Failed to format string: {}\n", .{err});
            return null;
        };
        written += lights_target_txt.len + 1;

        const lights_color_txt = std.fmt.bufPrintZ(buff[written..], "lights[{}].color", .{state.lightsCount}) catch |err| {
            std.debug.print("Failed to format string: {}\n", .{err});
            return null;
        };

        light = Light{
            .enabled = true,
            .type = lightType,
            .position = position,
            .target = target,
            .color = colour,
            .attenuation = 0,

            // NOTE: Lighting shader naming must be the provided ones
            .enabledLoc = api.getShaderLocation(shader, lights_enabled_txt),
            .typeLoc = api.getShaderLocation(shader, lights_type_txt),
            .positionLoc = api.getShaderLocation(shader, lights_position_txt),
            .targetLoc = api.getShaderLocation(shader, lights_target_txt),
            .colorLoc = api.getShaderLocation(shader, lights_color_txt),
        };

        updateLightValues(api, shader, light.?);

        state.lightsCount += 1;
    }

    return light;
}

/// Send light properties to shader.
/// NOTE: Light shader locations should be available
fn updateLightValues(api: utils.RenderAPI, shader: Shader, light: Light) void {

    // Send to shader light enabled state and type
    api.setShaderValue(shader, light.enabledLoc, &light.enabled, uniform_int);
    api.setShaderValue(shader, light.typeLoc, &light.type, uniform_int);

    // Send to shader light position values
    api.setShaderValue(shader, light.positionLoc, &light.position, uniform_vec3);

    // Send to shader light target position values
    api.setShaderValue(shader, light.targetLoc, &light.target, uniform_vec3);

    // Send to shader light color values
    api.setShaderValue(shader, light.colorLoc, &light.color, uniform_vec4);
}

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

export fn setup(app_data: *AppData, _: i32, _: i32) callconv(.C) void {
    const draw_api = app_data.draw_api;

    const allocator = app_data.fba.allocator();

    var state: *State = allocator.create(State) catch |err| {
        std.debug.print("Failed to create State: {}\n", .{err});
        return;
    };

    state.* = State{
        .camera = Camera3D{
            .position = utils.Vector3{ .x = 2, .y = 2, .z = 3 },
            .target = utils.Vector3{ .x = 0, .y = 0, .z = 0 },
            .up = utils.Vector3{ .x = 0, .y = 1, .z = 0 },
            .fovy = 45,
            .projection = @intFromEnum(CameraProjection.camera_perspective),
        },
        .lights = undefined,
        .shader = undefined,
    };

    state.sponge.generate(allocator, config.depth) catch |err| {
        std.debug.print("Failed to generate sponge: {}\n", .{err});
    };

    if (draw_api.loadShaderFromMemory(lighting_vs, lighting_fs)) |shader| {
        state.shader = shader;
    } else {
        std.debug.print("Failed to load shader.\n", .{});
    }
    state.shader.locs[loc_vector_view] = draw_api.getShaderLocation(state.shader, "viewPos");

    const ambientloc = draw_api.getShaderLocation(state.shader, "ambient");
    draw_api.setShaderValue(state.shader, ambientloc, &V4{ 0.1, 0.1, 0.1, 1 }, uniform_vec4);

    const origin: V3 = .{ 0, 0, 0 };
    const red_v4 = V4{ 1, 0, 0, 1 };
    const green_v4 = V4{ 0, 1, 0, 1 };
    const blue_v4 = V4{ 0, 0, 1, 1 };
    const yellow_v4 = V4{ 1, 1, 0, 1 };

    state.lights = .{
        createLight(app_data.draw_api, state, .LIGHT_POINT, .{ -2, 1, -2 }, origin, yellow_v4, state.shader).?,
        createLight(app_data.draw_api, state, .LIGHT_POINT, .{ 2, 1, 2 }, origin, red_v4, state.shader).?,
        createLight(app_data.draw_api, state, .LIGHT_POINT, .{ -2, 1, 2 }, origin, green_v4, state.shader).?,
        createLight(app_data.draw_api, state, .LIGHT_POINT, .{ 2, 1, -2 }, origin, blue_v4, state.shader).?,
    };
}

export fn update(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));

    app_data.draw_api.updateCamera(&state.camera, @intFromEnum(CameraMode.CAMERA_ORBITAL));
}

export fn render(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));
    const draw_api = app_data.draw_api;

    draw_api.clearBackground(Colours.bg);

    draw_api.beginMode3D(state.camera);
    defer draw_api.endMode3D();

    {
        draw_api.beginShaderMode(state.shader);
        defer draw_api.endShaderMode();

        state.sponge.draw(draw_api);
    }
}

export fn cleanup(app_data: *AppData) callconv(.C) void {
    const allocator = app_data.fba.allocator();
    const draw_api = app_data.draw_api;
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));

    state.sponge.cleanup(allocator, state.sponge.depth);

    allocator.destroy(state);

    draw_api.unloadShader(state.shader);
}

// ---------------------------------------------------------------------------------
// Shader definitions
//----------------------------------------------------------------------------------

const lighting_fs =
    \\ #version 330
    \\
    \\ // Input vertex attributes (from vertex shader)
    \\ in vec3 fragPosition;
    \\ in vec2 fragTexCoord;
    \\ //in vec4 fragColor;
    \\ in vec3 fragNormal;
    \\
    \\ // Input uniform values
    \\ uniform sampler2D texture0;
    \\ uniform vec4 colDiffuse;
    \\
    \\ // Output fragment color
    \\ out vec4 finalColor;
    \\
    \\ // NOTE: Add here your custom variables
    \\ #define     MAX_LIGHTS              4
    \\ #define     LIGHT_DIRECTIONAL       0
    \\ #define     LIGHT_POINT             1
    \\
    \\ struct Light {
    \\     int enabled;
    \\     int type;
    \\     vec3 position;
    \\     vec3 target;
    \\     vec4 color;
    \\ };
    \\
    \\ // Input lighting values
    \\ uniform Light lights[MAX_LIGHTS];
    \\ uniform vec4 ambient;
    \\ uniform vec3 viewPos;
    \\
    \\ void main()
    \\ {
    \\     // Texel color fetching from texture sampler
    \\     vec4 texelColor = texture(texture0, fragTexCoord);
    \\     vec3 lightDot = vec3(0.0);
    \\     vec3 normal = normalize(fragNormal);
    \\     vec3 viewD = normalize(viewPos - fragPosition);
    \\     vec3 specular = vec3(0.0);
    \\
    \\     // NOTE: Implement here your fragment shader code
    \\     for (int i = 0; i < MAX_LIGHTS; i++)
    \\     {
    \\         if (lights[i].enabled == 1)
    \\         {
    \\             vec3 light = vec3(0.0);
    \\             if (lights[i].type == LIGHT_DIRECTIONAL)
    \\             {
    \\                 light = -normalize(lights[i].target - lights[i].position);
    \\             }
    \\             if (lights[i].type == LIGHT_POINT)
    \\             {
    \\                 light = normalize(lights[i].position - fragPosition);
    \\             }
    \\             float NdotL = max(dot(normal, light), 0.0);
    \\             lightDot += lights[i].color.rgb*NdotL;
    \\             float specCo = 0.0;
    \\             if (NdotL > 0.0) specCo = pow(max(0.0, dot(viewD, reflect(-(light), normal))), 16.0); // 16 refers to shine
    \\             specular += specCo;
    \\         }
    \\     }
    \\
    \\     finalColor = (texelColor*((colDiffuse + vec4(specular, 1.0))*vec4(lightDot, 1.0)));
    \\     finalColor += texelColor*(ambient/10.0)*colDiffuse;
    \\     // Gamma correction
    \\     finalColor = pow(finalColor, vec4(1.0/2.2));
    \\ }
;

const lighting_vs =
    \\ #version 330
    \\ // Input vertex attributes
    \\ in vec3 vertexPosition;
    \\ in vec2 vertexTexCoord;
    \\ in vec3 vertexNormal;
    \\ in vec4 vertexColor;
    \\
    \\ // Input uniform values
    \\ uniform mat4 mvp;
    \\ uniform mat4 matModel;
    \\ uniform mat4 matNormal;
    \\
    \\ // Output vertex attributes (to fragment shader)
    \\ out vec3 fragPosition;
    \\ out vec2 fragTexCoord;
    \\ out vec4 fragColor;
    \\ out vec3 fragNormal;
    \\
    \\ // NOTE: Add here your custom variables
    \\ void main()
    \\ {
    \\     // Send vertex attributes to fragment shader
    \\     fragPosition = vec3(matModel*vec4(vertexPosition, 1.0));
    \\     fragTexCoord = vertexTexCoord;
    \\     fragColor = vertexColor;
    \\     fragNormal = normalize(vec3(matNormal*vec4(vertexNormal, 1.0)));
    \\ 
    \\     // Calculate final vertex position
    \\     gl_Position = mvp*vec4(vertexPosition, 1.0);
    \\ }
;
