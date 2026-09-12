///|
/// 四叉树节点：Branch（恒 4 槽）或 Leaf（点 + 重合点链表）。
///
/// 对齐 d3-quadtree 的「数组=内部节点 / {data,next}=叶节点」鸭子类型，
/// Leaf 存建树时的坐标快照（用于分裂判断，等价 d3 的 tree._x(data)），
/// idx 为节点池索引（等价 d3 的 data）。
///
/// 聚合缓存字段（value/cx/cy/r）挂在节点上而非 visit 包装上，
/// 对齐 d3 在 quad 对象上就地写聚合值的用法（Barnes-Hut 自底向上聚合）。
pub enum QNode {
  Leaf(QLeaf)
  Branch(QBranch)
}

///|
/// 内部节点：4 槽 + 聚合缓存。
pub struct QBranch {
  children : FixedArray[QNode?]
  mut value : Double // manyBody：聚合电荷
  mut cx : Double // manyBody：聚合质心 x
  mut cy : Double // manyBody：聚合质心 y
  mut r : Double // collide：子树最大半径
}

///|
/// 叶节点：坐标快照 + 重合点链表 + 聚合缓存。
pub struct QLeaf {
  x : Double // 建树时坐标快照
  y : Double
  idx : Int // 节点池索引（d3 的 data）
  mut next : QLeaf? // 重合点链表：新点为表头
  mut value : Double
  mut cx : Double
  mut cy : Double
  mut r : Double // collide：该点半径
}

///|
fn new_branch() -> QBranch {
  { children: FixedArray::make(4, None), value: 0.0, cx: 0.0, cy: 0.0, r: 0.0, }
}

///|
fn new_leaf(x : Double, y : Double, idx : Int) -> QLeaf {
  { x, y, idx, next: None, value: 0.0, cx: 0.0, cy: 0.0, r: 0.0, }
}

