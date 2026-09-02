// moonforce × d3-force 基准：相同初始条件、相同力配置、同步 tick
import { forceSimulation, forceManyBody, forceLink } from "d3-force";
import { loadMoonforce } from "../packages/moonforce/dist/index.js";
import { baGraph, erGraph, mulberry32 } from "./datasets.js";

const WARMUP = 50;
const TICKS = 300;
const ROUNDS = 5;

const SIZES = [
  { key: "miserables", label: "社区图", n: 80, make: (n) => baGraph(n, 2) },
  { key: "er100", label: "ER", n: 100, make: (n) => erGraph(n, 4) },
  { key: "ba500", label: "BA", n: 500, make: (n) => baGraph(n, 2) },
  { key: "er1000", label: "ER", n: 1000, make: (n) => erGraph(n, 4) },
  { key: "ba2000", label: "BA", n: 2000, make: (n) => baGraph(n, 2) },
  { key: "ba5000", label: "BA", n: 5000, make: (n) => baGraph(n, 2) },
  { key: "ba10000", label: "BA", n: 10000, make: (n) => baGraph(n, 2) },
];

/** 初始坐标（两边完全一致；绕开 cos/sin 实现差异） */
function initialPositions(n) {
  const rand = mulberry32(2026);
  const px = new Float64Array(n);
  const py = new Float64Array(n);
  const R = Math.sqrt(n) * 6;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + rand() * 0.5;
    const r = R * (0.5 + rand() * 0.5);
    px[i] = Math.cos(a) * r;
    py[i] = Math.sin(a) * r;
  }
  return { px, py };
}

function stats(times) {
  const sorted = [...times].sort((a, b) => a - b);
  const n = sorted.length;
  const mean = sorted.reduce((s, v) => s + v, 0) / n;
  const median = sorted[Math.floor(n / 2)];
  const p95 = sorted[Math.min(n - 1, Math.floor(n * 0.95))];
  return { mean, median, p95 };
}

/** 每配置跑 5 轮取中位轮的完整统计 */
async function benchConfig(mf, cfg) {
  const { n } = cfg;
  const { nodes, edges } = cfg.make(n);
  const { px, py } = initialPositions(n);
  const edgeObjs = edges.map(([source, target]) => ({ source, target }));

  const result = {
    label: `${cfg.label} ${n}`,
    nodes: n,
    edges: edges.length,
    d3: { compute: null, full: null },
    moonforce: { compute: null, full: null },
  };

  function runD3(withReadout) {
    const nodesD3 = Array.from({ length: n }, (_, i) => ({ x: px[i], y: py[i] }));
    const sim = forceSimulation(nodesD3);
    sim.stop();
    sim
      .force("charge", forceManyBody().strength(-30))
      .force("link", forceLink(edgeObjs).distance(30));
    // warmup
    for (let t = 0; t < WARMUP; t++) sim.tick();
    const times = [];
    const sink = new Float64Array(n * 2);
    for (let t = 0; t < TICKS; t++) {
      const t0 = performance.now();
      sim.tick();
      if (withReadout) {
        for (let i = 0; i < n; i++) {
          sink[2 * i] = nodesD3[i].x;
          sink[2 * i + 1] = nodesD3[i].y;
        }
      }
      const t1 = performance.now();
      times.push(t1 - t0);
    }
    // 防止死代码消除（虽然 JS 引擎一般不会）
    if (sink[0] === 12345.678) console.log(sink[1]);
    return stats(times);
  }

  function runMoonforce(withReadout) {
    const sim = mf.createSimulation(n);
    for (let i = 0; i < n; i++) sim.setNodePos(i, px[i], py[i]);
    sim.addManyBodyForce({ strength: -30 });
    sim.addLinkForce(edgeObjs, { distance: 30 });
    // warmup
    sim.step(WARMUP);
    const times = [];
    const xy = new Float64Array(n * 2);
    for (let t = 0; t < TICKS; t++) {
      const t0 = performance.now();
      sim.step(1);
      if (withReadout) {
        sim.positions(xy);
      }
      const t1 = performance.now();
      times.push(t1 - t0);
    }
    sim.dispose();
    return stats(times);
  }

  // 5 轮取中位（按 median 排序取中间轮）
  function medianOfRuns(fn, withReadout) {
    const runs = [];
    for (let r = 0; r < ROUNDS; r++) {
      runs.push(fn(withReadout));
    }
    runs.sort((a, b) => a.median - b.median);
    return runs[Math.floor(ROUNDS / 2)];
  }

  result.d3.compute = medianOfRuns(runD3, false);
  result.d3.full = medianOfRuns(runD3, true);
  result.moonforce.compute = medianOfRuns(runMoonforce, false);
  result.moonforce.full = medianOfRuns(runMoonforce, true);
  return result;
}

const fmt = (s) => (s == null ? "–" : s.median.toFixed(3));
const speedup = (a, b) => (a == null || b == null || b.median <= 0 ? "–" : (a.median / b.median).toFixed(2) + "×");

let lastResults = null;

async function runBench() {
  const err = document.getElementById("err");
  err.style.display = "none";
  document.getElementById("running").style.display = "inline";
  await new Promise((r) => setTimeout(r, 30)); // 让 UI 先渲染
  try {
    const mf = await loadMoonforce();
    const tbody = document.querySelector("#result tbody");
    tbody.innerHTML = "";
    const results = [];
    for (const cfg of SIZES) {
      const res = await benchConfig(mf, cfg);
      results.push(res);
      const tr = document.createElement("tr");
      const cells = [
        res.label,
        `${res.nodes} / ${res.edges}`,
        fmt(res.d3.compute), fmt(res.moonforce.compute),
        speedup(res.d3.compute, res.moonforce.compute),
        fmt(res.d3.full), fmt(res.moonforce.full),
        speedup(res.d3.full, res.moonforce.full),
      ];
      for (const c of cells) {
        const td = document.createElement("td");
        td.textContent = c;
        tr.appendChild(td);
      }
      // 加速比列高亮
      tr.children[4].classList.add("speedup");
      tr.children[7].classList.add("speedup");
      tbody.appendChild(tr);
      // 让出主线程：逐行渲染可见，避免整段基准冻结 UI
      await new Promise((r) => setTimeout(r, 0));
    }
    lastResults = {
      meta: {
        userAgent: navigator.userAgent,
        date: new Date().toISOString(),
        warmup: WARMUP, ticks: TICKS, rounds: ROUNDS,
        forces: "manyBody(-30) + link(30)",
      },
      results,
    };
  } catch (e) {
    err.textContent = `基准运行失败: ${e.message}`;
    err.style.display = "block";
  } finally {
    document.getElementById("running").style.display = "none";
  }
}

document.getElementById("run").addEventListener("click", runBench);
document.getElementById("export").addEventListener("click", () => {
  if (!lastResults) return;
  const blob = new Blob([JSON.stringify(lastResults, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "moonforce-bench.json";
  a.click();
});
