extends SceneTree

## The Lv1-3 spine, asserted as rates rather than as vibes. This design lives or
## dies on its numbers -- an earlier draft needed 910 crystal to reach copper,
## which is fifty in-game days -- so the gates are pinned here in units of "how
## many three-minute days is this".

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim := Sim.new()
	sim.setup(4242)

	# --- Lv1: the player produces before anything else exists -----------------
	_assert(not sim.is_unlocked(Defs.M_MINER), "nothing is buildable on the first frame")
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) == Defs.ITEM_CRYSTAL:
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "the world starts with crystal to hand-mine")

	_assert(sim.hand_mine(seam, Defs.HAND_MINE_PERIOD * 0.5) < 0, "half a swing yields nothing")
	_assert(sim.hand_fraction() > 0.4 and sim.hand_fraction() < 0.6, "and the swing is half shown")
	_assert(sim.hand_mine(seam, Defs.HAND_MINE_PERIOD * 0.6) == Defs.ITEM_CRYSTAL,
		"a full swing yields one crystal shard")
	_assert(sim.hand_mine(Vector2i(500, 500), 99.0) < 0, "swinging at bare ground yields nothing")

	var opened: Array[int] = sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	_assert(opened.has(Defs.M_MINER) and opened.has(Defs.M_EXCHANGER),
		"the first crystal opens the miner and the exchanger together")
	_assert(not sim.is_unlocked(Defs.M_GENERATOR), "but the power line stays shut")

	# --- Hauling: cats clear the floor, slowly --------------------------------
	sim.carried_boxes = Defs.BOXES_PER_CAT
	sim.adopt_cats()
	_assert(sim.cats.size() >= 1, "three crates buy a cat")
	var kitty = sim.cats[0]
	var drop := Vector2i(3, 0)
	_assert(sim.drop_item(drop, Defs.ITEM_CRYSTAL), "a shard can lie on the floor")
	_assert(not sim.drop_item(drop, Defs.ITEM_CRYSTAL), "one item per cell keeps the floor readable")
	kitty.pos = sim.cell_centre(drop + Vector2i(1, 0))
	var banked: int = int(sim.stock.get(Defs.ITEM_CRYSTAL, 0))
	for step in 400:
		sim.tick(0.05)
	_assert(sim.ground.is_empty(), "an idle cat picks the floor clean")
	_assert(int(sim.stock.get(Defs.ITEM_CRYSTAL, 0)) > banked, "and banks it at the base")

	# The haul is a round trip on foot, so it degrades with distance. That is the
	# entire reason belts are worth building later.
	var near_trip: float = _haul_seconds(4)
	var far_trip: float = _haul_seconds(16)
	_assert(far_trip > near_trip * 3.0,
		"hauling from four times the distance takes far longer: %.1fs vs %.1fs" % [far_trip, near_trip])

	# --- Lv2: crystal becomes distance ---------------------------------------
	_assert(int(Defs.ITEM_VALUES[Defs.ITEM_CRYSTAL]) == 0, "raw crystal is a material, not heat")
	_assert(int(Defs.ITEM_VALUES[Defs.ITEM_ENERGY]) > 0, "energy is the only heat")

	# One exchanger keeps up with four miners; miners stay the bottleneck.
	var miner_rate: float = 1.0 / Defs.MINER_PERIOD
	var exchanger_intake: float = float(Defs.CRYSTAL_COST_ENERGY) / Defs.EXCHANGER_PERIOD
	_assert(absf(exchanger_intake / miner_rate - 4.0) < 0.6,
		"one exchanger absorbs about four miners (%.1f)" % (exchanger_intake / miner_rate))

	# The gate that matters: reaching copper must be days, not hours.
	var heat_needed: float = (Defs.COPPER_RING.x - Defs.WARM_BASE) / Defs.WARM_PER_HEAT
	var energy_needed: float = heat_needed / float(Defs.ITEM_VALUES[Defs.ITEM_ENERGY])
	var crystal_needed: float = energy_needed * float(Defs.CRYSTAL_COST_ENERGY)
	var seconds_two_miners: float = crystal_needed / (2.0 * miner_rate)
	var days: float = seconds_two_miners / 120.0    # productive seconds per day
	_assert(days < 6.0, "two miners reach copper inside six days (%.1f)" % days)
	_assert(days > 1.0, "but not on the first day (%.1f)" % days)
	print("PROGRESSION: copper at %.1f days with two miners (%.0f crystal)" % [days, crystal_needed])

	# --- Lv3: power is a rate, and it gates logistics -------------------------
	sim.note_resource_seen(Defs.ITEM_COPPER)
	_assert(sim.is_unlocked(Defs.M_GENERATOR) and sim.is_unlocked(Defs.M_BELT),
		"the first copper opens generators and belts")
	sim.stock[Defs.ITEM_COPPER] = 100
	sim.stock[Defs.ITEM_CRYSTAL] = 100

	var belt_cell := Vector2i(5, 5)
	_assert(sim.build(Defs.M_BELT, belt_cell, Vector2i.LEFT), "a belt goes down")
	sim.tick(0.01)
	_assert(is_equal_approx(sim.power_draw, Defs.BELT_POWER_DRAW), "and draws power")
	_assert(is_equal_approx(sim.power_capacity, 0.0), "with nothing supplying it yet")

	var gen_cell := Vector2i(5, 7)
	_assert(sim.build(Defs.M_GENERATOR, gen_cell, Vector2i.RIGHT), "a generator goes down")
	sim.tick(0.01)
	_assert(is_equal_approx(sim.power_capacity, 0.0), "an unfuelled generator supplies nothing")
	sim.machine_at(gen_cell).buffer[Defs.ITEM_ENERGY] = 3
	sim.tick(0.01)
	_assert(sim.power_capacity >= Defs.GENERATOR_OUTPUT, "a fuelled one supplies its rating")
	_assert(sim.power_capacity > sim.power_draw, "one generator carries many belts")

	# Fuel is consumed, so power is an ongoing cost rather than a one-off build.
	var fuel_before: int = int(sim.machine_at(gen_cell).buffer[Defs.ITEM_ENERGY])
	for step in int(Defs.GENERATOR_PERIOD / 0.1) + 4:
		sim.tick(0.1)
	_assert(int(sim.machine_at(gen_cell).buffer[Defs.ITEM_ENERGY]) < fuel_before,
		"a running generator burns its fuel")

	sim.free()
	if failures == 0:
		print("PROGRESSION_TEST: PASS")
	quit(failures)

## How long a cat takes to fetch one item from `tiles` away and bank it.
func _haul_seconds(tiles: int) -> float:
	var sim := Sim.new()
	sim.setup(4242)
	sim.carried_boxes = Defs.BOXES_PER_CAT
	sim.adopt_cats()
	var cat = sim.cats[0]
	cat.pos = sim.cell_centre(sim.core_cell)
	var at := sim.core_cell + Vector2i(tiles, 0)
	sim.ore.erase(at)
	sim.machines.erase(at)
	sim.drop_item(at, Defs.ITEM_CRYSTAL)
	var elapsed := 0.0
	var banked: int = int(sim.stock.get(Defs.ITEM_CRYSTAL, 0))
	while elapsed < 600.0:
		sim.tick(0.05)
		elapsed += 0.05
		if int(sim.stock.get(Defs.ITEM_CRYSTAL, 0)) > banked:
			break
	sim.free()
	return elapsed

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("PROGRESSION_TEST: FAIL - " + message)
		failures += 1
