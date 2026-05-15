-- lua-zbench: Fibonacci benchmark example
-- Compares recursive vs iterative Fibonacci implementations.
--
-- Usage:
--   luajit examples/fibonacci.lua
--   lua examples/fibonacci.lua

local bench = require("lua-zbench")

-- Recursive Fibonacci (naive, O(2^n))
local function fib_recursive(n)
    if n < 2 then return n end
    return fib_recursive(n - 1) + fib_recursive(n - 2)
end

-- Iterative Fibonacci (O(n))
local function fib_iterative(n)
    if n < 2 then return n end
    local a, b = 0, 1
    for _ = 2, n do
        a, b = b, a + b
    end
    return b
end

-- Memoized Fibonacci (O(n) with cache)
local fib_memo
fib_memo = function(n, cache)
    cache = cache or {}
    if cache[n] then return cache[n] end
    if n < 2 then return n end
    cache[n] = fib_memo(n - 1, cache) + fib_memo(n - 2, cache)
    return cache[n]
end

-- Tail-recursive Fibonacci (O(n))
local function fib_tail(n, a, b)
    a = a or 0
    b = b or 1
    if n == 0 then return a end
    return fib_tail(n - 1, b, a + b)
end

-- Verify all implementations produce the same results
local expected = {
    [0] = 0, [1] = 1, [2] = 1, [5] = 5, [10] = 55, [20] = 6765
}
for n, expected_val in pairs(expected) do
    assert(fib_recursive(n) == expected_val, "recursive mismatch at n=" .. n)
    assert(fib_iterative(n) == expected_val, "iterative mismatch at n=" .. n)
    assert(fib_memo(n) == expected_val, "memoized mismatch at n=" .. n)
    assert(fib_tail(n) == expected_val, "tail mismatch at n=" .. n)
end

print("All implementations verified. Starting benchmarks...\n")

-- Define benchmark suites
bench.describe("Fibonacci(20) - Small n", function()
    bench.it("recursive", function()
        local r = fib_recursive(20)
        -- Use the result to prevent optimization
        if r ~= 6765 then error("wrong result") end
    end, { time_budget_ms = 1000 })

    bench.it("iterative", function()
        local r = fib_iterative(20)
        if r ~= 6765 then error("wrong result") end
    end, { time_budget_ms = 500 })

    bench.it("memoized", function()
        local r = fib_memo(20)
        if r ~= 6765 then error("wrong result") end
    end, { time_budget_ms = 500 })

    bench.it("tail-recursive", function()
        local r = fib_tail(20)
        if r ~= 6765 then error("wrong result") end
    end, { time_budget_ms = 500 })
end)

bench.describe("Fibonacci(30) - Medium n", function()
    bench.it("recursive", function()
        local r = fib_recursive(30)
        if r ~= 832040 then error("wrong result") end
    end, { time_budget_ms = 2000 })

    bench.it("iterative", function()
        local r = fib_iterative(30)
        if r ~= 832040 then error("wrong result") end
    end, { time_budget_ms = 500 })

    bench.it("memoized", function()
        local r = fib_memo(30)
        if r ~= 832040 then error("wrong result") end
    end, { time_budget_ms = 500 })

    bench.it("tail-recursive", function()
        local r = fib_tail(30)
        if r ~= 832040 then error("wrong result") end
    end, { time_budget_ms = 500 })
end)

bench.describe("Fibonacci(10) - With Memory Tracking", function()
    bench.it("recursive (track mem)", function()
        local r = fib_recursive(10)
        if r ~= 55 then error("wrong result") end
    end, { time_budget_ms = 500, track_memory = true })

    bench.it("iterative (track mem)", function()
        local r = fib_iterative(10)
        if r ~= 55 then error("wrong result") end
    end, { time_budget_ms = 500, track_memory = true })
end)

-- Run all benchmarks and output results
local results = bench.run({ json = true, json_file = "fibonacci_results.json" })

-- Print summary comparison
print("\n--- Summary ---")
print("For Fibonacci(20), the iterative approach is typically")
print("10,000-100,000x faster than the naive recursive approach.")
print("Memoization and tail-recursion are also significantly faster.")
