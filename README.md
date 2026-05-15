# lua-zbench

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Zig](https://img.shields.io/badge/Zig-0.16.x-orange)](https://ziglang.org/)
[![LuaJIT](https://img.shields.io/badge/LuaJIT-2.1-blue)](https://luajit.org/)

**lua-zbench** 是一个专业、跨平台、零额外开销的 Lua 微基准测试框架。基于 Zig + zBench + ziglua，为任意 Lua 函数（C 扩展或纯 Lua）提供精准的性能测量，输出包含百分位数、内存分配等维度的统计报告。

## 特性

- 🎯 **高精度测量** — 基于 zBench 引擎，支持自适应批处理、预热阶段，测量精度达纳秒级
- 📊 **完整统计** — 均值、标准差、最小值/最大值、百分位数（p75/p99/p99.9）
- 🧠 **内存追踪** — 捕获被测函数的内存分配次数与字节数
- 🎨 **声明式 DSL** — `describe`/`it`/`run` 模式，灵感来自 BDD 测试框架
- 📝 **JSON 输出** — 结果可导出为 JSON 文件，便于 CI 集成和数据分析
- 🔇 **基线校准** — 自动测量空函数噪音，帮助评估测量精度
- 🌐 **跨平台** — 支持 Linux (x86_64/aarch64)、macOS (x86_64/aarch64)、Windows (x86_64)
- ⚡ **高性能** — 基于 Zig 实现，FFI 调用开销极小

## 安装

### 前置要求

- [Zig](https://ziglang.org/download/) 0.16.x
- [LuaJIT](https://luajit.org/) 2.1（或兼容的 Lua 5.1 实现）
- [LuaRocks](https://luarocks.org/)（可选，用于包管理）

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/yourusername/lua-zbench.git
cd lua-zbench

# 构建共享库
zig build -Doptimize=ReleaseFast

# 安装到 Lua 路径
# 将 zig-out/lib/zbench.so 复制到 Lua 的 cpath 目录
cp zig-out/lib/zbench.so /usr/local/lib/lua/5.1/
# 或将 src/lua-zbench.lua 复制到 Lua 的 path 目录
cp src/lua-zbench.lua /usr/local/share/lua/5.1/
```

### 通过 LuaRocks 安装

```bash
luarocks install lua-zbench
```

## 快速开始

### 3 行代码完成基准测试

```lua
local bench = require("lua-zbench")
local result = bench.run_single("my_function", function()
    -- 被测代码
    local sum = 0
    for i = 1, 1000 do sum = sum + i end
end, { time_budget_ms = 500 })

print(string.format("Mean: %.2f ns", result.mean_ns))
```

### 声明式 DSL

```lua
local bench = require("lua-zbench")

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

### 内存追踪

```lua
local bench = require("lua-zbench")

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

## 示例

更多示例请参见 [examples/](examples/) 目录：

- [basic.lua](examples/basic.lua) — 基础用法和计时验证
- [fibonacci.lua](examples/fibonacci.lua) — 对比递归与迭代斐波那契实现
- [noise_baseline.lua](bench/noise_baseline.lua) — 测量噪音基线

## API 概览

| 函数 | 描述 |
|------|------|
| `bench.run_single(name, func, opts)` | 运行单个基准测试 |
| `bench.gettime()` | 获取高精度时间戳（秒） |
| `bench.baseline(opts)` | 测量空函数噪音基线 |
| `bench.describe(name, fn)` | 定义基准测试套件 |
| `bench.it(name, func, opts)` | 定义基准测试用例 |
| `bench.run(opts)` | 运行所有注册的基准测试 |
| `bench.to_json(results)` | 将结果转换为 JSON 字符串 |
| `bench.reset()` | 重置所有注册的套件 |

完整 API 文档请参见 [docs/api.md](docs/api.md)。

## 选项参考

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `time_budget_ms` | `number` | `1000` | 基准测试时间预算（毫秒） |
| `max_iterations` | `number` | `10000` | 最大迭代次数 |
| `track_memory` | `boolean` | `false` | 启用内存分配追踪 |
| `warmup_iter` | `number` | `1000` | 预热迭代次数 |

## 结果格式

每个基准测试结果包含以下字段：

| 字段 | 类型 | 描述 |
|------|------|------|
| `name` | `string` | 基准测试名称 |
| `iterations` | `number` | 执行的迭代次数 |
| `mean_ns` | `number` | 平均执行时间（纳秒） |
| `stddev_ns` | `number` | 标准差（纳秒） |
| `min_ns` | `number` | 最小执行时间（纳秒） |
| `max_ns` | `number` | 最大执行时间（纳秒） |
| `total_ns` | `number` | 总执行时间（纳秒） |
| `p75_ns` | `number` | 第 75 百分位数（纳秒） |
| `p99_ns` | `number` | 第 99 百分位数（纳秒） |
| `p99_9_ns` | `number` | 第 99.9 百分位数（纳秒） |
| `alloc_max_bytes` | `number` | （可选）最大分配字节数 |
| `alloc_mean_bytes` | `number` | （可选）平均分配字节数 |
| `alloc_count` | `number` | （可选）分配次数 |

## 项目结构

```
lua-zbench/
├── src/
│   ├── lua-zbench.lua      # Lua 胶水代码（声明式 DSL）
│   ├── lua_zbench.zig       # Zig 核心模块（zBench 封装）
│   └── main.zig             # 共享库入口
├── examples/
│   ├── basic.lua            # 基础用法示例
│   └── fibonacci.lua        # 斐波那契基准测试
├── bench/
│   └── noise_baseline.lua   # 噪音基线测量
├── docs/
│   └── api.md               # API 参考文档
├── build.zig                # Zig 构建配置
├── build.zig.zon            # Zig 依赖声明
└── ROADMAP.md               # 项目路线图
```

## 技术栈

| 组件 | 版本/来源 |
|------|-----------|
| Zig | 0.16.x |
| zBench | [hendriknielaender/zBench](https://github.com/hendriknielaender/zBench) |
| ziglua | [natecraddock/ziglua](https://github.com/natecraddock/ziglua) |
| LuaJIT | 2.1 |

## 贡献

欢迎贡献！请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解如何参与。

## 许可证

本项目基于 MIT 许可证开源 — 详见 [LICENSE](LICENSE) 文件。
