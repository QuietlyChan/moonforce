// 下载 d3-force / d3-quadtree 源码到 vendor/ 作为语义对齐参考（ISC 许可）
const files = {
  "d3-quadtree": ["quadtree.js", "add.js", "cover.js", "visit.js", "visitAfter.js", "x.js", "y.js", "extent.js"],
  "d3-force": ["simulation.js", "center.js", "collide.js", "link.js", "many.js", "x.js", "y.js", "radial.js", "lcg.js", "jiggle.js"],
};
for (const [repo, fs] of Object.entries(files)) {
  for (const f of fs) {
    const url = `https://raw.githubusercontent.com/d3/${repo}/main/src/${f}`;
    try {
      const r = await fetch(url);
      if (!r.ok) {
        console.log("MISS", url, r.status);
        continue;
      }
      const t = await r.text();
      const dir = `vendor/${repo}`;
      await Bun.write(`${dir}/${f}`, t);
      console.log("OK", repo, f, t.length);
    } catch (e) {
      console.log("ERR", url, String(e));
    }
  }
}
