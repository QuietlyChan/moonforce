// golden.mjs — 用 d3-force@3 固定种子生成数值对齐 fixture（MoonBit 测试代码）
//
// 方法（对齐 M2/M3 验收标准）：
// - 两边使用完全一致的显式初始坐标（绕开 cos/sin 实现差异，见计划 R5）
// - d3 默认 lcg（s=1）与 MoonBit Lcg::new() 位一致
// - 手动同步 tick（绕开 d3-timer），300 tick，每 50 tick 快照全量坐标
// - 生成的 MoonBit 测试断言绝对误差 < 1e-9
import { forceSimulation, forceManyBody, forceCenter, forceX, forceY, forceRadial, forceLink, forceCollide } from "d3-force";

// ---------- 配置矩阵 ----------
// 每项：name, n, 初始坐标, force 构造函数（返回 d3 simulation 配置）,
// 以及对应的 MoonBit 侧代码生成器
const cases = [];

function makeNodes(px, py) {
  return px.map((x, i) => ({ x, y: py[i] }));
}

// 1. manyBody only（5 节点）
cases.push({
  name: "manybody_5",
  px: [1.5, 20.3, -5.7, 8.2, -12.9],
  py: [2.1, -8.4, 15.6, -3.3, 7.7],
  setupD3: (sim) => sim.force("charge", forceManyBody().strength(-30)),
  setupMb: (n) => `  ignore(sim.add_force(@forces.Force::ManyBody(@forces.ManyBodyForce::new(${n}, -30.0))))`,
});

// 2. manyBody + center（10 节点）
cases.push({
  name: "manybody_center_10",
  px: [1.5, 20.3, -5.7, 8.2, -12.9, 30.0, -25.5, 14.2, -1.1, 6.6],
  py: [2.1, -8.4, 15.6, -3.3, 7.7, -20.2, 11.3, -14.8, 25.0, -6.9],
  setupD3: (sim) =>
    sim
      .force("charge", forceManyBody().strength(-30))
      .force("center", forceCenter(0, 0)),
  setupMb: (n) =>
    `  ignore(sim.add_force(@forces.Force::ManyBody(@forces.ManyBodyForce::new(${n}, -30.0))))\n` +
    `  ignore(sim.add_force(@forces.Force::Center(@forces.CenterForce::new(0.0, 0.0, 1.0))))`,
});

// 3. forceX + forceY（6 节点）
cases.push({
  name: "xy_6",
  px: [5.0, 12.0, -8.0, 3.0, -15.0, 9.0],
  py: [4.0, -11.0, 7.0, -2.0, 13.0, -9.0],
  setupD3: (sim) =>
    sim.force("x", forceX(0).strength(0.1)).force("y", forceY(0).strength(0.1)),
  setupMb: (n) =>
    `  ignore(sim.add_force(@forces.Force::PosX(@forces.XForce::new(${n}, 0.0, 0.1))))\n` +
    `  ignore(sim.add_force(@forces.Force::PosY(@forces.YForce::new(${n}, 0.0, 0.1))))`,
});

// 4. radial（8 节点）
cases.push({
  name: "radial_8",
  px: [10.0, -10.0, 0.0, 5.0, -5.0, 20.0, -20.0, 0.0],
  py: [0.0, 0.0, 10.0, -5.0, 5.0, 20.0, -20.0, -10.0],
  setupD3: (sim) => sim.force("radial", forceRadial(50).strength(0.1)),
  setupMb: (n) =>
    `  ignore(sim.add_force(@forces.Force::Radial(@forces.RadialForce::new(${n}, 0.0, 0.0, 50.0, 0.1))))`,
});

// 5. 含重合初始点（jiggle / lcg 消耗对齐关键用例）
cases.push({
  name: "manybody_coincident_4",
  px: [3.3, 3.3, -7.7, 12.1], // 前两个点完全重合
  py: [4.4, 4.4, -6.6, 9.9],
  setupD3: (sim) => sim.force("charge", forceManyBody().strength(-30)),
  setupMb: (n) => `  ignore(sim.add_force(@forces.Force::ManyBody(@forces.ManyBodyForce::new(${n}, -30.0))))`,
});

// 6. link（链图）+ manyBody
const chainEdges = [
  [0, 1],
  [1, 2],
  [2, 3],
  [3, 4],
  [4, 5],
  [5, 0],
];
cases.push({
  name: "link_manybody_6",
  px: [1.5, 20.3, -5.7, 8.2, -12.9, 30.0],
  py: [2.1, -8.4, 15.6, -3.3, 7.7, -20.2],
  setupD3: (sim) =>
    sim
      .force("charge", forceManyBody().strength(-60))
      .force("link", forceLink(chainEdges.map(([s, t]) => ({ source: s, target: t }))).distance(25)),
  setupMb: (n) => {
    let s = `  ignore(sim.add_force(@forces.Force::ManyBody(@forces.ManyBodyForce::new(${n}, -60.0))))\n`;
    s += `  let lf = @forces.LinkForce::create(${n}, 25.0, 1)\n`;
    for (const [a, b] of chainEdges) {
      s += `  lf.add_edge(${a}, ${b})\n`;
    }
    s += `  ignore(sim.add_force(@forces.Force::Link(lf)))`;
    return s;
  },
});

