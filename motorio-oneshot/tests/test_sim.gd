extends SceneTree

## Drives the simulation directly, with no rendering, so the core loop is proven
## rather than assumed. Failures accumulate and the exit code is decided once.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_generation()
	_test_build_rules()
	_test_miner_to_core()
	_test_miner_rate()
	_test_belt_transport()
	_test_furnace_alloy()
	_test_economy_and_warmth()
	_test_frost_throttle()
	_test_blocked_output_preserves_work()
	if failures == 0:
		print("SIM_TEST: PASS")
	quit(failures)

## Miners are inert without an operator, so any test about mining output has to
## staff the machine first.
func _staff(sim: Sim, cell: Vector2i) -> Sim.Cat:
	var cat := Sim.Cat.new()
	cat.assigned = cell
	cat.state = Defs.CAT_WORKING
	cat.pos = sim.cell_centre(cell)
	sim.cats.append(cat)
	return cat

func _fresh() -> Sim:
	var sim := Sim.new()
	sim.setup(12345)
	return sim

func _test_generation() -> void:
	var sim := _fresh()
	var frost := 0
	var copper := 0
	for cell: Vector2i in sim.ore:
		if sim.ore[cell] == Defs.ITEM_FROST:
			frost += 1
		else:
			copper += 1
	# Ore is a fifth as dense as it was: scarcity is the point, but the guaranteed
	# seams must still make the opening and the iron recipe reachable.
	_assert(frost >= 6, "frost ore exists in workable but scarce amounts")
	_assert(copper >= 6, "copper ore exists in workable but scarce amounts")
	_assert(frost < 20 and copper < 20, "ore density stays scarce after the reduction")
	_assert(not sim.ore.has(sim.core_cell), "ore never spawns under the core")

	# Frost must be reachable at the opening radius or the first 45 seconds stall.
	var reachable := 0
	for cell: Vector2i in sim.ore:
		if sim.ore[cell] == Defs.ITEM_FROST and Vector2(cell).length() <= Defs.WARM_BASE:
			reachable += 1
	_assert(reachable > 0, "some frost ore sits inside the starting warm radius")

	# Ember must NOT be reachable at the start, or the progression has no arc.
	var early_copper := 0
	for cell: Vector2i in sim.ore:
		if sim.ore[cell] == Defs.ITEM_COPPER and Vector2(cell).length() <= Defs.WARM_BASE:
			early_copper += 1
	_assert(early_copper == 0, "copper ore starts outside the warm radius")

	# The opening must be identical every run: a patch south of the core plus a
	# clear two-tile lane to belt through. Otherwise the first minute is a search.
	for offset: Vector2i in Sim.STARTER_PATCH:
		_assert(sim.ore.get(sim.core_cell + offset, -1) == Defs.ITEM_FROST,
			"guaranteed starter ore exists at %s" % offset)
	for offset: Vector2i in Sim.STARTER_LANE:
		_assert(not sim.ore.has(sim.core_cell + offset),
			"the belt lane home stays clear at %s" % offset)
		_assert(sim.can_build(Defs.M_BELT, sim.core_cell + offset) == "",
			"a belt can always be placed in the starter lane at %s" % offset)

	# The alloy chain must be buildable in every run, not only when the scatter
	# is kind: a guaranteed ember seam plus a clear column back to the core.
	for offset: Vector2i in Sim.STARTER_COPPER:
		_assert(sim.ore.get(sim.core_cell + offset, -1) == Defs.ITEM_COPPER,
			"guaranteed copper seam exists at %s" % offset)
	for step in range(1, 9):
		var lane_cell: Vector2i = sim.core_cell + Vector2i(1, -step)
		_assert(sim.can_build(Defs.M_BELT, lane_cell) == "",
			"the copper column home is clear at %s" % lane_cell)
	_assert(Vector2(Sim.STARTER_COPPER[0]).length() > Defs.WARM_BASE,
		"the copper seam starts outside the opening warm radius, so it must be earned")
	_assert(Vector2(Sim.STARTER_COPPER[0]).length() < Defs.WARM_MAX,
		"the copper seam is reachable within a single run")
	sim.free()

	# The opening is deterministic across different world seeds.
	var other := Sim.new()
	other.setup(90210)
	for offset: Vector2i in Sim.STARTER_PATCH:
		_assert(other.ore.get(other.core_cell + offset, -1) == Defs.ITEM_FROST,
			"the starter patch does not depend on the run seed")
	other.free()

