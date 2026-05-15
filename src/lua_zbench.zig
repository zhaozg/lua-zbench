//! lua-zbench - Lua microbenchmarking framework
//! Core module that bridges Zig, zBench, and Lua via zlua.
//!
//! Phase 1: Basic binding and timing verification.
//! Provides `lua_high_res_time` function that returns high-resolution
//! timestamps as Lua numbers (seconds as f64).

const std = @import("std");
const zlua = @import("zlua");
const zbench = @import("zbench");

const Lua = zlua.Lua;

/// High-resolution time function for Lua.
/// Returns the current time in seconds as a f64 (nanosecond precision).
/// Usage in Lua:
///   local time = lua_zbench.gettime()
fn luaHighResTime(lua: *Lua) callconv(.c) c_int {
    // Use POSIX clock_gettime for reliable high-resolution timing
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.REALTIME, &ts);
    const seconds = @as(f64, @floatFromInt(ts.sec)) +
        @as(f64, @floatFromInt(ts.nsec)) / 1_000_000_000.0;
    lua.pushNumber(seconds);
    return 1;
}

// Thread-local storage for passing context to benchmark functions
threadlocal var bench_lua: ?*Lua = null;
threadlocal var bench_ref: c_int = 0;

fn benchFuncWrapper(_: std.mem.Allocator) void {
    if (bench_lua) |lua| {
        _ = callLuaFunc(lua, bench_ref);
    }
}