// 7. collide（含重合初始点对，触发 jiggle）
cases.push({
  name: "collide_overlap_8",
  px: [1.0, 1.0, 15.0, 15.0, -12.0, 25.0, -25.0, 8.0], // (0,1) 重合 (2,3) 重合
  py: [2.0, 2.0, -10.0, -10.0, 5.0, -18.0, 12.0, -5.0],
  setupD3: (sim) =>
    sim.force("collide", forceCollide(4).strength(0.7).iterations(2)),
  setupMb: (n) =>
    `  ignore(sim.add_force(@forces.Force::Collide(@forces.CollideForce::create(${n}, 4.0, 0.7, 2))))`,
});

// 8. 全家桶：link + collide + center + manyBody
cases.push({
  name: "combo_10",
  px: [1.5, 20.3, -5.7, 8.2, -12.9, 30.0, -25.5, 14.2, -1.1, 6.6],
  py: [2.1, -8.4, 15.6, -3.3, 7.7, -20.2, 11.3, -14.8, 25.0, -6.9],
  setupD3: (sim) =>
    sim
      .force("charge", forceManyBody().strength(-40))
      .force(
        "link",
        forceLink(
          [
            [0, 1],
            [1, 2],
            [2, 3],
            [3, 4],
            [4, 5],
            [5, 6],
            [6, 7],
            [7, 8],
            [8, 9],
            [9, 0],
            [0, 5],
            [2, 7],
          ].map(([s, t]) => ({ source: s, target: t })),
        ).distance(30),
      )
      .force("collide", forceCollide(3))
      .force("center", forceCenter()),
  setupMb: (n) => {
    // 顺序必须与 d3 侧一致（charge → link → collide → center）
    let s = `  ignore(sim.add_force(@forces.Force::ManyBody(@forces.ManyBodyForce::new(${n}, -40.0))))\n`;
    s += `  let lf = @forces.LinkForce::create(${n}, 30.0, 1)\n`;
    for (const [a, b] of [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 4],
      [4, 5],
      [5, 6],
      [6, 7],
      [7, 8],
      [8, 9],
      [9, 0],
      [0, 5],
      [2, 7],
    ]) {
      s += `  lf.add_edge(${a}, ${b})\n`;
    }
    s += `  ignore(sim.add_force(@forces.Force::Link(lf)))\n`;
    s += `  ignore(sim.add_force(@forces.Force::Collide(@forces.CollideForce::create(${n}, 3.0, 1.0, 1))))\n`;
    s += `  ignore(sim.add_force(@forces.Force::Center(@forces.CenterForce::new(0.0, 0.0, 1.0))))`;
    return s;
  },
});

// ---------- 运行 d3 并生成 MoonBit 测试 ----------
const TICKS = 300;
const SNAPSHOT_EVERY = 50;

function fmt(v) {
  // JS 最短往返表示 → MoonBit 解析同值
  return String(v);
}

let out = `// 本文件由 scripts/golden.mjs 自动生成（d3-force@3.0.0 固定种子）。
// 断言绝对误差 < 1e-9；重新生成：bun scripts/golden.mjs
`;

for (const c of cases) {
  const n = c.px.length;
  const nodes = makeNodes(c.px, c.py);
  const sim = forceSimulation(nodes);
  sim.stop(); // 手动驱动，绕开 d3-timer
  c.setupD3(sim);
  const snapshots = [];
  for (let t = 1; t <= TICKS; t++) {
    sim.tick();
    if (t % SNAPSHOT_EVERY === 0) {
      snapshots.push({ t, xs: nodes.map((d) => d.x), ys: nodes.map((d) => d.y), alpha: sim.alpha() });
    }
  }
  out += `\ntest "golden: ${c.name} (${TICKS} tick, 每 ${SNAPSHOT_EVERY} tick 快照)" {\n`;
  out += `  let sim = @simulation.Simulation::new(${n})\n`;
  for (let i = 0; i < n; i++) {
    out += `  sim.nodes.xs[${i}] = ${fmt(c.px[i])}\n`;
    out += `  sim.nodes.ys[${i}] = ${fmt(c.py[i])}\n`;
  }
  out += `${c.setupMb(n)}\n`;
  for (const s of snapshots) {
    out += `  ignore(sim.tick(${SNAPSHOT_EVERY}))\n`;
    for (let i = 0; i < n; i++) {
      out += `  assert_true((sim.nodes.xs[${i}] - ${fmt(s.xs[i])}).abs() < 1.0e-9)\n`;
      out += `  assert_true((sim.nodes.ys[${i}] - ${fmt(s.ys[i])}).abs() < 1.0e-9)\n`;
    }
    out += `  assert_true((sim.alpha - ${fmt(s.alpha)}).abs() < 1.0e-12)\n`;
  }
  out += `}\n`;
}

await Bun.write("src/simulation/golden_test.mbt", out);
console.log(`生成 ${cases.length} 个 golden 测试 → src/simulation/golden_test.mbt`);