func _test_build_rules() -> void:
	var sim := _fresh()
	var ore_cell: Vector2i = sim.ore.keys()[0]
	_assert(sim.can_build(Defs.M_MINER, ore_cell) == "", "a miner may be placed on ore")
	_assert(sim.can_build(Defs.M_BELT, ore_cell) != "", "a belt may not be placed on ore")
	var empty := Vector2i(2, 0)
	_assert(sim.can_build(Defs.M_MINER, empty) != "", "a miner may not be placed off ore")
	_assert(sim.can_build(Defs.M_BELT, empty) == "", "a belt may be placed on bare ground")
	_assert(sim.can_build(Defs.M_BELT, sim.core_cell) != "", "nothing may overwrite the core")

	var before: int = sim.heat
	_assert(sim.build(Defs.M_BELT, empty, Vector2i.RIGHT), "building a belt succeeds")
	_assert(sim.heat == before - Defs.MACHINE_COSTS[Defs.M_BELT], "building spends heat")
	_assert(not sim.build(Defs.M_BELT, empty, Vector2i.RIGHT), "a filled cell rejects a second build")
	_assert(sim.demolish(empty), "a placed machine can be reclaimed")
	_assert(sim.heat > before - Defs.MACHINE_COSTS[Defs.M_BELT], "reclaiming refunds part of the cost")
	_assert(not sim.demolish(sim.core_cell), "the core can never be demolished")

	sim.heat = 0
	_assert(sim.can_build(Defs.M_FURNACE, empty) != "", "an unaffordable machine is rejected")
	sim.free()

func _test_miner_to_core() -> void:
	# Miner directly adjacent to the core, pointing at it.
	var sim := Sim.new()
	sim.setup(999)
	var cell := Vector2i(-1, 0)
	sim.ore[cell] = Defs.ITEM_FROST
	sim.heat = 100
	_assert(sim.build(Defs.M_MINER, cell, Vector2i.RIGHT), "miner placed next to the core")
	_staff(sim, cell)
	var before: int = sim.total_heat
	for step in 80:
		sim.tick(0.1)     # comfortably longer than one mining period
	_assert(sim.total_heat > before, "a miner pointed at the core earns heat")
	_assert(sim.delivered[Defs.ITEM_FROST] > 0, "delivered frost ore is counted")
	sim.free()

func _test_miner_rate() -> void:
	# One cat is deliberately a trickle; the number is load-bearing for balance.
	var sim := Sim.new()
	sim.setup(555)
	sim.heat = 200
	var cell := Vector2i(-1, 0)
	sim.ore[cell] = Defs.ITEM_FROST
	sim.build(Defs.M_MINER, cell, Vector2i.RIGHT)
	_staff(sim, cell)
	for step in 50:
		sim.tick(0.1)     # five seconds
	_assert(sim.delivered[Defs.ITEM_FROST] == 0, "a miner produces nothing within five seconds")
	for step in 20:
		sim.tick(0.1)     # seven seconds total
	_assert(sim.delivered[Defs.ITEM_FROST] == 1, "a miner delivers its first ore just after its period")
	sim.free()

func _test_belt_transport() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.heat = 200
	# miner at (-3,0) -> belts at (-2,0) and (-1,0) -> core at (0,0)
	sim.ore[Vector2i(-3, 0)] = Defs.ITEM_FROST
	_assert(sim.build(Defs.M_MINER, Vector2i(-3, 0), Vector2i.RIGHT), "miner built")
	_staff(sim, Vector2i(-3, 0))
	_assert(sim.build(Defs.M_BELT, Vector2i(-2, 0), Vector2i.RIGHT), "first belt built")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 0), Vector2i.RIGHT), "second belt built")
	var saw_item := false
	for step in 120:
		sim.tick(0.1)
		if sim.items_in_transit() > 0:
			saw_item = true
	_assert(saw_item, "items visibly occupy the belt while travelling")
	_assert(sim.delivered[Defs.ITEM_FROST] > 0, "a two-tile belt run reaches the core")
	sim.free()

func _test_furnace_alloy() -> void:
	var sim := Sim.new()
	sim.setup(777)
	sim.heat = 500
	var furnace_cell := Vector2i(-2, 0)
	_assert(sim.build(Defs.M_FURNACE, furnace_cell, Vector2i.RIGHT), "furnace built")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 0), Vector2i.RIGHT), "furnace output belt built")
	var furnace: Sim.Machine = sim.machine_at(furnace_cell)

	# Only one input type present: nothing may be produced.
	furnace.buffer[Defs.ITEM_FROST] = 2
	for step in 40:
		sim.tick(0.1)
	_assert(sim.delivered[Defs.ITEM_IRON] == 0, "a furnace with one ore type produces nothing")

	# Input may arrive on any face except the one the furnace outputs from.
	var out_cell: Vector2i = furnace_cell + Vector2i.RIGHT
	var side_cell: Vector2i = furnace_cell + Vector2i.UP
	var back_cell: Vector2i = furnace_cell + Vector2i.LEFT
	_assert(sim._push_into(furnace_cell, Defs.ITEM_COPPER, side_cell),
		"the furnace accepts ore pushed in from the side")
	_assert(sim._push_into(furnace_cell, Defs.ITEM_COPPER, back_cell),
		"the furnace accepts ore pushed in from behind")
	_assert(not sim._push_into(furnace_cell, Defs.ITEM_COPPER, out_cell),
		"the furnace refuses ore pushed in from its own output face")
	_assert(not sim._push_into(furnace_cell, Defs.ITEM_IRON, side_cell),
		"the furnace never takes its own product as input")

	furnace.buffer[Defs.ITEM_COPPER] = 2
	for step in 80:
		sim.tick(0.1)
	_assert(sim.delivered[Defs.ITEM_IRON] > 0, "frost plus ember yields alloy at the core")
	_assert(Defs.ITEM_VALUES[Defs.ITEM_IRON] > Defs.ITEM_VALUES[Defs.ITEM_FROST] + Defs.ITEM_VALUES[Defs.ITEM_COPPER],
		"alloy is worth more than its inputs, so the routing puzzle pays off")
	sim.free()

