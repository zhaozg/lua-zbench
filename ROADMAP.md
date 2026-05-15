# ROADMAP.md – lua-zbench

## 项目愿景

构建一个**专业、跨平台、零额外开销**的 Lua 微基准测试框架。基于 Zig + zBench + ziglua，为任意 Lua 函数
（C 扩展或纯 Lua）提供精准的性能测量，输出包含百分位数、内存分配等维度的统计报告。

## 里程碑概览

| 阶段        | 目标                  | 关键产出                                           | 完成状态       |
| ------      | ------                | ----------                                         | ---------- |
| **Phase 1** | 基础绑定与计时验证    | Zig 模块加载、`gettime` 导出、最小 Lua 调用示例    | [x] 完成     |
| **Phase 2** | 集成 zBench 引擎      | 自适应批处理、预热钩子、基础统计（均值/最小/最大） | [x] 完成      |
| **Phase 3** | Lua 侧 API 与完整统计 | 声明式测试脚本、百分位数、内存追踪、JSON 输出      | [ ] 进行中      |
| **Phase 4** | 跨平台与性能优化      | 多平台 CI、消除 FFI 调用噪音、基线校准             | [ ] 规划      |
| **Phase 5** | 文档、打包与发布      | LuaRocks 上传、用户指南、贡献文档                  | [ ] 规划      |

## 依赖项目

- [ziglua](https://github.com/natecraddock/ziglua)
- [zBench](https://github.com/hendriknielaender/zBench)

---

## Phase 1：基础绑定与计时验证（1 周）

**目标**：打通 Zig → Lua 的调用链路，验证计时精度在纳秒级。

**关键任务**：

- [x] 初始化 Zig 项目，添加 `ziglua` 与 `zbench` 依赖。
- [x] 实现 `lua_high_res_time` 函数，返回高精度秒级浮点数。
- [x] 编写 `build.zig`，生成共享库（`.so`/`.dylib`/`.dll`）。
- [x] 编写最小 Lua 测试脚本：加载模块并打印时间戳。
- [x] 验证计时精度：对比循环 1e6 次空操作的理论耗时与测量结果（误差 ≤ 2%）。

**交付物**：

- 可编译的共享库
- `examples/basic.lua` 示例
- 精度验证报告

---

## Phase 2：集成 zBench 核心引擎（2 周）

**目标**：将 `zBench` 的微基准测试能力完整接入，实现自适应批处理。

**关键任务**：

- [x] 将 `zBench` 作为 Zig 依赖引入。
- [x] 封装 `zBench.Benchmark`：将 Lua 函数包装为 `BenchFunc`。
- [x] 实现生命周期钩子：`before_all` 中创建 `lua_State` 并加载被测函数；`before_each` 中重置栈。
- [x] 实现预热阶段：调用被测函数 `WARMUP_ITER` 次（默认 1000）。
- [x] 导出 `lua_bench_run(name, func_ref, opts)` 函数。
- [x] 基础统计：返回均值、最小值、最大值、样本数、百分位数。

**交付物**：

- `src/lua_zbench.zig` 核心模块
- Lua 示例 `examples/bench_rsa.lua`（使用 `lua-openssl` 或任意简单函数）
- 验证：对 1µs 的 busy-loop 测量结果稳定（RSD ≤ 5%）

---

## Phase 3：Lua 侧 API 与完整统计（2 周）

**目标**：提供友好的 Lua 声明式 API，输出专业统计报告。

**关键任务**：

- [x] 实现百分位数（p75, p99, p99.9）计算。
- [x] 内存分配追踪：通过 `zBench` 的 `track_allocations` 获取每次基准的分配次数与总字节数。
- [ ] 支持 JSON 输出（`results.json`）, 通过 cjson 模块。
- [ ] 设计 Lua 侧 DSL：
  ```lua
  local bench = require("lua-zbench")
  bench.describe("RSA 签名", function()
      bench.it("1024-bit", function()
          -- 被测代码
      end, { time_budget_ms = 1000 })
  end)
  bench.run()
  ```
- [x] 添加 `opts` 参数：`time_budget_ms`, `track_memory`, `warmup_iter` 等。

**交付物**：

- 完整 Lua API 文档（`docs/api.md`）
- 示例：对比 Lua 版与 C 版斐波那契数列的性能
- 支持终端彩色表格输出 + JSON 导出

---

## Phase 4：跨平台与性能优化（1 周）

**目标**：确保框架在 Linux/macOS/Windows 上行为一致，并消除测量噪音。

**关键任务**：

- [ ] 设置 GitHub Actions CI：矩阵测试 Zig 0.16.x + LuaJIT 2.1。
- [ ] 解决 Windows 上 DLL 导出符号的问题（`__declspec(dllexport)`）。
- [ ] 实现“空基线”测量：自动运行空函数，将结果作为噪音参考值输出。
- [ ] 自适应批处理优化：当单次调用耗时 > 10µs 时，batch_size = 1（避免过度批量）。
- [ ] 验证高性能场景：对耗时 10ns 的空循环，测量结果的 CV（变异系数）≤ 10%。

**交付物**：

- CI 绿色通过（三个平台）
- 性能优化报告（对比 Phase 2 与 Phase 4 的测量方差）
- `bench/noise_baseline.lua` 示例

---

## Phase 5：文档、打包与发布（1 周）

**目标**：提供完整的用户文档、贡献指南，并发布到 LuaRocks。

**关键任务**：

- [ ] 编写 `README.md`：特性、安装、快速开始、示例。
- [ ] 编写 `CONTRIBUTING.md`：如何添加新的基准测试、代码规范。
- [ ] 编写 `CHANGELOG.md`（基于 Keep a Changelog）。
- [ ] 创建 `lua-zbench-0.1.0-1.rockspec`，配置外部依赖（LuaJIT、openssl 可选）。
- [ ] 测试 `luarocks install lua-zbench --local` 在干净环境中的可用性。
- [ ] 发布到 GitHub Releases 及 LuaRocks 仓库。

**交付物**：
- 版本 0.1.0 发布
- 完整文档站（可选 GitHub Pages）
- 视频演示（或 GIF）展示框架使用方法

---

## 成功标准（验收条件）

- ✅ 用户能用 3 行 Lua 代码完成对一个函数的微基准测试。
- ✅ 测量精度：单次调用耗时 ≥ 100ns 时，标准误差 ≤ 2%；调用耗时 10-100ns 时，CV ≤ 15%。
- ✅ 跨平台：CI 中 Linux（x86_64/aarch64）、macOS（x86_64/aarch64）、Windows（x86_64）均通过。
- ✅ 内存追踪能正确捕获被测函数产生的分配次数与字节数。
- ✅ 文档齐全，一个不熟悉 Zig 的 Lua 开发者也能在 10 分钟内上手。

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| `zBench` 与 Zig 0.16.x 兼容性问题 | 高 | 优先 fork 并适配，必要时提交 PR 到上游 |
| LuaJIT 在 Windows 上的构建失败 | 中 | 使用 `zig-luajit-build`，并在 CI 中预先测试 |
| FFI 调用开销掩盖极快函数性能 | 中 | 提供批量循环选项（在 Lua 侧循环 N 次，再除以 N） |
| `ziglua` 尚未完全支持 Zig 0.16 | 低 | 跟踪 upstream，必要时打补丁 |

---

## 路线图更新机制

- 每个里程碑结束后，团队进行复盘，更新下一阶段的任务细节。
- 重大变更（如放弃 zBench 改用自研引擎）需通过 Issue 讨论并更新本文档。
- 文档版本跟随代码版本，每次发布时同步更新 ROADMAP.md 的完成状态。
