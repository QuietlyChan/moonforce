// 合成图数据集生成器（demo 与 bench 共用）
// 确定性 PRNG（mulberry32），保证可复现

export function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Les-Misérables 风格的社区图：k 个社区 + 稀疏社区间边 */
export function communityGraph(nCommunities = 10, sizeMean = 8) {
  const rand = mulberry32(42);
  const nodes = [];
  const edges = [];
  let id = 0;
  for (let c = 0; c < nCommunities; c++) {
    const size = Math.max(3, Math.round(sizeMean * (0.5 + rand())));
    const start = id;
    for (let i = 0; i < size; i++) {
      nodes.push({ id, group: c, deg: 0 });
      id++;
    }
    // 社区内：链 + 随机弦（模拟主角配角结构）
    for (let i = start + 1; i < start + size; i++) {
      edges.push([i - 1, i]);
    }
    const extra = Math.round(size * 0.8);
    for (let k = 0; k < extra; k++) {
      const a = start + Math.floor(rand() * size);
      const b = start + Math.floor(rand() * size);
      if (a !== b) edges.push([a, b]);
    }
  }
  // 社区之间：枢纽连接
  const hubs = [];
  for (let c = 0; c < nCommunities; c++) {
    // 每社区第一个成员视为枢纽
    hubs.push(c * Math.round(sizeMean * 0.75) + Math.floor(rand() * 3));
  }
  for (let i = 1; i < hubs.length; i++) {
    edges.push([hubs[i - 1], hubs[i]]);
  }
  for (const [s, t] of edges) {
    if (s < nodes.length && t < nodes.length) {
      nodes[s].deg++;
      nodes[t].deg++;
    }
  }
  return { nodes, edges };
}

/** ER 随机图 */
export function erGraph(n, avgDeg = 4) {
  const rand = mulberry32(7);
  const p = avgDeg / n;
  const nodes = Array.from({ length: n }, (_, i) => ({ id: i, deg: 0 }));
  const edges = [];
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      if (rand() < p) edges.push([i, j]);
    }
  }
  for (const [s, t] of edges) {
    nodes[s].deg++;
    nodes[t].deg++;
  }
  return { nodes, edges };
}

/** BA 无标度图（优先连接） */
export function baGraph(n, m = 2) {
  const rand = mulberry32(11);
  const nodes = Array.from({ length: n }, (_, i) => ({ id: i, deg: 0 }));
  const edges = [];
  const repeated = [];
  // 种子：完全图 m+1
  for (let i = 0; i <= m; i++) {
    for (let j = i + 1; j <= m; j++) {
      edges.push([i, j]);
      repeated.push(i, j);
    }
  }
  for (let v = m + 1; v < n; v++) {
    const targets = new Set();
    while (targets.size < m) {
      const u = repeated[Math.floor(rand() * repeated.length)];
      if (u !== v) targets.add(u);
    }
    for (const u of targets) {
      edges.push([v, u]);
      repeated.push(v, u);
    }
  }
  for (const [s, t] of edges) {
    nodes[s].deg++;
    nodes[t].deg++;
  }
  return { nodes, edges };
}

/** 龙虾树（每节点 1-3 个子节点，两层枝干） */
export function lobsterGraph(n) {
  const rand = mulberry32(13);
  const nodes = Array.from({ length: n }, (_, i) => ({ id: i, deg: 0 }));
  const edges = [];
  let next = 1;
  let parent = 0;
  const spine = [0];
  while (next < n) {
    // 脊柱延伸
    const children = 1 + Math.floor(rand() * 2);
    for (let k = 0; k < children && next < n; k++) {
      edges.push([parent, next]);
      spine.push(next);
      next++;
    }
    // 叶子
    const leaves = Math.floor(rand() * 4);
    for (let k = 0; k < leaves && next < n; k++) {
      edges.push([spine[spine.length - 1], next]);
      next++;
    }
    parent = spine[Math.floor(rand() * spine.length)];
  }
  for (const [s, t] of edges) {
    nodes[s].deg++;
    nodes[t].deg++;
  }
  return { nodes, edges };
}

/** 网格图 */
export function gridGraph(w, h) {
  const n = w * h;
  const nodes = Array.from({ length: n }, (_, i) => ({ id: i, deg: 0 }));
  const edges = [];
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      if (x + 1 < w) edges.push([i, i + 1]);
      if (y + 1 < h) edges.push([i, i + w]);
    }
  }
  for (const [s, t] of edges) {
    nodes[s].deg++;
    nodes[t].deg++;
  }
  return { nodes, edges };
}

export const DATASETS = {
  miserables: { label: "Les Misérables 风格 (社区图 ~80)", make: () => communityGraph(10, 8) },
  er200: { label: "ER 随机图 (200)", make: () => erGraph(200, 4) },
  ba1000: { label: "BA 无标度 (1000)", make: () => baGraph(1000, 2) },
  lobster2000: { label: "龙虾树 (2000)", make: () => lobsterGraph(2000) },
  grid2500: { label: "网格 (50×50)", make: () => gridGraph(50, 50) },
  ba5000: { label: "BA 无标度 (5000)", make: () => baGraph(5000, 2) },
};
