import type {
  CenterOptions,
  CollideOptions,
  LinkOptions,
  ManyBodyOptions,
  MoonforceWasmExports,
  RadialOptions,
  XYOptions,
  Edge,
} from "./index";
import { ForceType } from "./types";

const NAN = Number.NaN;

/**
 * moonforce simulation 的 TS 句柄封装。
 *
 * 数据驻留 wasm 堆（SoA NodePool），热路径零跨界；
 * 坐标读取用拉取模式（positions() 循环调用 mf_node_x/y）。
 *
 * API 心智对齐 d3-force，但为句柄式调用：
 * 时间驱动（rAF/setTimeout 循环）由宿主负责。
 */
export class MoonforceSimulation {
  private readonly wasm: MoonforceWasmExports;
  private readonly handle: number;
  private readonly n: number;
  private disposed = false;

  constructor(wasm: MoonforceWasmExports, numNodes: number) {
    this.wasm = wasm;
    this.handle = wasm.mf_create(numNodes);
    this.n = numNodes;
  }

  private assertAlive(): void {
    if (this.disposed) {
      throw new Error("moonforce: simulation already disposed");
    }
  }

  /** 节点数 */
  get numNodes(): number {
    return this.n;
  }

  /** d3 sim.tick()：执行 iterations 次 tick */
  step(iterations = 1): this {
    this.assertAlive();
    this.wasm.mf_step(this.handle, iterations);
    return this;
  }

  /** 当前 alpha（d3 sim.alpha()） */
  get alpha(): number {
    this.assertAlive();
    return this.wasm.mf_alpha(this.handle);
  }

  set alpha(v: number) {
    this.assertAlive();
    this.wasm.mf_set_alpha(this.handle, v);
  }

  setAlphaMin(v: number): this {
    this.assertAlive();
    this.wasm.mf_set_alpha_min(this.handle, v);
    return this;
  }

  setAlphaDecay(v: number): this {
    this.assertAlive();
    this.wasm.mf_set_alpha_decay(this.handle, v);
    return this;
  }

  setAlphaTarget(v: number): this {
    this.assertAlive();
    this.wasm.mf_set_alpha_target(this.handle, v);
    return this;
  }

  /** 传入 friction（d3 语义：内部存 1 - friction），默认 0.4 */
  setVelocityDecay(friction: number): this {
    this.assertAlive();
    this.wasm.mf_set_velocity_decay(this.handle, friction);
    return this;
  }

  /** d3 sim.stop()（计算侧等价：alpha 归零） */
  stop(): this {
    this.assertAlive();
    this.wasm.mf_stop(this.handle);
    return this;
  }

  /** d3 sim.restart()（计算侧等价：重置 alpha） */
  restart(alpha = 1): this {
    this.assertAlive();
    this.wasm.mf_restart(this.handle, alpha);
    return this;
  }

  /** 读取第 i 个节点 x 坐标 */
  nodeX(i: number): number {
    return this.wasm.mf_node_x(this.handle, i);
  }

  nodeY(i: number): number {
    return this.wasm.mf_node_y(this.handle, i);
  }

  nodeVX(i: number): number {
    return this.wasm.mf_node_vx(this.handle, i);
  }

  nodeVY(i: number): number {
    return this.wasm.mf_node_vy(this.handle, i);
  }

  /**
   * 拉取全部坐标到复用的 Float64Array（交错 [x0,y0,x1,y1,...]）。
   * 不传则内部分配一次（每 tick 复用建议外部传入）。
   */
  positions(into?: Float64Array): Float64Array {
    this.assertAlive();
    const xy = into ?? new Float64Array(this.n * 2);
    if (xy.length < this.n * 2) {
      throw new Error(`moonforce: positions buffer too small`);
    }
    for (let i = 0; i < this.n; i++) {
      xy[2 * i] = this.wasm.mf_node_x(this.handle, i);
      xy[2 * i + 1] = this.wasm.mf_node_y(this.handle, i);
    }
    return xy;
  }

  /** 覆盖节点初始坐标（对齐 d3 preset x/y；JS 侧预置坐标保证与 d3 位一致） */
  setNodePos(i: number, x: number, y: number): this {
    this.assertAlive();
    this.wasm.mf_set_node_pos(this.handle, i, x, y);
    return this;
  }

  /** 固定节点（d3 node.fx/fy）；传 null 解除固定 */
  setFixed(i: number, fx: number | null, fy: number | null): this {
    this.assertAlive();
    this.wasm.mf_set_fixed(this.handle, i, fx ?? NAN, fy ?? NAN);
    return this;
  }

  /** d3 sim.find()：返回最近节点索引或 null */
  find(x: number, y: number, radius = Infinity): number | null {
    this.assertAlive();
    const idx = this.wasm.mf_find(this.handle, x, y, radius);
    return idx >= 0 ? idx : null;
  }

  // —— 力添加（顺序即 d3 插入序，影响轨迹）——

  addManyBodyForce(opts: ManyBodyOptions = {}): this {
    this.assertAlive();
    this.wasm.mf_add_manybody(
      this.handle,
      opts.strength ?? -30,
      opts.theta ?? 0.9,
      opts.distanceMin ?? 1,
      opts.distanceMax ?? -1, // <= 0 视为 ∞
    );
    return this;
  }

  /**
   * d3 forceLink：边为节点索引对。
   * JS 侧完成 id → index 映射（d3 forceLink().id() 的职责）。
   */
  addLinkForce(edges: ReadonlyArray<Edge>, opts: LinkOptions = {}): this {
    this.assertAlive();
    this.wasm.mf_add_link(this.handle, opts.distance ?? 30, opts.iterations ?? 1);
    for (const e of edges) {
      this.wasm.mf_link_edge(this.handle, e.source, e.target);
    }
    return this;
  }

  addCollideForce(opts: CollideOptions = {}): this {
    this.assertAlive();
    this.wasm.mf_add_collide(
      this.handle,
      opts.radius ?? 1,
      opts.strength ?? 1,
      opts.iterations ?? 1,
    );
    return this;
  }

  /** 设置单个节点碰撞半径（需已 addCollideForce） */
  setCollideRadius(i: number, r: number): this {
    this.assertAlive();
    this.wasm.mf_set_collide_radius(this.handle, i, r);
    return this;
  }

  addCenterForce(opts: CenterOptions = {}): this {
    this.assertAlive();
    this.wasm.mf_add_center(
      this.handle,
      opts.x ?? 0,
      opts.y ?? 0,
      opts.strength ?? 1,
    );
    return this;
  }

  addXForce(opts: XYOptions = {}): this {
    this.assertAlive();
    this.wasm.mf_add_x(this.handle, opts.target ?? 0, opts.strength ?? 0.1);
    return this;
  }

  addYForce(opts: XYOptions = {}): this {
    this.assertAlive();
    this.wasm.mf_add_y(this.handle, opts.target ?? 0, opts.strength ?? 0.1);
    return this;
  }

  addRadialForce(opts: RadialOptions = {}): this {
    this.assertAlive();
    this.wasm.mf_add_radial(
      this.handle,
      opts.cx ?? 0,
      opts.cy ?? 0,
      opts.radius ?? 100,
      opts.strength ?? 0.1,
    );
    return this;
  }

  /** 按类型移除力（每种力至多一个实例，以类型代名字） */
  removeForce(type: ForceType): this {
    this.assertAlive();
    this.wasm.mf_remove_force(this.handle, type);
    return this;
  }

  /** 释放 wasm 侧句柄 */
  dispose(): void {
    if (!this.disposed) {
      this.wasm.mf_free(this.handle);
      this.disposed = true;
    }
  }
}
