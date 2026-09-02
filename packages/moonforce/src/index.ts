import { loadWasm } from "./loader";
import { MoonforceSimulation } from "./simulation";
import type { Edge } from "./types";

export { ForceType } from "./types";
export type { Edge, MoonforceWasmExports } from "./types";
export { MoonforceSimulation };

export interface Moonforce {
  /** ABI 版本 */
  readonly version: number;
  /** 创建 n 节点的 simulation（phyllotaxis 初始化，对齐 d3 默认） */
  createSimulation(numNodes: number): MoonforceSimulation;
}

/**
 * 加载 moonforce wasm 模块（幂等，内部缓存）。
 *
 * ```ts
 * const mf = await loadMoonforce();
 * const sim = mf.createSimulation(100);
 * ```
 */
export async function loadMoonforce(): Promise<Moonforce> {
  const wasm = await loadWasm();
  return {
    get version() {
      return wasm.mf_version();
    },
    createSimulation(numNodes: number): MoonforceSimulation {
      return new MoonforceSimulation(wasm, numNodes);
    },
  };
}

/** 力配置选项（对齐 d3-force 各力默认值） */
export interface ManyBodyOptions {
  /** 默认 -30 */
  strength?: number;
  /** Barnes-Hut theta，默认 0.9 */
  theta?: number;
  /** 默认 1 */
  distanceMin?: number;
  /** 默认 ∞；传入 <= 0 视为 ∞ */
  distanceMax?: number;
}

export interface LinkOptions {
  /** 默认 30 */
  distance?: number;
  /** 默认 1 */
  iterations?: number;
}

export interface CollideOptions {
  /** 默认 1 */
  radius?: number;
  /** 默认 1 */
  strength?: number;
  /** 默认 1 */
  iterations?: number;
}

export interface CenterOptions {
  x?: number;
  y?: number;
  /** 默认 1 */
  strength?: number;
}

export interface XYOptions {
  target?: number;
  /** 默认 0.1 */
  strength?: number;
}

export interface RadialOptions {
  cx?: number;
  cy?: number;
  radius?: number;
  /** 默认 0.1 */
  strength?: number;
}

export { loadWasm };
export type { Edge };
