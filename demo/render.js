// Canvas 渲染器：视图变换（缩放/平移）+ 批量绘制

export class View {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.scale = 1;
    this.ox = 0;
    this.oy = 0;
    this.resize();
  }

  resize() {
    const dpr = window.devicePixelRatio || 1;
    const r = this.canvas.getBoundingClientRect();
    this.canvas.width = r.width * dpr;
    this.canvas.height = r.height * dpr;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.w = r.width;
    this.h = r.height;
  }

  /** 屏幕坐标 → 世界坐标 */
  toWorld(sx, sy) {
    return [(sx - this.w / 2 - this.ox) / this.scale, (sy - this.h / 2 - this.oy) / this.scale];
  }

  /** 世界坐标 → 屏幕坐标 */
  toScreen(wx, wy) {
    return [wx * this.scale + this.w / 2 + this.ox, wy * this.scale + this.h / 2 + this.oy];
  }

  centerOn(wx, wy) {
    this.ox = -wx * this.scale;
    this.oy = -wy * this.scale;
  }
}

const GROUP_COLORS = [
  "#58a6ff", "#f78166", "#7ee787", "#d2a8ff", "#ffa657",
  "#79c0ff", "#ff7b72", "#56d364", "#e3b341", "#a5d6ff",
];

/**
 * 绘制一帧。
 * @param xy Float64Array 交错坐标 [x0,y0,x1,y1,...]
 * @param edges 边索引数组
 * @param nodeMeta 每节点 {deg, group}
 */
export function render(view, xy, edges, nodeMeta, n) {
  const { ctx, w, h, scale, ox, oy } = view;
  ctx.save();
  ctx.fillStyle = "#0d1117";
  ctx.fillRect(0, 0, w, h);

  // 变换：先平移到屏幕中心，再应用视图偏移和缩放
  ctx.translate(w / 2 + ox, h / 2 + oy);
  ctx.scale(scale, scale);

  // 边（单路径批量）
  ctx.strokeStyle = "rgba(139,148,158,0.25)";
  ctx.lineWidth = 1 / scale;
  ctx.beginPath();
  for (let e = 0; e < edges.length; e++) {
    const [s, t] = edges[e];
    ctx.moveTo(xy[2 * s], xy[2 * s + 1]);
    ctx.lineTo(xy[2 * t], xy[2 * t + 1]);
  }
  ctx.stroke();

  // 节点（半径与度数相关）
  const baseR = 3.5;
  for (let i = 0; i < n; i++) {
    const meta = nodeMeta[i];
    const r = baseR + Math.min(6, Math.sqrt(meta.deg) * 0.8);
    const color = GROUP_COLORS[meta.group % GROUP_COLORS.length];
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(xy[2 * i], xy[2 * i + 1], r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

/** 计算点集包围盒 */
export function bounds(xy, n) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (let i = 0; i < n; i++) {
    const x = xy[2 * i], y = xy[2 * i + 1];
    if (x < x0) x0 = x;
    if (x > x1) x1 = x;
    if (y < y0) y0 = y;
    if (y > y1) y1 = y;
  }
  return { x0, y0, x1, y1, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, w: x1 - x0, h: y1 - y0 };
}
