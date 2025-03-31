const std = @import("std");
const RndGen = std.Random.DefaultPrng;

var rnd = RndGen.init(0);

pub const V3 = @Vector(3, f32);
pub const V4 = @Vector(4, f32);
pub const V2 = @Vector(2, f32);

pub const V2I = @Vector(2, i32);
pub const V3I = @Vector(3, i32);
pub const V4I = @Vector(4, i32);

// -

pub const Vector3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Shader = extern struct {
    id: c_uint,
    locs: [*c]c_int,
};

pub const Camera3D = extern struct {
    position: Vector3,
    target: Vector3,
    up: Vector3,
    fovy: f32,
    projection: c_int,
};

pub const Colours = struct {
    pub const bg = 0x202020ff; //#202020
    pub const black = 0x000000ff; // #000000ff
    pub const gold = 0xffcb00ff; // #ffcb00ff
    pub const white = 0xffffffff; //#ffffffff
};

pub const DrawAPI = struct {
    clearBackground: *const fn (color: u32) void,

    // shape
    drawCircle: *const fn (p: V2, radius: f32, color: u32) void,
    drawLine: *const fn (start: V2, end: V2, color: u32) void,
    drawText: *const fn (text: [:0]const u8, p: V2, fontSize: i32, color: u32) void,
    drawCube: *const fn (p: V3, size: V3, color: u32) void,

    // shader
    loadShader: *const fn (vsFileName: [:0]const u8, fsFileName: [:0]const u8) ?Shader,
    unloadShader: *const fn (shader: Shader) void,
    getShaderLocation: *const fn (shader: Shader, uniformName: [:0]const u8) c_int,
    beginShaderMode: *const fn (shader: Shader) void,
    endShaderMode: *const fn () void,
    setShaderValue: *const fn (shader: Shader, locIndex: c_int, value: *const anyopaque, uniformType: c_int) void,

    // camera
    beginMode3D: *const fn (camera: Camera3D) void,
    endMode3D: *const fn () void,
    updateCamera: *const fn (camera: *Camera3D, camera_mode: c_int) void,
};

pub const InputAPI = struct {
    // Input Functions
    getMousePosition: *const fn () V2,
};

pub const AppData = struct {
    fba: std.heap.FixedBufferAllocator,

    draw_api: DrawAPI,
    input_api: InputAPI,
};

pub const AppMode = enum {
    None,
};

pub const AppType = enum(u32) {
    starfield,
    menger_sponge,
    // snake,
    // purple_rain,
    // space_invaders,

    pub fn getList() [:0]const u8 {
        const type_info = @typeInfo(@This());

        comptime var list = type_info.@"enum".fields[0].name;
        inline for (type_info.@"enum".fields[1..]) |field| {
            list = list ++ ";" ++ field.name;
        }

        return list;
    }
};

pub fn App() type {
    return struct {
        pub const SetupFn = *const fn (app_data: *AppData, width: i32, height: i32) callconv(.C) void;
        pub const CommonFn = *const fn (app_data: *const AppData) callconv(.C) void;
        pub const CleanUpFn = *const fn (app_data: *AppData) callconv(.C) void;

        tag: AppType,
        setup: SetupFn,
        update: CommonFn,
        /// draws to a render texture
        render: CommonFn,
        cleanup: CleanUpFn,
    };
}

pub inline fn remap(value: f32, inputStart: f32, inputEnd: f32, outputStart: f32, outputEnd: f32) f32 {
    const result = (value - inputStart) / (inputEnd - inputStart) * (outputEnd - outputStart) + outputStart;
    return result;
}

pub fn randomInt(min: i32, max: i32) i32 {
    return rnd.random().intRangeLessThan(i32, min, max);
}

pub fn randomFloat(min: f32, max: f32) f32 {
    std.debug.assert(min <= max);
    return min + (max - min) * rnd.random().float(f32);
}

pub fn scale(v: V2, scl: f32) V2 {
    const scaleV: V2 = @splat(scl);
    return v * scaleV;
}

pub fn xy(v: anytype) V2 {
    return V2{ v[0], v[1] };
}
