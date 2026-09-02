// moonforce wasm ABI：i32 句柄式导出层。
//
// 设计要点：
// - 句柄表：mf_create 返回 i32 句柄（registry 槽位索引），mf_free 释放
// - 纯数值 ABI（Int/Double），无 String → wasm Import 段为空，加载零依赖
// - 力添加顺序即 d3 Map 插入序，影响数值轨迹（调用方需按 d3 顺序添加）
// - 无效句柄会 abort（trap）；JS 层保证正确使用

///|
/// ABI 版本（语义不兼容变更时递增）
#export_name("mf_version")
pub fn mf_version() -> Int {
  1
}

///|
/// 句柄注册表（Array 本身可变，绑定不可变）
let registry : Array[@simulation.Simulation?] = []

///|
fn get_sim(handle : Int) -> @simulation.Simulation {
  if handle < 0 || handle >= registry.length() {
    abort("moonforce: invalid handle \{handle}")
  }
  match registry[handle] {
    Some(sim) => sim
    None => abort("moonforce: handle \{handle} already freed")
  }
}

///|
/// 创建 n 节点的 simulation（phyllotaxis 初始化，等价 d3 默认）。
/// 返回句柄。
#export_name("mf_create")
pub fn mf_create(num_nodes : Int) -> Int {
  if num_nodes < 0 {
    abort("moonforce: num_nodes must be >= 0")
  }
  let sim = @simulation.Simulation::new(num_nodes)
  // 复用已释放的槽位
  for i in 0..<registry.length() {
    if registry[i] is None {
      registry[i] = Some(sim)
      return i
    }
  }
  registry.push(Some(sim))
  registry.length() - 1
}

///|
/// 释放句柄。
#export_name("mf_free")
pub fn mf_free(handle : Int) -> Unit {
  if handle < 0 || handle >= registry.length() {
    return
  }
  registry[handle] = None
}

///|
/// 节点数。
#export_name("mf_num_nodes")
pub fn mf_num_nodes(handle : Int) -> Int {
  get_sim(handle).nodes.n
}

///|
/// 执行 iterations 次 tick（默认 1）。
#export_name("mf_step")
pub fn mf_step(handle : Int, iterations : Int) -> Unit {
  ignore(get_sim(handle).tick(iterations))
}

///|
/// 当前 alpha。
#export_name("mf_alpha")
pub fn mf_alpha(handle : Int) -> Double {
  get_sim(handle).alpha
}

///|
/// stop（alpha 置 0，等价 d3 alphaTarget(0)+timer.stop 的计算侧）。
#export_name("mf_stop")
pub fn mf_stop(handle : Int) -> Unit {
  ignore(get_sim(handle).stop())
}

///|
/// restart（重置 alpha）。
#export_name("mf_restart")
pub fn mf_restart(handle : Int, alpha : Double) -> Unit {
  ignore(get_sim(handle).restart(alpha))
}

// —— simulation 参数 setter（d3 链式 API 的扁平化）——

///|
#export_name("mf_set_alpha")
pub fn mf_set_alpha(handle : Int, v : Double) -> Unit {
  ignore(get_sim(handle).set_alpha(v))
}

///|
#export_name("mf_set_alpha_min")
pub fn mf_set_alpha_min(handle : Int, v : Double) -> Unit {
  ignore(get_sim(handle).set_alpha_min(v))
}

///|
#export_name("mf_set_alpha_decay")
pub fn mf_set_alpha_decay(handle : Int, v : Double) -> Unit {
  ignore(get_sim(handle).set_alpha_decay(v))
}

///|
#export_name("mf_set_alpha_target")
pub fn mf_set_alpha_target(handle : Int, v : Double) -> Unit {
  ignore(get_sim(handle).set_alpha_target(v))
}

///|
/// 传入 friction（d3 语义：内部存 1 - friction）。
#export_name("mf_set_velocity_decay")
pub fn mf_set_velocity_decay(handle : Int, friction : Double) -> Unit {
  ignore(get_sim(handle).set_velocity_decay(friction))
}

// —— 节点访问 ——

///|
#export_name("mf_node_x")
pub fn mf_node_x(handle : Int, i : Int) -> Double {
  get_sim(handle).nodes.xs[i]
}

///|
#export_name("mf_node_y")
pub fn mf_node_y(handle : Int, i : Int) -> Double {
  get_sim(handle).nodes.ys[i]
}

///|
#export_name("mf_node_vx")
pub fn mf_node_vx(handle : Int, i : Int) -> Double {
  get_sim(handle).nodes.vxs[i]
}

///|
#export_name("mf_node_vy")
pub fn mf_node_vy(handle : Int, i : Int) -> Double {
  get_sim(handle).nodes.vys[i]
}

///|
/// 覆盖节点初始坐标（JS 侧预置坐标时使用，对齐 d3 preset x/y）。
#export_name("mf_set_node_pos")
pub fn mf_set_node_pos(handle : Int, i : Int, x : Double, y : Double) -> Unit {
  let sim = get_sim(handle)
  sim.nodes.xs[i] = x
  sim.nodes.ys[i] = y
}

