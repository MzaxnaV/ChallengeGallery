const std = @import("std");
// const rlz = @import("raylib-zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_math = raylib_dep.module("raylib-math");
    const raylib_artifact = raylib_dep.artifact("raylib");

    // NOTE: Not interested in web exports atm
    //web exports are completely separate
    // if (target.query.os_tag == .emscripten) {
    //     const exe_lib = rlz.emcc.compileForEmscripten(b, "'ChallengeGallery'", "src/main.zig", target, optimize);

    //     exe_lib.linkLibrary(raylib_artifact);
    //     exe_lib.root_module.addImport("raylib", raylib);
    //     exe_lib.root_module.addImport("raylib-math", raylib_math);

    //     // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
    //     const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });

    //     b.getInstallStep().dependOn(&link_step.step);
    //     const run_step = try rlz.emcc.emscriptenRunStep(b);
    //     run_step.step.dependOn(&link_step.step);
    //     const run_option = b.step("run", "Run 'ChallengeGallery'");
    //     run_option.dependOn(&run_step.step);
    //     return;
    // }

    const utils = b.createModule(.{
        .root_source_file = b.path("./src/utils.zig"),
    });

    const exe = b.addExecutable(.{ .name = "ChallengeGallery", .root_source_file = .{ .path = "src/main.zig" }, .optimize = optimize, .target = target });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raylib-math", raylib_math);
    exe.root_module.addImport("utils", utils);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run ChallengeGallery");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
