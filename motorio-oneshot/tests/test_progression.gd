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

	# --- Splitters: the grammar for writing a ratio down ----------------------
	# Without one you can only build 1:1 lines, so this is the piece that makes
	# the published rates worth knowing.
	var split_sim := Sim.new()
	split_sim.setup(31337)
	split_sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	split_sim.note_resource_seen(Defs.ITEM_COPPER)
	split_sim.stock[Defs.ITEM_COPPER] = 200
	split_sim.stock[Defs.ITEM_CRYSTAL] = 200

	var hub := Vector2i(20, 20)
	for around: Vector2i in [hub, hub + Vector2i.RIGHT, hub + Vector2i.DOWN, hub + Vector2i.UP]:
		split_sim.ore.erase(around)
		split_sim.machines.erase(around)
	_assert(split_sim.build(Defs.M_SPLITTER, hub, Vector2i.RIGHT), "a splitter goes down")
	_assert(split_sim.build(Defs.M_BELT, hub + Vector2i.RIGHT, Vector2i.RIGHT), "east branch")
	_assert(split_sim.build(Defs.M_BELT, hub + Vector2i.DOWN, Vector2i.DOWN), "south branch")

	var east: Sim.Machine = split_sim.machine_at(hub + Vector2i.RIGHT)
	var south: Sim.Machine = split_sim.machine_at(hub + Vector2i.DOWN)
	var seen_east := 0
	var seen_south := 0
	for round_index in 10:
		_assert(split_sim._push_into(hub, Defs.ITEM_CRYSTAL, hub + Vector2i.LEFT),
			"the splitter accepts from behind")
		for step in 30:
			split_sim.tick(0.05)
			if east.items.size() > 0:
				seen_east += 1
				east.items.clear()
				break
			if south.items.size() > 0:
				seen_south += 1
				south.items.clear()
				break
	_assert(seen_east + seen_south >= 8,
		"nearly every item came out somewhere (%d)" % (seen_east + seen_south))
	_assert(absf(float(seen_east - seen_south)) <= 2.0,
		"and the split is even: %d east, %d south" % [seen_east, seen_south])
	print("SPLITTER: %d east / %d south" % [seen_east, seen_south])

	# A blocked branch must not stop the other one, or a splitter is just a fork.
	south.items.clear()
	for fill in Defs.BELT_CAPACITY:
		south.items.append({"type": Defs.ITEM_CRYSTAL, "t": 0.1})
	var got_east := 0
	for round_index in 6:
		split_sim._push_into(hub, Defs.ITEM_CRYSTAL, hub + Vector2i.LEFT)
		for step in 30:
			split_sim.tick(0.05)
			if east.items.size() > 0:
				got_east += 1
				east.items.clear()
				break
	_assert(got_east >= 4,
		"a backed-up branch is skipped rather than stalling the line (%d)" % got_east)
	split_sim.free()

	# --- The published numbers have to be the real ones ----------------------
	_assert(Defs.throughput_line(Defs.M_MINER).find("6/분") >= 0,
		"the miner advertises its real rate: %s" % Defs.throughput_line(Defs.M_MINER))
	_assert(Defs.ratio_hint().find("4") >= 0,
		"and the exchanger ratio is stated: %s" % Defs.ratio_hint())

	# --- Purity: distance buys richness --------------------------------------
	var grade_sim := Sim.new()
	grade_sim.setup(20260801)
	var near_best := 0
	var far_best := 0
	for cell: Vector2i in grade_sim.ore:
		var distance: float = Vector2(cell - grade_sim.core_cell).length()
		if distance < Defs.PURITY_RICH_RING:
			near_best = maxi(near_best, grade_sim.purity_of(cell))
		if distance >= Defs.PURITY_PURE_RING:
			far_best = maxi(far_best, grade_sim.purity_of(cell))
	_assert(near_best == Defs.PURITY_NORMAL, "seams beside the base are ordinary")
	if far_best > 0:
		_assert(far_best > near_best, "and the far ones are richer (%d vs %d)" % [far_best, near_best])
	# A richer seam must actually mine faster, or the grade is decoration.
	var plain := Vector2i(grade_sim.core_cell.x + 5, grade_sim.core_cell.y)
	var rich := Vector2i(grade_sim.core_cell.x + int(Defs.PURITY_PURE_RING) + 2, grade_sim.core_cell.y)
	grade_sim.ore[plain] = Defs.ITEM_CRYSTAL
	grade_sim.ore[rich] = Defs.ITEM_CRYSTAL
	grade_sim._assign_purity()
	_assert(grade_sim.seam_period(rich) < grade_sim.seam_period(plain),
		"a pure seam yields faster: %.1fs vs %.1fs" % [grade_sim.seam_period(rich), grade_sim.seam_period(plain)])
	print("PURITY: %.1fs plain / %.1fs pure" % [grade_sim.seam_period(plain), grade_sim.seam_period(rich)])

	# --- Full refund: tearing down must cost nothing --------------------------
	grade_sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	grade_sim.stock[Defs.ITEM_CRYSTAL] = 50
	var before_stock: int = int(grade_sim.stock[Defs.ITEM_CRYSTAL])
	var spot := Vector2i(grade_sim.core_cell.x + 6, grade_sim.core_cell.y + 6)
	grade_sim.ore.erase(spot)
	grade_sim.machines.erase(spot)
	_assert(grade_sim.build(Defs.M_EXCHANGER, spot, Vector2i.RIGHT), "an exchanger goes down")
	_assert(int(grade_sim.stock[Defs.ITEM_CRYSTAL]) < before_stock, "and costs materials")
	_assert(grade_sim.demolish(spot), "and comes back up")
	_assert(int(grade_sim.stock[Defs.ITEM_CRYSTAL]) == before_stock,
		"with every material returned, so rebuilding is free")
	grade_sim.free()

	# --- Power scales the factory, cats no longer cap it ----------------------
	# The ratio the game now advertises (one exchanger to four miners) is useless
	# if four miners need four cats and cats come from walking. Electricity is
	# what turns factory scale back into an engineering problem.
	var grid := Sim.new()
	grid.setup(9090)
	grid.note_resource_seen(Defs.ITEM_CRYSTAL)
	grid.note_resource_seen(Defs.ITEM_COPPER)
	grid.stock[Defs.ITEM_CRYSTAL] = 200
	grid.stock[Defs.ITEM_COPPER] = 200
	var seam2 := Vector2i(grid.core_cell.x + 4, grid.core_cell.y + 4)
	grid.ore[seam2] = Defs.ITEM_CRYSTAL
	grid._assign_purity()
	_assert(grid.build(Defs.M_MINER, seam2, Vector2i.RIGHT), "a miner goes down")

	var idle_before: int = int(grid.delivered.get(Defs.ITEM_CRYSTAL, 0))
	for step in int(Defs.MINER_PERIOD / 0.1) * 2:
		grid.tick(0.1)
	_assert(not grid.miner_on_power(seam2), "an unstaffed miner with no grid is not on power")
	_assert(grid.ground.is_empty() and int(grid.delivered.get(Defs.ITEM_CRYSTAL, 0)) == idle_before,
		"and produces nothing at all")

	var gen2 := Vector2i(grid.core_cell.x + 8, grid.core_cell.y + 8)
	grid.ore.erase(gen2)
	_assert(grid.build(Defs.M_GENERATOR, gen2, Vector2i.RIGHT), "a generator goes down")
	grid.machine_at(gen2).buffer[Defs.ITEM_ENERGY] = 4
	grid.tick(0.02)
	_assert(grid.miner_on_power(seam2), "with power the miner runs itself")
	_assert(grid.power_draw >= Defs.MINER_POWER_DRAW, "and pays the grid for it")
	for step in int(Defs.MINER_PERIOD / 0.1) * 2:
		grid.tick(0.1)
	_assert(not grid.ground.is_empty() or int(grid.delivered.get(Defs.ITEM_CRYSTAL, 0)) > idle_before,
		"a grid-run miner actually produces")

	var worker = Sim.Cat.new()
	worker.assigned = seam2
	worker.state = Defs.CAT_WORKING
	worker.pos = grid.cell_centre(seam2)
	grid.cats.append(worker)
	grid.tick(0.02)
	_assert(not grid.miner_on_power(seam2), "a staffed miner stops drawing from the grid")
	print("POWER: unstaffed miner draws %.1f, one generator carries %.0f" % [
		Defs.MINER_POWER_DRAW, Defs.GENERATOR_OUTPUT / Defs.MINER_POWER_DRAW])
	grid.free()

	# --- Alternate recipe: efficiency becomes a choice ------------------------
	# The test that matters is that neither recipe wins outright. If one is
	# strictly better the choice is decoration.
	var plain_rate: float = Defs.recipe_rate(Defs.RECIPE_PLAIN)
	var alloy_rate: float = Defs.recipe_rate(Defs.RECIPE_ALLOY)
	var plain_cost: float = Defs.recipe_crystal_cost(Defs.RECIPE_PLAIN)
	var alloy_cost: float = Defs.recipe_crystal_cost(Defs.RECIPE_ALLOY)
	_assert(alloy_cost < plain_cost,
		"the alloy recipe stretches crystal further (%.2f vs %.2f per energy)" % [alloy_cost, plain_cost])
	_assert(Defs.RECIPES[Defs.RECIPE_ALLOY]["in"].has(Defs.ITEM_COPPER),
		"and pays for it with copper, which is also what machines are made of")
	_assert(Defs.COPPER_PERIOD > Defs.MINER_PERIOD,
		"copper being slower to mine is what makes that a real cost")
	print("RECIPES: 기본 %.0f/분 @ %.2f수정, 촉매 %.0f/분 @ %.2f수정" % [
		plain_rate, plain_cost, alloy_rate, alloy_cost])

	var rec := Sim.new()
	rec.setup(5150)
	rec.note_resource_seen(Defs.ITEM_CRYSTAL)
	rec.stock[Defs.ITEM_CRYSTAL] = 100
	var ex := Vector2i(rec.core_cell.x + 7, rec.core_cell.y + 7)
	rec.ore.erase(ex)
	_assert(rec.build(Defs.M_EXCHANGER, ex, Vector2i.RIGHT), "an exchanger goes down")
	_assert(not rec.recipe_unlocked(Defs.RECIPE_ALLOY), "the second recipe starts locked")
	_assert(rec.cycle_recipe(ex) == Defs.RECIPE_PLAIN, "and cycling does nothing while locked")
	_assert(not rec._push_into(ex, Defs.ITEM_COPPER, ex + Vector2i.UP),
		"a plain exchanger refuses copper it has no use for")

	rec.note_resource_seen(Defs.ITEM_COPPER)
	_assert(rec.recipe_unlocked(Defs.RECIPE_ALLOY), "holding copper opens the second recipe")
	_assert(rec.cycle_recipe(ex) == Defs.RECIPE_ALLOY, "and the machine can switch to it")
	_assert(rec._push_into(ex, Defs.ITEM_COPPER, ex + Vector2i.UP),
		"which then accepts copper")

	# The batch of three must not be silently destroyed when the output is full.
	var machine_ref: Sim.Machine = rec.machine_at(ex)
	machine_ref.buffer[Defs.ITEM_CRYSTAL] = 2
	machine_ref.buffer[Defs.ITEM_COPPER] = 1
	for around: Vector2i in [ex + Vector2i.RIGHT]:
		rec.ore[around] = Defs.ITEM_CRYSTAL      # block the output entirely
	for step in int(float(Defs.RECIPES[Defs.RECIPE_ALLOY]["period"]) / 0.1) + 8:
		rec.tick(0.1)
	_assert(int(machine_ref.buffer.get(Defs.ITEM_CRYSTAL, 0)) == 2,
		"a blocked alloy batch keeps its inputs rather than eating them")
	rec.free()

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
