///|
/// d3-force forceX：把节点拉向目标 x 坐标（弹簧，经速度系统）。
///
/// 源码对齐（x.js）：`vx += (xz[i] - x) * strengths[i] * alpha`；
/// 目标值 NaN 时该点 strength 置 0。
pub struct XForce {
  strength : Double // 默认 0.1
  xz : FixedArray[Double] // 每节点目标 x
  strengths : FixedArray[Double]
}

///|
pub fn XForce::new(n : Int, target : Double, strength : Double) -> XForce {
  {
    strength,
    xz: FixedArray::make(n, target),
    strengths: FixedArray::make(n, strength),
  }
}

///|
/// 设置单个节点的目标 x（NaN 表示该点不受力，对齐 d3 x accessor 返回 NaN）。
pub fn XForce::set_target(self : XForce, i : Int, target : Double) -> Unit {
  self.xz[i] = target
}

///|
fn XForce::initialize(self : XForce, nodes : @types.NodePool) -> Unit {
  for i in 0..<nodes.n {
    self.strengths[i] = if self.xz[i].is_nan() { 0.0 } else { self.strength }
  }
}

///|
fn XForce::apply(
  self : XForce,
  nodes : @types.NodePool,
  alpha : Double,
) -> Unit {
  for i in 0..<nodes.n {
    nodes.vxs[i] = nodes.vxs[i] +
      (self.xz[i] - nodes.xs[i]) * self.strengths[i] * alpha
  }
}
