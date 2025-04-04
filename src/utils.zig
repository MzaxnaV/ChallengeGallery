const std = @import("std");
const RndGen = std.Random.DefaultPrng;

var rnd = RndGen.init(0);

pub const V3 = @Vector(3, f32);
pub const V4 = @Vector(4, f32);
pub const V2 = @Vector(2, f32);

pub const V2I = @Vector(2, i32);
pub const V3I = @Vector(3, i32);
pub const V4I = @Vector(4, i32);

pub const Rect = struct {
    p: V2,
    size: V2,
};

pub inline fn V2ItoV2(v: V2I) V2 {
    return .{ @floatFromInt(v[0]), @floatFromInt(v[1]) };
}

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
    pub const gold = 0xffcb00ff; // #ffcb00ff
    pub const black = 0x000000ff; // #000000ff
    pub const white = 0xffffffff; //#ffffffff
};

pub const DrawAPI = struct {
    clearBackground: *const fn (color: u32) void,

    // shape
    drawCircle: *const fn (p: V2, radius: f32, color: u32) void,
    drawLine: *const fn (start: V2, end: V2, color: u32) void,
    drawText: *const fn (text: [:0]const u8, p: V2, fontSize: i32, color: u32) void,
    drawCube: *const fn (p: V3, size: V3, color: u32) void,
    drawRectangle: *const fn (p: V2, size: V2, colour: u32) void,

    // shader
    loadShaderFromMemory: *const fn (vsCode: [:0]const u8, fsCode: [:0]const u8) ?Shader,
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
    getFrameTime: *const fn () f32,

    getMousePosition: *const fn () V2,
    isKeyReleased: *const fn (key: c_int) bool,
    isKeyDown: *const fn (key: c_int) bool,

    // math
    checkCollisionCircleRec: *const fn (center: V2, radius: f32, rec: Rect) bool,
    checkCollisionPointRec: *const fn (point: V2, rec: Rect) bool,
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
    snake,
    purple_rain,
    space_invaders,

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

pub fn randomInt(comptime T: type, min: T, max: T) T {
    comptime {
        const typeInfo = @typeInfo(T);
        if (typeInfo != .int) {
            @compileError("Invalid type, only ints allowed");
        }
    }
    return rnd.random().intRangeLessThan(T, min, max);
}

pub fn randomFloat(min: f32, max: f32) f32 {
    std.debug.assert(min <= max);
    return min + (max - min) * rnd.random().float(f32);
}

pub fn randomV(comptime T: type, min_a: T, max_a: T, min_b: T, max_b: T) @Vector(2, T) {
    return switch (T) {
        u32, i32, comptime_int => @Vector(2, T){
            randomInt(T, min_a, max_a),
            randomInt(T, min_b, max_b),
        },
        f32, comptime_float => @Vector(2, T){
            randomFloat(min_a, max_a),
            randomFloat(min_b, max_b),
        },

        else => undefined,
    };
}
