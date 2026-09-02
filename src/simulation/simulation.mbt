///|
/// d3-force simulation.js 的核心状态机（不含 d3-timer / d3-dispatch 事件层，
/// 时间驱动与回调在 JS 宿主侧完成，wasm 只做纯计算）。
///
/// tick 每次迭代的精确顺序：
/// 1. `alpha += (alphaTarget - alpha) * alphaDecay`
/// 2. 按插入顺序遍历 forces
/// 3. 每节点：fx 为 null → `x += vx *= velocityDecay`（先衰减后位移）；
///    否则 `x = fx; vx = 0`
pub struct Simulation {
  nodes : @types.NodePool
  forces : Array[@forces.Force] // 插入顺序即应用顺序（对齐 Map 迭代序）
  random : @types.Lcg
  mut alpha : Double // 初始 1
  mut alpha_min : Double // 0.001
  mut alpha_decay : Double // 1 - 0.001^(1/300)
  mut alpha_target : Double // 0
  mut velocity_decay : Double // 0.6
}

///|
/// 1 - 0.001^(1/300)（位精确常量，JS Math.pow 实算硬编码，规避 R5）
let default_alpha_decay : Double = 0.02276277904418933

///|
pub fn Simulation::new(n : Int) -> Simulation {
  {
    nodes: @types.NodePool::init(n),
    forces: [],
    random: @types.Lcg::new(),
    alpha: 1.0,
    alpha_min: 0.001,
    alpha_decay: default_alpha_decay,
    alpha_target: 0.0,
    velocity_decay: 0.6,
  }
}

///|
/// d3 simulation.force(name, force)：加入力并立即 initialize。
pub fn Simulation::add_force(
  self : Simulation,
  force : @forces.Force,
) -> Simulation {
  force.initialize(self.nodes, self.random)
  self.forces.push(force)
  self
}

///|
/// 移除指定类型的力（d3 用名字删除；此处每类型至多一个实例，以类型代名字）。
pub fn Simulation::remove_force_kind(
  self : Simulation,
  kind : ForceKind,
) -> Simulation {
  let kept : Array[@forces.Force] = []
  for f in self.forces {
    if force_kind(f) != kind {
      kept.push(f)
    }
  }
  self.forces.clear()
  for f in kept {
    self.forces.push(f)
  }
  self
}

///|
/// 力类型标识（ffi 层按 Int 传入）。
pub(all) enum ForceKind {
  KCenter
  KManyBody
  KLink
  KCollide
  KPosX
  KPosY
  KRadial
} derive(Eq)

///|
fn force_kind(f : @forces.Force) -> ForceKind {
  match f {
    @forces.Center(_) => KCenter
    @forces.ManyBody(_) => KManyBody
    @forces.Link(_) => KLink
    @forces.Collide(_) => KCollide
    @forces.PosX(_) => KPosX
    @forces.PosY(_) => KPosY
    @forces.Radial(_) => KRadial
  }
}

///|
/// 对齐 d3 tick(iterations = 1)。
pub fn Simulation::tick(self : Simulation, iterations : Int) -> Simulation {
  let n = self.nodes.n
  for _ in 0..<iterations {
    self.alpha = self.alpha +
      (self.alpha_target - self.alpha) * self.alpha_decay
    for f in self.forces {
      f.apply(self.nodes, self.random, self.alpha)
    }
    for i in 0..<n {
      if self.nodes.fxs[i].is_nan() {
        self.nodes.vxs[i] = self.nodes.vxs[i] * self.velocity_decay
        self.nodes.xs[i] = self.nodes.xs[i] + self.nodes.vxs[i]
      } else {
        self.nodes.xs[i] = self.nodes.fxs[i]
        self.nodes.vxs[i] = 0.0
      }
      if self.nodes.fys[i].is_nan() {
        self.nodes.vys[i] = self.nodes.vys[i] * self.velocity_decay
        self.nodes.ys[i] = self.nodes.ys[i] + self.nodes.vys[i]
      } else {
        self.nodes.ys[i] = self.nodes.fys[i]
        self.nodes.vys[i] = 0.0
      }
    }
  }
  self
}

///|
/// d3 simulation.stop：置 alpha 低于 alphaMin（timer 停止由宿主负责）。
pub fn Simulation::stop(self : Simulation) -> Simulation {
  self.alpha = 0.0
  self.alpha_target = 0.0
  self
}

///|
/// d3 simulation.restart：重置 alpha 为 1 并重新开始（宿主驱动）。
pub fn Simulation::restart(self : Simulation, alpha : Double) -> Simulation {
  self.alpha = alpha
  self
}

///|
/// d3 velocityDecay setter：传入 friction，内部存 1 - friction。
pub fn Simulation::set_velocity_decay(
  self : Simulation,
  friction : Double,
) -> Simulation {
  self.velocity_decay = 1.0 - friction
  self
}

///|
/// d3 simulation.alpha(_)：getter/setter 一体，此处 setter。
pub fn Simulation::set_alpha(self : Simulation, v : Double) -> Simulation {
  self.alpha = v
  self
}

///|
/// d3 simulation.alphaMin(_)。
pub fn Simulation::set_alpha_min(self : Simulation, v : Double) -> Simulation {
  self.alpha_min = v
  self
}

///|
/// d3 simulation.alphaDecay(_)。
pub fn Simulation::set_alpha_decay(self : Simulation, v : Double) -> Simulation {
  self.alpha_decay = v
  self
}

///|
/// d3 simulation.alphaTarget(_)。
pub fn Simulation::set_alpha_target(
  self : Simulation,
  v : Double,
) -> Simulation {
  self.alpha_target = v
  self
}
