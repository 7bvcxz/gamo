extends "res://tests/framework/test_case.gd"

## Step 06's variants: data overrides on the base, and the rules each adds.


func test_overrides_come_from_data_and_base_is_untouched() -> void:
	var base := Balance.load_variant("base")
	assert_false(base.spring_enabled or base.reveal, "base has no variant rules")
	assert_eq(base.kick_seconds, 0.0, "base has no kick")
	var a := Balance.load_variant("a")
	assert_true(a.spring_enabled, "A: the spring")
	var b := Balance.load_variant("b")
	assert_true(b.reveal, "B: the reveal")
	assert_eq(b.awaken_seconds, 3.2, "B: a longer awakening")
	var c := Balance.load_variant("c")
	assert_eq(c.kick_seconds, 10.0, "C: the kick")
	assert_eq(c.awaken_seconds, 0.9, "C: a short awakening")
	assert_near(c.rates[0], base.rates[0] * 1.25, 1e-9, "C: dolls work harder")
	for v: Balance in [a, b, c]:
		assert_eq(Array(v.costs), Array(base.costs), "%s keeps the base costs" % v.variant)
		assert_eq(v.problems(), [] as Array[String], "%s data usable" % v.variant)


func test_a_spring_holds_energy_until_let_go() -> void:
	var b := Balance.load_variant("a")
	var at := Atelier.new(b)
	for i in 30:
		assert_true(at.wind() > 0.0, "turn %d coils the spring" % i)
		at.tick(0.2)
	assert_eq(at.energy, 0.0, "nothing delivered while wound")
	assert_near(at.spring, 30.0, 1e-9, "the spring holds 30")
	assert_near(at.release(), 30.0, 1e-9, "letting go releases it")
	assert_near(at.energy, 30.0, 1e-9, "as energy")
	assert_eq(at.spring, 0.0, "the spring is slack")
	for i in 200:
		at.wind()
		at.tick(0.2)
	assert_near(at.spring, at.spring_capacity(), 1e-9, "the spring stops at the next doll's cost")
	assert_true(at.spring_full_refusals > 0, "turns past full are refused")
	at.release()
	at.tick(0.01)
	assert_true(at.waking == 0 or at.awake == 1, "a full spring let go wakes the doll")
	assert_near(at.accounted_energy(), at.energy, 1e-6, "accounting holds with a spring")


func test_c_a_new_doll_kicks_the_next() -> void:
	var b := Balance.load_variant("c")
	var at := Atelier.new(b)
	var kicks: Array = []
	at.kicked.connect(func(i: int, e: float) -> void: kicks.append([i, e]))
	at.energy = b.costs[0]
	at.manual_energy = at.energy
	at.tick(0.01)
	at.tick(b.awaken_seconds)
	assert_eq(at.awake, 1, "awake")
	assert_eq(kicks.size(), 1, "one kick")
	assert_near(float(kicks[0][1]), b.rates[0] * b.kick_seconds, 1e-9, "rate x kick_seconds")
	assert_near(at.accounted_energy(), at.energy, 1e-6, "the kick is accounted as automatic energy")


func test_b_reveal_timeline() -> void:
	for g in 5:
		var tl := DollRig.reveal_timeline(g)
		assert_eq(float(tl[tl.size() - 1][0]), 3.2, "gesture %d ends at 3.2 s" % g)
		for key: Array in tl:
			assert_true(DollRig.POSES.has(key[1]) or DollRig.GESTURE_POSES.has(key[1]), "pose %s exists" % key[1])
