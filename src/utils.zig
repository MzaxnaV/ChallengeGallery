const std = @import("std");
const RndGen = std.Random.DefaultPrng;

const rl = @import("raylib");

pub const Vector2I = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Vector2I {
        return Vector2I{ .x = x, .y = y };
    }

    pub fn toVector2(vec: Vector2I) rl.Vector2 {
        const result = rl.Vector2.init(@floatFromInt(vec.x), @floatFromInt(vec.y));
        return result;
    }

    pub fn fromVector2(vec: rl.Vector2) Vector2I {
        const result = rl.Vector2.init(@intFromFloat(vec.x), @intFromFloat(vec.y));
        return result;
    }
};

pub var rnd = RndGen.init(0);

pub fn randomInt(min: i32, max: i32) i32 {
    return rnd.random().intRangeLessThan(i32, min, max);
}

pub fn randomFloat(min: f32, max: f32) f32 {
    std.debug.assert(min <= max);
    return min + (max - min) * rnd.random().float(f32);
}

pub fn randomVector2(min_x: f32, max_x: f32, min_y: f32, max_y: f32) rl.Vector2 {
    std.debug.assert(min_x <= max_x);
    std.debug.assert(min_y <= max_y);

    return rl.Vector2.init(randomFloat(min_x, max_x), randomFloat(min_y, max_y));
}

//----------------------------------------------------------------------------------
// Vector2 utility functions
// ---------------------------------------------------------------------------------

pub fn randomVector2I(min_x: i32, max_x: i32, min_y: i32, max_y: i32) Vector2I {
    std.debug.assert(min_x <= max_x);
    std.debug.assert(min_y <= max_y);

    return Vector2I.init(randomInt(min_x, max_x), randomInt(min_y, max_y));
}

pub fn isEqual(a: Vector2I, b: Vector2I) bool {
    return a.x == b.x and a.y == b.y;
}

//----------------------------------------------------------------------------------
// Vector2I math functions
// ---------------------------------------------------------------------------------

pub fn vector2IScale(v: Vector2I, scale: i32) Vector2I {
    return Vector2I.init(v.x * scale, v.y * scale);
}

pub fn vector2IAdd(v1: Vector2I, v2: Vector2I) Vector2I {
    return Vector2I.init(v1.x + v2.x, v1.y + v2.y);
}
