# 贡献指南

感谢您对 lua-zbench 的关注！我们欢迎各种形式的贡献，包括但不限于：

- 报告 Bug
- 提交功能请求
- 改进文档
- 添加新的基准测试示例
- 修复代码问题
- 优化测量精度

## 行为准则

请保持友善和专业。我们致力于为所有参与者提供友好的环境。

## 如何贡献

### 报告 Bug

如果您发现了 Bug，请通过 GitHub Issues 提交，并包含以下信息：

1. **环境信息**：操作系统、Zig 版本、LuaJIT 版本
2. **复现步骤**：最小化的 Lua 脚本和构建命令
3. **预期行为**：您期望发生什么
4. **实际行为**：实际发生了什么（包括完整的错误输出）
5. **测量数据**：如果与精度相关，请提供多次运行的结果

### 提交功能请求

在提交新功能前，请先搜索现有 Issues 确认是否已有相关讨论。提交时请说明：

1. **使用场景**：您希望在什么场景下使用该功能
2. **预期 API**：您期望的接口设计（可选）
3. **替代方案**：您尝试过的其他解决方案

### 代码贡献

#### 1. 准备工作

```bash
# Fork 并克隆仓库
git clone https://github.com/yourusername/lua-zbench.git
cd lua-zbench

# 确保可以构建
zig build -Doptimize=ReleaseFast
```

#### 2. 代码规范

**Zig 代码：**

- 遵循 `zig fmt` 格式
- 使用 `snake_case` 函数名，`PascalCase` 类型名
- 所有可能失败的调用使用 `!` 或 `catch`
- 通过 `ziglua` 进行安全的 Lua C API 调用，禁止直接使用 `lua_*` 原始函数
- 每个导出的函数需有 `///` 注释，说明参数、返回值和精度单位

**Lua 代码：**

- 使用 4 空格缩进
- 局部变量优先（`local`）
- 函数名使用 `snake_case`
- 添加适当的注释说明关键逻辑

#### 3. 添加新的基准测试

如果您想添加新的基准测试示例：

1. 在 `examples/` 目录下创建 `.lua` 文件
2. 使用 `bench.describe()` / `bench.it()` / `bench.run()` DSL
3. 确保包含结果验证（`assert` 或显式检查）
4. 在文件头部添加使用说明注释

示例模板：

```lua
-- examples/my_benchmark.lua
-- 描述：这个基准测试测量什么
--
-- 用法：
--   luajit examples/my_benchmark.lua

local bench = require("bench")

bench.describe("My Benchmark Suite", function()
    bench.it("case 1", function()
        -- 被测代码
    end, { time_budget_ms = 500 })
end)

bench.run({ json = true })
```

#### 4. 运行测试

```bash
# 运行 Zig 单元测试
zig build test

# 运行 Lua 集成测试
luajit examples/basic.lua
luajit examples/fibonacci.lua
```

#### 5. 提交代码

```bash
# 创建功能分支
git checkout -b feat/your-feature-name

# 提交更改
git add .
git commit -m "feat: 简洁描述您的更改"

# 推送并创建 Pull Request
git push origin feat/your-feature-name
```

#### 6. Pull Request 要求

- PR 标题遵循 [Conventional Commits](https://www.conventionalcommits.org/) 格式：
  - `feat:` 新功能
  - `fix:` Bug 修复
  - `docs:` 文档变更
  - `perf:` 性能优化
  - `refactor:` 重构
  - `test:` 测试相关
  - `chore:` 构建/工具链相关
- 包含对变更的详细描述
- 如果涉及测量逻辑变更，需附带精度影响分析
- 确保 CI 通过（Linux/macOS/Windows）
- 更新相关文档（API 文档、示例等）

## 开发指南

### 测量精度注意事项

- 基准循环内部禁止执行 `printf` / 文件 I/O
- 不要假设被测函数为纯函数——考虑 Lua GC 或 C 扩展内部状态
- 预热阶段不可省略
- 添加新功能时，需评估对测量精度的影响（引入的开销 ≤ 测量时长的 1%）

### 构建配置

- 发布构建使用 `zig build -Doptimize=ReleaseFast`
- 调试构建使用 `zig build`（默认 Debug 模式）
- 交叉编译示例：`zig build -Dtarget=aarch64-linux-gnu`

### 文档更新

- API 变更需同步更新 `docs/api.md`
- 新增示例需在 `README.md` 的示例章节添加引用
- 重大变更需更新 `CHANGELOG.md`

## 发布流程

维护者执行以下步骤发布新版本：

1. 更新 `CHANGELOG.md` 中的版本和日期
2. 更新 `build.zig.zon` 中的版本号
3. 创建 Git 标签：`git tag v0.1.0`
4. 构建并测试所有平台
5. 发布到 GitHub Releases
6. 发布到 LuaRocks

## 获取帮助

- 提交 [Issue](https://github.com/yourusername/lua-zbench/issues)
- 在 PR 中 @ 维护者
- 查阅 [API 文档](docs/api.md)
