const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Use zlua's built-in LuaJIT compilation support
    // (ziglua can compile LuaJIT from source, no system LuaJIT needed)
    const zlua_dep = b.dependency("ziglua", .{
        .lang = .luajit,
        .additional_system_headers = b.path("deps/luajit-include"),
    });
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

    // Windows-specific: ensure proper DLL export
    if (target.result.os.tag == .windows) {
        lib_root_module.export_symbol_names = &.{"luaopen_zbench"};
    }

    // Determine the output library name based on the operating system
    // Lua's package.cpath looks for .so on Unix-like systems and .dll on Windows
    const lib_name = if (target.result.os.tag == .windows) "zbench.dll" else "zbench.so";

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "zbench",
        .root_module = lib_root_module,
    });

    // Install with the correct extension for the target OS
    const install_lib = b.addInstallFileWithDir(
        lib.getEmittedBin(),
        .{ .custom = "lib" },
        lib_name,
    );
    b.getInstallStep().dependOn(&install_lib.step);

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/lua_zbench.zig"),
        .target = target,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "zbench", .module = zbench.module("zbench") },
        },
    });

    const mod_tests = b.addTest(.{
        .root_module = test_module,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
