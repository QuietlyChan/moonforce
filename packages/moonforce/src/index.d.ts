/** 力类型（removeForce 参数） */
export declare enum ForceType {
  Center = 0,
  ManyBody = 1,
  Link = 2,
  Collide = 3,
  X = 4,
  Y = 5,
  Radial = 6,
}

/** 边（节点索引对） */
export declare interface Edge {
  source: number;
  target: number;
}

export declare interface ManyBodyOptions {
  strength?: number;
  theta?: number;
  distanceMin?: number;
  distanceMax?: number;
}

export declare interface LinkOptions {
  distance?: number;
  iterations?: number;
}

export declare interface CollideOptions {
  radius?: number;
  strength?: number;
  iterations?: number;
}

export declare interface CenterOptions {
  x?: number;
  y?: number;
  strength?: number;
}

export declare interface XYOptions {
  target?: number;
  strength?: number;
}

export declare interface RadialOptions {
  cx?: number;
  cy?: number;
  radius?: number;
  strength?: number;
}

export declare interface Moonforce {
  readonly version: number;
  createSimulation(numNodes: number): MoonforceSimulation;
}

/** 加载 moonforce wasm 模块（幂等，内部缓存） */
export declare function loadMoonforce(): Promise<Moonforce>;

export declare function loadWasm(): Promise<MoonforceWasmExports>;

export declare class MoonforceSimulation {
  private constructor();
  get numNodes(): number;
  step(iterations?: number): this;
  get alpha(): number;
  set alpha(v: number);
  setAlphaMin(v: number): this;
  setAlphaDecay(v: number): this;
  setAlphaTarget(v: number): this;
  setVelocityDecay(friction: number): this;
  stop(): this;
  restart(alpha?: number): this;
  nodeX(i: number): number;
  nodeY(i: number): number;
  nodeVX(i: number): number;
  nodeVY(i: number): number;
  positions(into?: Float64Array): Float64Array;
  setNodePos(i: number, x: number, y: number): this;
  setFixed(i: number, fx: number | null, fy: number | null): this;
  find(x: number, y: number, radius?: number): number | null;
  addManyBodyForce(opts?: ManyBodyOptions): this;
  addLinkForce(edges: ReadonlyArray<Edge>, opts?: LinkOptions): this;
  addCollideForce(opts?: CollideOptions): this;
  setCollideRadius(i: number, r: number): this;
  addCenterForce(opts?: CenterOptions): this;
  addXForce(opts?: XYOptions): this;
  addYForce(opts?: XYOptions): this;
  addRadialForce(opts?: RadialOptions): this;
  removeForce(type: ForceType): this;
  dispose(): void;
}

/** wasm 导出的原始 ABI */
export declare interface MoonforceWasmExports {
  mf_version(): number;
  mf_create(numNodes: number): number;
  mf_free(handle: number): void;
  mf_num_nodes(handle: number): number;
  mf_step(handle: number, iterations: number): void;
  mf_alpha(handle: number): number;
  mf_stop(handle: number): void;
  mf_restart(handle: number, alpha: number): void;
  mf_set_alpha(handle: number, v: number): void;
  mf_set_alpha_min(handle: number, v: number): void;
  mf_set_alpha_decay(handle: number, v: number): void;
  mf_set_alpha_target(handle: number, v: number): void;
  mf_set_velocity_decay(handle: number, friction: number): void;
  mf_node_x(handle: number, i: number): number;
  mf_node_y(handle: number, i: number): number;
  mf_node_vx(handle: number, i: number): number;
  mf_node_vy(handle: number, i: number): number;
  mf_set_node_pos(handle: number, i: number, x: number, y: number): void;
  mf_set_fixed(handle: number, i: number, fx: number, fy: number): void;
  mf_find(handle: number, x: number, y: number, radius: number): number;
  mf_remove_force(handle: number, kind: number): void;
  mf_add_center(handle: number, x: number, y: number, strength: number): void;
  mf_add_manybody(
    handle: number,
    strength: number,
    theta: number,
    distanceMin: number,
    distanceMax: number,
  ): void;
  mf_add_link(handle: number, distance: number, iterations: number): void;
  mf_link_edge(handle: number, source: number, target: number): void;
  mf_add_collide(
    handle: number,
    radius: number,
    strength: number,
    iterations: number,
  ): void;
  mf_set_collide_radius(handle: number, i: number, r: number): void;
  mf_add_x(handle: number, target: number, strength: number): void;
  mf_add_y(handle: number, target: number, strength: number): void;
  mf_add_radial(
    handle: number,
    cx: number,
    cy: number,
    radius: number,
    strength: number,
  ): void;
}
