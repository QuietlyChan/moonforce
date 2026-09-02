// 用 Bun 验证 wasm-gc 产物：
// 1. Import 段必须为空（可移植性承诺，风险 R3）
// 2. 列出全部导出（核对 #export_name）
const path = process.argv[2];
if (!path) {
  console.error("usage: bun scripts/check-wasm.mjs <wasm-file>");
  process.exit(2);
}
const bytes = await Bun.file(path).arrayBuffer();
const mod = await WebAssembly.compile(bytes);
const imports = WebAssembly.Module.imports(mod);
const exports = WebAssembly.Module.exports(mod);
console.log(`file: ${path} (${bytes.byteLength} bytes)`);
console.log("imports:", imports.length === 0 ? "(empty)" : "");
for (const im of imports) {
  console.log(`  import ${im.module} ${im.name} (${im.kind})`);
}
console.log("exports:");
for (const ex of exports) {
  console.log(`  ${ex.kind} ${ex.name}`);
}
if (imports.length !== 0) {
  console.error("FAIL: import section is not empty");
  process.exit(1);
}
console.log("OK: import section empty");
