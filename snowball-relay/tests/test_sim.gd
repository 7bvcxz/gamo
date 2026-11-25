extends SceneTree
# Headless rules test. godot --headless --path snowball-relay --script res://tests/test_sim.gd
const Sim := preload("res://scripts/Sim.gd")
var fails: int = 0

func ok(c: bool, msg: String) -> void:
	if c:
		print("ok   ", msg)
	else:
		print("FAIL ", msg)
		fails += 1

func run(s: RefCounted, secs: float) -> void:
	for i in int(secs * 60.0):
		s.step(1.0 / 60.0)

func _init() -> void:
	# a fresh game: first push gives snow almost at once and the ball stops by itself
	var s: RefCounted = Sim.new(7)
	ok(s.snow == 0.0 and s.speed == 0.0 and s.mass == 1.0, "fresh state")
	s.push(0.8)
	run(s, 0.6)
	ok(s.snow > 0.0, "snow arrives within 0.6 s of the first push (%.2f)" % s.snow)
	run(s, 6.0)
	ok(s.speed == 0.0, "the ball stops on its own")
	ok(s.last_roll_len > 2.0 and s.last_roll_len < 4.5, "starting roll lasts about 3 s (%.2f)" % s.last_roll_len)
	ok(s.dist > 3.0, "it travelled after release (%.1f units)" % s.dist)
	# nothing is lost while waiting
	var before: float = s.snow
	run(s, 30.0)
	var mass_before: float = s.mass
	run(s, 5.0)
	ok(s.snow == before and s.mass == mass_before, "waiting costs nothing")
	# mass is a state, never spent
	var m0: float = s.mass
	s.snow = 1000.0
	s.buy(1)
	ok(s.mass == m0, "buying does not touch mass")
	# can't buy what you can't afford; cost rises
	var p: RefCounted = Sim.new(7)
	ok(not p.buy(0), "unaffordable upgrade refused")
	ok(p.cost(0) == 8.0, "first Mass costs 8")
	p.snow = 100.0
	ok(p.buy(0) and p.cost(0) > 8.0 and p.snow == 92.0, "buying spends snow and raises the price")
	# momentum lengthens the roll, measurably
	var a: RefCounted = Sim.new(7)
	var b: RefCounted = Sim.new(7)
	b.lv[2] = 5
	a.push(1.0)
	b.push(1.0)
	run(a, 60.0)
	run(b, 60.0)
	ok(b.last_roll_len > a.last_roll_len * 2.0, "Momentum 5 more than doubles the roll (%.1f vs %.1f s)" % [b.last_roll_len, a.last_roll_len])
	ok(b.dist > a.dist, "and it goes farther")
	# soft saturation: spamming gains much less than its input count suggests
	var calm: RefCounted = Sim.new(7)
	var spam: RefCounted = Sim.new(7)
	var elapsed: float = 0.0
	while elapsed < 30.0:
		if calm.speed <= 0.0:
			calm.push(0.8)
		spam.push(0.8)   # every 1/10 s
		for i in 6:
			calm.step(1.0 / 60.0)
			spam.step(1.0 / 60.0)
		elapsed += 0.1
	ok(spam.pushes > calm.pushes * 10, "scenario: spam really pushed far more often (%d vs %d)" % [spam.pushes, calm.pushes])
	ok(spam.speed <= spam.vcap() + 0.001, "speed never exceeds the cap (%.1f <= %.1f)" % [spam.speed, spam.vcap()])
	ok(spam.earned < calm.earned * 4.0, "spam earns less than 4x a relaxed player (%.0f vs %.0f)" % [spam.earned, calm.earned])
	# props: always broken, always pay
	var q: RefCounted = Sim.new(7)
	q.push(1.0)
	run(q, 10.0)
	ok(q.breaks >= 1, "props break as it rolls (%d)" % q.breaks)
	# big frames do not teleport: one 10 s step equals many small ones
	var x: RefCounted = Sim.new(7)
	var y: RefCounted = Sim.new(7)
	x.push(1.0)
	y.push(1.0)
	x.step(10.0)
	run(y, 10.0)
	ok(absf(x.dist - y.dist) < 0.5, "step size does not change the result")
	print("FAILS: ", fails)
	quit(fails)
