///|
fn make_tree(points : Array[(Double, Double)]) -> @quadtree.Quadtree {
  let tree = @quadtree.Quadtree::new()
  for i, p in points {
    let (x, y) = p
    ignore(tree.add(x, y, i))
  }
  tree
}

///|
fn fail_test(msg : String) -> Unit raise {
  @test.fail(msg)
}

///|
test "空树 add 单点：根为叶" {
  let tree = make_tree([(5.5, 5.5)])
  let (x0, y0, x1, y1) = tree.extent()
  // cover: floor(5.5)=5 → [5,6)×[5,6)
  @test.assert_eq(x0, 5.0)
  @test.assert_eq(y0, 5.0)
  @test.assert_eq(x1, 6.0)
  @test.assert_eq(y1, 6.0)
  match tree.root {
    Some(@quadtree.Leaf(l)) => @test.assert_eq(l.idx, 0)
    _ => fail_test("root should be leaf")
  }
}

///|
test "cover 扩展：范围翻倍、根变内部节点" {
  let tree = make_tree([(0.5, 0.5), (5.5, 5.5)])
  let (x0, y0, x1, y1) = tree.extent()
  // 第一点 [0,1)×[0,1)；第二点 (5.5,5.5) 在右下外侧：i=0（旧树挂左上槽）
  // d3 cover: z=1→2, x1 = x0+2 = 2 → 仍不覆盖；z=4, x1=4 → 不覆盖；z=8, x1=8 → 覆盖
  @test.assert_eq(x0, 0.0)
  @test.assert_eq(y0, 0.0)
  @test.assert_eq(x1, 8.0)
  @test.assert_eq(y1, 8.0)
  assert_true(tree.root is Some(@quadtree.Branch(_)))
}

///|
test "重合点：叶链表新点为表头" {
  let tree = make_tree([(1.5, 1.5), (1.5, 1.5), (1.5, 1.5)])
  match tree.root {
    Some(@quadtree.Leaf(l)) => {
      @test.assert_eq(l.idx, 2) // 最后加入的是表头
      let l1 = l.next.unwrap()
      @test.assert_eq(l1.idx, 1)
      let l2 = l1.next.unwrap()
      @test.assert_eq(l2.idx, 0)
      assert_true(l2.next is None)
    }
    _ => fail_test("root should be leaf with next chain")
  }
}

///|
test "不同点分裂：两叶挂同一内部节点" {
  // 同 cell 内两点 (1.1,1.1) (1.9,1.9)：cell [1,2)×[1,2)，中点 1.5
  // 点1 右下 (1.1<1.5? x=1.1→left, y=1.1→top) → 象限 0；点2 (1.9,1.9) → 象限 3
  let tree = make_tree([(1.1, 1.1), (1.9, 1.9)])
  match tree.root {
    Some(@quadtree.Branch(b)) => {
      assert_true(b.children[0] is Some(@quadtree.Leaf(_)))
      assert_true(b.children[1] is None)
      assert_true(b.children[2] is None)
      assert_true(b.children[3] is Some(@quadtree.Leaf(_)))
    }
    _ => fail_test("root should be branch")
  }
}

///|
test "visit 先序顺序：子象限 0,1,2,3" {
  // 4 点分居 4 象限：范围 [0,4)×[0,4)
  let tree = @quadtree.Quadtree::new()
  ignore(tree.add(0.5, 0.5, 0)) // 象限 0（左上）
  ignore(tree.add(3.5, 0.5, 1)) // 象限 1（右上）
  ignore(tree.add(0.5, 3.5, 2)) // 象限 2（左下）
  ignore(tree.add(3.5, 3.5, 3)) // 象限 3（右下）
  let order : Array[Int] = []
  tree.visit(quad => {
    match quad.node {
      Leaf(l) => order.push(l.idx)
      Branch(_) => ()
    } // 不剪枝
    false
  })
  @test.assert_eq(order, [0, 1, 2, 3])
}

///|
test "visit 剪枝：返回 true 不深入" {
  let tree = @quadtree.Quadtree::new()
  ignore(tree.add(0.5, 0.5, 0))
  ignore(tree.add(3.5, 0.5, 1))
  ignore(tree.add(0.5, 3.5, 2))
  ignore(tree.add(3.5, 3.5, 3))
  let visited : Array[Int] = []
  tree.visit(quad => {
    match quad.node {
      Leaf(l) => visited.push(l.idx)
      Branch(_) => visited.push(-1)
    }
    quad.x1 - quad.x0 <= // 根（宽度 4）直接剪枝
    4.0
  })
  // 只访问根 branch，不深入任何子节点
  @test.assert_eq(visited, [-1])
}

///|
test "visitAfter 自底向上" {
  let tree = @quadtree.Quadtree::new()
  ignore(tree.add(0.5, 0.5, 0))
  ignore(tree.add(3.5, 0.5, 1))
  ignore(tree.add(0.5, 3.5, 2))
  ignore(tree.add(3.5, 3.5, 3))
  let order : Array[Int] = []
  tree.visit_after(quad => {
    match quad.node {
      Leaf(l) => order.push(l.idx)
      Branch(_) => order.push(-1)
    }
  })
  // 收集序（先序 3,2,1,0）：root, 叶3, 叶2, 叶1, 叶0 → 逆序回调：叶0, 叶1, 叶2, 叶3, root
  @test.assert_eq(order, [0, 1, 2, 3, -1])
}

///|
test "build 批量构建与 NaN 跳过" {
  let xs : FixedArray[Double] = [0.5, 3.5, @double.not_a_number, 0.5, 3.5]
  let ys : FixedArray[Double] = [0.5, 0.5, 1.0, 0.5, 3.5]
  let tree = @quadtree.Quadtree::build(xs, ys)
  // NaN 点不参与 extent
  let (x0, y0, x1, y1) = tree.extent()
  @test.assert_eq(x0, 0.0)
  @test.assert_eq(y0, 0.0)
  @test.assert_eq(x1, 4.0)
  @test.assert_eq(y1, 4.0)
  // 有效点：(0.5,0.5) (3.5,0.5) (0.5,0.5) (3.5,3.5)；(0.5,0.5) 重合两次（idx 0 与 3）
  let leaf_count = {
    let count : Array[Int] = []
    tree.visit(quad => {
      match quad.node {
        Leaf(l) => {
          let mut c = 1
          let mut cur = l.next
          while cur is Some(next_leaf) {
            c = c + 1
            cur = next_leaf.next
          }
          count.push(c)
        }
        Branch(_) => ()
      }
      false
    })
    count
  }
  // 象限 0：2 个重合点（0 和 3）；象限 1：1 个（idx 1）；象限 2：空；象限 3：1 个（idx 4）
  @test.assert_eq(leaf_count, [2, 1, 1])
}
