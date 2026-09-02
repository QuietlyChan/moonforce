///|
/// d3-force forceCollide：节点碰撞（圆碰撞，基于预测位置）。
///
/// 源码对齐（collide.js）：
/// - 每次 iteration：以预测位置（x+vx, y+vy）重建四叉树
///   → visitAfter(prepare) 自底向上聚合子树最大半径
///   → 每节点 visit(apply)
/// - prepare：叶 r = radii[idx]（链表头）；内部 r = max(子 r)
/// - apply：叶只处理 `data.index > node.index` 的对（每对一次）；
///   内部节点做 AABB 剪枝
/// - 碰撞解算：`l = (r - sqrt(l)) / sqrt(l) * strength`；
///   权重 `w = rj² / (ri² + rj²)`；速度对冲
/// - 注意：d3 forceCollide 不使用 alpha
pub struct CollideForce {
  radii : FixedArray[Double] // 每节点半径
  mut strength : Double // 默认 1
  mut iterations : Int // 默认 1
  // 预测位置缓冲（复用，避免每 tick 分配）
  pxs : FixedArray[Double]
  pys : FixedArray[Double]
}

///|
pub fn CollideForce::create(
  n : Int,
  radius : Double,
  strength : Double,
  iterations : Int,
) -> CollideForce {
  {
    radii: FixedArray::make(n, radius),
    strength,
    iterations,
    pxs: FixedArray::make(n, 0.0),
    pys: FixedArray::make(n, 0.0),
  }
}

///|
/// 设置单个节点半径。
pub fn CollideForce::set_radius(
  self : CollideForce,
  i : Int,
  r : Double,
) -> Unit {
  self.radii[i] = r
}

///|
/// d3 force.strength(_)。
pub fn CollideForce::set_strength(self : CollideForce, v : Double) -> Unit {
  self.strength = v
}

///|
/// d3 force.iterations(_)。
pub fn CollideForce::set_iterations(self : CollideForce, v : Int) -> Unit {
  self.iterations = v
}

///|
fn CollideForce::initialize(
  self : CollideForce,
  nodes : @types.NodePool,
  random : @types.Lcg,
) -> Unit {
  ignore(nodes)
  ignore(random)
}

///|
fn CollideForce::apply(
  self : CollideForce,
  nodes : @types.NodePool,
  random : @types.Lcg,
  alpha : Double,
) -> Unit {
  ignore(alpha) // d3 forceCollide 不使用 alpha
  let n = nodes.n
  for _ in 0..<self.iterations {
    // 每次 iteration 重算预测位置（速度在解算中变化）
    for i in 0..<n {
      self.pxs[i] = nodes.xs[i] + nodes.vxs[i]
      self.pys[i] = nodes.ys[i] + nodes.vys[i]
    }
    let tree = @quadtree.Quadtree::build(self.pxs, self.pys)
    tree.visit_after(quad => self.prepare(quad))
    for i in 0..<n {
      let ri = self.radii[i]
      let ri2 = ri * ri
      let xi = nodes.xs[i] + nodes.vxs[i]
      let yi = nodes.ys[i] + nodes.vys[i]
      tree.visit(quad => self.apply_one(quad, nodes, i, xi, yi, ri, ri2, random))
    }
  }
}

///|
/// 对齐 collide.js prepare：自底向上聚合子树最大半径。
fn CollideForce::prepare(self : CollideForce, quad : @quadtree.Quad) -> Unit {
  match quad.node {
    @quadtree.Leaf(l) => quad.node.set_aggr_r(self.radii[l.idx])
    @quadtree.Branch(b) => {
      let mut r = 0.0
      for i in 0..<4 {
        match b.children[i] {
          Some(child) => {
            let cr = child.aggr_r()
            if cr > r {
              r = cr
            }
          }
          None => ()
        }
      }
      quad.node.set_aggr_r(r)
    }
  }
}

///|
/// 对齐 collide.js apply：对单个节点的遍历回调。
/// 返回 true = 剪枝。
fn CollideForce::apply_one(
  self : CollideForce,
  quad : @quadtree.Quad,
  nodes : @types.NodePool,
  node_idx : Int,
  xi : Double,
  yi : Double,
  ri : Double,
  ri2 : Double,
  random : @types.Lcg,
) -> Bool {
  match quad.node {
    @quadtree.Leaf(l) => {
      // d3: if (data.index > node.index)——每对只处理一次
      if l.idx > node_idx {
        let rj = l.r
        let r = ri + rj
        let mut x = xi - nodes.xs[l.idx] - nodes.vxs[l.idx]
        let mut y = yi - nodes.ys[l.idx] - nodes.vys[l.idx]
        let mut l2 = x * x + y * y
        if l2 < r * r {
          if x == 0.0 {
            x = @types.jiggle(random)
            l2 = l2 + x * x
          }
          if y == 0.0 {
            y = @types.jiggle(random)
            l2 = l2 + y * y
          }
          let ls = l2.sqrt()
          let factor = (r - ls) / ls * self.strength
          x = x * factor
          y = y * factor
          let rj2 = rj * rj
          let w = rj2 / (ri2 + rj2)
          nodes.vxs[node_idx] = nodes.vxs[node_idx] + x * w
          nodes.vys[node_idx] = nodes.vys[node_idx] + y * w
          let w2 = 1.0 - w
          nodes.vxs[l.idx] = nodes.vxs[l.idx] - x * w2
          nodes.vys[l.idx] = nodes.vys[l.idx] - y * w2
        }
      }
      // d3: return（undefined → 继续深入；叶无子节点，无影响）
      false
    }
    @quadtree.Branch(_) => {
      // AABB 剪枝：quad 与 (xi,yi) 半径 r 的圆无交集则跳过
      let r = ri + quad.node.aggr_r()
      quad.x0 > xi + r ||
      quad.x1 < xi - r ||
      quad.y0 > yi + r ||
      quad.y1 < yi - r
    }
  }
}
