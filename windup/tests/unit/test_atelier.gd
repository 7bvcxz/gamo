extends "res://tests/framework/test_case.gd"

## The rules (src/game/atelier.gd) against data/balance.json.

var b: Balance


func before_each() -> void:
	b = Balance.load_default()


func _turns(a: Atelier, n: int) -> void:
	for i in n:
		a.wind()
		a.tick(1.0 / b.max_turns_per_second + 0.001)


func test_balance_data_is_usable() -> void:
	assert_eq(b.problems(), [] as Array[String], "balance.json problems")
	assert_eq(b.positions.size(), b.doll_count(), "a place for every doll")
	var bad := Balance.from_dict({"wind": {"energy_per_turn": 1, "gear_bonus_per_doll": 0, "max_turns_per_second": 2,
		"hold_turns_per_second": 3, "hold_delay": 0}, "awaken_seconds": 1, "hint_idle_seconds": 1,
		"idle_report_seconds": 1, "autosave_seconds": 1,
		"dolls": [{"cost": 10, "rate": 1, "pos": [0, 0]}, {"cost": 5, "rate": 1, "pos": [0, 0]}],
		"stages": [{"dolls": 1, "name": "x"}]})
	assert_eq(bad.problems().size(), 3, "hold above cap, falling costs, first stage not at 0")


func test_a_turn_adds_wind_power_and_the_cap_refuses_faster_turns() -> void:
	var a := Atelier.new(b)
	assert_eq(a.wind(), b.energy_per_turn, "first turn")
	assert_eq(a.wind(), 0.0, "same instant: refused")
	assert_eq(a.blocked, 1, "blocked counted")
	a.tick(1.0 / b.max_turns_per_second)
	assert_eq(a.wind(), b.energy_per_turn, "after 1/cap seconds: accepted")
	assert_eq(a.turns, 2, "turns")


func test_the_first_doll_wakes_at_its_cost_and_then_works() -> void:
	var a := Atelier.new(b)
	var woke: Array[int] = []
	a.awakening.connect(func(i: int) -> void: woke.append(i))
	var need := int(ceil(b.costs[0] / b.energy_per_turn))
	_turns(a, need - 1)
	assert_eq(woke, [] as Array[int], "not yet")
	_turns(a, 1)
	assert_eq(woke, [0] as Array[int], "awakening starts when the cost is covered")
	assert_eq(a.waking, 0, "doll 0 is waking")
	assert_eq(a.auto_rate(), 0.0, "a waking doll does not work yet")
	a.tick(b.awaken_seconds)
	assert_eq(a.awake, 1, "awake after the wake-up")
	assert_eq(a.auto_rate(), b.rates[0], "and working")
	assert_eq(a.stage, 1, "first stage")
	assert_near(a.wind_power(), b.energy_per_turn * (1.0 + b.gear_bonus_per_doll), 1e-9, "the gear train adds power")


func test_energy_is_accounted_exactly() -> void:
	var a := Atelier.new(b)
	for i in 3000:
		if i % 3 != 0:
			a.wind()
		a.tick(0.1)
		if absf(a.accounted_energy() - a.energy) > 1e-6:
			fail("energy drifted at step %d: %f vs %f" % [i, a.energy, a.accounted_energy()])
			return
	assert_true(a.awake >= 3, "several dolls woke in 300 s (%d)" % a.awake)
	assert_true(a.energy >= 0.0, "never negative")


func test_dolls_wake_in_order_one_at_a_time() -> void:
	var a := Atelier.new(b)
	var order: Array[int] = []
	# The lambda must not hold `a` itself: atelier -> callable -> atelier is a
	# cycle that leaks at exit (AGENTS.md, 2026-11-01).
	a.awakening.connect(func(i: int) -> void: order.append(i))
	a.energy = b.costs[0] + b.costs[1] + b.costs[2]
	a.manual_energy = a.energy
	a.tick(0.01)
	assert_eq(order, [0] as Array[int], "only one wakes at a time")
	for i in 4:
		a.tick(b.awaken_seconds)
	assert_eq(order, [0, 1, 2] as Array[int], "the rest follow, in order")


func test_save_round_trip_and_repair() -> void:
	var a := Atelier.new(b)
	_turns(a, 120)
	a.tick(0.4)
	var d := a.to_dict()
	var c := Atelier.new(b)
	c.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(c.awake, a.awake, "awake")
	assert_near(c.energy, a.energy, 1e-6, "energy")
	assert_eq(c.waking, a.waking, "waking")
	var bad := Atelier.new(b)
	bad.from_dict({"awake": 99, "energy": -5, "waking": 3})
	assert_eq(bad.awake, b.doll_count(), "awake clamped")
	assert_eq(bad.energy, 0.0, "energy clamped")
	assert_eq(bad.waking, -1, "an impossible waking doll is dropped")
	assert_near(bad.accounted_energy(), bad.energy, 1e-9, "accounting repaired")
