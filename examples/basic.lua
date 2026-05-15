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