func _test_economy_and_warmth() -> void:
	var sim := _fresh()
	var start_radius: float = sim.warm_radius
	sim.heat = 0
	sim.total_heat = 0
	sim._deliver(Defs.ITEM_IRON, sim.core_cell)
	_assert(sim.heat == Defs.ITEM_VALUES[Defs.ITEM_IRON], "delivery credits spendable heat")
	_assert(sim.total_heat == Defs.ITEM_VALUES[Defs.ITEM_IRON], "delivery credits lifetime heat")
	for step in 400:
		sim._deliver(Defs.ITEM_IRON, sim.core_cell)
	sim.tick(0.016)
	_assert(sim.warm_radius > start_radius, "lifetime heat expands the warm radius")
	_assert(sim.warm_radius <= Defs.WARM_MAX, "the warm radius is capped")

	# Spending must not shrink the map: radius follows lifetime, not balance.
	var radius_before: float = sim.warm_radius
	sim.heat = 10
	sim.tick(0.016)
	_assert(is_equal_approx(sim.warm_radius, radius_before), "spending heat never shrinks the warm radius")

	var banked: int = sim.heat
	var lost: int = sim.spend_rescue()
	_assert(lost > 0 and sim.heat == banked - lost, "blacking out costs a share of banked heat")
	sim.free()

func _test_frost_throttle() -> void:
	# Identical belts, one inside the warm radius and one far outside it. After
	# the same elapsed time the frozen belt must have carried its item less far.
	var sim := Sim.new()
	sim.setup(31337)
	sim.heat = 500
	var warm_cell := Vector2i(2, 0)
	var cold_cell := Vector2i(int(Defs.WARM_MAX) + 8, 0)
	_assert(sim.is_warm(warm_cell), "the warm test cell is inside the radius")
	_assert(not sim.is_warm(cold_cell), "the cold test cell is outside the radius")
	_assert(sim.build(Defs.M_BELT, warm_cell, Vector2i.UP), "warm belt built")
	_assert(sim.build(Defs.M_BELT, cold_cell, Vector2i.UP), "cold belt built")

	var warm_belt: Sim.Machine = sim.machine_at(warm_cell)
	var cold_belt: Sim.Machine = sim.machine_at(cold_cell)
	# Facing UP into empty ground, so neither can hand its item off and both
	# simply accumulate travel along their own tile.
	warm_belt.items.append({"type": Defs.ITEM_FROST, "t": 0.0})
	cold_belt.items.append({"type": Defs.ITEM_FROST, "t": 0.0})
	for step in 3:
		sim.tick(0.05)
	var warm_t: float = float(warm_belt.items[0]["t"])
	var cold_t: float = float(cold_belt.items[0]["t"])
	_assert(warm_t > cold_t, "a frozen belt moves items more slowly than a warm one")
	_assert(cold_t > 0.0, "a frozen machine still runs rather than stopping dead")
	_assert(cold_t < warm_t * 0.8, "the frost penalty is large enough for the player to feel")
	sim.free()

func _test_blocked_output_preserves_work() -> void:
	var sim := Sim.new()
	sim.setup(2468)
	sim.heat = 200
	# Miner facing empty ground: nothing accepts its output. Kept inside the warm
	# radius so the frost throttle is not a second variable in this test.
	var cell := Vector2i(3, 3)
	sim.ore[cell] = Defs.ITEM_FROST
	sim.build(Defs.M_MINER, cell, Vector2i.RIGHT)
	_staff(sim, cell)
	var machine: Sim.Machine = sim.machine_at(cell)
	for step in 80:
		sim.tick(0.1)
	_assert(is_equal_approx(machine.progress, Defs.MINER_PERIOD),
		"a blocked miner holds its finished item instead of discarding it")
	_assert(sim.delivered[Defs.ITEM_FROST] == 0, "a blocked miner delivers nothing")
	_assert(machine.stalled, "a blocked miner reports itself stalled so the player can see it")

	# Give it somewhere to send the ore and the warning must clear on its own.
	sim.build(Defs.M_BELT, cell + Vector2i.RIGHT, Vector2i.RIGHT)
	for step in 40:
		sim.tick(0.1)
	_assert(not machine.stalled, "the stall warning clears once the output is unblocked")

	# A belt whose head has nowhere to go backs up and reports it too.
	var dead_end := Vector2i(20, 20)
	sim.build(Defs.M_BELT, dead_end, Vector2i.RIGHT)
	var belt: Sim.Machine = sim.machine_at(dead_end)
	for index in Defs.BELT_CAPACITY:
		belt.items.append({"type": Defs.ITEM_FROST, "t": 1.0})
	sim.tick(0.2)
	_assert(belt.stalled, "a full belt with no destination reports itself stalled")
	sim.free()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SIM_TEST: FAIL - " + message)
		failures += 1
