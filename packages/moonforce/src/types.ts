/** wasm 导出的原始 ABI（i32 句柄 + 数值参数） */
export interface MoonforceWasmExports {
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

/** 力类型（removeForce 参数，与 wasm ABI 的 kind 一致） */
export enum ForceType {
  Center = 0,
  ManyBody = 1,
  Link = 2,
  Collide = 3,
  X = 4,
  Y = 5,
  Radial = 6,
}

/** 边（节点索引对） */
export interface Edge {
  source: number;
  target: number;
}
