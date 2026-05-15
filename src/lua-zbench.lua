-- lua-zbench: Lua microbenchmarking framework
-- Pure Lua wrapper providing a declarative DSL on top of the Zig shared library.
--
-- Usage:
--   local bench = require("lua-zbench")
--   bench.describe("My Benchmark Suite", function()
--       bench.it("fast function", function()
--           -- code to benchmark
--       end, { time_budget_ms = 500 })
--   end)
--   bench.run()
--
-- Or use the low-level API directly:
--   local results = bench.run_single("name", func, opts)

local M = {}

-- Internal state for the declarative DSL
local suites = {}       -- list of { name, benchmarks: { name, func, opts }[] }
local current_suite = nil

-- ANSI color codes for terminal output
local COLORS = {
    reset     = "\27[0m",
    bold      = "\27[1m",
    red       = "\27[31m",
    green     = "\27[32m",
    yellow    = "\27[33m",
    blue      = "\27[34m",
    magenta   = "\27[35m",
    cyan      = "\27[36m",
    white     = "\27[37m",
    gray      = "\27[90m",
}

local function has_color()
    -- Check if stdout is a terminal
    if type(io.stdout) == "userdata" and io.stdout.setvbuf then
        local ok, err = pcall(io.stdout.isatty, io.stdout)
        if ok then return err end
    end
    -- Fallback: check common environment variables
    local term = os.getenv("TERM")
    if term then
        return term ~= "dumb" and term ~= ""
    end
    return false
end

local use_color = has_color()

local function color(text, c)
    if use_color then
        return COLORS[c] .. text .. COLORS.reset
    end
    return text
end

local function bold(text)
    if use_color then
        return COLORS.bold .. text .. COLORS.reset
    end
    return text
end

-- Format nanoseconds into a human-readable string
local function format_duration(ns)
    if ns < 1000 then
        return string.format("%.2f ns", ns)
    elseif ns < 1000000 then
        return string.format("%.3f µs", ns / 1000)
    elseif ns < 1000000000 then
        return string.format("%.3f ms", ns / 1000000)
    else
        return string.format("%.3f s", ns / 1000000000)
    end
end

-- Format bytes into a human-readable string
local function format_bytes(bytes)
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.2f KiB", bytes / 1024)
    else
        return string.format("%.2f MiB", bytes / (1024 * 1024))
    end
end

-- Try to load the native zbench module
local ok, native = pcall(function()
    return require("zbench")
end)

if not ok then
    error("Failed to load native zbench module: " .. tostring(native) .. "\n" ..
          "Make sure libzbench is installed and accessible via package.cpath.")
end

-- Low-level API: run a single benchmark
-- Returns a table with: name, iterations, mean_ns, min_ns, max_ns, stddev_ns,
--                       p75_ns, p99_ns, p99_9_ns, total_ns
--                       (and optionally alloc_max_bytes, alloc_mean_bytes, alloc_count)
function M.run_single(name, func, opts)
    opts = opts or {}
    return native.run(name, func, opts)
end

-- High-resolution time function
function M.gettime()
    return native.gettime()
end

-- Declarative DSL: describe a benchmark suite
function M.describe(name, fn)
    current_suite = {
        name = name,
        benchmarks = {},
    }
    table.insert(suites, current_suite)
    fn()
    current_suite = nil
end

-- Declarative DSL: define a benchmark case
function M.it(name, func, opts)
    if not current_suite then
        error("bench.it() must be called inside a bench.describe() block")
    end
    table.insert(current_suite.benchmarks, {
        name = name,
        func = func,
        opts = opts or {},
    })
end

