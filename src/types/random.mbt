///|
/// 与 d3-force lcg.js 位精确一致的线性同余发生器。
///
/// s 初始为 1；next: s = (1664525 * s + 1013904223) mod 2^32，返回 s / 2^32。
/// MoonBit 的 UInt 运算天然按 mod 2^32 回绕，与 JS 实现位精确一致。
pub struct Lcg {
  mut s : UInt
}

///|
/// 默认种子 s = 1（对齐 d3-force 3.x 默认 lcg）。
pub fn Lcg::new() -> Lcg {
  { s: 1, }
}

///|
pub fn Lcg::with_seed(seed : UInt) -> Lcg {
  { s: seed, }
}

///|
/// 返回 [0, 1) 的下一个随机数。
pub fn Lcg::next(self : Lcg) -> Double {
  self.s = 1664525 * self.s + 1013904223
  self.s.to_double() / 4294967296.0
}

///|
/// d3-force jiggle：(random() - 0.5) * 1e-6
pub fn jiggle(random : Lcg) -> Double {
  (random.next() - 0.5) * 1.0e-6
}
