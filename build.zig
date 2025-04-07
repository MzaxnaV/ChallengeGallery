const std = @import("std");
const rlz = @import("raylib-zig");

fn buildChallenges(b: *std.Build, utils: *std.Build.Module, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) !void {
    var dir = try std.fs.cwd().openDir("src/challenges/", .{ .iterate = true });

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .file and entry.kind != .directory) {
            var buff: [64]u8 = [1]u8{0} ** 64;
            const path = try std.fmt.bufPrint(buff[0..], "src/challenges/{s}", .{entry.name});

            const lib_mod = b.createModule(.{
                .root_source_file = b.path(path),
                .target = target,
                .optimize = optimize,
            });

            lib_mod.addImport("utils", utils);

            const name_without_extensions = entry.name[0 .. entry.name.len - 4];

            const lib = b.addSharedLibrary(.{
                .name = name_without_extensions,
                .root_module = lib_mod,
            });

            b.installArtifact(lib);
        }
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const utils = b.createModule(.{
        .root_source_file = b.path("./src/utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    // //web exports are completely separate
    // if (target.query.os_tag == .emscripten) {
    //     const exe_lib = try rlz.emcc.compileForEmscripten(b, "'ChallengeGallery'", "src/main.zig", target, optimize);

    //     exe_lib.linkLibrary(raylib_artifact);
    //     exe_lib.root_module.addImport("raylib", raylib);
    //     exe_lib.root_module.addImport("utils", utils);

    //     // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
    //     const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });

    //     b.getInstallStep().dependOn(&link_step.step);
    //     const run_step = try rlz.emcc.emscriptenRunStep(b);
    //     run_step.step.dependOn(&link_step.step);
    //     const run_option = b.step("run", "Run 'ChallengeGallery'");
    //     run_option.dependOn(&run_step.step);
    //     return;
    // }

    try buildChallenges(b, utils, optimize, target);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ChallengeGallery",
        .root_module = exe_mod,
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
    exe.root_module.addImport("utils", utils);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run ChallengeGallery");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
