--[[
basic.lua - Basic usage example for lua-zbench
Phase 1: Load the module and get high-resolution timestamps
]]

-- Load the lua-zbench shared library
local zbench = require("zbench")

-- Get a high-resolution timestamp
local t1 = zbench.gettime()
print(string.format("Timestamp 1: %.9f seconds", t1))

-- Do some work
local sum = 0
for i = 1, 1000000 do
    sum = sum + i
end

local t2 = zbench.gettime()
print(string.format("Timestamp 2: %.9f seconds", t2))
print(string.format("Elapsed: %.9f seconds (%.3f ns)", t2 - t1, (t2 - t1) * 1e9))
print(string.format("Sum: %d", sum))

-- Verify timing precision
print("\n--- Timing Precision Verification ---")
local iterations = 1000000
local start = zbench.gettime()
local dummy = 0
for i = 1, iterations do
    dummy = dummy + 1
end
local finish = zbench.gettime()
local elapsed = finish - start
local per_iter_ns = (elapsed / iterations) * 1e9
print(string.format("Loop %d iterations:", iterations))
print(string.format("  Total: %.6f seconds", elapsed))
print(string.format("  Per iteration: %.3f ns", per_iter_ns))
print(string.format("  Dummy: %d", dummy))

-- Phase 2: Use the benchmark runner
print("\n--- Benchmark Runner ---")

-- Benchmark a simple computation
local result = zbench.run("sum_100", function()
    local s = 0
    for i = 1, 100 do s = s + i end
end, {time_budget_ms=500, max_iterations=100})

print(string.format("Benchmark: %s", result.name))
print(string.format("  Iterations: %d", result.iterations))
print(string.format("  Mean: %.2f ns", result.mean_ns))
print(string.format("  Min: %.0f ns", result.min_ns))
print(string.format("  Max: %.0f ns", result.max_ns))
print(string.format("  StdDev: %.2f ns", result.stddev_ns))
print(string.format("  p75: %.0f ns", result.p75_ns))
print(string.format("  p99: %.0f ns", result.p99_ns))
print(string.format("  p99.9: %.0f ns", result.p99_9_ns))
print(string.format("  Total: %.2f ns", result.total_ns))