/// Run a benchmark from Lua.
/// Usage in Lua:
///   local results = lua_zbench.run(name, func, opts)
/// Returns a table with: name, iterations, mean_ns, min_ns, max_ns,
///   stddev_ns, p75_ns, p99_ns, p99_9_ns, total_ns
fn luaBenchRun(lua: *Lua) callconv(.c) c_int {
    const name = lua.checkString(1);
    if (!lua.isFunction(2)) {
        _ = lua.pushString("argument #2 must be a function");
        return 0;
    }

    var config = zbench.Config{};
    if (lua.getTop() >= 3 and lua.isTable(3)) {
        _ = lua.getField(3, "time_budget_ms");
        if (!lua.isNil(-1)) {
            config.time_budget_ns = @intFromFloat((lua.toNumber(-1) catch 0.0) * 1_000_000.0);
        }
        lua.pop(1);

        _ = lua.getField(3, "max_iterations");
        if (!lua.isNil(-1)) {
            config.max_iterations = @intFromFloat(lua.toNumber(-1) catch 0.0);
        }
        lua.pop(1);

        _ = lua.getField(3, "track_memory");
        if (!lua.isNil(-1)) {
            config.track_allocations = lua.toBoolean(-1);
        }
        lua.pop(1);
    }

    // Push the function and get a reference to it
    lua.pushValue(2);
    const func_ref = lua.ref(zlua.registry_index);

    const allocator = std.heap.page_allocator;

    // Adaptive batch size optimization:
    // First, do a quick probe run to estimate the function's execution time.
    // If single call takes > 10µs, reduce max_iterations to avoid over-batching.
    {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const probe_start = std.Io.Timestamp.now(io, .awake).nanoseconds;
        bench_lua = lua;
        bench_ref = func_ref;
        benchFuncWrapper(allocator);
        const probe_elapsed = std.Io.Timestamp.now(io, .awake).nanoseconds - probe_start;
        bench_lua = null;
        bench_ref = 0;

        // If probe shows > 10µs per call, reduce iterations to avoid over-batching
        if (probe_elapsed > 10_000) {
            // For slow functions, we don't need many iterations
            if (config.max_iterations > 100) {
                config.max_iterations = 100;
            }
        }
    }

    // Create a benchmark and add the Lua function as a benchmark
    var bench = zbench.Benchmark.init(allocator, config);

    // Set thread-local context before adding benchmark
    bench_lua = lua;
    bench_ref = func_ref;

    bench.add(name, benchFuncWrapper, .{}) catch {
        bench_lua = null;
        bench_ref = 0;
        lua.unref(zlua.registry_index, func_ref);
        _ = lua.pushString("failed to add benchmark");
        return 0;
    };

    // Run the benchmark using iterator API to avoid stdout output
    // and collect results programmatically
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    var iter = bench.iterator() catch {
        bench_lua = null;
        bench_ref = 0;
        lua.unref(zlua.registry_index, func_ref);
        bench.deinit();
        _ = lua.pushString("failed to create iterator");
        return 0;
    };

    var result: ?zbench.Result = null;
    while (iter.next(io) catch {
        bench_lua = null;
        bench_ref = 0;
        lua.unref(zlua.registry_index, func_ref);
        bench.deinit();
        _ = lua.pushString("benchmark iteration failed");
        return 0;
    }) |step| {
        switch (step) {
            .progress => {},
            .result => |r| {
                result = r;
            },
        }
    }

    bench_lua = null;
    bench_ref = 0;
    lua.unref(zlua.registry_index, func_ref);

    const bench_result = result orelse {
        bench.deinit();
        _ = lua.pushString("no benchmark result");
        return 0;
    };

    // Calculate statistics from the readings
    const timings_ns = bench_result.readings.timings_ns;
    const stats = zbench.statistics.Statistics(u64).init(timings_ns) catch {
        bench_result.deinit();
        bench.deinit();
        _ = lua.pushString("failed to compute statistics");
        return 0;
    };

    // Build results table for Lua
    lua.newTable();

    // name
    _ = lua.pushString("name");
    _ = lua.pushString(bench_result.name);
    lua.setTable(-3);

    // iterations
    _ = lua.pushString("iterations");
    lua.pushNumber(@as(f64, @floatFromInt(bench_result.readings.iterations)));
    lua.setTable(-3);

    // total_ns
    _ = lua.pushString("total_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.total)));
    lua.setTable(-3);

    // mean_ns
    _ = lua.pushString("mean_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.mean)));
    lua.setTable(-3);

    // stddev_ns
    _ = lua.pushString("stddev_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.stddev)));
    lua.setTable(-3);

    // min_ns
    _ = lua.pushString("min_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.min)));
    lua.setTable(-3);

    // max_ns
    _ = lua.pushString("max_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.max)));
    lua.setTable(-3);

    // p75_ns
    _ = lua.pushString("p75_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.percentiles.p75)));
    lua.setTable(-3);

    // p99_ns
    _ = lua.pushString("p99_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.percentiles.p99)));
    lua.setTable(-3);

    // p99_9_ns (zBench provides p995, we use it as p99.9 approximation)
    _ = lua.pushString("p99_9_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.percentiles.p995)));
    lua.setTable(-3);

    // Memory tracking results (if enabled)
    if (bench_result.readings.allocations) |allocs| {
        const mem_stats = zbench.statistics.Statistics(usize).init(allocs.maxes) catch {
            bench_result.deinit();
            bench.deinit();
            _ = lua.pushString("failed to compute memory statistics");
            return 0;
        };

        _ = lua.pushString("alloc_max_bytes");
        lua.pushNumber(@as(f64, @floatFromInt(mem_stats.max)));
        lua.setTable(-3);

        _ = lua.pushString("alloc_mean_bytes");
        lua.pushNumber(@as(f64, @floatFromInt(mem_stats.mean)));
        lua.setTable(-3);

        _ = lua.pushString("alloc_count");
        lua.pushNumber(@as(f64, @floatFromInt(allocs.counts[0])));
        lua.setTable(-3);
    }

    bench_result.deinit();
    bench.deinit();

    return 1;
}

fn callLuaFunc(lua: *Lua, func_ref: c_int) c_int {
    // Use rawgeti via the C API directly
    const c_api = @as(*zlua.LuaState, @ptrCast(lua));
    _ = zlua.c.lua_rawgeti(c_api, zlua.registry_index, func_ref);
    lua.protectedCall(.{ .args = 0, .results = 0 }) catch {
        return -1;
    };
    return 0;
}

/// Run an empty baseline benchmark to measure measurement overhead.
/// Returns the same result format as luaBenchRun, representing the noise floor.
/// Usage in Lua:
///   local noise = lua_zbench.baseline(opts)
fn luaBaseline(lua: *Lua) callconv(.c) c_int {
    var config = zbench.Config{};
    if (lua.getTop() >= 1 and lua.isTable(1)) {
        _ = lua.getField(1, "time_budget_ms");
        if (!lua.isNil(-1)) {
            config.time_budget_ns = @intFromFloat((lua.toNumber(-1) catch 0.0) * 1_000_000.0);
        }
        lua.pop(1);

        _ = lua.getField(1, "max_iterations");
        if (!lua.isNil(-1)) {
            config.max_iterations = @intFromFloat(lua.toNumber(-1) catch 0.0);
        }
        lua.pop(1);
    }

    const allocator = std.heap.page_allocator;
    var bench = zbench.Benchmark.init(allocator, config);

    bench.add("__baseline__", struct {
        fn run(_: std.mem.Allocator) void {
            std.mem.doNotOptimizeAway(@as(u64, 0));
        }
    }.run, .{}) catch {
        _ = lua.pushString("failed to add baseline benchmark");
        return 0;
    };

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    var iter = bench.iterator() catch {
        bench.deinit();
        _ = lua.pushString("failed to create iterator");
        return 0;
    };

    var result: ?zbench.Result = null;
    while (iter.next(io) catch {
        bench.deinit();
        _ = lua.pushString("baseline iteration failed");
        return 0;
    }) |step| {
        switch (step) {
            .progress => {},
            .result => |r| {
                result = r;
            },
        }
    }

    const bench_result = result orelse {
        bench.deinit();
        _ = lua.pushString("no baseline result");
        return 0;
    };

    const timings_ns = bench_result.readings.timings_ns;
    const stats = zbench.statistics.Statistics(u64).init(timings_ns) catch {
        bench_result.deinit();
        bench.deinit();
        _ = lua.pushString("failed to compute baseline statistics");
        return 0;
    };

    lua.newTable();

    _ = lua.pushString("name");
    _ = lua.pushString("__baseline__");
    lua.setTable(-3);

    _ = lua.pushString("iterations");
    lua.pushNumber(@as(f64, @floatFromInt(bench_result.readings.iterations)));
    lua.setTable(-3);

    _ = lua.pushString("mean_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.mean)));
    lua.setTable(-3);

    _ = lua.pushString("stddev_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.stddev)));
    lua.setTable(-3);

    _ = lua.pushString("min_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.min)));
    lua.setTable(-3);

    _ = lua.pushString("max_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.max)));
    lua.setTable(-3);

    _ = lua.pushString("total_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.total)));
    lua.setTable(-3);

    _ = lua.pushString("p75_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.percentiles.p75)));
    lua.setTable(-3);

    _ = lua.pushString("p99_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.percentiles.p99)));
    lua.setTable(-3);

    _ = lua.pushString("p99_9_ns");
    lua.pushNumber(@as(f64, @floatFromInt(stats.percentiles.p995)));
    lua.setTable(-3);

    bench_result.deinit();
    bench.deinit();

    return 1;
}

fn registerModule(lua: *Lua) void {
    lua.newTable();

    _ = lua.pushString("gettime");
    lua.pushFunction(zlua.wrap(luaHighResTime));
    lua.setTable(-3);

    _ = lua.pushString("run");
    lua.pushFunction(zlua.wrap(luaBenchRun));
    lua.setTable(-3);

    _ = lua.pushString("baseline");
    lua.pushFunction(zlua.wrap(luaBaseline));
    lua.setTable(-3);
}

/// Lua entry point: called by `require("zbench")`.
/// Uses `callconv(.c)` for C ABI compatibility.
/// On Windows, Zig's `export` keyword automatically handles
/// `__declspec(dllexport)` for DLL symbol visibility.
pub export fn luaopen_zbench(state: ?*zlua.LuaState) callconv(.c) c_int {
    const lua = @as(*Lua, @ptrCast(state.?));
    registerModule(lua);
    return 1;
}

// ============================================================
// Tests
// ============================================================

test "high_res_time returns valid timestamp" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const t1 = std.Io.Timestamp.now(io, .awake).nanoseconds;
    const seconds1 = @as(f64, @floatFromInt(t1)) / 1_000_000_000.0;

    var i: u64 = 0;
    while (i < 100_000) : (i += 1) {
        std.mem.doNotOptimizeAway(i);
    }

    const t2 = std.Io.Timestamp.now(io, .awake).nanoseconds;
    const seconds2 = @as(f64, @floatFromInt(t2)) / 1_000_000_000.0;

    try std.testing.expect(seconds2 > seconds1);
    try std.testing.expect(seconds2 - seconds1 < 1.0);
}

test "benchmark empty function" {
    const allocator = std.testing.allocator;

    var bench = zbench.Benchmark.init(allocator, .{
        .time_budget_ns = 10_000_000,
        .max_iterations = 10,
    });
    defer bench.deinit();

    try bench.add("test_empty", struct {
        fn run(_: std.mem.Allocator) void {
            std.mem.doNotOptimizeAway(@as(u64, 0));
        }
    }.run, .{});

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    // Use iterator API to avoid outputting benchmark table to stdout
    // (stdout is used by test runner protocol in --listen mode)
    var iter = try bench.iterator();
    var result_count: usize = 0;
    while (try iter.next(io)) |step| {
        switch (step) {
            .progress => {},
            .result => |r| {
                result_count += 1;
                try std.testing.expectEqualStrings("test_empty", r.name);
                r.deinit();
            },
        }
    }
    try std.testing.expectEqual(@as(usize, 1), result_count);
}

test "benchmark with simple computation" {
    const allocator = std.testing.allocator;

    var bench = zbench.Benchmark.init(allocator, .{
        .time_budget_ns = 10_000_000,
        .max_iterations = 10,
    });
    defer bench.deinit();

    try bench.add("test_compute", struct {
        fn run(_: std.mem.Allocator) void {
            var sum: u64 = 0;
            for (0..100) |i| {
                sum += i * i;
            }
            std.mem.doNotOptimizeAway(sum);
        }
    }.run, .{});

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    // Use iterator API to avoid outputting benchmark table to stdout
    var iter = try bench.iterator();
    var result_count: usize = 0;
    while (try iter.next(io)) |step| {
        switch (step) {
            .progress => {},
            .result => |r| {
                result_count += 1;
                try std.testing.expectEqualStrings("test_compute", r.name);
                r.deinit();
            },
        }
    }
    try std.testing.expectEqual(@as(usize, 1), result_count);
}
