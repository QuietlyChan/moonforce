<div align="center">

[简体中文](README.zh-CN.md) · **English**

</div>

# moonforce

[![CI](https://github.com/QuietlyChan/moonforce/actions/workflows/ci.yml/badge.svg)](https://github.com/QuietlyChan/moonforce/actions/workflows/ci.yml)

**A force-directed graph layout engine written in [MoonBit](https://www.moonbitlang.com/), compiled to WASM-GC** — a modern alternative that precisely matches [d3-force](https://github.com/d3/d3-force) 3.x semantics.

[Live Demo](https://quietlychan.github.io/moonforce/) · [Performance Benchmark](https://quietlychan.github.io/moonforce/demo/bench.html)

## Why moonforce

- **Fast**: Barnes-Hut O(N log N) + SoA data layout + wasm-gc compilation. Measured speedup over d3-force@3 under identical initial conditions and force configuration (tick time at 10k nodes):

  | Scale | d3-force | moonforce | Speedup |
  |---|---|---|---|
  | 500 nodes | 3.0 ms/tick | 1.0 ms/tick | **3.0×** |
  | 2000 nodes | 12.0 ms/tick | 7.0 ms/tick | **1.7×** |
  | 5000 nodes | 37.0 ms/tick | 20.0 ms/tick | **1.85×** |
  | 10000 nodes | 81.0 ms/tick | 46.0 ms/tick | **1.76×** |

  (Measured in [bench.html](demo/bench.html) — reproducible in your own browser. Honest caveat: at ≤500 nodes, boundary-crossing overhead grows and the advantage shrinks or disappears.)

- **Small**: wasm artifact is **28 KB** (uncompressed, empty import section — zero host dependencies, works with a plain `WebAssembly.instantiate(bytes, {})`)

- **Numerically reproducible**: **bit-level aligned** with d3-force 3.x. Golden tests run d3-force with a fixed seed to generate trajectory fixtures; moonforce asserts absolute per-coordinate error < 1e-9 over 300 ticks — including coincident-point jiggle perturbation and the exact consumption order of the lcg random sequence (see [scripts/golden.mjs](scripts/golden.mjs))

- **MoonBit native**: install directly from [mooncakes.io](https://mooncakes.io) with `moon add`, or consume as a wasm module from npm — one core implementation, two ecosystems

## Quick Start

### Try it locally

```bash
git clone https://github.com/QuietlyChan/moonforce
cd moonforce
bun install
bun run build        # moon build + npm package build
bun scripts/serve.mjs
# → http://localhost:8080/demo/ (interactive layout)
# → http://localhost:8080/demo/bench.html (d3-force comparison)
```

### npm (JS/TS)

```bash
bun add moonforce   # or npm i moonforce
```

```ts
import { loadMoonforce } from "moonforce";

const mf = await loadMoonforce();
const sim = mf.createSimulation(nodes.length);

// Preset initial positions (equivalent to d3 preset x/y)
nodes.forEach((n, i) => sim.setNodePos(i, n.x, n.y));

// Force insertion order = d3 Map insertion order (affects the trajectory; follow d3 conventions)
sim.addManyBodyForce({ strength: -30 });
sim.addLinkForce(links, { distance: 30 });   // links: [{source, target}] node index pairs
sim.addCollideForce({ radius: 3 });
sim.addCenterForce();

// Time driving is the host's responsibility (rAF / worker, either works)
const xy = new Float64Array(nodes.length * 2);
function frame() {
  sim.step(1);
  sim.positions(xy);          // [x0, y0, x1, y1, ...]
  render(xy);
  if (sim.alpha > 0.001) requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
```

Dragging nodes (matching d3 conventions):

```ts
const hit = sim.find(worldX, worldY, 15);     // nearest node index or null
sim.setAlphaTarget(0.3);                      // keep warm while dragging
sim.setFixed(hit, worldX, worldY);
// on mouseup:
sim.setFixed(hit, null, null);
sim.setAlphaTarget(0);                        // cool down and settle
```

### MoonBit (mooncakes)

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

## Semantic Alignment (the core promise of this project)

moonforce is implemented line-by-line against the [d3-force](vendor/d3-force) and [d3-quadtree](vendor/d3-quadtree) sources. Three "common misconceptions" have been corrected per the source:

| Point | Actual d3-force 3.x behavior |
|---|---|
| manyBody default theta | **0.9** (internally stored as theta²=0.81), not 0.8 |
| forceCenter | **Hard position shift**: `x -= (Σx/n - cx) * strength`, bypassing the velocity system |
| forceLink | **Predicted positions**: `target.x + target.vx - source.x - source.vx` |

Deeper details that are aligned:

- **tick 3-step order**: alpha decay → iterate forces in insertion order → `x += vx *= velocityDecay` (the decay-then-move compound assignment)
- **lcg random source**: `(1664525·s + 1013904223) mod 2^32`, bit-exact with JS; the **consumption order** of jiggle calls (visit pre-order 0-3, visitAfter bottom-up) is aligned node by node
- **Quadtree**: cover starts from integer cells to prevent floating-point drift, coincident-point `next` chains (new point becomes head), exact do-while split loop
- **Barnes-Hut**: `w²/θ² < l` criterion, distanceMin soft floor (geometric mean `√(dmin²·l)`), `!quad.value` pruning matched to JS falsy (0/-0/NaN all prune)
- **forceCollide**: tree built from predicted positions, AABB pruning, each pair handled once (`data.index > node.index`), weight `rj²/(ri²+rj²)`
- **Numeric constants**: `alphaDecay = 0.02276277904418933` (computed with JS `Math.pow`, then hardcoded to avoid ULP differences in wasm pow implementations)

**Golden test method**: `bun scripts/golden.mjs` runs d3-force@3 (fixed seed, explicit initial coordinates) over a matrix of 8 configurations × 300 ticks each and generates [src/simulation/golden_test.mbt](src/simulation/golden_test.mbt) (currently 27 cases, all green, error < 1e-9).

### Known differences from d3-force

- Each force has **at most one instance** (d3 allows multiple same-named instances, e.g. two forceX) — force type replaces the name; an MVP simplification
- per-node/per-link strength/distance functions: replaced by uniform scalar parameters + per-point setters (`setCollideRadius` etc.)
- The timer/dispatch event layer stays out of wasm: time driving and `on("tick")` callbacks are implemented by the JS host (the render loop lives on the JS side anyway)
- `simulation.find` is a linear scan (same as d3; semantics identical)

## Competitors

| Library | Language/Delivery | Algorithm family | Activity | Notes |
|---|---|---|---|---|
| **moonforce** | **MoonBit → WASM-GC** | **velocity verlet + Barnes-Hut** | **this project** | **bit-level d3-force alignment + dual-ecosystem release** |
| d3-force | JS | velocity verlet + Barnes-Hut | very active | the de-facto standard; this project's semantic baseline |
| elk.js | Java→GWT→JS | layered/Sugiyama | active | directed/port graphs, not force-directed |
| dagre | JS | Sugiyama layered | low maintenance | layered layout |
| graphology-forceatlas2 | JS | ForceAtlas2 (with BH) | active | Sigma.js ecosystem |
| webcola | JS | constraint solving | low | academic origins |
| ngraph.forces | JS | custom physics | medium-low | vivagraph ecosystem |
| AntV G6 | TS | aggregated layouts | very active | platform-level, not a standalone layout kernel |
| ForceAtlas2 (Gephi) | Java | FA2 | stable | paper's origin, desktop |
| OpenOrd | C++ | multilevel coarsening | academic legacy | large scale |
| Graphviz fdp/neato | C | spring/stress | dormant | batch-render oriented |
| OGDF | C++ | comprehensive | academic | research library |
| yFiles | commercial | industrial suite | ongoing | commercial counterpart |

Positioning in one sentence: **the only force-directed layout kernel that is MoonBit-native, bit-level aligned with d3-force 3.x, Barnes-Hut, delivered as WASM-GC, and published to both mooncakes + npm**.

## Architecture

```
src/
├── types/       SoA NodePool (FixedArray[Double] → unboxed (array f64))
│                + lcg (bit-exact with JS) + jiggle
├── quadtree/    d3-quadtree-aligned loose quadtree (cover/add/visit/visitAfter;
│                aggregate caches live on nodes, bottom-up aggregation)
├── forces/      7 forces (enum static dispatch, no trait boxing)
│                center · manyBody(Barnes-Hut) · link · collide · x · y · radial
├── simulation/  tick state machine (alpha decay 3-step loop)
└── ffi/         foreign_library: 30 mf_* exports (i32 handle table,
                 pure numeric ABI → empty wasm import section)

packages/moonforce/   npm package (TS glue: loadMoonforce/Simulation class; data lives in wasm)
demo/                 interactive demo + bench (d3-force comparison)
```

Data lives in the wasm heap (SoA); the hot path crosses the boundary zero times. Coordinate reads use the pull model (`positions()` loops `mf_node_x/y` — ~0.1–0.25 ms/tick at 5000 nodes, acceptable relative to compute cost).

## Development

```bash
bun install                # d3-force (for golden/bench)
moon test src/types src/quadtree src/forces src/simulation   # 27 cases (incl. golden)
bun scripts/golden.mjs     # regenerate golden fixtures (when changing semantics)
bun run build              # moon build --target wasm-gc --release + npm package
bun scripts/check-wasm.mjs _build/wasm-gc/release/build/src/ffi/ffi.wasm   # assert empty import section
bun test packages/moonforce   # end-to-end (incl. d3 numeric alignment)
bun scripts/serve.mjs      # demo + bench
```

Toolchain: see [AGENTS.md](AGENTS.md) (moon ships weekly; local dev and CI both track the latest release, with golden tests guarding the numeric semantics).

## Roadmap

- [ ] per-node manyBody strength, per-link distance (function → index arrays)
- [ ] `mf_step_into`: push-mode coordinate writeback (saving the JS-side pull loop)
- [ ] Web Worker wrapper (move large-graph layout off the main thread in the demo)
- [ ] Inline manyBody/collide traversal in wasm-gc (drop closure boxing; do after benching)
- [ ] Multi-instance forces (name → handle)

## License

MIT. The [d3-force](vendor/d3-force) (ISC) and [d3-quadtree](vendor/d3-quadtree) (ISC) sources vendored into this repo serve as the semantic reference — with thanks.

<div align="center">

[简体中文](README.zh-CN.md) · **English**

</div>
