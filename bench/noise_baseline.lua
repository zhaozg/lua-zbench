-- noise_baseline.lua - Measurement noise baseline example
-- This script demonstrates how to measure the noise floor of the benchmarking
-- framework and use it to interpret benchmark results.
--
-- Usage:
--   luajit bench/noise_baseline.lua
--   lua bench/noise_baseline.lua

local bench = require("bench")

print("")
print("=== Measurement Noise Baseline ===")
print("This script measures the noise floor of the benchmarking framework.")
print("The baseline represents the minimum measurable overhead.")
print("")

-- Measure baseline (noise floor)
local baseline = bench.baseline({ time_budget_ms = 500 })

print("Baseline (empty function) statistics:")
print(string.format("  Mean:   %.2f ns", baseline.mean_ns))
print(string.format("  StdDev: %.2f ns", baseline.stddev_ns))
print(string.format("  Min:    %.0f ns", baseline.min_ns))
print(string.format("  Max:    %.0f ns", baseline.max_ns))
print(string.format("  p75:    %.0f ns", baseline.p75_ns))
print(string.format("  p99:    %.0f ns", baseline.p99_ns))
print(string.format("  p99.9:  %.0f ns", baseline.p99_9_ns))
print("")

-- Coefficient of Variation (CV) for baseline
local cv = (baseline.stddev_ns / baseline.mean_ns) * 100
print(string.format("Baseline CV: %.2f%%", cv))
if cv <= 10 then
    print("  ✓ CV ≤ 10%: Baseline is stable.")
else
    print("  ⚠ CV > 10%: Baseline has high variance. Consider system load.")
end
print("")

-- Now run some benchmarks and compare with baseline
print("=== Benchmarks with Baseline Comparison ===")

bench.describe("Micro-benchmarks (comparing with noise floor)", function()
    -- Very fast: empty loop (should be close to baseline)
    bench.it("empty loop (10 iters)", function()
        for i = 1, 10 do
            local x = i * i
            if x < 0 then error("unreachable") end
        end
    end, { time_budget_ms = 500 })

    -- Fast: simple arithmetic
    bench.it("simple add (100 iters)", function()
        local s = 0
        for i = 1, 100 do
            s = s + i
        end
        if s ~= 5050 then error("wrong result") end
    end, { time_budget_ms = 500 })

    -- Medium: table operations
    bench.it("table insert (100 iters)", function()
        local t = {}
        for i = 1, 100 do
            t[#t + 1] = i
        end
        if #t ~= 100 then error("wrong size") end
    end, { time_budget_ms = 500 })

    -- Slower: string concatenation
    bench.it("string concat (100 iters)", function()
        local s = ""
        for i = 1, 100 do
            s = s .. tostring(i)
        end
    end, { time_budget_ms = 500 })
end)

local results = bench.run({
    baseline = true,
    json = true,
    json_file = "noise_baseline_results.json"
})

-- Print analysis
print("=== Analysis ===")
print("")
print("If a benchmark's mean is close to the baseline mean,")
print("the measurement is dominated by noise. Consider:")
print("  1. Increasing the workload per iteration")
print("  2. Using batch processing (loop N times in the benchmark)")
print("  3. Using a larger time budget")
print("")
print("Rule of thumb:")
print("  - Mean > 10x baseline:  Reliable measurement")
print("  - Mean 3-10x baseline:  Somewhat reliable, check CV")
print("  - Mean < 3x baseline:   Unreliable, increase workload")
print("")

-- Calculate signal-to-noise ratio for each benchmark
if results and #results > 0 then
    for _, suite in ipairs(results) do
        for _, r in ipairs(suite.results) do
            if r.mean_ns then
                local snr = r.mean_ns / baseline.mean_ns
                local status
                if snr > 10 then
                    status = "✓ Reliable"
                elseif snr > 3 then
                    status = "~ Somewhat reliable"
                else
                    status = "✗ Unreliable (too close to noise)"
                end
                print(string.format("  %s: SNR=%.1fx (%s)", r.name, snr, status))
            end
        end
    end
end
print("")
