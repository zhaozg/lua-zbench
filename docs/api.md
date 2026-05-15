# lua-zbench API Reference

**Version:** 0.1.0
**Module:** `lua-zbench` (Lua wrapper) / `zbench` (native Zig module)

## Table of Contents

1. [Getting Started](#getting-started)
2. [Declarative DSL](#declarative-dsl)
   - [`bench.describe(name, fn)`](#benchdescribename-fn)
   - [`bench.it(name, func, opts)`](#benchname-func-opts)
   - [`bench.run(opts)`](#benchrunopts)
3. [Low-Level API](#low-level-api)
   - [`bench.run_single(name, func, opts)`](#benchrun_singlename-func-opts)
   - [`bench.gettime()`](#benchgettime)
4. [Options Reference](#options-reference)
5. [Result Format](#result-format)
6. [JSON Output](#json-output)
7. [Examples](#examples)

---

## Getting Started

```lua
local bench = require("bench")

-- Simple one-shot benchmark
local result = bench.run_single("my_function", function()
    -- code to benchmark
end, { time_budget_ms = 500 })

print("Mean: " .. result.mean_ns .. " ns")
```

---

## Declarative DSL

The declarative DSL provides a `describe`/`it`/`run` pattern inspired by BDD-style testing frameworks.

### `bench.describe(name, fn)`

Define a benchmark suite. All `bench.it()` calls inside `fn` will be grouped under this suite.

**Parameters:**

| Name   | Type     | Description              |
|--------|----------|--------------------------|
| `name` | `string` | Suite name for display   |
| `fn`   | `function` | Function containing `bench.it()` calls |

**Example:**

```lua
bench.describe("String Operations", function()
    bench.it("concat", function()
        local s = ""
        for i = 1, 100 do s = s .. tostring(i) end
    end)
end)
```

### `bench.it(name, func, opts)`

Define a single benchmark case. Must be called inside a `bench.describe()` block.

**Parameters:**

| Name   | Type       | Description                              |
|--------|------------|------------------------------------------|
| `name` | `string`   | Benchmark name for display               |
| `func` | `function` | The function to benchmark                |
| `opts` | `table`    | (Optional) Configuration options (see [Options Reference](#options-reference)) |

**Example:**

```lua
bench.it("fast sort", function()
    local t = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3}
    table.sort(t)
end, { time_budget_ms = 200 })
```

### `bench.run(opts)`

Run all registered benchmarks and print a formatted results table.

**Parameters:**

| Name   | Type     | Description                              |
|--------|----------|------------------------------------------|
| `opts` | `table`  | (Optional) Run options (see below)       |

**Options:**

| Key          | Type      | Default        | Description                    |
|-------------|-----------|----------------|--------------------------------|
| `json`      | `boolean` | `false`        | Enable JSON output to file     |
| `json_file` | `string`  | `"results.json"` | JSON output file path        |

**Returns:** `table` - Array of suite results, each containing `suite` (name) and `results` (array of benchmark results).

**Example:**

```lua
local results = bench.run({ json = true, json_file = "my_results.json" })
```

---

## Low-Level API

### `bench.run_single(name, func, opts)`

Run a single benchmark directly without the DSL.

**Parameters:**

| Name   | Type       | Description                              |
|--------|------------|------------------------------------------|
| `name` | `string`   | Benchmark name                           |
| `func` | `function` | The function to benchmark                |
| `opts` | `table`    | (Optional) Configuration options         |

**Returns:** `table` - Benchmark result (see [Result Format](#result-format)).

**Example:**

```lua
local r = bench.run_single("compute", function()
    local sum = 0
    for i = 1, 1000 do sum = sum + i end
end, { time_budget_ms = 1000, track_memory = true })

print(string.format("Mean: %.2f ns, Allocations: %d", r.mean_ns, r.alloc_count))
```

### `bench.gettime()`

Get the current high-resolution time in seconds (nanosecond precision).

**Returns:** `number` - Current time in seconds as a floating-point number.

**Example:**

```lua
local start = bench.gettime()
-- ... do something ...
local elapsed = bench.gettime() - start
print(string.format("Elapsed: %.9f seconds", elapsed))
```

---

## Options Reference

Options can be passed as the third argument to `bench.run_single()` or `bench.it()`.

| Key               | Type      | Default | Description                                      |
|-------------------|-----------|---------|--------------------------------------------------|
| `time_budget_ms`  | `number`  | `1000`  | Time budget in milliseconds for the benchmark     |
| `max_iterations`  | `number`  | `10000` | Maximum number of iterations                      |
| `track_memory`    | `boolean` | `false` | Enable memory allocation tracking                 |
| `warmup_iter`     | `number`  | `1000`  | Number of warmup iterations (not yet implemented) |

**Example with all options:**

```lua
bench.it("my test", my_func, {
    time_budget_ms = 2000,    -- Run for up to 2 seconds
    max_iterations = 5000,    -- But no more than 5000 iterations
    track_memory = true,      -- Track memory allocations
})
```

---

## Result Format

Each benchmark result is a Lua table with the following fields:

| Field              | Type     | Description                              |
|--------------------|----------|------------------------------------------|
| `name`             | `string` | Benchmark name                           |
| `iterations`       | `number` | Number of iterations performed           |
| `mean_ns`          | `number` | Mean execution time in nanoseconds       |
| `stddev_ns`        | `number` | Standard deviation in nanoseconds        |
| `min_ns`           | `number` | Minimum execution time in nanoseconds    |
| `max_ns`           | `number` | Maximum execution time in nanoseconds    |
| `total_ns`         | `number` | Total execution time in nanoseconds      |
| `p75_ns`           | `number` | 75th percentile in nanoseconds           |
| `p99_ns`           | `number` | 99th percentile in nanoseconds           |
| `p99_9_ns`         | `number` | 99.9th percentile in nanoseconds         |
| `alloc_max_bytes`  | `number` | (Optional) Maximum allocation in bytes   |
| `alloc_mean_bytes` | `number` | (Optional) Mean allocation in bytes      |
| `alloc_count`      | `number` | (Optional) Number of allocations         |

---

## JSON Output

When `bench.run({ json = true })` is called, results are written to a JSON file.

**Example output (`results.json`):**

```json
{
  "benchmarks": [
    {
      "suite": "Fibonacci(20) - Small n",
      "results": [
        {
          "name": "recursive",
          "iterations": 100,
          "mean_ns": 1250000,
          "stddev_ns": 15000,
          "min_ns": 1230000,
          "max_ns": 1280000,
          "total_ns": 125000000,
          "p75_ns": 1260000,
          "p99_ns": 1280000,
          "p99_9_ns": 1280000
        }
      ]
    }
  ]
}
```

---

## Examples

### Basic Usage

```lua
local bench = require("zbench")

bench.describe("Table Operations", function()
    bench.it("table.insert", function()
        local t = {}
        for i = 1, 1000 do table.insert(t, i) end
    end)

    bench.it("t[i] = value", function()
        local t = {}
        for i = 1, 1000 do t[i] = i end
    end)
end)

bench.run({ json = true })
```

### Memory Tracking

```lua
local bench = require("bench")

bench.describe("String Building", function()
    bench.it("concatenation", function()
        local s = ""
        for i = 1, 1000 do s = s .. tostring(i) end
    end, { track_memory = true })

    bench.it("table.concat", function()
        local parts = {}
        for i = 1, 1000 do parts[i] = tostring(i) end
        local s = table.concat(parts)
    end, { track_memory = true })
end)

bench.run()
```

### Manual Timing

```lua
local bench = require("bench")

local start = bench.gettime()
-- Simulate work
for i = 1, 1000000 do end
local elapsed = bench.gettime() - start

print(string.format("Elapsed: %.6f seconds", elapsed))
```
