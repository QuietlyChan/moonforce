# AGENTS.md — 开发约定与工具链版本

## 工具链版本（锁定）

MoonBit 工具链**每周发版**，本仓库在 CI 与本地开发中锁定以下版本（R1 风险缓解）：

```
moon  0.1.20260713 (75c7e1f 2026-07-13)
moonc 0.10.4+2cc641edf (2026-07-15)
moonrun 0.1.20260713
Bun   >= 1.4
```

安装特定版本：`curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash`（或参考 [moon 官方文档](https://docs.moonbitlang.com)）。语法漂移时优先查 `moon.pkg` schema 与 FFI 文档，不要依赖旧博客。

## 项目结构

```
src/types      SoA NodePool + lcg（勿改动数值语义，见下）
src/quadtree   d3-quadtree 对齐四叉树
src/forces     7 种力（enum 分发）
src/simulation tick 状态机
src/ffi        wasm 导出（唯一 foreign_library 包）
```

## 硬性约束

1. **数值语义冻结**：`src/` 下的浮点运算顺序、遍历顺序（visit 先序 0-3 / visitAfter 自底向上）、lcg 消耗序列**不可调整**——它们与 d3-force@3 位级对齐（golden 测试 < 1e-9）。重构必须先跑 `moon test src/simulation` 全绿。
2. **wasm 可移植性**：`src/ffi` 包禁用 `println`、`moonbitlang/core/env` 及任何引入宿主函数导入的依赖。验收：`bun scripts/check-wasm.mjs` 断言 Import 段为空。
3. **导出命名**：`#export_name` 受 C 标识符限制，统一 `mf_` 前缀 snake_case，包内唯一。
4. **moon test 逐包运行**：`ffi` 包是 foreign_library，`moon test`（全量）会因 InlineTest 驱动失败——按包路径测试：
   `moon test src/types src/quadtree src/forces src/simulation`
5. **力添加顺序敏感**：d3 Map 按插入序迭代 forces，任何 demo/bench/测试中力的添加顺序都会改变轨迹。

## 常用命令

```bash
moon test src/types src/quadtree src/forces src/simulation   # MoonBit 测试（含 golden）
bun scripts/golden.mjs       # 重新生成 golden fixture（改语义/加用例时）
bun run build                # wasm-gc release + npm dist
bun test packages/moonforce  # TS 层端到端
bun scripts/serve.mjs        # demo/bench 静态服务器
```

## MoonBit 语言速记（本仓库踩过的坑）

- `fn f(self : T, ...)` 首参数名 `self` + 本地类型 → 自动成为 T 的方法
- struct `mut` 字段**跨包只读**：跨包写入必须通过定义包提供的 setter
- enum 构造器跨包构造需要 `pub(all) enum`
- Option 槽赋值需要 `Some(...)` 显式装箱；`FixedArray[QNode?]` 元素同理
- `moon.pkg` DSL：`import { ... } for "test"`（黑盒测试依赖）；`pkgtype(kind: "foreign_library")`
- 字面量：`1e-6` 非法（用 `1.0e-6`）；`Double::nan()` 已弃用（用 `@double.not_a_number`）
- `&T` 引用语法不适用于普通 struct receiver（直接 `self : T`）

## d3 源码参考

`vendor/d3-force`（ISC）与 `vendor/d3-quadtree`（ISC）是语义对齐的**唯一权威**。实现任何力之前先读对应源文件，不要凭记忆。
