import type { MoonforceWasmExports } from "./types";

/** wasm 二进制与加载器的相对路径解析（dist/moonforce.wasm） */
const WASM_URL = new URL("./moonforce.wasm", import.meta.url);

async function loadWasmBytes(): Promise<ArrayBuffer> {
  // Node / Bun（Bun 兼容 node:fs）
  if (typeof process !== "undefined" && process.versions?.node) {
    const { readFile } = await import("node:fs/promises");
    const { fileURLToPath } = await import("node:url");
    return await readFile(fileURLToPath(WASM_URL));
  }
  // 浏览器 / Worker / Deno
  const resp = await fetch(WASM_URL);
  if (!resp.ok) {
    throw new Error(`moonforce: failed to fetch wasm: ${resp.status}`);
  }
  return await resp.arrayBuffer();
}

let cached: MoonforceWasmExports | null = null;

/** 加载并实例化 wasm（Import 段为空，零宿主依赖） */
export async function loadWasm(): Promise<MoonforceWasmExports> {
  if (cached) return cached;
  const bytes = await loadWasmBytes();
  const { instance } = await WebAssembly.instantiate(bytes, {});
  cached = instance.exports as MoonforceWasmExports;
  return cached;
}
