///|
/// d3-force forceY：把节点拉向目标 y 坐标（弹簧，经速度系统）。
///
/// 源码对齐（y.js）：`vy += (yz[i] - y) * strengths[i] * alpha`；
/// 目标值 NaN 时该点 strength 置 0。
pub struct YForce {
  strength : Double // 默认 0.1
  yz : FixedArray[Double] // 每节点目标 y
  strengths : FixedArray[Double]
}

///|
pub fn YForce::new(n : Int, target : Double, strength : Double) -> YForce {
  {
    strength,
    yz: FixedArray::make(n, target),
    strengths: FixedArray::make(n, strength),
  }
}

///|
/// 设置单个节点的目标 y（NaN 表示该点不受力）。
pub fn YForce::set_target(self : YForce, i : Int, target : Double) -> Unit {
  self.yz[i] = target
}

///|
fn YForce::initialize(self : YForce, nodes : @types.NodePool) -> Unit {
  for i in 0..<nodes.n {
    self.strengths[i] = if self.yz[i].is_nan() { 0.0 } else { self.strength }
  }
}

///|
fn YForce::apply(
  self : YForce,
  nodes : @types.NodePool,
  alpha : Double,
) -> Unit {
  for i in 0..<nodes.n {
    nodes.vys[i] = nodes.vys[i] +
      (self.yz[i] - nodes.ys[i]) * self.strengths[i] * alpha
  }
}
