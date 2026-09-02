///|
/// SoA 节点池：d3-force 节点状态的扁平化表示。
///
/// wasm-gc 下 `FixedArray[Double]` 编译为 unboxed 的 `(array f64)`，
/// 比每节点一个 struct 对 GC 与缓存都更友好。
///
/// `fxs/fys` 用 NaN 表示“未固定”（对齐 d3 的 `fx == null` 语义）。
pub struct NodePool {
  n : Int
  xs : FixedArray[Double] // x
  ys : FixedArray[Double] // y
  vxs : FixedArray[Double] // vx
  vys : FixedArray[Double] // vy
  fxs : FixedArray[Double] // 固定 x，NaN = 自由
  fys : FixedArray[Double] // 固定 y，NaN = 自由
}

///|
/// d3-force simulation.js 的 initialRadius
let initial_radius : Double = 10.0

///|
/// d3-force simulation.js 的 initialAngle：pi * (3 - sqrt(5))
let initial_angle : Double = @math.pi * (3.0 - 5.0.sqrt())

///|
/// 创建全 NaN 的原始节点池（未初始化）。
pub fn NodePool::make_raw(n : Int) -> NodePool {
  {
    n,
    xs: FixedArray::make(n, @double.not_a_number),
    ys: FixedArray::make(n, @double.not_a_number),
    vxs: FixedArray::make(n, @double.not_a_number),
    vys: FixedArray::make(n, @double.not_a_number),
    fxs: FixedArray::make(n, @double.not_a_number),
    fys: FixedArray::make(n, @double.not_a_number),
  }
}

///|
/// 按 d3-force initializeNodes 语义初始化：
///
/// - fx 非空（非 NaN）则 x = fx；
/// - x 或 y 为 NaN 时用 phyllotaxis 螺旋初始化对应分量：
///   radius = 10 * sqrt(0.5 + i)，angle = i * initialAngle；
/// - vx 或 vy 为 NaN 时两个都置 0。
///
/// 该函数就地修改并返回池子本身。
pub fn NodePool::initialize(self : NodePool) -> NodePool {
  let n = self.n
  for i in 0..<n {
    if !self.fxs[i].is_nan() {
      self.xs[i] = self.fxs[i]
    }
    if !self.fys[i].is_nan() {
      self.ys[i] = self.fys[i]
    }
    if self.xs[i].is_nan() || self.ys[i].is_nan() {
      let radius = initial_radius * (0.5 + i.to_double()).sqrt()
      let angle = i.to_double() * initial_angle
      if self.xs[i].is_nan() {
        self.xs[i] = radius * @math.cos(angle)
      }
      if self.ys[i].is_nan() {
        self.ys[i] = radius * @math.sin(angle)
      }
    }
    if self.vxs[i].is_nan() || self.vys[i].is_nan() {
      self.vxs[i] = 0.0
      self.vys[i] = 0.0
    }
  }
  self
}

///|
/// 创建并按 d3 默认语义初始化的节点池（等价于 d3 从空坐标数组开始）。
pub fn NodePool::init(n : Int) -> NodePool {
  NodePool::make_raw(n).initialize()
}

///|
/// 设置节点 i 的固定坐标（对齐 d3 的 node.fx/fy）。
/// fx 或 fy 为 NaN 表示解除固定。
pub fn NodePool::set_fixed(
  self : NodePool,
  i : Int,
  fx : Double,
  fy : Double,
) -> Unit {
  self.fxs[i] = fx
  self.fys[i] = fy
  if !fx.is_nan() {
    self.xs[i] = fx
    self.vxs[i] = 0.0
  }
  if !fy.is_nan() {
    self.ys[i] = fy
    self.vys[i] = 0.0
  }
}

///|
/// 查找距离 (x, y) 最近且不超过 radius 的节点索引，无则返回 -1。
/// 对齐 d3 simulation.find 的线性扫描语义（判定半径平方逐节点收缩）。
pub fn NodePool::find(
  self : NodePool,
  x : Double,
  y : Double,
  radius : Double,
) -> Int {
  let n = self.n
  let mut best = -1
  let mut best2 = radius * radius
  for i in 0..<n {
    let dx = self.xs[i] - x
    let dy = self.ys[i] - y
    let d2 = dx * dx + dy * dy
    if d2 < best2 {
      best = i
      best2 = d2
    }
  }
  best
}
