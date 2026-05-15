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
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const timestamp_ns = std.Io.Timestamp.now(io, .awake).nanoseconds;
    const seconds = @as(f64, @floatFromInt(timestamp_ns)) / 1_000_000_000.0;
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

    // Run the benchmark
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const file = std.Io.File.stdout();

    bench.run(io, file) catch {
        bench_lua = null;
        bench_ref = 0;
        lua.unref(zlua.registry_index, func_ref);
        _ = lua.pushString("benchmark failed");
        return 0;
    };

    bench_lua = null;
    bench_ref = 0;
    lua.unref(zlua.registry_index, func_ref);

    // Return a results table
    lua.newTable();

    _ = lua.pushString("name");
    _ = lua.pushString(name);
    lua.setTable(-3);

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

fn registerModule(lua: *Lua) void {
    lua.newTable();

    _ = lua.pushString("gettime");
    lua.pushFunction(zlua.wrap(luaHighResTime));
    lua.setTable(-3);

    _ = lua.pushString("run");
    lua.pushFunction(zlua.wrap(luaBenchRun));
    lua.setTable(-3);

    lua.setGlobal("lua_zbench");
}

pub export fn luaopen_lua_zbench(state: ?*zlua.LuaState) callconv(.c) c_int {
    const lua = @as(*Lua, @ptrCast(state));
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
        .time_budget_ns = 50_000_000,
        .max_iterations = 1000,
    });

    try bench.add("test_empty", struct {
        fn run(_: std.mem.Allocator) void {
            std.mem.doNotOptimizeAway(@as(u64, 0));
        }
    }.run, .{});

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const file = std.Io.File.stdout();
    try bench.run(io, file);
}

test "benchmark with simple computation" {
    const allocator = std.testing.allocator;

    var bench = zbench.Benchmark.init(allocator, .{
        .time_budget_ns = 100_000_000,
        .max_iterations = 100,
    });

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
    const file = std.Io.File.stdout();
    try bench.run(io, file);
}
