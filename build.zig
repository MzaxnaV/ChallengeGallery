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
    const rlgl = raylib_dep.module("rlgl");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const raygui_dep = b.dependency("raygui", .{});
    var raygui_step = b.addWriteFiles();
    // need a c file https://github.com/ziglang/zig/issues/19423
    const raygui_c = raygui_step.add("raygui.c", "#define RAYGUI_IMPLEMENTATION\n#include \"raygui.h\"\n");

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
        .target = target,
        .optimize = .ReleaseSafe,
        .imports = &.{
            std.Build.Module.Import{ .name = "raylib", .module = raylib },
            std.Build.Module.Import{ .name = "raylib-math", .module = raylib_math },
        },
    });

    const exe = b.addExecutable(.{
        .name = "ChallengeGallery",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize,
        .target = target,
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raylib-math", raylib_math);
    exe.root_module.addImport("rlgl", rlgl);
    exe.root_module.addImport("utils", utils);
    exe.addCSourceFile(.{ .file = raygui_c });
    exe.addIncludePath(raygui_dep.path("src"));

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run ChallengeGallery");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
