const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlua_dep = b.dependency("ziglua", .{});
    const zbench = b.dependency("zbench", .{});

    const zbench_mod = b.addModule("zbench", .{
        .root_source_file = b.path("src/lua_zbench.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "zbench", .module = zbench.module("zbench") },
        },
    });

    const lib_root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zbench", .module = zbench_mod },
        },
    });

    lib_root_module.linkSystemLibrary("luajit", .{});

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zbench",
        .root_module = lib_root_module,
    });

    b.installArtifact(lib);

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/lua_zbench.zig"),
        .target = target,
        .link_libc = true,
.imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "zbench", .module = zbench.module("zbench") },
        },
    });
    test_module.linkSystemLibrary("luajit", .{});

    const mod_tests = b.addTest(.{
        .root_module = test_module,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
