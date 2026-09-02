///|
/// d3-force forceCenter：把节点群平移到目标中心（位置硬移动，不经过速度系统）。
///
/// 源码对齐（center.js）：
/// `sx = (Σx/n - x) * strength; node.x -= sx`（strength 默认 1）。
pub struct CenterForce {
  cx : Double // d3: x，默认 0
  cy : Double // d3: y，默认 0
  strength : Double // 默认 1
}

///|
pub fn CenterForce::new(
  cx : Double,
  cy : Double,
  strength : Double,
) -> CenterForce {
  { cx, cy, strength }
}

///|
fn CenterForce::initialize(self : CenterForce, nodes : @types.NodePool) -> Unit {
  // d3: force.initialize 只保存 nodes 引用
  ignore(nodes)
  ignore(self)
}

///|
fn CenterForce::apply(self : CenterForce, nodes : @types.NodePool) -> Unit {
  let n = nodes.n
  let mut sx = 0.0
  let mut sy = 0.0
  for i in 0..<n {
    sx = sx + nodes.xs[i]
    sy = sy + nodes.ys[i]
  }
  sx = (sx / n.to_double() - self.cx) * self.strength
  sy = (sy / n.to_double() - self.cy) * self.strength
  for i in 0..<n {
    nodes.xs[i] = nodes.xs[i] - sx
    nodes.ys[i] = nodes.ys[i] - sy
  }
}
