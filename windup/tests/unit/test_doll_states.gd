extends "res://tests/framework/test_case.gd"

## The doll state machine (Atelier.doll_state): DORMANT -> WINDING ->
## AWAKENING -> WORKING, forward only, each doll once; costs paid once.

const ORDER := ["DORMANT", "WINDING", "AWAKENING", "WORKING"]


func test_states_only_move_forward_and_each_doll_wakes_once() -> void:
	var b := Balance.load_default()
	var a := Atelier.new(b)
	var woke: Array[int] = []
	a.awakening.connect(func(i: int) -> void: woke.append(i))
	var last: Array[int] = []
	for i in b.doll_count():
		last.append(0)
	for step in 30000:
		if step % 2 == 0:
			a.wind()
		a.tick(0.1)
		for i in b.doll_count():
			var s := ORDER.find(a.doll_state(i))
			if s < last[i]:
				fail("doll %d went back from %s to %s at step %d" % [i, ORDER[last[i]], ORDER[s], step])
				return
			last[i] = s
		if a.awake == b.doll_count():
			break
	assert_eq(a.awake, b.doll_count(), "everyone woke within 50 minutes of half-speed winding")
	var expect: Array[int] = []
	for i in b.doll_count():
		expect.append(i)
	assert_eq(woke, expect, "each doll woke exactly once, in order")
	var paid := 0.0
	for c in b.costs:
		paid += c
	assert_near(a.spent, paid, 1e-6, "every cost paid exactly once")
	assert_eq(a.doll_state(0), "WORKING", "the first is working")


func test_boundaries_zero_nearly_exact() -> void:
	var b := Balance.load_default()
	var a := Atelier.new(b)
	assert_eq(a.doll_state(0), "WINDING", "at 0 energy the first doll is the one being wound")
	assert_eq(a.doll_state(1), "DORMANT", "the rest sleep")
	a.energy = b.costs[0] - 0.001
	a.manual_energy = a.energy
	a.tick(0.0001)
	assert_eq(a.doll_state(0), "WINDING", "nearly enough is not enough")
	a.energy = b.costs[0]
	a.manual_energy = a.energy
	a.tick(0.0001)
	assert_eq(a.doll_state(0), "AWAKENING", "exactly the cost wakes it")
	assert_true(a.energy >= 0.0 and a.energy < 0.01, "and leaves ~0, never negative")
