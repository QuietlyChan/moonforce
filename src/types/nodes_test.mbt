///|
test "NodePool 初始化规模与速度清零" {
  let pool = @types.NodePool::init(10)
  @test.assert_eq(pool.n, 10)
  for i in 0..<10 {
    assert_false(pool.vxs[i].is_nan())
    assert_false(pool.vys[i].is_nan())
    assert_false(pool.xs[i].is_nan())
    assert_false(pool.ys[i].is_nan())
  }
}

///|
test "phyllotaxis 第一个节点位于 (10*sqrt(0.5), 0)" {
  // d3: radius = 10*sqrt(0.5), angle = 0 → x=radius, y≈0
  let pool = @types.NodePool::init(1)
  assert_true((pool.xs[0] - 10.0 * 0.5.sqrt()).abs() < 1.0e-12)
  assert_true(pool.ys[0].abs() < 1.0e-12)
}

///|
test "set_fixed 固定与解除语义" {
  let pool = @types.NodePool::init(4)
  pool.set_fixed(2, 100.0, 50.0)
  @test.assert_eq(pool.xs[2], 100.0)
  @test.assert_eq(pool.vxs[2], 0.0)
  // 解除固定
  pool.set_fixed(2, @double.not_a_number, @double.not_a_number)
  assert_true(pool.fxs[2].is_nan())
}

///|
test "find 返回最近节点" {
  let pool = @types.NodePool::init(3)
  pool.xs[0] = 0.0
  pool.ys[0] = 0.0
  pool.xs[1] = 5.0
  pool.ys[1] = 0.0
  pool.xs[2] = 10.0
  pool.ys[2] = 0.0
  @test.assert_eq(pool.find(5.5, 0.0, 2.0), 1)
  @test.assert_eq(pool.find(100.0, 0.0, 2.0), -1)
}
