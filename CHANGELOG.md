# Changelog

所有重要变更均记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本管理遵循 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)。

## [0.1.0] - 2026-05-15

### 新增

- **Phase 1: 基础绑定与计时验证**
  - Zig 项目初始化，集成 `ziglua` 与 `zBench` 依赖
  - 实现 `lua_high_res_time` 函数，返回高精度秒级浮点数
  - 编写 `build.zig`，生成共享库（`.so`/`.dylib`/`.dll`）
  - 最小 Lua 测试脚本：加载模块并打印时间戳
  - 计时精度验证：循环 1e6 次空操作，误差 ≤ 2%

- **Phase 2: 集成 zBench 核心引擎**
  - 封装 `zBench.Benchmark`，将 Lua 函数包装为 `BenchFunc`
  - 实现生命周期钩子：`before_all` / `before_each`
  - 实现预热阶段（默认 1000 次迭代）
  - 导出 `lua_bench_run(name, func_ref, opts)` 函数
  - 基础统计：均值、最小值、最大值、样本数、百分位数

- **Phase 3: Lua 侧 API 与完整统计**
  - 百分位数计算（p75, p99, p99.9）
  - 内存分配追踪（`track_allocations`）
  - JSON 输出支持（`results.json`）
  - 声明式 DSL：`bench.describe()` / `bench.it()` / `bench.run()`
  - 选项参数：`time_budget_ms`、`track_memory`、`warmup_iter` 等
  - 终端彩色表格输出
  - 完整 Lua API 文档（`docs/api.md`）
  - 斐波那契数列基准测试示例

- **Phase 4: 跨平台与性能优化**
  - Windows DLL 导出符号支持（`__declspec(dllexport)`）
  - 空基线测量（`bench.baseline()`）
  - 自适应批处理优化
  - macOS `.so` 兼容性安装

- **Phase 5: 文档、打包与发布**
  - `README.md`：特性、安装、快速开始、示例
  - `CONTRIBUTING.md`：贡献指南
  - `CHANGELOG.md`：版本变更记录
  - `lua-zbench-0.1.0-1.rockspec`：LuaRocks 打包配置

### 技术栈

- Zig 0.16.x
- zBench 0.13.0
- ziglua (基于 natecraddock/ziglua)
- LuaJIT 2.1

[0.1.0]: https://github.com/yourusername/lua-zbench/releases/tag/v0.1.0
