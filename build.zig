const std = @import("std");
const rlz = @import("raylib-zig");

fn buildChallenges(b: *std.Build, utils_mod: *std.Build.Module, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) !*std.Build.Module {
    var content = std.ArrayList(u8).init(b.allocator);
    var writer = content.writer();

    try writer.writeAll(
        \\pub const AppType = enum(u32) {
        \\
    );

    var dir = try std.fs.cwd().openDir("src/challenges/", .{ .iterate = true });

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .file and entry.kind != .directory) {
            const name_without_ext = entry.name[4 .. entry.name.len - 4];

            const path = try std.fmt.allocPrint(b.allocator, "src/challenges/{s}", .{entry.name});
            defer b.allocator.free(path);

            const lib_mod = b.createModule(.{
                .root_source_file = b.path(path),
                .target = target,
                .optimize = optimize,
            });

            lib_mod.addImport("utils", utils_mod);

            const lib = b.addSharedLibrary(.{
                .name = name_without_ext,
                .root_module = lib_mod,
            });

            try writer.print("\t{s},\n", .{name_without_ext});

            b.installArtifact(lib);
        }
    }

    try writer.writeAll(
        \\
        \\    pub fn getList() [:0]const u8 {
        \\        const type_info = @typeInfo(@This());
        \\
        \\        comptime var list = type_info.@"enum".fields[0].name;
        \\        inline for (type_info.@"enum".fields[1..]) |field| {
        \\            list = list ++ ";" ++ field.name;
        \\        }
        \\
        \\        return list;
        \\    }
        \\};
    );

    const module = b.createModule(.{
        .root_source_file = b.addWriteFiles().add("challenges.zig", content.items),
        .target = target,
        .optimize = optimize,
    });

    return module;
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

    const utils_mod = b.createModule(.{
        .root_source_file = b.path("./src/utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    const challenges_mod = try buildChallenges(b, utils_mod, optimize, target);

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

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("raylib", raylib);
    exe_mod.addImport("raygui", raygui);
    exe_mod.addImport("utils", utils_mod);
    exe_mod.addImport("challenges", challenges_mod);

    const exe = b.addExecutable(.{
        .name = "ChallengeGallery",
        .root_module = exe_mod,
    });

    exe.linkLibrary(raylib_artifact);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run ChallengeGallery");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
