// demo 静态服务器（Bun）
// 用法：bun scripts/serve.mjs [port]
const port = Number(process.argv[2] ?? 8080);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
};

Bun.serve({
  port,
  async fetch(req) {
    const url = new URL(req.url);
    let path = decodeURIComponent(url.pathname);
    if (path === "/") path = "/demo/index.html";
    const file = Bun.file("." + path);
    if (await file.exists()) {
      const ext = path.slice(path.lastIndexOf("."));
      return new Response(file, {
        headers: { "content-type": MIME[ext] ?? "application/octet-stream" },
      });
    }
    // 目录请求回退到 index.html
    if (path.endsWith("/")) {
      const index = Bun.file("." + path + "index.html");
      if (await index.exists()) {
        return new Response(index, {
          headers: { "content-type": "text/html; charset=utf-8" },
        });
      }
    }
    return new Response("404: " + path, { status: 404 });
  },
});

console.log(`moonforce demo → http://localhost:${port}/demo/`);
console.log(`benchmark    → http://localhost:${port}/demo/bench.html`);
