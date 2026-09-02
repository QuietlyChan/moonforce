// 构建 npm 包：wasm 复制 + TS 打包 + 类型声明
// 前置：moon build --target wasm-gc --release
import { $ } from "bun";

const WASM_SRC = "_build/wasm-gc/release/build/src/ffi/ffi.wasm";
const DIST = "packages/moonforce/dist";

await $`mkdir -p ${DIST}`;
await $`cp ${WASM_SRC} ${DIST}/moonforce.wasm`;

// 打包 ESM（bun build 产物为标准 ES 模块）
await Bun.build({
  entrypoints: ["packages/moonforce/src/index.ts"],
  outdir: DIST,
  target: "bun",
  format: "esm",
  naming: { entry: "index.[ext]" },
  external: [],
});

// 复制手写的类型声明
await $`cp packages/moonforce/src/index.d.ts ${DIST}/index.d.ts`;

const wasmSize = (await Bun.file(`${DIST}/moonforce.wasm`).arrayBuffer()).byteLength;
const jsSize = (await Bun.file(`${DIST}/index.js`).arrayBuffer()).byteLength;
console.log(`✓ dist/moonforce.wasm: ${(wasmSize / 1024).toFixed(1)} KB`);
console.log(`✓ dist/index.js: ${(jsSize / 1024).toFixed(1)} KB`);
console.log(`✓ dist/index.d.ts`);
