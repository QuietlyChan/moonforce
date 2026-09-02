// moonforce demo 主逻辑：wasm 布局 + rAF 驱动 + 交互
import { loadMoonforce } from "../packages/moonforce/dist/index.js";
import { DATASETS } from "./datasets.js";
import { View, render, bounds } from "./render.js";

const $ = (id) => document.getElementById(id);

const state = {
  sim: null,
  mf: null,
  dataset: null,
  edges: [],
  nodeMeta: [],
  n: 0,
  xy: null,
  running: false,
  tickMs: 0,
  fps: 0,
  frames: 0,
  fpsT0: 0,
};

// —— UI 绑定 ——
const sel = $("dataset");
for (const [key, d] of Object.entries(DATASETS)) {
  const opt = document.createElement("option");
  opt.value = key;
  opt.textContent = d.label;
  sel.appendChild(opt);
}
sel.value = "miserables";

const params = { charge: -60, distance: 30, collide: 3, friction: 0.4 };
function bindSlider(id, valId, transform, apply) {
  const el = $(id);
  el.addEventListener("input", () => {
    const raw = +el.value;
    $(valId).textContent = transform(raw);
    apply(raw);
    if (state.sim) reheat();
  });
}
bindSlider("charge", "chargeVal", (v) => String(v), (v) => { params.charge = v; });
bindSlider("dist", "distVal", (v) => String(v), (v) => { params.distance = v; });
bindSlider("collide", "collideVal", (v) => String(v), (v) => { params.collide = v; });
bindSlider("friction", "frictionVal", (v) => (v / 100).toFixed(2), (v) => { params.friction = v / 100; });
$("reheat").addEventListener("click", () => rebuild());

// —— 构建 simulation ——
async function rebuild() {
  const key = sel.value;
  const { nodes, edges } = DATASETS[key].make();
  state.dataset = key;
  state.edges = edges;
  state.nodeMeta = nodes.map((nd) => ({ deg: nd.deg, group: nd.group ?? 0 }));
  state.n = nodes.length;

  const sim = state.mf.createSimulation(state.n);
  state.sim = sim;
  sim.setVelocityDecay(params.friction);

  // JS 侧预置初始坐标（圆形，与 d3 preset 等价；保证跨引擎一致）
  const R = Math.sqrt(state.n) * 6;
  for (let i = 0; i < state.n; i++) {
    const a = (i / state.n) * Math.PI * 2;
    sim.setNodePos(i, Math.cos(a) * R, Math.sin(a) * R);
  }

  // 力添加顺序 = d3 惯例：charge → link → collide → center
  sim.addManyBodyForce({ strength: params.charge });
  sim.addLinkForce(
    edges.map(([source, target]) => ({ source, target })),
    { distance: params.distance },
  );
  if (params.collide > 0) {
    sim.addCollideForce({ radius: params.collide, strength: 0.7 });
  }
  sim.addCenterForce({ x: 0, y: 0 });

  state.xy = new Float64Array(state.n * 2);
  $("stNodes").textContent = state.n;
  $("stEdges").textContent = edges.length;
  view.scale = 1;
  view.ox = 0;
  view.oy = 0;
  autoFit = true;
  running(true);
}

function running(v) {
  state.running = v;
  $("stState").textContent = v ? "运行中" : "收敛";
}

function reheat() {
  // 参数变化时重建（保持力参数简单一致）
  rebuild();
}

// —— 视图与交互 ——
const view = new View($("cv"));
let autoFit = true; // 布局期间持续自适应视野；用户交互（拖拽/缩放）后停止

window.addEventListener("resize", () => {
  view.resize();
});

let drag = null; // {kind: 'node'|'pan', idx, lastX, lastY}
view.canvas.addEventListener("mousedown", (e) => {
  autoFit = false;
  const [wx, wy] = view.toWorld(e.offsetX, e.offsetY);
  const hit = state.sim?.find(wx, wy, 15 / view.scale);
  if (hit != null && state.sim) {
    drag = { kind: "node", idx: hit };
    state.sim.setAlphaTarget(0.3); // d3 拖拽惯例：保持热度
    state.sim.setFixed(hit, wx, wy);
    running(true);
  } else {
    drag = { kind: "pan", lastX: e.offsetX, lastY: e.offsetY };
  }
  view.canvas.classList.add("dragging");
});
window.addEventListener("mousemove", (e) => {
  if (!drag || !state.sim) return;
  const rect = view.canvas.getBoundingClientRect();
  const sx = e.clientX - rect.left;
  const sy = e.clientY - rect.top;
  if (drag.kind === "node") {
    const [wx, wy] = view.toWorld(sx, sy);
    state.sim.setFixed(drag.idx, wx, wy);
    running(true);
  } else {
    view.ox += sx - drag.lastX;
    view.oy += sy - drag.lastY;
    drag.lastX = sx;
    drag.lastY = sy;
  }
});
window.addEventListener("mouseup", () => {
  if (drag?.kind === "node" && state.sim) {
    state.sim.setFixed(drag.idx, null, null);
    state.sim.setAlphaTarget(0); // 冷却
  }
  drag = null;
  view.canvas.classList.remove("dragging");
});
view.canvas.addEventListener("wheel", (e) => {
  e.preventDefault();
  autoFit = false;
  const factor = Math.exp(-e.deltaY * 0.001);
  const [wx, wy] = view.toWorld(e.offsetX, e.offsetY);
  view.scale = Math.min(20, Math.max(0.05, view.scale * factor));
  // 缩放围绕指针
  view.centerOn(wx, wy);
}, { passive: false });

sel.addEventListener("change", rebuild);

// —— 主循环 ——
function frame() {
  requestAnimationFrame(frame);
  if (!state.sim) return;
  if (state.running) {
    const t0 = performance.now();
    state.sim.step(1);
    state.sim.positions(state.xy);
    const t1 = performance.now();
    state.tickMs = state.tickMs * 0.9 + (t1 - t0) * 0.1; // 平滑
    if (autoFit) {
      // 布局期间持续跟随视野（布局会先膨胀后稳定，直接锁定首帧会溢出）
      const b = bounds(state.xy, state.n);
      if (b.w > 0 && b.h > 0) {
        const s = Math.min(view.w / (b.w + 80), view.h / (b.h + 80));
        view.scale = Math.max(0.05, Math.min(3, s));
        view.ox = 0;
        view.oy = 0;
      }
    }
    if (state.sim.alpha < 0.001 && drag === null) {
      running(false);
    }
  }
  render(view, state.xy, state.edges, state.nodeMeta, state.n);
  // FPS 统计
  state.frames++;
  const now = performance.now();
  if (now - state.fpsT0 > 500) {
    state.fps = Math.round((state.frames * 1000) / (now - state.fpsT0));
    state.frames = 0;
    state.fpsT0 = now;
    $("stFps").textContent = state.fps;
    $("stTick").textContent = state.tickMs.toFixed(2);
    $("stAlpha").textContent = state.sim.alpha.toFixed(4);
  }
}

// —— 启动 ——
(async () => {
  state.mf = await loadMoonforce();
  state.fpsT0 = performance.now();
  rebuild();
  requestAnimationFrame(frame);
})();
