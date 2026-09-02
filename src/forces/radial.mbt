///|
/// d3-force forceRadial：把节点拉向以 (cx, cy) 为中心的目标半径圆环。
///
/// 源码对齐（radial.js）：
/// `dx = node.x - x || 1e-6; k = (radiuses[i] - r) * strengths[i] * alpha / r;
///  vx += dx * k; vy += dy * k`；radius NaN 时该点 strength 置 0。
pub struct RadialForce {
  cx : Double // d3: x，默认 0
  cy : Double // d3: y，默认 0
  strength : Double // 默认 0.1
  radii : FixedArray[Double]
  strengths : FixedArray[Double]
}

///|
pub fn RadialForce::new(
  n : Int,
  cx : Double,
  cy : Double,
  radius : Double,
  strength : Double,
) -> RadialForce {
  {
    cx,
    cy,
    strength,
    radii: FixedArray::make(n, radius),
    strengths: FixedArray::make(n, strength),
  }
}

///|
/// 设置单个节点的目标半径（NaN 表示该点不受力）。
pub fn RadialForce::set_radius(
  self : RadialForce,
  i : Int,
  radius : Double,
) -> Unit {
  self.radii[i] = radius
}

///|
fn RadialForce::initialize(self : RadialForce, nodes : @types.NodePool) -> Unit {
  for i in 0..<nodes.n {
    self.strengths[i] = if self.radii[i].is_nan() { 0.0 } else { self.strength }
  }
}

///|
fn RadialForce::apply(
  self : RadialForce,
  nodes : @types.NodePool,
  alpha : Double,
) -> Unit {
  for i in 0..<nodes.n {
    let mut dx = nodes.xs[i] - self.cx
    let mut dy = nodes.ys[i] - self.cy
    // d3: `dx = node.x - x || 1e-6`（0 或 NaN 时取 1e-6）
    if dx == 0.0 || dx.is_nan() {
      dx = 1.0e-6
    }
    if dy == 0.0 || dy.is_nan() {
      dy = 1.0e-6
    }
    let r = (dx * dx + dy * dy).sqrt()
    let k = (self.radii[i] - r) * self.strengths[i] * alpha / r
    nodes.vxs[i] = nodes.vxs[i] + dx * k
    nodes.vys[i] = nodes.vys[i] + dy * k
  }
}
