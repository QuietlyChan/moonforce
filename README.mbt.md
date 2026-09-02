# moonforce（MoonBit 包文档）

力导向图布局引擎，语义对齐 d3-force 3.x。本文件为 mooncakes.io 的模块文档；完整介绍、性能数据与竞品对比见 [README.md](README.md)。

## 安装

```bash
moon add moonforce/moonforce
```

## 包一览

| 包 | 用途 |
|---|---|
| `moonforce/moonforce/src/types` | SoA 节点池（`NodePool`）、lcg 随机源 |
| `moonforce/moonforce/src/quadtree` | d3-quadtree 对齐的松散四叉树 |
| `moonforce/moonforce/src/forces` | 7 种力（`Force` enum 静态分发） |
| `moonforce/moonforce/src/simulation` | `Simulation` tick 状态机（`ForceKind` 移除力） |
| `moonforce/moonforce/src/ffi` | wasm 导出层（foreign_library，`#export_name`） |

## 最小示例

```moonbit nocheck
import { "moonforce/moonforce/src/simulation" }
import { "moonforce/moonforce/src/forces" }

test "force-directed layout" {
  let sim : @simulation.Simulation = @simulation.Simulation::new(6)
  // 力添加顺序 = d3 Map 插入序，影响数值轨迹
  ignore(
    sim.add_force(
      @forces.Force::ManyBody(@forces.ManyBodyForce::new(6, -30.0)),
    ),
  )
  let link : @forces.LinkForce = @forces.LinkForce::create(6, 30.0, 1)
  link.add_edge(0, 1)
  link.add_edge(1, 2)
  ignore(sim.add_force(@forces.Force::Link(link)))
  ignore(sim.tick(300))
  assert_false(sim.nodes.xs[0].is_nan())
}
```

## 数值对齐

与 d3-force@3 位级对齐（300 tick 坐标误差 < 1e-9），golden fixture 由 `scripts/golden.mjs` 生成。详见 [README.md](README.md) 的「语义对齐」一节。
