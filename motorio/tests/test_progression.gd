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
		if int(sim.ore[cell]) == Defs.ITEM_HEATSTONE:
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "the world starts with heat stone to hand-mine")

	_assert(sim.hand_mine(seam, Defs.HAND_MINE_PERIOD * 0.5) < 0, "half a swing yields nothing")
	_assert(sim.hand_fraction() > 0.4 and sim.hand_fraction() < 0.6, "and the swing is half shown")
	_assert(sim.hand_mine(seam, Defs.HAND_MINE_PERIOD * 0.6) == Defs.ITEM_HEATSTONE,
		"a full swing yields one heat stone")
	_assert(sim.hand_mine(Vector2i(500, 500), 99.0) < 0, "swinging at bare ground yields nothing")

	# The two lines open separately now, and in the order the player meets them.
	# The miner is the thing you want after carrying stones by hand; the
	# exchanger is the thing you want after finding crystal, which is a walk away.
	var opened: Array[int] = sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	_assert(opened.has(Defs.M_MINER), "the first heat stone opens the miner")
	_assert(not opened.has(Defs.M_EXCHANGER), "and not the exchanger")
	_assert(sim.note_resource_seen(Defs.ITEM_CRYSTAL).has(Defs.M_EXCHANGER),
		"the first crystal opens the exchanger")
	_assert(not sim.is_unlocked(Defs.M_GENERATOR), "but the power line stays shut")

	# --- Hauling: cats clear the floor, slowly --------------------------------
	sim.grant_cats(1)
	_assert(sim.cats.size() >= 1, "three crates buy a cat")
	var kitty = sim.cats[0]
	var drop := Vector2i(3, 0)
	_assert(sim.drop_item(drop, Defs.ITEM_CRYSTAL), "a shard can lie on the floor")
	# A tile takes a pile of the same thing, because a belt that ends in the open
	# pours onto the ground and one-per-tile made it stop after a single item.
	# Two different things on one tile is still refused: a tile draws one
	# picture, and it cannot be a picture of two materials.
	_assert(sim.drop_item(drop, Defs.ITEM_CRYSTAL), "같은 것은 쌓인다")
	_assert(sim.ground_count(drop) == 2, "그리고 개수로 센다")
	_assert(not sim.drop_item(drop, Defs.ITEM_COPPER), "다른 것은 같은 칸에 못 놓는다")
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

	# --- Lv2: stone and crystal become distance -------------------------------
	# Heat stone is the fuel and nothing else is, as of 1.0.5. The energy crystal
	# used to burn as well, which made "how many more do I need" a question with
	# two answers -- and it let a player widen the circle without ever touching
	# the seam the circle is supposed to be about.
	var fire := Sim.new()
	fire.setup(4242)
	fire.stock[Defs.ITEM_ENERGY] = 20
	fire.stock[Defs.ITEM_CRYSTAL] = 20
	fire.stock[Defs.ITEM_COPPER] = 20
	_assert(not fire.has_fuel(), "수정도 구리도 에너지결정도 연료가 아니다")
	fire.stock[Defs.ITEM_HEATSTONE] = 3
	_assert(fire.has_fuel(), "열석만 연료다")
	var burnt: Dictionary = fire.deposit_fuel()
	_assert(burnt.size() == 1 and burnt.has(Defs.ITEM_HEATSTONE),
		"투입은 열석만 가져간다")
	_assert(int(fire.stock.get(Defs.ITEM_ENERGY, 0)) == 20, "나머지는 가방에 남는다")
	fire.free()

	# One exchanger keeps up with more than one miner, so miners stay the
	# bottleneck. It used to be four; the miner doubled to 12/min and it is two,
	# which is the same property with less headroom.
	var miner_rate: float = 1.0 / Defs.MINER_PERIOD
	var exchanger_intake: float = float(Defs.CRYSTAL_COST_ENERGY) / Defs.EXCHANGER_PERIOD
	var ratio: float = exchanger_intake / miner_rate
	_assert(ratio >= 1.5,
		"one exchanger absorbs more than one miner (%.1f)" % ratio)

	# The gate that matters: reaching copper must be days, not hours.
	#
	# Measured on heat stone, because that is what a player actually does -- heat
	# stone is the seam beside the base and it burns straight in the core.
	# Crystal cannot be the answer any more: there is a fixed number of pieces in
	# a world and no way to make another.
	#
	# The circle goes up in steps now, so the gate is the first step that reaches
	# the copper ring rather than an arithmetic on a rate.
	var stones_needed: float = 0.0
	for level: Dictionary in Defs.BASE_LEVELS:
		if float(level["radius"]) >= Defs.COPPER_RING.x:
			stones_needed = float(level["stones"])
			break
	_assert(stones_needed > 0.0, "구리 고리에 닿는 기지 단계가 존재한다")
	var seconds_two_miners: float = stones_needed / (2.0 * miner_rate)
	var days: float = seconds_two_miners / 120.0    # productive seconds per day
	_assert(days < 6.0, "two miners reach copper inside six days (%.1f)" % days)
	# The old floor here was "not inside a single day", and it encoded a curve
	# that no longer exists: the circle used to creep up by a hundredth of a tile
	# per heat, so the time to copper was an arithmetic on a rate. It goes up in
	# authored steps now, and copper sits behind the fourth of them. What is
	# worth holding is the shape of the table rather than a number derived from
	# a rate that is gone.
	var levels: Array[Dictionary] = Defs.BASE_LEVELS
	for index in range(1, levels.size()):
		_assert(int(levels[index]["stones"]) > int(levels[index - 1]["stones"])
			and float(levels[index]["radius"]) > float(levels[index - 1]["radius"]),
			"기지 단계 %d은 앞 단계보다 비싸고 넓다" % index)
	var copper_level: int = Defs.base_level(int(stones_needed))
	_assert(copper_level >= 4,
		"구리는 오프닝에서 네 단계 뒤에 있다 (%d단계)" % copper_level)
	_assert(Defs.warm_radius(int(stones_needed)) >= Defs.COPPER_RING.x,
		"그 단계의 온기가 구리 고리에 실제로 닿는다")
	print("PROGRESSION: copper at %.1f days with two miners (%.0f 열석)" % [days, stones_needed])

	# --- Lv3: power is a rate, and it gates logistics -------------------------
	sim.note_resource_seen(Defs.ITEM_COPPER)
	_assert(sim.is_unlocked(Defs.M_GENERATOR) and sim.is_unlocked(Defs.M_BELT),
		"the first copper opens generators and belts")
	sim.stock[Defs.ITEM_COPPER] = 100
	sim.stock[Defs.ITEM_CRYSTAL] = 100
	sim.stock[Defs.ITEM_HEATSTONE] = 100

	var belt_cell := Vector2i(5, 5)
	_assert(sim.build(Defs.M_BELT, belt_cell, Vector2i.LEFT), "a belt goes down")
	sim.tick(0.01)
	# A belt asks the grid for nothing. It used to draw 0.1, which with no
	# generator yet made the supply ratio zero and froze every belt in the early
	# game -- the tier belts are supposed to lead to was required to run them.
	_assert(is_equal_approx(sim.power_draw, 0.0), "a belt draws no power")
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
	split_sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	split_sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	split_sim.note_resource_seen(Defs.ITEM_COPPER)
	split_sim.stock[Defs.ITEM_COPPER] = 200
	split_sim.stock[Defs.ITEM_CRYSTAL] = 200
	split_sim.stock[Defs.ITEM_HEATSTONE] = 200

	# One into two: a splitter facing east splits north and south, and takes its
	# input from the west. R turns that axis.
	var hub := Vector2i(20, 20)
	for around: Vector2i in [hub, hub + Vector2i.RIGHT, hub + Vector2i.DOWN,
			hub + Vector2i.UP, hub + Vector2i.LEFT]:
		split_sim.ore.erase(around)
		split_sim.machines.erase(around)
	_assert(split_sim.build(Defs.M_SPLITTER, hub, Vector2i.RIGHT), "a splitter goes down")
	var outs: Array[Vector2i] = split_sim.splitter_outputs(split_sim.machine_at(hub))
	_assert(outs.size() == 2, "it has exactly two outputs")
	_assert(not outs.has(Vector2i.RIGHT) and not outs.has(Vector2i.LEFT),
		"and they are perpendicular to the way it faces")
	_assert(split_sim.build(Defs.M_BELT, hub + Vector2i.UP, Vector2i.UP), "north branch")
	_assert(split_sim.build(Defs.M_BELT, hub + Vector2i.DOWN, Vector2i.DOWN), "south branch")

	var east: Sim.Machine = split_sim.machine_at(hub + Vector2i.UP)
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
		"and the split is even: %d north, %d south" % [seen_east, seen_south])
	print("SPLITTER: %d north / %d south" % [seen_east, seen_south])

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
	# The published number is the real one, derived rather than typed, so retuning
	# the miner cannot leave the hotbar advertising the old rate.
	var advertised: String = "%.0f/분" % Defs.per_minute(Defs.MINER_PERIOD)
	_assert(Defs.throughput_line(Defs.M_MINER).find(advertised) >= 0,
		"the miner advertises its real rate: %s" % Defs.throughput_line(Defs.M_MINER))
	_assert(Defs.ratio_hint().find("%.0f" % ratio) >= 0,
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
	grade_sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	grade_sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	grade_sim.stock[Defs.ITEM_CRYSTAL] = 50
	grade_sim.stock[Defs.ITEM_HEATSTONE] = 50
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
	grid.note_resource_seen(Defs.ITEM_HEATSTONE)
	grid.note_resource_seen(Defs.ITEM_CRYSTAL)
	grid.note_resource_seen(Defs.ITEM_COPPER)
	grid.stock[Defs.ITEM_CRYSTAL] = 200
	grid.stock[Defs.ITEM_HEATSTONE] = 200
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
	rec.note_resource_seen(Defs.ITEM_HEATSTONE)
	rec.note_resource_seen(Defs.ITEM_CRYSTAL)
	rec.stock[Defs.ITEM_CRYSTAL] = 100
	rec.stock[Defs.ITEM_HEATSTONE] = 100
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

	# --- Belt grades are a convenience, never a gate --------------------------
	_assert(Defs.BELT_TIERS.size() == 3, "three grades, no more")
	_assert(is_equal_approx(Defs.belt_speed(0), Defs.BELT_SPEED), "grade 1 is the baseline")
	_assert(is_equal_approx(Defs.belt_speed(1), Defs.BELT_SPEED * 3.0), "grade 2 is three times")
	_assert(is_equal_approx(Defs.belt_speed(2), Defs.BELT_SPEED * 10.0), "grade 3 is ten times")
	# Two properties, pulling against each other, and both have to hold.
	# Throughput: even the slowest belt must carry more than the best single
	# miner, so a one-to-one line never chokes and nobody is forced to upgrade.
	# Latency: it must still be slow enough to be felt on a long run, or the
	# grades are buying nothing and may as well not exist.
	var belt_rate: float = Defs.BELT_SPEED / 0.34 * 60.0
	var fastest_miner: float = Defs.per_minute(Defs.MINER_PERIOD / Defs.PURITY_RATE[Defs.PURITY_PURE])
	_assert(belt_rate > fastest_miner * 2.0,
		"grade 1 carries %.0f/min against a best miner's %.0f, so one line never chokes"
			% [belt_rate, fastest_miner])
	var ten_tiles: float = 10.0 / Defs.BELT_SPEED
	_assert(ten_tiles > 20.0,
		"a ten-tile run takes %.0fs at grade 1, which is long enough to want better" % ten_tiles)
	_assert(10.0 / Defs.belt_speed(2) < 6.0,
		"and grade 3 makes the same run barely noticeable (%.1fs)" % (10.0 / Defs.belt_speed(2)))

	var belt_sim := Sim.new()
	belt_sim.setup(777888)
	belt_sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	belt_sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	belt_sim.note_resource_seen(Defs.ITEM_COPPER)
	belt_sim.stock[Defs.ITEM_COPPER] = 100
	var lane := Vector2i(belt_sim.core_cell.x + 9, belt_sim.core_cell.y + 9)
	belt_sim.ore.erase(lane)
	_assert(belt_sim.build(Defs.M_BELT, lane, Vector2i.RIGHT), "a belt goes down at grade 1")
	_assert(belt_sim.machine_at(lane).tier == 0, "starting at the base grade")
	var copper_before: int = int(belt_sim.stock[Defs.ITEM_COPPER])
	_assert(belt_sim.cycle_belt_tier(lane) == 1, "F upgrades it")
	_assert(int(belt_sim.stock[Defs.ITEM_COPPER]) < copper_before, "and charges the difference")
	_assert(belt_sim.cycle_belt_tier(lane) == 2, "and again")
	_assert(belt_sim.cycle_belt_tier(lane) == 0, "then wraps back to the base grade")
	belt_sim.stock[Defs.ITEM_COPPER] = 0
	_assert(belt_sim.cycle_belt_tier(lane) < 0, "an upgrade you cannot afford is refused")
	print("BELTS: grade1 %.0f/min, 10 tiles in %.0fs -> grade3 %.0f/min, %.1fs" % [
		belt_rate, ten_tiles, Defs.belt_speed(2) / 0.34 * 60.0, 10.0 / Defs.belt_speed(2)])
	belt_sim.free()

	sim.free()
	if failures == 0:
		print("PROGRESSION_TEST: PASS")
	quit(failures)

## How long a cat takes to fetch one item from `tiles` away and bank it.
func _haul_seconds(tiles: int) -> float:
	var sim := Sim.new()
	sim.setup(4242)
	sim.grant_cats(1)
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
