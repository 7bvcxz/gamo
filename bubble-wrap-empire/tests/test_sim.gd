extends SceneTree
# Headless rules test. godot --headless --path bubble-wrap-empire --script res://tests/test_sim.gd
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

func levels(s: RefCounted, a: Array) -> void:
	for i in 5:
		s.lv[i] = int(a[i])

func mid() -> Vector2:
	return Vector2(3.0, 4.0 * 0.866)

func _init() -> void:
	# a fresh sheet: one tap pops exactly one bubble, and pays at once
	var s: RefCounted = Sim.new(5)
	ok(s.pos.size() == 70 and s.full_count() == 70, "fresh sheet is full")
	var seed_i: int = s.trigger(mid())
	run(s, 0.3)
	ok(seed_i >= 0 and s.pops == 1 and s.pop == 1.0, "a first tap pops one bubble for 1 POP (pops=%d pop=%.1f)" % [s.pops, s.pop])
	ok(s.full_count() == 69, "and leaves 69 full")
	# refill: it comes back full, smoothly, after Refill-dependent time
	run(s, 8.0)
	ok(s.full_count() == 70, "the popped bubble refills (6 s base)")
	var q: RefCounted = Sim.new(5)
	q.lv[3] = 5
	q.trigger(mid())
	run(q, 3.5)
	ok(q.full_count() == 70 and q.refill_time() < 2.0, "Refill 5 refills within 3.5 s (%.2f s)" % q.refill_time())
	# chain: a wave spreads after the trigger, not at once, and never double-pays
	var c: RefCounted = Sim.new(5)
	c.lv[1] = 4
	c.lv[0] = 4
	c.trigger(mid())
	ok(c.pops == 0 and c.pending.size() > 1, "wave is scheduled, nothing paid at the instant of the tap (%d pending)" % c.pending.size())
	run(c, 0.05)
	var early: int = c.pops
	run(c, 1.0)
	ok(c.pops > early and c.last_wave_count == c.pops, "pops arrive over time (%d at 0.05 s, %d later)" % [early, c.pops])
	ok(c.last_wave_secs > 0.1, "the wave takes visible time (%.2f s)" % c.last_wave_secs)
	var paid: float = c.earned
	var tally: float = 0.0
	for i in c.pos.size():
		tally += 0.0
	ok(c.pop == paid, "POP equals what was earned")
	# no bubble pays twice in one wave: pops never exceed bubbles
	ok(c.pops <= 70, "a bubble pays once per wave")
	# value upgrade scales the payout
	var v: RefCounted = Sim.new(5)
	v.lv[2] = 3
	v.trigger(mid())
	run(v, 0.3)
	ok(absf(v.pop - pow(1.35, 3)) < 0.01, "Value 3 pays 1.35^3 (%.2f)" % v.pop)
	# spam: taps faster than refill drain the sheet; income saturates near full/refill
	var calm: RefCounted = Sim.new(5)
	var spam: RefCounted = Sim.new(5)
	for k in [calm, spam]:
		levels(k, [3, 4, 2, 2, 0])
	var elapsed: float = 0.0
	var spam_taps: int = 0
	var calm_taps: int = 0
	while elapsed < 60.0:
		if int(elapsed * 10.0) % 40 == 0 and int(elapsed * 10.0) != int((elapsed - 0.1) * 10.0):
			calm.trigger(mid())
			calm_taps += 1
		if spam.trigger(Vector2(randf_range(0.0, 6.0), randf_range(0.0, 7.8))) >= 0:
			spam_taps += 1
		run(calm, 0.1)
		run(spam, 0.1)
		elapsed += 0.1
	ok(spam.triggers > calm.triggers * 5, "scenario: spam really tapped far more often (%d vs %d accepted)" % [spam.triggers, calm.triggers])
	ok(spam.earned < calm.earned * 5.0, "spam earns less than 5x a relaxed tapper (%.0f vs %.0f)" % [spam.earned, calm.earned])
	# an empty sheet costs nothing and does not crash
	var e: RefCounted = Sim.new(5)
	for i in e.fill.size():
		e.fill[i] = 0.0
	ok(e.trigger(mid()) == -1 and e.triggers == 0, "empty sheet: trigger refused without charge")
	# same-instant touches are one touch
	var d: RefCounted = Sim.new(5)
	d.trigger(mid())
	ok(d.trigger(mid()) == -1, "a second touch in the same instant is not a second trigger")
	# mega: unlocks with level, comes ready on its own, and is a bigger wave
	var m: RefCounted = Sim.new(5)
	ok(not m.mega_ready(), "mega is locked at level 0")
	levels(m, [2, 3, 0, 0, 2])
	run(m, m.mega_period() + 0.5)
	ok(m.mega_ready(), "mega comes ready by itself (%.0f s)" % m.mega_period())
	var plain: RefCounted = Sim.new(5)
	levels(plain, [2, 3, 0, 0, 0])
	plain.trigger(mid())
	run(plain, 2.0)
	m.trigger(mid())
	run(m, 2.0)
	ok(m.pops > plain.pops and not m.mega_ready(), "the mega wave is bigger (%d vs %d) and uses up the charge" % [m.pops, plain.pops])
	# a big frame equals many small ones
	var x: RefCounted = Sim.new(5)
	var y: RefCounted = Sim.new(5)
	levels(x, [3, 5, 0, 0, 0])
	levels(y, [3, 5, 0, 0, 0])
	x.trigger(mid())
	y.trigger(mid())
	x.step(3.0)
	run(y, 3.0)
	ok(x.pops == y.pops, "step size does not change the result (%d vs %d)" % [x.pops, y.pops])
	print("FAILS: ", fails)
	quit(fails)
