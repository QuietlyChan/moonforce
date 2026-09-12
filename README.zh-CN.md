<div align="center">

**简体中文** · [English](README.md)

</div>

# moonforce

[![CI](https://github.com/QuietlyChan/moonforce/actions/workflows/ci.yml/badge.svg)](https://github.com/QuietlyChan/moonforce/actions/workflows/ci.yml)

**用 [MoonBit](https://www.moonbitlang.com/) 编写、编译为 WASM-GC 的力导向图布局引擎** —— 精确对齐 [d3-force](https://github.com/d3/d3-force) 3.x 语义的现代替代。

[在线 Demo](https://quietlychan.github.io/moonforce/) · [性能对比基准](https://quietlychan.github.io/moonforce/demo/bench.html)

## 为什么是 moonforce

- **快**：Barnes-Hut O(N log N) + SoA 数据布局 + wasm-gc 编译。相同初始条件、相同力配置下，对比 d3-force@3 的实测加速比（10000 节点 tick 级）：

  | 规模 | d3-force | moonforce | 加速比 |
  |---|---|---|---|
  | 500 节点 | 3.0 ms/tick | 1.0 ms/tick | **3.0×** |
  | 2000 节点 | 12.0 ms/tick | 7.0 ms/tick | **1.7×** |
  | 5000 节点 | 37.0 ms/tick | 20.0 ms/tick | **1.85×** |
  | 10000 节点 | 81.0 ms/tick | 46.0 ms/tick | **1.76×** |

  （实测环境见 [bench.html](demo/bench.html)，可在自己浏览器中复现；诚实说明：≤500 节点时跨界开销占比升高，优势缩小甚至持平）

- **小**：wasm 产物 **28 KB**（未压缩，Import 段为空——零宿主依赖，`WebAssembly.instantiate(bytes, {})` 即用）

- **数值可复现**：与 d3-force 3.x **位级对齐**。golden 测试用固定种子跑 d3-force 生成轨迹 fixture，moonforce 断言 300 tick 每坐标绝对误差 < 1e-9——包括重合点 jiggle 扰动和 lcg 随机序列的消耗顺序（见 [scripts/golden.mjs](scripts/golden.mjs)）

- **MoonBit 原生**：[mooncakes.io](https://mooncakes.io) 可直接 `moon add`，也可以从 npm 以 wasm 模块引入——一套核心算法，两种生态

## 快速开始

### 在线体验

```bash
git clone https://github.com/QuietlyChan/moonforce
cd moonforce
bun install
bun run build        # moon build + npm 包构建
bun scripts/serve.mjs
# → http://localhost:8080/demo/（交互式布局）
# → http://localhost:8080/demo/bench.html（与 d3-force 性能对比）
```

### npm（JS/TS）

```bash
bun add moonforce   # 或 npm i moonforce
```

```ts
import { loadMoonforce } from "moonforce";

const mf = await loadMoonforce();
const sim = mf.createSimulation(nodes.length);

// 预置初始坐标（与 d3 preset x/y 等价）
nodes.forEach((n, i) => sim.setNodePos(i, n.x, n.y));

// 力添加顺序 = d3 Map 插入序（影响轨迹，按 d3 惯例添加）
sim.addManyBodyForce({ strength: -30 });
sim.addLinkForce(links, { distance: 30 });   // links: [{source, target}] 节点索引对
sim.addCollideForce({ radius: 3 });
sim.addCenterForce();

// 时间驱动由宿主负责（rAF / worker 均可）
const xy = new Float64Array(nodes.length * 2);
function frame() {
  sim.step(1);
  sim.positions(xy);          // [x0, y0, x1, y1, ...]
  render(xy);
  if (sim.alpha > 0.001) requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
```

拖拽节点（对齐 d3 惯例）：

```ts
const hit = sim.find(worldX, worldY, 15);     // 返回最近节点索引或 null
sim.setAlphaTarget(0.3);                      // 拖拽时保持热度
sim.setFixed(hit, worldX, worldY);
// mouseup：
sim.setFixed(hit, null, null);
sim.setAlphaTarget(0);                        // 冷却收敛
```

### MoonBit（mooncakes）

```bash
moon add QuietlyChan/moonforce
```

```moonbit
import { "QuietlyChan/moonforce/src/simulation" }
import { "QuietlyChan/moonforce/src/forces" }

let sim : @simulation.Simulation = @simulation.Simulation::new(100)
ignore(
  sim.add_force(
    @forces.Force::ManyBody(@forces.ManyBodyForce::new(100, -30.0)),
  ),
)
ignore(sim.tick(300))
```

## 语义对齐（这是本项目的核心承诺）

moonforce 逐行对照 [d3-force](vendor/d3-force) 与 [d3-quadtree](vendor/d3-quadtree) 源码实现，三处"常见误解"已按源码修正：

| 要点 | d3-force 3.x 实际行为 |
|---|---|
| manyBody theta 默认 | **0.9**（内部存 theta²=0.81），不是 0.8 |
| forceCenter | **位置硬移动**：`x -= (Σx/n - cx) * strength`，不经过速度系统 |
| forceLink | **预测位置**：`target.x + target.vx - source.x - source.vx` |

更深的细节对齐：

- **tick 三步序**：alpha 衰减 → 按插入序遍历 forces → `x += vx *= velocityDecay`（先衰减后位移的复合赋值）
- **lcg 随机源**：`(1664525·s + 1013904223) mod 2^32`，与 JS 位精确一致；jiggle 的**消耗顺序**（visit 先序 0-3、visitAfter 自底向上）逐节点对齐
- **四叉树**：cover 整数单元起步防浮点漂移、重合点 next 链表（新点为表头）、分裂 do-while 精确复刻
- **Barnes-Hut**：`w²/θ² < l` 判定、distanceMin 软下限（几何平均 `√(dmin²·l)`）、`!quad.value` 剪枝对齐 JS falsy（0/-0/NaN 均剪枝）
- **forceCollide**：预测位置建树、AABB 剪枝、每对只处理一次（`data.index > node.index`）、权重 `rj²/(ri²+rj²)`
- **数值常量**：`alphaDecay = 0.02276277904418933`（JS `Math.pow` 实算后硬编码，规避 wasm pow 实现的 ULP 差异）

**golden 测试方法**：`bun scripts/golden.mjs` 用 d3-force@3（固定种子、显式初始坐标）跑 8 个配置矩阵各 300 tick，生成 [src/simulation/golden_test.mbt](src/simulation/golden_test.mbt)（当前 27 个用例全绿，误差 < 1e-9）。

### 与 d3-force 的已知差异

- 每种力**至多一个实例**（d3 允许同名多实例，如两个 forceX）——以力类型代名字，MVP 简化
- per-node/per-link 的 strength/distance 函数：改为统一标量参数 + 单点 setter（`setCollideRadius` 等）
- timer/dispatch 事件层不进 wasm：时间驱动与 `on("tick")` 回调由 JS 宿主实现（渲染循环本来就在 JS 侧）
- `simulation.find` 为线性扫描（d3 同为线性，语义一致）

## 竞品一览

| 库 | 语言/交付 | 算法家族 | 活跃度 | 备注 |
|---|---|---|---|---|
| **moonforce** | **MoonBit → WASM-GC** | **velocity verlet + Barnes-Hut** | **本项目** | **d3-force 语义位级对齐 + 双生态发布** |
| d3-force | JS | velocity verlet + Barnes-Hut | 极活跃 | 事实标准，本项目的语义基准 |
| elk.js | Java→GWT→JS | 层次/Sugiyama | 活跃 | 方向图/端口图，非力导向 |
| dagre | JS | Sugiyama 层次 | 低频维护 | 层次布局 |
| graphology-forceatlas2 | JS | ForceAtlas2（含 BH） | 活跃 | Sigma.js 生态 |
| webcola | JS | 约束求解 | 低 | 学术出身 |
| ngraph.forces | JS | 自研物理 | 中低 | vivagraph 生态 |
| AntV G6 | TS | 多布局聚合 | 极活跃 | 平台级，非独立布局内核 |
| ForceAtlas2 (Gephi) | Java | FA2 | 稳定 | 论文源头，桌面端 |
| OpenOrd | C++ | 多级粗化 | 学术遗留 | 大规模 |
| Graphviz fdp/neato | C | spring/stress | 停滞 | 批量渲染导向 |
| OGDF | C++ | 全面 | 学术维护 | 研究库 |
| yFiles | 商业闭源 | 工业级全家桶 | 持续 | 商业对标 |

定位一句话：**唯一 MoonBit 原生实现、与 d3-force 3.x 位级对齐、Barnes-Hut、WASM-GC 交付、mooncakes + npm 双发布的力导向布局内核**。

## 架构

```
src/
├── types/       SoA NodePool（FixedArray[Double] → unboxed (array f64)）
│                + lcg（与 JS 位精确）+ jiggle
├── quadtree/    d3-quadtree 对齐的松散四叉树（cover/add/visit/visitAfter，
│                聚合缓存挂节点，自底向上聚合）
├── forces/      7 种力（enum 静态分发，无 trait 装箱）
│                center · manyBody(Barnes-Hut) · link · collide · x · y · radial
├── simulation/  tick 状态机（alpha 衰减三步循环）
└── ffi/         foreign_library：30 个 mf_* 导出（i32 句柄表，
                 纯数值 ABI → wasm Import 段为空）

packages/moonforce/   npm 包（TS 胶水：loadMoonforce/Simulation 类，数据驻留 wasm）
demo/                 交互式 demo + bench（d3-force 对比）
```

数据驻留 wasm 堆（SoA），热路径零跨界；坐标读取为拉取模式（`positions()` 循环 `mf_node_x/y`，5000 节点约 0.1-0.25 ms/tick，相对计算成本可接受）。

## 开发

```bash
bun install                # d3-force（golden/bench 用）
moon test src/types src/quadtree src/forces src/simulation   # 27 用例（含 golden）
bun scripts/golden.mjs     # 重新生成 golden fixture（改语义时）
bun run build              # moon build --target wasm-gc --release + npm 包
bun scripts/check-wasm.mjs _build/wasm-gc/release/build/src/ffi/ffi.wasm   # 断言 Import 段为空
bun test packages/moonforce   # 端到端（含 d3 数值对齐）
bun scripts/serve.mjs      # demo + bench
```

工具链：见 [AGENTS.md](AGENTS.md)（moon 工具链周更，本地与 CI 统一跟随 latest，golden 测试守卫数值语义）。

## Roadmap

- [ ] per-node manyBody strength、per-link distance（函数 → 索引数组）
- [ ] `mf_step_into`：推送模式坐标回写（省 JS 侧拉取循环）
- [ ] Web Worker 封装（demo 大图布局移入 worker）
- [ ] wasm-gc 内联 manyBody/collide 遍历（去掉闭包装箱，bench 定位后再做）
- [ ] 多实例 force（名字 → 句柄）

## License

MIT。语义对齐参考的 [d3-force](vendor/d3-force)（ISC 许可）与 [d3-quadtree](vendor/d3-quadtree)（ISC 许可）源码已 vendor 进仓库，谨此致谢。

<div align="center">

**简体中文** · [English](README.md)

</div>
