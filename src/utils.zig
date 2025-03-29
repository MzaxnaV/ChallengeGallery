const std = @import("std");
const RndGen = std.Random.DefaultPrng;

var rnd = RndGen.init(0);

pub const Vector3 = @Vector(3, f32);
pub const Vector4 = @Vector(4, f32);
pub const Vector2 = @Vector(2, f32);

pub const Vector2I = @Vector(2, i32);
pub const Vector3I = @Vector(3, i32);
pub const Vector4I = @Vector(4, i32);

pub const Colours = struct {
    pub const black = 0x000000ff; // #000000ff
    pub const gold = 0xffcb00ff; // #ffcb00ff
    pub const white = 0xffffffff; // #ffffffff
};

pub const DrawAPI = struct {
    // Draw Functions
    clearBackground: *const fn (color: u32) void,
    drawCircle: *const fn (p: Vector2, radius: f32, color: u32) void,
    drawLine: *const fn (start: Vector2, end: Vector2, color: u32) void,
    drawText: *const fn (text: [:0]const u8, p: Vector2, fontSize: i32, color: u32) void,
};

pub const InputAPI = struct {
    // Input Functions
    getMousePosition: *const fn () Vector2,
};

pub const AppData = struct {
    storage_size: usize,
    storage: [*]u8,

    draw_api: DrawAPI,
    input_api: InputAPI,
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

pub fn App(comptime tag: AppType) type {
    return struct {
        pub const SetupFn = *const fn (app_data: *AppData, width: i32, height: i32) callconv(.C) void;
        pub const CommonFn = *const fn (app_data: *const AppData) callconv(.C) void;

        tag: AppType = tag,
        setup: SetupFn,
        update: CommonFn,
        /// draws to a render texture
        render: CommonFn,
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

pub fn scale(v: Vector2, scl: f32) Vector2 {
    const scaleV: Vector2 = @splat(scl);
    return v * scaleV;
}

pub fn xy(v: anytype) Vector2 {
    return Vector2{ v[0], v[1] };
}