-- Run all registered benchmarks and print results
function M.run(opts)
    opts = opts or {}
    local json_output = opts.json or false
    local json_filename = opts.json_file or "results.json"
    local results = {}

    -- Print header
    local total_benchmarks = 0
    for _, suite in ipairs(suites) do
        total_benchmarks = total_benchmarks + #suite.benchmarks
    end

    if total_benchmarks == 0 then
        print(color("No benchmarks defined. Use bench.describe() and bench.it() to define them.", "yellow"))
        return {}
    end

    print("")
    print(bold(color("lua-zbench - Microbenchmark Results", "cyan")))
    print(color(string.rep("─", 80), "gray"))
    print("")

    for _, suite in ipairs(suites) do
        print(bold(color("Suite: " .. suite.name, "magenta")))
        print("")

        local suite_results = {}

        for _, b in ipairs(suite.benchmarks) do
            -- Run the benchmark
            local ok, result = pcall(M.run_single, b.name, b.func, b.opts)
            if not ok then
                print(color("  ✗ " .. b.name .. ": " .. tostring(result), "red"))
                table.insert(suite_results, { name = b.name, error = tostring(result) })
            else
                table.insert(suite_results, result)
                print(color("  ✓ " .. b.name, "green"))
                print(string.format("      Iterations: %s", color(tostring(result.iterations), "cyan")))
                print(string.format("      Mean:       %s", color(format_duration(result.mean_ns), "yellow")))
                print(string.format("      StdDev:     %s", color(format_duration(result.stddev_ns), "gray")))
                print(string.format("      Min:        %s", color(format_duration(result.min_ns), "green")))
                print(string.format("      Max:        %s", color(format_duration(result.max_ns), "red")))
                print(string.format("      p75:        %s", color(format_duration(result.p75_ns), "cyan")))
                print(string.format("      p99:        %s", color(format_duration(result.p99_ns), "cyan")))
                print(string.format("      p99.9:      %s", color(format_duration(result.p99_9_ns), "cyan")))

                if result.alloc_max_bytes then
                    print(string.format("      Alloc max:  %s", color(format_bytes(result.alloc_max_bytes), "blue")))
                    print(string.format("      Alloc mean: %s", color(format_bytes(result.alloc_mean_bytes), "blue")))
                    print(string.format("      Alloc cnt:  %s", color(tostring(result.alloc_count), "blue")))
                end
                print("")
            end
        end

        table.insert(results, {
            suite = suite.name,
            results = suite_results,
        })
    end

    print(color(string.rep("─", 80), "gray"))
    print(string.format("Total: %d benchmark(s) in %d suite(s)", total_benchmarks, #suites))
    print("")

    -- JSON output
    if json_output then
        local json = M.to_json(results)
        local file, err = io.open(json_filename, "w")
        if file then
            file:write(json)
            file:close()
            print(color("Results written to " .. json_filename, "green"))
        else
            print(color("Failed to write " .. json_filename .. ": " .. tostring(err), "red"))
        end
    end

    return results
end

-- Simple JSON encoder for strings
local function json_encode(s)
    if type(s) == "string" then
        -- Escape special characters
        s = string.gsub(s, '\\', '\\\\')
        s = string.gsub(s, '"', '\\"')
        s = string.gsub(s, '\n', '\\n')
        s = string.gsub(s, '\r', '\\r')
        s = string.gsub(s, '\t', '\\t')
        return '"' .. s .. '"'
    end
    return tostring(s)
end

-- Convert results to JSON string
function M.to_json(results)
    local parts = {}
    table.insert(parts, '{\n  "benchmarks": [\n')

    for i, suite in ipairs(results) do
        table.insert(parts, '    {\n')
        table.insert(parts, '      "suite": ' .. json_encode(suite.suite) .. ',\n')
        table.insert(parts, '      "results": [\n')

        for j, r in ipairs(suite.results) do
            if r.error then
                table.insert(parts, '        {\n')
                table.insert(parts, '          "name": ' .. json_encode(r.name) .. ',\n')
                table.insert(parts, '          "error": ' .. json_encode(r.error) .. '\n')
                table.insert(parts, '        }')
            else
                table.insert(parts, '        {\n')
                table.insert(parts, '          "name": ' .. json_encode(r.name) .. ',\n')
                table.insert(parts, '          "iterations": ' .. r.iterations .. ',\n')
                table.insert(parts, '          "mean_ns": ' .. r.mean_ns .. ',\n')
                table.insert(parts, '          "stddev_ns": ' .. r.stddev_ns .. ',\n')
                table.insert(parts, '          "min_ns": ' .. r.min_ns .. ',\n')
                table.insert(parts, '          "max_ns": ' .. r.max_ns .. ',\n')
                table.insert(parts, '          "total_ns": ' .. r.total_ns .. ',\n')
                table.insert(parts, '          "p75_ns": ' .. r.p75_ns .. ',\n')
                table.insert(parts, '          "p99_ns": ' .. r.p99_ns .. ',\n')
                table.insert(parts, '          "p99_9_ns": ' .. r.p99_9_ns)

                if r.alloc_max_bytes then
                    table.insert(parts, ',\n')
                    table.insert(parts, '          "alloc_max_bytes": ' .. r.alloc_max_bytes .. ',\n')
                    table.insert(parts, '          "alloc_mean_bytes": ' .. r.alloc_mean_bytes .. ',\n')
                    table.insert(parts, '          "alloc_count": ' .. r.alloc_count)
                end

                table.insert(parts, '\n        }')
            end

            if j < #suite.results then
                table.insert(parts, ',')
            end
            table.insert(parts, '\n')
        end

        table.insert(parts, '      ]\n')
        table.insert(parts, '    }')

        if i < #results then
            table.insert(parts, ',')
        end
        table.insert(parts, '\n')
    end

    table.insert(parts, '  ]\n')
    table.insert(parts, '}\n')

    return table.concat(parts)
end

-- Simple JSON encoder for strings
local function json_encode(s)
    if type(s) == "string" then
        -- Escape special characters
        s = string.gsub(s, '\\', '\\\\')
        s = string.gsub(s, '"', '\\"')
        s = string.gsub(s, '\n', '\\n')
        s = string.gsub(s, '\r', '\\r')
        s = string.gsub(s, '\t', '\\t')
        return '"' .. s .. '"'
    end
    return tostring(s)
end

-- Reset all registered suites (useful for re-running)
function M.reset()
    suites = {}
    current_suite = nil
end

-- Return the native module for advanced usage
function M.native()
    return native
end

return M
