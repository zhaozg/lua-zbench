# AGENT.md – lua-zbench

## 项目定位

基于 Zig + zBench + ziglua 的 Lua 微基准测试框架，专为评估 `lua-openssl` 等密码学扩展的真实性能而设计。

## 核心原则

- **准确性优先**：测量结果必须可复现、低噪声，自适应批处理与预热阶段不可省略。
- **跨平台一致**：利用 Zig 的交叉编译能力，确保 Linux/macOS/Windows 行为一致。
- **零开销抽象**：基准循环本身不引入可测量的额外开销；FFI 调用成本需在分析中予以考虑。
- **透明可审计**：所有统计结果（均值、百分位数、内存分配）输出到 JSON/终端，并标注基线噪音。

## 技术栈

| 组件          | 版本/来源                                 |
|---------------|------------------------------------------|
| Zig           | 0.16.x                                    |
| zBench        | https://github.com/hendriknielaender/zBench |
| ziglua        | v0.3.0 (natecraddock/ziglua)              |
| LuaJIT        | 2.1 (via ziglua )                |

## 代码规范

1. **Zig 风格**：遵循 `zig fmt`，使用 `snake_case` 函数名，`PascalCase` 类型名。
2. **错误处理**：所有可能失败的调用使用 `!` 或 `catch`；基准函数内部不应静默吞掉错误。
3. **内存管理**：Lua 状态的生命周期由框架管理；zBench 的 `track_allocations` 仅用于分析，不干扰被测代码。
4. **Lua C API 封装**：通过 `ziglua` 进行安全调用，禁止直接使用 `lua_*` 原始函数。

## 测试要求

- **单元测试**：Zig 侧使用 `std.testing` 覆盖计时器校准、统计模块。
- **集成测试**：Lua 脚本调用框架，必须包含 `lua-openssl` 的至少一个密码运算（如 AES‑GCM 加解密）。
- **性能回归**：合并 PR 前，需运行 `bench/` 下现有基准并提交报告（通过 CI 生成）。

## 文档规范

- **API 文档**：每个导出的 Zig 函数及 Lua 绑定函数都需有 `///` 注释，说明参数、返回值和精度单位。
- **用户指南**：`docs/usage.md` 包含安装步骤、Lua 脚本编写示例及统计结果解读。
- **贡献指南**：`CONTRIBUTING.md` 说明如何添加新的基准测试。

## 构建与发布

- **构建命令**：`zig build -Doptimize=ReleaseFast` 生成共享库。
- **LuaRocks 打包**：提供 `.rockspec`，将编译后的二进制与 Lua 胶水代码一并发布。
- **CI 要求**：GitHub Actions 需覆盖 Linux (x86_64, aarch64)、macOS、Windows (x86_64)。

## AI 工作流程

1. 收到任务时，先确认是否涉及 `ziglua` / `zBench` / `lua-openssl` 任一模块。
2. 提供代码示例前，先阐述设计理由（如为何选择自适应批处理而非固定循环）。
3. 若建议修改核心测量逻辑，必须附带对测量精度的定量影响分析（如引入的开销 ≤ 测量时长的 1%）。
4. 提交代码时自动生成 `CHANGELOG.md` 条目（按 Keep a Changelog 格式）。

## 禁止事项

- ❌ 在基准循环内部执行 `printf` / 文件 I/O。
- ❌ 假设被测函数为纯函数而不考虑 Lua GC 或 OpenSSL 内部状态。
- ❌ 直接复制 `zBench` 示例而未适配 Lua 调用模型。
- ❌ 忽略预热阶段或盲目使用过高的 `time_budget` 导致测试时间过长。

## 参考资源

- [zBench 文档](https://github.com/hendriknielaender/zBench)
- [ziglua README](https://github.com/natecraddock/ziglua)
- [Lua/C API 手册](https://www.lua.org/manual/5.1/manual.html#3)
- [Zig 0.16 语言参考](https://ziglang.org/documentation/0.16.0/)
