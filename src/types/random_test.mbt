///|
test "lcg 与 d3-force 位精确对齐（参考值由 JS lcg 生成）" {
  let r = @types.Lcg::new()
  // s=1 → 1015568748 → /2^32
  @test.assert_eq(r.next(), 0.23645552527159452)
  @test.assert_eq(r.next(), 0.3692706737201661)
  @test.assert_eq(r.next(), 0.5042420323006809)
  @test.assert_eq(r.next(), 0.7048832636792213)
  @test.assert_eq(r.next(), 0.05054362863302231)
  @test.assert_eq(r.next(), 0.3695183543022722)
}

///|
test "lcg 满流回绕（mod 2^32）正确性" {
  // s=0：1664525*0+1013904223 = 1013904223
  let r = @types.Lcg::with_seed(0)
  @test.assert_eq(r.next(), 1013904223.0 / 4294967296.0)
}

///|
test "jiggle 幅度为 1e-6 量级" {
  let r = @types.Lcg::new()
  let j = @types.jiggle(r)
  assert_true(j <= 0.5 * 1.0e-6)
  assert_true(j >= -0.5 * 1.0e-6)
}
