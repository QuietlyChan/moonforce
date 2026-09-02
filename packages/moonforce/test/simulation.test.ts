// 端到端冒烟测试：wasm 加载 + TS API + 与 d3-force 数值对齐
// 注意：测试导入 dist 产物（发布形态），先运行 bun scripts/build.mjs
import { describe, expect, test } from "bun:test";
import { forceSimulation, forceManyBody, forceLink, forceCollide } from "d3-force";
import { loadMoonforce, ForceType } from "../dist/index.js";

describe("moonforce wasm 端到端", () => {
  test("加载与 ABI 版本", async () => {
    const mf = await loadMoonforce();
    expect(mf.version).toBe(1);
  });

  test("基本生命周期：create/step/positions/free", async () => {
    const mf = await loadMoonforce();
    const sim = mf.createSimulation(5);
    expect(sim.numNodes).toBe(5);
    sim.addManyBodyForce({ strength: -30 });
    sim.step(10);
    const xy = sim.positions();
    expect(xy.length).toBe(10);
    for (const v of xy) {
      expect(Number.isFinite(v)).toBe(true);
    }
    sim.dispose();
    expect(() => sim.step(1)).toThrow();
  });

  test("与 d3-force 数值对齐：manyBody + link + collide（300 tick）", async () => {
    const n = 10;
    const px = [1.5, 20.3, -5.7, 8.2, -12.9, 30.0, -25.5, 14.2, -1.1, 6.6];
    const py = [2.1, -8.4, 15.6, -3.3, 7.7, -20.2, 11.3, -14.8, 25.0, -6.9];
    const edges = [
      [0, 1], [1, 2], [2, 3], [3, 4], [4, 5],
      [5, 6], [6, 7], [7, 8], [8, 9], [9, 0], [0, 5], [2, 7],
    ];

    // d3 侧
    const nodes = px.map((x, i) => ({ x, y: py[i] }));
    const d3sim = forceSimulation(nodes);
    d3sim.stop();
    d3sim
      .force("charge", forceManyBody().strength(-40))
      .force("link", forceLink(edges.map(([s, t]) => ({ source: s, target: t }))).distance(30))
      .force("collide", forceCollide(3));
    for (let t = 0; t < 300; t++) d3sim.tick();

    // moonforce 侧（相同力添加顺序）
    const mf = await loadMoonforce();
    const sim = mf.createSimulation(n);
    for (let i = 0; i < n; i++) sim.setNodePos(i, px[i], py[i]);
    sim.addManyBodyForce({ strength: -40 });
    sim.addLinkForce(
      edges.map(([source, target]) => ({ source, target })),
      { distance: 30 },
    );
    sim.addCollideForce({ radius: 3 });
    sim.step(300);

    const xy = sim.positions();
    let maxErr = 0;
    for (let i = 0; i < n; i++) {
      const ex = Math.abs(xy[2 * i] - nodes[i].x);
      const ey = Math.abs(xy[2 * i + 1] - nodes[i].y);
      maxErr = Math.max(maxErr, ex, ey);
    }
    expect(maxErr).toBeLessThan(1e-9);
  });

  test("find 与 setFixed", async () => {
    const mf = await loadMoonforce();
    const sim = mf.createSimulation(3);
    sim.setNodePos(0, 0, 0);
    sim.setNodePos(1, 10, 0);
    sim.setNodePos(2, 20, 0);
    expect(sim.find(10.5, 0, 2)).toBe(1);
    expect(sim.find(100, 0, 2)).toBe(null);
    sim.setFixed(1, 10, 0);
    sim.addManyBodyForce();
    sim.step(5);
    expect(sim.nodeX(1)).toBe(10); // 固定不动
    sim.setFixed(1, null, null);
    sim.step(5);
    expect(sim.nodeX(1)).not.toBe(10); // 解除后移动
  });

  test("removeForce 与重复创建", async () => {
    const mf = await loadMoonforce();
    const sim = mf.createSimulation(4);
    sim.addXForce({ target: 0 });
    sim.removeForce(ForceType.X);
    // 句柄复用
    const sim2 = mf.createSimulation(8);
    expect(sim2.numNodes).toBe(8);
    sim.dispose();
    sim2.dispose();
  });
});
