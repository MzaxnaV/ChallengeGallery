const std = @import("std");
const RndGen = std.rand.DefaultPrng;

pub var rnd = RndGen.init(0);

pub fn map(value: f32, start1: f32, stop1: f32, start2: f32, stop2: f32) f32 {
    return start2 + ((value - start1) * (stop2 - start2) / (stop1 - start1));
}

pub fn randomInt(min: i32, max: i32) i32 {
    return rnd.random().intRangeLessThan(i32, min, max);
}

pub fn randomFloat(min: f32, max: f32) f32 {
    std.debug.assert(min <= max);
    return min + (max - min) * rnd.random().float(f32);
}
