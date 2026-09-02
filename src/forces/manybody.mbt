///|
/// d3-force forceManyBody：多体电荷力（Barnes-Hut O(N log N) 近似）。
///
/// 源码对齐（manyBody.js）：
/// - 每次 force：重建四叉树 → visitAfter 自底向上聚合 → 对每个节点 visit(apply)
/// - 聚合：内部节点 value = Σ子值，质心按 |value| 加权；叶 value = Σ链表 strengths
/// - Barnes-Hut 判定 `w²/theta2 < l`（w = quad 宽度，l = 平方距离）
/// - distanceMin 软下限：`l = sqrt(distanceMin2 * l)`
/// - 力 = `x * quad.value * alpha / l`（l 为平方距离）
/// - 重合点：jiggle 随机扰动；力系数 = `strengths[idx] * alpha / l`
pub struct ManyBodyForce {
  strength : Double // 默认 -30（常数）
  mut theta2 : Double // theta²，默认 0.81（theta=0.9）
  mut distance_min2 : Double // distanceMin²，默认 1
  mut distance_max2 : Double // distanceMax²，默认 ∞
  strengths : FixedArray[Double] // initialize 预计算
}

///|
pub fn ManyBodyForce::new(n : Int, strength : Double) -> ManyBodyForce {
  {
    strength,
    theta2: 0.81,
    distance_min2: 1.0,
    distance_max2: @double.infinity,
    strengths: FixedArray::make(n, strength),
  }
}

///|
/// d3 force.theta(_)：传入 theta，内部存 theta²。
pub fn ManyBodyForce::set_theta(self : ManyBodyForce, theta : Double) -> Unit {
  self.theta2 = theta * theta
}

///|
/// d3 force.distanceMin(_)：传入距离，内部存平方。
pub fn ManyBodyForce::set_distance_min(
  self : ManyBodyForce,
  d : Double,
) -> Unit {
  self.distance_min2 = d * d
}

///|
/// d3 force.distanceMax(_)：传入距离，内部存平方。
pub fn ManyBodyForce::set_distance_max(
  self : ManyBodyForce,
  d : Double,
) -> Unit {
  self.distance_max2 = d * d
}

///|
fn ManyBodyForce::initialize(
  self : ManyBodyForce,
  nodes : @types.NodePool,
  random : @types.Lcg,
) -> Unit {
  ignore(random)
  for i in 0..<nodes.n {
    self.strengths[i] = self.strength
  }
}

///|
fn ManyBodyForce::apply(
  self : ManyBodyForce,
  nodes : @types.NodePool,
  random : @types.Lcg,
  alpha : Double,
) -> Unit {
  let tree = @quadtree.Quadtree::build(nodes.xs, nodes.ys)
  tree.visit_after(quad => self.accumulate(quad, nodes))
  for i in 0..<nodes.n {
    tree.visit(quad => self.apply_one(quad, nodes, i, alpha, random))
  }
}

///|
/// 对齐 manyBody.js accumulate：自底向上聚合电荷与质心。
fn ManyBodyForce::accumulate(
  self : ManyBodyForce,
  quad : @quadtree.Quad,
  nodes : @types.NodePool,
) -> Unit {
  ignore(nodes)
  match quad.node {
    @quadtree.Branch(b) => {
      let mut strength = 0.0
      let mut weight = 0.0
      let mut x = 0.0
      let mut y = 0.0
      for i in 0..<4 {
        match b.children[i] {
          Some(@quadtree.Leaf(l)) => {
            // d3: if ((q = quad[i]) && (c = Math.abs(q.value)))
            let c = l.value.abs()
            if not(c.is_nan()) && c != 0.0 {
              strength = strength + l.value
              weight = weight + c
              x = x + c * l.cx
              y = y + c * l.cy
            }
          }
          Some(@quadtree.Branch(qb)) => {
            let c = qb.value.abs()
            if not(c.is_nan()) && c != 0.0 {
              strength = strength + qb.value
              weight = weight + c
              x = x + c * qb.cx
              y = y + c * qb.cy
            }
          }
          None => ()
        }
      }
      quad.node.set_aggr_cx(x / weight)
      quad.node.set_aggr_cy(y / weight)
      quad.node.set_aggr_value(strength)
    }
    @quadtree.Leaf(_) => {
      // d3: q.x = q.data.x（叶质心 = 实时坐标，此处用建树快照，同一 tick 内等价）
      quad.node.set_aggr_cx(quad.node.leaf_x())
      quad.node.set_aggr_cy(quad.node.leaf_y())
      // do strength += strengths[q.data.index]; while (q = q.next)
      let mut s = 0.0
      let mut cur : @quadtree.QLeaf? = quad.node.leaf_data()
      while cur is Some(q) {
        s = s + self.strengths[q.idx]
        cur = q.next
      }
      quad.node.set_aggr_value(s)
    }
  }
}

///|
/// 对齐 manyBody.js apply：对单个节点的四叉树遍历回调。
/// 返回 true = 剪枝（不深入）。
fn ManyBodyForce::apply_one(
  self : ManyBodyForce,
  quad : @quadtree.Quad,
  nodes : @types.NodePool,
  node_idx : Int,
  alpha : Double,
  random : @types.Lcg,
) -> Bool {
  // if (!quad.value) return true（0 / -0 / NaN 均剪枝，对齐 JS falsy）
  let qv = quad.node.aggr_value()
  if qv == 0.0 || qv.is_nan() {
    return true
  }
  let mut x = quad.node.aggr_cx() - nodes.xs[node_idx]
  let mut y = quad.node.aggr_cy() - nodes.ys[node_idx]
  let w = quad.x1 - quad.x0
  let mut l = x * x + y * y
  // Barnes-Hut 判定：quad 够远，整体近似
  if w * w / self.theta2 < l {
    if l < self.distance_max2 {
      if x == 0.0 {
        x = @types.jiggle(random)
        l = l + x * x
      }
      if y == 0.0 {
        y = @types.jiggle(random)
        l = l + y * y
      }
      if l < self.distance_min2 {
        l = (self.distance_min2 * l).sqrt()
      }
      nodes.vxs[node_idx] = nodes.vxs[node_idx] + x * qv * alpha / l
      nodes.vys[node_idx] = nodes.vys[node_idx] + y * qv * alpha / l
    }
    return true
  }
  // 否则：内部节点继续深入；超出 distanceMax 的不再处理
  if quad.is_branch() || l >= self.distance_max2 {
    return false
  }
  // 叶节点：处理重合点链表
  let leaf : @quadtree.QLeaf = match quad.node {
    @quadtree.Leaf(lf) => lf
    @quadtree.Branch(_) => abort("unreachable")
  }
  // if (quad.data !== node || quad.next)
  if leaf.idx != node_idx || leaf.next is Some(_) {
    if x == 0.0 {
      x = @types.jiggle(random)
      l = l + x * x
    }
    if y == 0.0 {
      y = @types.jiggle(random)
      l = l + y * y
    }
    if l < self.distance_min2 {
      l = (self.distance_min2 * l).sqrt()
    }
  }
  // do if (quad.data !== node) { w = strengths[idx] * alpha / l; vx += x*w; vy += y*w }
  let mut cur : @quadtree.QLeaf? = Some(leaf)
  while cur is Some(q) {
    if q.idx != node_idx {
      let w2 = self.strengths[q.idx] * alpha / l
      nodes.vxs[node_idx] = nodes.vxs[node_idx] + x * w2
      nodes.vys[node_idx] = nodes.vys[node_idx] + y * w2
    }
    cur = q.next
  }
  false
}