///|
/// 固定/解除固定节点（fx/fy 为 NaN 表示解除，对齐 d3 null）。
#export_name("mf_set_fixed")
pub fn mf_set_fixed(handle : Int, i : Int, fx : Double, fy : Double) -> Unit {
  get_sim(handle).nodes.set_fixed(i, fx, fy)
}

///|
/// 查找最近节点（返回索引，-1 = 无）。
#export_name("mf_find")
pub fn mf_find(handle : Int, x : Double, y : Double, radius : Double) -> Int {
  get_sim(handle).nodes.find(x, y, radius)
}

// —— 力添加（顺序即 d3 插入序，影响轨迹）——

///|
fn add_force(handle : Int, force : @forces.Force) -> Unit {
  ignore(get_sim(handle).add_force(force))
}

///|
/// 力类型常量（mf_remove_force 的 kind 参数）：
/// 0=Center 1=ManyBody 2=Link 3=Collide 4=X 5=Y 6=Radial
#export_name("mf_remove_force")
pub fn mf_remove_force(handle : Int, kind : Int) -> Unit {
  let k : @simulation.ForceKind = match kind {
    0 => @simulation.KCenter
    1 => @simulation.KManyBody
    2 => @simulation.KLink
    3 => @simulation.KCollide
    4 => @simulation.KPosX
    5 => @simulation.KPosY
    _ => @simulation.KRadial
  }
  ignore(get_sim(handle).remove_force_kind(k))
}

///|
#export_name("mf_add_center")
pub fn mf_add_center(
  handle : Int,
  x : Double,
  y : Double,
  strength : Double,
) -> Unit {
  add_force(handle, @forces.Center(@forces.CenterForce::new(x, y, strength)))
}

///|
#export_name("mf_add_manybody")
pub fn mf_add_manybody(
  handle : Int,
  strength : Double,
  theta : Double,
  distance_min : Double,
  distance_max : Double,
) -> Unit {
  let n = get_sim(handle).nodes.n
  let f = @forces.ManyBodyForce::new(n, strength)
  if theta != 0.9 {
    f.set_theta(theta)
  }
  if distance_min != 1.0 {
    f.set_distance_min(distance_min)
  }
  // distance_max <= 0 视为 ∞（wasm 无 Infinity 字面量 ABI）
  if distance_max > 0.0 {
    f.set_distance_max(distance_max)
  }
  add_force(handle, @forces.ManyBody(f))
}

///|
/// 创建空 LinkForce 并加入（边用 mf_link_edge 逐条添加，dirty 重算）。
#export_name("mf_add_link")
pub fn mf_add_link(handle : Int, distance : Double, iterations : Int) -> Unit {
  let n = get_sim(handle).nodes.n
  add_force(
    handle,
    @forces.Link(@forces.LinkForce::create(n, distance, iterations)),
  )
}

///|
/// 向已存在的 LinkForce 添加边（source/target 为节点索引）。
#export_name("mf_link_edge")
pub fn mf_link_edge(handle : Int, source : Int, target : Int) -> Unit {
  let sim = get_sim(handle)
  let mut found : @forces.LinkForce? = None
  for f in sim.forces {
    match f {
      @forces.Link(lf) => {
        found = Some(lf)
        break
      }
      _ => ()
    }
  }
  match found {
    Some(lf) => lf.add_edge(source, target)
    None => abort("moonforce: no link force; call mf_add_link first")
  }
}

///|
#export_name("mf_add_collide")
pub fn mf_add_collide(
  handle : Int,
  radius : Double,
  strength : Double,
  iterations : Int,
) -> Unit {
  let n = get_sim(handle).nodes.n
  add_force(
    handle,
    @forces.Collide(
      @forces.CollideForce::create(n, radius, strength, iterations),
    ),
  )
}

///|
/// 设置单个节点的碰撞半径（需已添加 collide）。
#export_name("mf_set_collide_radius")
pub fn mf_set_collide_radius(handle : Int, i : Int, r : Double) -> Unit {
  let sim = get_sim(handle)
  let mut found : @forces.CollideForce? = None
  for f in sim.forces {
    match f {
      @forces.Collide(cf) => {
        found = Some(cf)
        break
      }
      _ => ()
    }
  }
  match found {
    Some(cf) => cf.set_radius(i, r)
    None => abort("moonforce: no collide force; call mf_add_collide first")
  }
}

///|
#export_name("mf_add_x")
pub fn mf_add_x(handle : Int, target : Double, strength : Double) -> Unit {
  let n = get_sim(handle).nodes.n
  add_force(handle, @forces.PosX(@forces.XForce::new(n, target, strength)))
}

///|
#export_name("mf_add_y")
pub fn mf_add_y(handle : Int, target : Double, strength : Double) -> Unit {
  let n = get_sim(handle).nodes.n
  add_force(handle, @forces.PosY(@forces.YForce::new(n, target, strength)))
}

///|
#export_name("mf_add_radial")
pub fn mf_add_radial(
  handle : Int,
  cx : Double,
  cy : Double,
  radius : Double,
  strength : Double,
) -> Unit {
  let n = get_sim(handle).nodes.n
  add_force(
    handle,
    @forces.Radial(@forces.RadialForce::new(n, cx, cy, radius, strength)),
  )
}