///|
/// visit / visitAfter 回调的包装节点（边界 + 节点引用）。
/// 聚合值通过 node 上的聚合字段访问。
pub struct Quad {
  node : QNode
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
/// d3-quadtree 语义的松散四叉树。
pub struct Quadtree {
  mut root : QNode?
  mut x0 : Double
  mut y0 : Double
  mut x1 : Double
  mut y1 : Double
}

///|
pub fn Quadtree::new() -> Quadtree {
  {
    root: None,
    x0: @double.not_a_number,
    y0: @double.not_a_number,
    x1: @double.not_a_number,
    y1: @double.not_a_number,
  }
}

///|
fn qnode_is_branch(node : QNode) -> Bool {
  match node {
    Branch(_) => true
    Leaf(_) => false
  }
}

///|
/// 获取 Branch 的 4 槽数组。
pub fn Quad::children(self : Quad) -> FixedArray[QNode?] {
  match self.node {
    Branch(b) => b.children
    Leaf(_) => abort("children on leaf")
  }
}

///|
/// 是否内部节点（对齐 d3 的 quad.length > 0）。
pub fn Quad::is_branch(self : Quad) -> Bool {
  qnode_is_branch(self.node)
}

///|
/// 叶节点数据（idx + next 链表）。仅叶节点有效。
pub fn Quad::leaf_data(self : Quad) -> QLeaf? {
  match self.node {
    Leaf(l) => Some(l)
    Branch(_) => None
  }
}

///|
/// —— 聚合字段访问器（供 forces 读写）——
pub fn QNode::aggr_value(self : QNode) -> Double {
  match self {
    Branch(b) => b.value
    Leaf(l) => l.value
  }
}

///|
pub fn QNode::set_aggr_value(self : QNode, v : Double) -> Unit {
  match self {
    Branch(b) => b.value = v
    Leaf(l) => l.value = v
  }
}

///|
pub fn QNode::aggr_cx(self : QNode) -> Double {
  match self {
    Branch(b) => b.cx
    Leaf(l) => l.cx
  }
}

///|
pub fn QNode::set_aggr_cx(self : QNode, v : Double) -> Unit {
  match self {
    Branch(b) => b.cx = v
    Leaf(l) => l.cx = v
  }
}

///|
pub fn QNode::aggr_cy(self : QNode) -> Double {
  match self {
    Branch(b) => b.cy
    Leaf(l) => l.cy
  }
}

///|
pub fn QNode::set_aggr_cy(self : QNode, v : Double) -> Unit {
  match self {
    Branch(b) => b.cy = v
    Leaf(l) => l.cy = v
  }
}

///|
pub fn QNode::aggr_r(self : QNode) -> Double {
  match self {
    Branch(b) => b.r
    Leaf(l) => l.r
  }
}

///|
pub fn QNode::set_aggr_r(self : QNode, v : Double) -> Unit {
  match self {
    Branch(b) => b.r = v
    Leaf(l) => l.r = v
  }
}

///|
/// 对齐 d3-quadtree cover.js：扩展树范围以覆盖 (x, y)。
///
/// 初始范围从 floor(x)/floor(y) 的整数单元起步（保证后续翻倍时
/// 象限边界不因浮点误差漂移）；之后按象限向外翻倍。
pub fn Quadtree::cover(self : Quadtree, x : Double, y : Double) -> Quadtree {
  if x.is_nan() || y.is_nan() {
    return self
  }
  let mut x0 = self.x0
  let mut y0 = self.y0
  let mut x1 = self.x1
  let mut y1 = self.y1
  if x0.is_nan() {
    // 首次：整数单元
    x0 = @double.floor(x)
    y0 = @double.floor(y)
    x1 = x0 + 1.0
    y1 = y0 + 1.0
  } else {
    let mut z = if x1 - x0 == 0.0 { 1.0 } else { x1 - x0 }
    let mut node : QNode? = self.root
    while x0 > x || x >= x1 || y0 > y || y >= y1 {
      let i = (if y < y0 { 2 } else { 0 }) + (if x < x0 { 1 } else { 0 })
      let parent = new_branch()
      parent.children[i] = node
      node = Some(Branch(parent))
      z = z * 2.0
      if i == 0 {
        x1 = x0 + z
        y1 = y0 + z
      } else if i == 1 {
        x0 = x1 - z
        y1 = y0 + z
      } else if i == 2 {
        x1 = x0 + z
        y0 = y1 - z
      } else {
        x0 = x1 - z
        y0 = y1 - z
      }
    }
    // 只有当根已是内部节点时才替换（leaf 根不依赖范围）
    match self.root {
      Some(node_root) => if qnode_is_branch(node_root) { self.root = node }
      None => ()
    }
  }
  self.x0 = x0
  self.y0 = y0
  self.x1 = x1
  self.y1 = y1
  self
}

///|
/// 对齐 d3-quadtree add.js 的内部 add（假定已 cover）。
fn Quadtree::add_internal(
  self : Quadtree,
  x : Double,
  y : Double,
  idx : Int,
) -> Quadtree {
  if x.is_nan() || y.is_nan() {
    return self
  }
  let leaf = new_leaf(x, y, idx)
  let node_opt = self.root
  let mut x0 = self.x0
  let mut y0 = self.y0
  let mut x1 = self.x1
  let mut y1 = self.y1
  // 空树：根即叶
  if node_opt is None {
    self.root = Some(Leaf(leaf))
    return self
  }
  // 沿内部节点下行，找到空槽或叶
  let mut parent : FixedArray[QNode?]? = None
  let mut i = 0
  let mut node = node_opt.unwrap()
  while qnode_is_branch(node) {
    let children = match node {
      Branch(b) => b.children
      Leaf(_) => abort("unreachable")
    }
    let xm = (x0 + x1) / 2.0
    let ym = (y0 + y1) / 2.0
    let right = x >= xm
    if right {
      x0 = xm
    } else {
      x1 = xm
    }
    let bottom = y >= ym
    if bottom {
      y0 = ym
    } else {
      y1 = ym
    }
    parent = Some(children)
    i = (if bottom { 2 } else { 0 }) + (if right { 1 } else { 0 })
    match children[i] {
      None => {
        children[i] = Some(Leaf(leaf))
        return self
      }
      Some(child) => node = child
    }
  }
  // node 现在是已存在的叶
  let old : QLeaf = match node {
    Leaf(l) => l
    Branch(_) => abort("unreachable: node is branch")
  }
  let xp = old.x
  let yp = old.y
  // 新点与已有点完全重合：新叶作为链表头
  if x == xp && y == yp {
    leaf.next = Some(old)
    match parent {
      Some(p) => p[i] = Some(Leaf(leaf))
      None => self.root = Some(Leaf(leaf))
    }
    return self
  }
  // 否则分裂旧叶直到两点分离（对齐 add.js 的 do-while）
  while true {
    let new_branch = new_branch()
    match parent {
      Some(p) => p[i] = Some(Branch(new_branch))
      None => self.root = Some(Branch(new_branch))
    }
    parent = Some(new_branch.children)
    let xm = (x0 + x1) / 2.0
    let ym = (y0 + y1) / 2.0
    let right = x >= xm
    if right {
      x0 = xm
    } else {
      x1 = xm
    }
    let bottom = y >= ym
    if bottom {
      y0 = ym
    } else {
      y1 = ym
    }
    let i_new = (if bottom { 2 } else { 0 }) + (if right { 1 } else { 0 })
    let j = (if yp >= ym { 2 } else { 0 }) + (if xp >= xm { 1 } else { 0 })
    if i_new != j {
      new_branch.children[j] = Some(Leaf(old))
      new_branch.children[i_new] = Some(Leaf(leaf))
      break
    }
    i = i_new
  }
  self
}

///|
/// 对齐 d3-quadtree add.js：add = cover + 内部 add。
pub fn Quadtree::add(
  self : Quadtree,
  x : Double,
  y : Double,
  idx : Int,
) -> Quadtree {
  ignore(self.cover(x, y))
  self.add_internal(x, y, idx)
}

///|
/// 对齐 d3-quadtree addAll：批量构建。
/// NaN 点跳过；先 cover 整个 extent（两个角点），再逐点 add。
pub fn Quadtree::build(
  xs : FixedArray[Double],
  ys : FixedArray[Double],
) -> Quadtree {
  let tree = Quadtree::new()
  let n = xs.length()
  let mut x0 = @double.infinity
  let mut y0 = @double.infinity
  let mut x1 = @double.neg_infinity
  let mut y1 = @double.neg_infinity
  for i in 0..<n {
    let x = xs[i]
    let y = ys[i]
    if x.is_nan() || y.is_nan() {
      continue
    }
    if x < x0 {
      x0 = x
    }
    if x > x1 {
      x1 = x
    }
    if y < y0 {
      y0 = y
    }
    if y > y1 {
      y1 = y
    }
  }
  if x0 > x1 || y0 > y1 {
    return tree
  }
  ignore(tree.cover(x0, y0))
  ignore(tree.cover(x1, y1))
  for i in 0..<n {
    ignore(tree.add_internal(xs[i], ys[i], i))
  }
  tree
}

///|
fn make_quad(
  node : QNode,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Quad {
  { node, x0, y0, x1, y1, }
}

///|
/// 对齐 d3-quadtree visit.js：先序遍历，子象限按 0,1,2,3 顺序。
/// callback 返回 true 时不再深入该节点（剪枝）。
pub fn Quadtree::visit(self : Quadtree, callback : (Quad) -> Bool) -> Unit {
  match self.root {
    None => ()
    Some(root) => {
      let stack : Array[Quad] = [
        make_quad(root, self.x0, self.y0, self.x1, self.y1),
      ]
      while stack.length() > 0 {
        let quad = stack.pop().unwrap()
        let node = quad.node
        let prune = callback(quad)
        // d3: if (!callback(...) && node.length) → 返回 false 且是内部节点才深入
        if !prune && qnode_is_branch(node) {
          let children = match node {
            Branch(b) => b.children
            Leaf(_) => abort("unreachable")
          }
          let x0 = quad.x0
          let y0 = quad.y0
          let x1 = quad.x1
          let y1 = quad.y1
          let xm = (x0 + x1) / 2.0
          let ym = (y0 + y1) / 2.0
          // push 3,2,1,0 → pop 顺序 0,1,2,3
          push_child(stack, children, 3, xm, ym, x1, y1)
          push_child(stack, children, 2, x0, ym, xm, y1)
          push_child(stack, children, 1, xm, y0, x1, ym)
          push_child(stack, children, 0, x0, y0, xm, ym)
        }
      }
    }
  }
}

///|
fn push_child(
  stack : Array[Quad],
  children : FixedArray[QNode?],
  slot : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  match children[slot] {
    None => ()
    Some(node) => stack.push(make_quad(node, x0, y0, x1, y1))
  }
}

///|
/// 对齐 d3-quadtree visitAfter.js：先按 3,2,1,0 的先序收集，
/// 再逆序回调（自底向上）。
pub fn Quadtree::visit_after(
  self : Quadtree,
  callback : (Quad) -> Unit,
) -> Unit {
  match self.root {
    None => ()
    Some(root) => {
      let quads : Array[Quad] = []
      let next : Array[Quad] = []
      quads.push(make_quad(root, self.x0, self.y0, self.x1, self.y1))
      while quads.length() > 0 {
        let quad = quads.pop().unwrap()
        let node = quad.node
        if qnode_is_branch(node) {
          let children = match node {
            Branch(b) => b.children
            Leaf(_) => abort("unreachable")
          }
          let x0 = quad.x0
          let y0 = quad.y0
          let x1 = quad.x1
          let y1 = quad.y1
          let xm = (x0 + x1) / 2.0
          let ym = (y0 + y1) / 2.0
          // d3 visitAfter push 顺序 0,1,2,3 → pop 顺序 3,2,1,0
          push_child(quads, children, 0, x0, y0, xm, ym)
          push_child(quads, children, 1, xm, y0, x1, ym)
          push_child(quads, children, 2, x0, ym, xm, y1)
          push_child(quads, children, 3, xm, ym, x1, y1)
        }
        next.push(quad)
      }
      // 逆序回调 = 自底向上
      while next.length() > 0 {
        callback(next.pop().unwrap())
      }
    }
  }
}

///|
/// 树范围访问器。
pub fn Quadtree::extent(self : Quadtree) -> (Double, Double, Double, Double) {
  (self.x0, self.y0, self.x1, self.y1)
}

///|
/// 叶节点建树时的坐标快照 x（仅叶有效）。
pub fn QNode::leaf_x(self : QNode) -> Double {
  match self {
    Leaf(l) => l.x
    Branch(_) => abort("leaf_x on branch")
  }
}

///|
/// 叶节点建树时的坐标快照 y（仅叶有效）。
pub fn QNode::leaf_y(self : QNode) -> Double {
  match self {
    Leaf(l) => l.y
    Branch(_) => abort("leaf_y on branch")
  }
}

///|
/// 叶节点数据（idx + next 链表）。
pub fn QNode::leaf_data(self : QNode) -> QLeaf? {
  match self {
    Leaf(l) => Some(l)
    Branch(_) => None
  }
}
