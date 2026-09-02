///|
test "alpha 衰减与 velocity decay" {
  let sim = @simulation.Simulation::new(3)
  @test.assert_eq(sim.alpha, 1.0)
  ignore(sim.tick(1))
  // alpha1 = 1 + (0 - 1) * 0.02276277904418933
  assert_true((sim.alpha - 0.9772372209558107).abs() < 1.0e-15)
  // 无力 + phyllotaxis 初始 → tick 后 vx 衰减
  // vx0 = 0 → 0 * 0.6 = 0；x 不动
  @test.assert_eq(sim.nodes.xs[0], 10.0 * 0.5.sqrt())
}

///|
test "velocityDecay friction 语义（传入 0.4 → 内部 0.6）" {
  let sim = @simulation.Simulation::new(2)
  ignore(sim.set_velocity_decay(0.4))
  @test.assert_eq(sim.velocity_decay, 0.6)
}

///|
test "stop 置零 alpha" {
  let sim = @simulation.Simulation::new(2)
  ignore(sim.stop())
  @test.assert_eq(sim.alpha, 0.0)
  ignore(sim.restart(1.0))
  @test.assert_eq(sim.alpha, 1.0)
}

///|
test "tick 三步顺序：单节点 manyBody 不自排斥" {
  // d3 语义：`quad.data !== node || quad.next` 均不满足 → 不 jiggle、无力
  let sim = @simulation.Simulation::new(1)
  ignore(
    sim.add_force(@forces.Force::ManyBody(@forces.ManyBodyForce::new(1, -30.0))),
  )
  let x0 = 10.0 * 0.5.sqrt()
  ignore(sim.tick(10))
  @test.assert_eq(sim.nodes.xs[0], x0) // 位置完全不动
  @test.assert_eq(sim.nodes.vxs[0], 0.0)
}
