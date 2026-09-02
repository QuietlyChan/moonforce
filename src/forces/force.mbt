///|
/// 力模型统一接口（enum 静态分发，避免 wasm-gc 下的 trait 装箱开销）。
///
/// 语义对齐 d3-force 3.x：initialize 在加入 simulation 时调用一次
/// （预计算 strengths 等缓存），apply 每个 tick 调用。
pub(all) enum Force {
  Center(CenterForce)
  ManyBody(ManyBodyForce)
  Link(LinkForce)
  Collide(CollideForce)
  PosX(XForce)
  PosY(YForce)
  Radial(RadialForce)
}

///|
/// d3 simulation.initializeForce：force.initialize(nodes, random)
pub fn Force::initialize(
  self : Force,
  nodes : @types.NodePool,
  random : @types.Lcg,
) -> Unit {
  match self {
    Center(f) => f.initialize(nodes)
    ManyBody(f) => f.initialize(nodes, random)
    Link(f) => f.initialize(nodes, random)
    Collide(f) => f.initialize(nodes, random)
    PosX(f) => f.initialize(nodes)
    PosY(f) => f.initialize(nodes)
    Radial(f) => f.initialize(nodes)
  }
}

///|
/// d3 tick: forces.forEach(force => force(alpha))
pub fn Force::apply(
  self : Force,
  nodes : @types.NodePool,
  random : @types.Lcg,
  alpha : Double,
) -> Unit {
  match self {
    Center(f) => f.apply(nodes) // d3 forceCenter 不使用 alpha
    ManyBody(f) => f.apply(nodes, random, alpha)
    Link(f) => f.apply(nodes, random, alpha)
    Collide(f) => f.apply(nodes, random, alpha) // d3 forceCollide 不使用 alpha
    PosX(f) => f.apply(nodes, alpha)
    PosY(f) => f.apply(nodes, alpha)
    Radial(f) => f.apply(nodes, alpha)
  }
}
