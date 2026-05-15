-- lua-zbench: Lua microbenchmarking framework
-- Based on Zig + zBench + ziglua
--
-- This rockspec defines the package for LuaRocks installation.
-- The shared library (zbench.so/.dylib/.dll) is built from Zig source
-- and bundled with the Lua wrapper module.

package = "lua-zbench"
version = "0.1.0-1"

source = {
    url = "https://github.com/yourusername/lua-zbench/archive/v0.1.0.tar.gz",
    dir = "lua-zbench-0.1.0",
}

description = {
    summary = "Professional microbenchmarking framework for Lua",
    detailed = [[
        lua-zbench is a professional, cross-platform, zero-overhead Lua
        microbenchmarking framework. Built on Zig + zBench + ziglua,
        it provides precise performance measurement for any Lua function
        (C extensions or pure Lua), with statistical reports including
        percentiles and memory allocation tracking.

        Features:
        - High-precision measurement with nanosecond accuracy
        - Adaptive batching and warmup phases
        - Full statistics: mean, stddev, min/max, percentiles (p75/p99/p99.9)
        - Memory allocation tracking
        - Declarative DSL (describe/it/run)
        - JSON output for CI integration
        - Baseline noise calibration
        - Cross-platform (Linux/macOS/Windows)
    ]],
    homepage = "https://github.com/yourusername/lua-zbench",
    license = "MIT",
    maintainer = "Your Name <your.email@example.com>",
    labels = {"benchmark", "performance", "profiling", "testing"},
}

dependencies = {
    "lua >= 5.1, < 5.5",
}

build = {
    type = "builtin",
    modules = {
        ["lua-zbench"] = "src/lua-zbench.lua",
    },
    copy_directories = {
        "docs",
        "examples",
        "bench",
    },
    platforms = {
        -- Linux
        unix = {
            build = {
                type = "command",
                command = "zig build -Doptimize=ReleaseFast",
                build_variables = {
                    ZIG = "zig",
                },
            },
            install = {
                -- Install the shared library to lib directory
                ["zbench.so"] = "zig-out/lib/zbench.so",
            },
        },
        -- macOS
        macosx = {
            build = {
                type = "command",
                command = "zig build -Doptimize=ReleaseFast",
                build_variables = {
                    ZIG = "zig",
                },
            },
            install = {
                -- Install the shared library (both .dylib and .so for compatibility)
                ["zbench.so"] = "zig-out/lib/zbench.so",
                ["zbench.dylib"] = "zig-out/lib/libzbench.dylib",
            },
        },
        -- Windows
        windows = {
            build = {
                type = "command",
                command = "zig build -Doptimize=ReleaseFast",
                build_variables = {
                    ZIG = "zig",
                },
            },
            install = {
                ["zbench.dll"] = "zig-out/lib/zbench.dll",
            },
        },
    },
}
