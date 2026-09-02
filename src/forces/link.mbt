///|
/// d3-force forceLink：弹簧边（使用预测位置）。
///
/// 源码对齐（link.js）：
/// - `x = target.x + target.vx - source.x - source.vx || jiggle(random)`
///   （0 或 NaN 触发 jiggle）
/// - `l = (l - distances[i]) / l * alpha * strengths[i]`
/// - bias 分摊：`target.vx -= x * bias; source.vx += x * (1 - bias)`
/// - 默认 strength = 1 / min(deg_source, deg_target)；bias = deg_s / (deg_s + deg_t)
pub struct LinkForce {
  n : Int // 节点数
  es : Array[Int] // 每边 source 索引（可增长）
  et : Array[Int] // 每边 target 索引
  mut distance : Double // 默认 30
  mut iterations : Int // 默认 1
  // 预计算缓存（recompute 时按当前边数重建）
  mut biases : FixedArray[Double]
  mut strengths : FixedArray[Double]
  mut distances : FixedArray[Double]
  mut m_cache : Int // 预计算时的边数（0 = 未计算）
}

///|
pub fn LinkForce::create(
  n : Int,
  distance : Double,
  iterations : Int,
) -> LinkForce {
  {
    n,
    es: [],
    et: [],
    distance,
    iterations,
    biases: FixedArray::make(0, 0.0),
    strengths: FixedArray::make(0, 0.0),
    distances: FixedArray::make(0, 0.0),
    m_cache: 0,
  }
}

///|
/// 添加一条边（source/target 为节点索引）。
/// d3 语义：修改 links 后需要重新 initialize。
pub fn LinkForce::add_edge(
  self : LinkForce,
  source : Int,
  target : Int,
) -> Unit {
  self.es.push(source)
  self.et.push(target)
  self.m_cache = 0 // 标记需要重算
}

///|
pub fn LinkForce::edge_count(self : LinkForce) -> Int {
  self.es.length()
}

///|
/// d3 force.distance(_)（修改后重算缓存）。
pub fn LinkForce::set_distance(self : LinkForce, v : Double) -> Unit {
  self.distance = v
  self.m_cache = 0
}

///|
/// d3 force.iterations(_)。
pub fn LinkForce::set_iterations(self : LinkForce, v : Int) -> Unit {
  self.iterations = v
}

///|
/// 重建预计算缓存（度数、bias、strength、distance）。
fn LinkForce::recompute(self : LinkForce) -> Unit {
  let n = self.n
  let m = self.es.length()
  let count : FixedArray[Int] = FixedArray::make(n, 0)
  for i in 0..<m {
    count[self.es[i]] = count[self.es[i]] + 1
    count[self.et[i]] = count[self.et[i]] + 1
  }
  self.biases = FixedArray::make(m, 0.0)
  self.strengths = FixedArray::make(m, 0.0)
  self.distances = FixedArray::make(m, 0.0)
  for i in 0..<m {
    let cs = count[self.es[i]]
    let ct = count[self.et[i]]
    self.biases[i] = cs.to_double() / (cs + ct).to_double()
    // defaultStrength = 1 / min(count[source], count[target])
    let min_deg = if cs < ct { cs } else { ct }
    self.strengths[i] = 1.0 / min_deg.to_double()
    self.distances[i] = self.distance
  }
  self.m_cache = m
}

///|
fn LinkForce::initialize(
  self : LinkForce,
  nodes : @types.NodePool,
  random : @types.Lcg,
) -> Unit {
  ignore(random)
  ignore(nodes)
  if self.m_cache != self.es.length() {
    self.recompute()
  }
}

///|
fn LinkForce::apply(
  self : LinkForce,
  nodes : @types.NodePool,
  random : @types.Lcg,
  alpha : Double,
) -> Unit {
  if self.m_cache != self.es.length() {
    self.recompute()
  }
  let m = self.es.length()
  for _ in 0..<self.iterations {
    for i in 0..<m {
      let s = self.es[i]
      let t = self.et[i]
      // 预测位置：0 或 NaN 触发 jiggle（对齐 JS ||）
      let mut x = nodes.xs[t] + nodes.vxs[t] - nodes.xs[s] - nodes.vxs[s]
      if x == 0.0 || x.is_nan() {
        x = @types.jiggle(random)
      }
      let mut y = nodes.ys[t] + nodes.vys[t] - nodes.ys[s] - nodes.vys[s]
      if y == 0.0 || y.is_nan() {
        y = @types.jiggle(random)
      }
      let mut l = (x * x + y * y).sqrt()
      l = (l - self.distances[i]) / l * alpha * self.strengths[i]
      x = x * l
      y = y * l
      let b = self.biases[i]
      nodes.vxs[t] = nodes.vxs[t] - x * b
      nodes.vys[t] = nodes.vys[t] - y * b
      let b2 = 1.0 - b
      nodes.vxs[s] = nodes.vxs[s] + x * b2
      nodes.vys[s] = nodes.vys[s] + y * b2
    }
  }
}
