extends SceneTree

## The worker system: miners are machines, cats are the labour that runs them,
## and food is what keeps it running. How a cat is acquired -- found frozen and
## carried home -- is test_frozen.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_miner_needs_operator()
	_test_cat_on_a_bare_seam()
	_test_new_cats_stand_apart()
	_test_morning_dispatch()
	_test_hunger_and_feeding()
	# --- One item, one cat, and the nearest one --------------------------------
	# It used to be a pull: every idle cat asked for the item closest to itself,
	# so one rock on the floor sent the whole crew, seven of them arrived to find
	# nothing, and went home. A cat cannot know whether another cat is closer;
	# the sim can, so the decision is made per item.
	var haul := Sim.new()
	haul.setup(1234)
	haul.cats.clear()
	haul.ground.clear()
	var spots: Array[Vector2] = [Vector2(0, 0), Vector2(400, 0), Vector2(800, 0)]
	for spot: Vector2 in spots:
		var cat = haul.Cat.new()
		cat.pos = spot
		haul.cats.append(cat)
	var drop: Vector2i = Vector2i(13, 0)          # nearest to the cat at 400
	haul.ground[drop] = Defs.ITEM_CRYSTAL
	haul._assign_haulers()
	var going: Array[int] = []
	for index in haul.cats.size():
		if haul.cats[index].state == Defs.CAT_HAUL_TO_ITEM:
			going.append(index)
	_assert(going.size() == 1, "한 마리만 주우러 간다 (%d마리)" % going.size())
	if going.size() == 1:
		var nearest: int = 0
		var best: float = 1e20
		for index in haul.cats.size():
			var distance: float = haul.cats[index].pos.distance_to(haul.cell_centre(drop))
			if distance < best:
				best = distance
				nearest = index
		_assert(going[0] == nearest, "가장 가까운 고양이가 간다 (%d번, 기대 %d번)"
			% [going[0], nearest])
		_assert(haul.cats[going[0]].haul_target == drop, "그 고양이가 그 칸을 맡는다")

	# A second item goes to a different cat, and the claim survives the next tick
	# rather than being re-decided into a stampede.
	haul.ground[Vector2i(25, 0)] = Defs.ITEM_CRYSTAL
	haul._assign_haulers()
	var targets: Dictionary[Vector2i, int] = {}
	for cat in haul.cats:
		if cat.state == Defs.CAT_HAUL_TO_ITEM:
			targets[cat.haul_target] = int(targets.get(cat.haul_target, 0)) + 1
	_assert(targets.size() == 2, "물건 두 개면 두 마리가 나선다 (%d)" % targets.size())
	for cell: Vector2i in targets:
		_assert(targets[cell] == 1, "한 칸에 한 마리만 간다 (%s에 %d마리)"
			% [str(cell), targets[cell]])
	# A cat already assigned to a machine is not free, however close it is.
	haul.ground[Vector2i(0, 0)] = Defs.ITEM_CRYSTAL
	haul.cats[2].assigned = Vector2i(5, 5)
	haul.cats[2].state = Defs.CAT_IDLE
	haul._assign_haulers()
	_assert(haul.cats[2].state != Defs.CAT_HAUL_TO_ITEM, "배치된 고양이는 줍지 않는다")
	haul.free()

	# --- Loitering -------------------------------------------------------------
	# A cat with nothing to do used to stand exactly still, which reads as a
	# paused game. It strolls now: pause, short walk, pause. Driven for a couple
	# of minutes because the pauses are up to six seconds and a shorter run can
	# miss the walking half entirely and pass for the wrong reason.
	var idle := Sim.new()
	idle.setup(99)
	idle.cats.clear()
	idle.ground.clear()
	var loafer = idle.Cat.new()
	var anchor: Vector2 = idle.cell_centre(idle.shelter_cell) + Vector2(0.0, float(Defs.TILE))
	loafer.pos = anchor
	idle.cats.append(loafer)
	var moved: float = 0.0
	var still_ticks: int = 0
	var walked_ticks: int = 0
	var furthest: float = 0.0
	var step: float = 1.0 / 30.0
	var previous: Vector2 = loafer.pos
	for tick in 3600:
		idle._cat_wander(loafer, step)
		var hop: float = loafer.pos.distance_to(previous)
		moved += hop
		if hop > 0.0001:
			walked_ticks += 1
			_assert(hop <= Defs.CAT_SPEED * Defs.WANDER_SPEED * step + 0.01,
				"어슬렁거림은 걷기보다 느리다 (%.3fpx)" % hop)
		else:
			still_ticks += 1
		furthest = maxf(furthest, loafer.pos.distance_to(anchor))
		previous = loafer.pos
	_assert(moved > 100.0, "실제로 돌아다닌다 (%.0fpx)" % moved)
	_assert(walked_ticks > 200 and still_ticks > 200,
		"걷는 시간과 서 있는 시간이 둘 다 있다 (걷기 %d, 정지 %d)" % [walked_ticks, still_ticks])
	# Leashed, or the crew wanders out of the warm radius and the player goes
	# looking for it.
	_assert(furthest < Defs.WANDER_LEASH * 2.0,
		"숙소에서 너무 멀어지지 않는다 (%.0fpx)" % furthest)
	# And walking is reported, or the sheet plays a standing cat sliding along.
	loafer.state = Defs.CAT_IDLE
	loafer.path = [loafer.pos + Vector2(32.0, 0.0)] as Array[Vector2]
	_assert(loafer.is_walking(), "어슬렁거리는 동안은 걷는 것으로 센다")
	loafer.path.clear()
	_assert(not loafer.is_walking(), "멈춰 있으면 서 있는 것으로 센다")
	idle.free()

	if failures == 0:
		print("WORKERS_TEST: PASS")
	quit(failures)

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(31415)
	_open(sim)
	return sim

## A cat put on a bare seam digs it out and carries the stone home itself, and a
## cat on a miner is faster. Both halves matter: the first is what makes a
## rescued cat useful the minute it wakes, the second is the entire reason to
## build the machine.
##
## Measured by running both and counting what came out, rather than by comparing
## the two constants. The constants only describe the digging; the seam-cat also
## walks to the core and back between every stone, and that walk is most of the
## difference.
func _test_cat_on_a_bare_seam() -> void:
	var sim := _sim()
	sim.cats.clear()
	# A seam beside the core, so the round trip is as short as it ever gets --
	# which makes this the *most* favourable case for the seam and the test still
	# has to come out the same way.
	var seam: Vector2i = sim.core_cell + Sim.STARTER_PATCH[0]
	_assert(sim.ore.has(seam) and not sim.machines.has(seam), "맨 광맥이 있다")

	sim.grant_cats(1)
	var cat: Sim.Cat = sim.cats[0]
	sim.carried_cat = cat
	_assert(sim.place_cat(seam), "맨 광맥 위에도 고양이를 내려놓을 수 있다")
	_assert(cat.assigned == seam and cat.state == Defs.CAT_WORKING, "그 자리에서 일한다")
	_assert(not sim.place_cat(seam), "같은 자리에 두 마리는 안 된다")

	# One stone, from digging to delivery to walking back.
	var elapsed: float = 0.0
	var dug := false
	var delivered := false
	var returned := false
	while elapsed < 200.0:
		sim.tick(0.1)
		elapsed += 0.1
		if cat.carrying >= 0:
			dug = true
		if dug and int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) > 0:
			delivered = true
		if delivered and cat.state == Defs.CAT_WORKING:
			returned = true
			break
	_assert(dug, "고양이가 열석을 캐서 든다")
	_assert(delivered, "기지까지 스스로 가져간다")
	_assert(returned, "그리고 자기 광맥으로 돌아온다 — 서서 기다리지 않는다")
	_assert(cat.assigned == seam, "자리를 잃지 않는다")
	sim.free()

	# Now the same seam with a machine on it, for the same simulated minutes.
	#
	# The machine is faster at *getting the stone out*, which is what it is for.
	# It is not faster at delivering, because it does not deliver: it drops the
	# stone on the next tile and something else has to move it. So the extraction
	# rate is measured with the output tile kept clear -- otherwise the number
	# being compared is the hauling.
	var by_hand: float = _seam_rate()
	var by_machine: float = _miner_rate(true)
	_assert(by_hand > 0.0, "맨 광맥도 실제로 생산한다 (%.2f/분)" % by_hand)
	_assert(by_machine > by_hand * 1.5,
		"채굴기가 확실히 빨리 캔다 (%.2f/분 대 %.2f/분)" % [by_machine, by_hand])

	# And the other half of the same fact, which is the one a player meets first:
	# one cat, one miner and nowhere for the stone to go produces a single stone
	# and then stops. The same cat on the bare seam beside it carries its own
	# output and never stalls. The machine is not an upgrade you drop in -- it is
	# a machine that needs a second cat or a belt, and that is the lesson the
	# first miner is there to teach.
	var stalled: float = _miner_rate(false)
	_assert(stalled < by_hand,
		"나를 사람이 없으면 채굴기는 오히려 못 미친다 (%.2f/분 대 %.2f/분)"
			% [stalled, by_hand])
	print("WORKERS: 맨 광맥 %.2f/분 · 채굴기(나름) %.2f/분 · 채굴기(막힘) %.2f/분"
		% [by_hand, by_machine, stalled])

## Stones a cat digs out of a bare seam and banks, per minute.
func _seam_rate() -> float:
	var sim := _sim()
	sim.cats.clear()
	var seam: Vector2i = sim.core_cell + Sim.STARTER_PATCH[0]
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[0]
	sim.place_cat(seam)
	for _step in 3000:
		sim.tick(0.1)
	var count: float = float(int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)))
	sim.free()
	return count / 5.0

## Stones a miner pulls out of the same seam, per minute. Counted at the machine
## rather than at the core: a miner drops its output on the next tile and
## something else has to move it, so measuring deliveries would be measuring the
## hauling rather than the mining.
## Stones a miner pulls out of the same seam, per minute. With `hauled`, the
## output tile is emptied every tick, which stands in for a belt or a second cat
## and measures the machine rather than the logistics around it. Without it, the
## output has nowhere to go and the machine stops -- which is the state a player
## with exactly one cat actually arrives in.
func _miner_rate(hauled: bool) -> float:
	var sim := _sim()
	sim.cats.clear()
	var seam: Vector2i = sim.core_cell + Sim.STARTER_PATCH[0]
	sim.build(Defs.M_MINER, seam, Vector2i(0, 1))
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[0]
	sim.place_cat(seam)
	var produced: float = 0.0
	for _step in 3000:
		sim.tick(0.1)
		if not hauled:
			continue
		for cell: Vector2i in sim.ground.keys():
			if int(sim.ground[cell]) == Defs.ITEM_HEATSTONE:
				sim.ground.erase(cell)
				produced += 1.0
	if not hauled:
		for cell: Vector2i in sim.ground:
			if int(sim.ground[cell]) == Defs.ITEM_HEATSTONE:
				produced += 1.0
		produced += float(int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)))
	sim.free()
	return produced / 5.0

# --- 5-1 -------------------------------------------------------------------

func _test_miner_needs_operator() -> void:
	var sim := _sim()
	var cell := Vector2i(-1, 0)
	sim.ore[cell] = Defs.ITEM_CRYSTAL
	_assert(sim.build(Defs.M_MINER, cell, Vector2i.RIGHT), "a miner can be built on ore")
	for step in 100:
		sim.tick(0.1)
	_assert(sim.delivered[Defs.ITEM_CRYSTAL] == 0, "an unstaffed miner produces nothing at all")
	_assert(not sim.machine_at(cell).operated, "and it reports itself unoperated")

	var cat := Sim.Cat.new()
	cat.assigned = cell
	cat.state = Defs.CAT_WORKING
	cat.pos = sim.cell_centre(cell)
	sim.cats.append(cat)
	for step in int(Defs.MINER_PERIOD / 0.1) * 2:
		sim.tick(0.1)
	_assert(sim.delivered[Defs.ITEM_CRYSTAL] > 0, "a staffed miner produces")
	_assert(sim.machine_at(cell).operated, "and reports itself operated")
	sim.free()

# --- 5-2 -------------------------------------------------------------------

func _test_new_cats_stand_apart() -> void:
	var sim := _sim()
	# Where a cat arrives from is test_frozen's business now. What is checked
	# here is where it stands once it has: two cats appearing at once used to
	# land on the same pixel, which reads as one cat until they walk away in
	# different directions.
	sim.grant_cats(2)
	_assert(sim.cats.size() == 2, "the cats exist")
	var door: Vector2 = sim.cell_centre(sim.shelter_cell) + Vector2(0.0, float(Defs.TILE))
	for cat: Sim.Cat in sim.cats:
		_assert(is_equal_approx(cat.pos.y, door.y), "a new cat starts on the shelter doorstep")
		_assert(absf(cat.pos.x - door.x) <= float(Defs.TILE), "and within a tile of the door")
		_assert(not sim.blocks_player(Vector2i((cat.pos / float(Defs.TILE)).floor())),
			"and not standing inside the building")
	_assert(sim.cats[0].pos.distance_to(sim.cats[1].pos) > 4.0,
		"two cats arriving together do not land on the same spot")
	sim.free()

# --- 5-3 -------------------------------------------------------------------

func _test_morning_dispatch() -> void:
	var sim := _sim()
	sim.ore[Vector2i(-1, 0)] = Defs.ITEM_CRYSTAL
	sim.ore[Vector2i(0, -1)] = Defs.ITEM_CRYSTAL
	sim.build(Defs.M_MINER, Vector2i(-1, 0), Vector2i.RIGHT)
	sim.build(Defs.M_MINER, Vector2i(0, -1), Vector2i.DOWN)
	sim.grant_cats(2)
	_assert(sim.cats.size() == 2, "two cats adopted")

	# Nothing is assigned automatically: the player carries each cat to a machine.
	sim.dispatch_cats()
	for cat: Sim.Cat in sim.cats:
		_assert(not cat.has_job(), "the game never picks a job for a cat")

	# Carrying: picking up and placing on a miner assigns it for good.
	var cat_cell: Vector2i = Vector2i((sim.cats[0].pos / float(Defs.TILE)).floor())
	_assert(sim.pick_up_cat(cat_cell), "a cat standing nearby can be picked up")
	_assert(sim.carried_cat != null, "the cat is now carried")
	# Both cats start on the same tile, so hold the reference that was actually
	# picked up rather than assuming an index.
	var first: Sim.Cat = sim.carried_cat
	_assert(not sim.pick_up_cat(cat_cell), "only one cat can be carried at a time")
	_assert(not sim.place_cat(Vector2i(5, 5)), "a cat cannot be placed on bare ground as a worker")
	_assert(sim.place_cat(Vector2i(-1, 0)), "a cat can be placed on a miner")
	_assert(sim.carried_cat == null, "the player's arms are free again")
	_assert(first.assigned == Vector2i(-1, 0), "the cat is bound to that machine")
	_assert(first.state == Defs.CAT_WORKING, "and starts working immediately")

	# One machine, one cat.
	var second: Sim.Cat = sim.cats[0] if sim.cats[0] != first else sim.cats[1]
	var second_cell: Vector2i = Vector2i((second.pos / float(Defs.TILE)).floor())
	sim.pick_up_cat(second_cell)
	_assert(not sim.place_cat(Vector2i(-1, 0)), "a taken machine refuses a second cat")
	_assert(sim.place_cat(Vector2i(0, -1)), "the free machine accepts it")

	# Picking a worker back up stops its machine at once.
	sim.tick(0.1)
	_assert(sim.machine_at(Vector2i(-1, 0)).operated, "the staffed machine is running")
	_assert(sim.pick_up_cat(Vector2i(-1, 0)), "the working cat can be collected again")
	sim.tick(0.1)
	_assert(not sim.machine_at(Vector2i(-1, 0)).operated, "and the machine stops")
	sim.drop_cat(sim.cell_centre(Vector2i(4, 4)))

	# Morning turns everyone out of the shelter, and assigned cats set off on foot.
	sim.dispatch_cats()
	var doorstep: Vector2 = sim.cell_centre(sim.shelter_cell)
	for cat: Sim.Cat in sim.cats:
		_assert(cat.pos.distance_to(doorstep) < float(Defs.TILE) * 2.5,
			"every cat comes out of the shelter at first light")
	var spots: Array[float] = []
	for cat: Sim.Cat in sim.cats:
		spots.append(cat.pos.x)
	_assert(absf(spots[0] - spots[1]) > 1.0, "cats stand apart rather than stacking on one tile")
	_assert(second.state == Defs.CAT_TO_MINER, "an assigned cat walks back each morning")
	sim.tick(0.05)
	_assert(not sim.machine_at(Vector2i(0, -1)).operated, "mining waits for arrival")
	for step in 300:
		sim.tick(0.1)
		if second.state == Defs.CAT_WORKING:
			break
	_assert(second.state == Defs.CAT_WORKING, "the cat reaches its machine and resumes")
	sim.free()

# --- 5-4 -------------------------------------------------------------------

func _test_hunger_and_feeding() -> void:
	var sim := _sim()
	_assert(sim.food == Defs.FOOD_START, "the food bin starts stocked")
	var cell := Vector2i(-1, 0)
	sim.ore[cell] = Defs.ITEM_CRYSTAL
	sim.build(Defs.M_MINER, cell, Vector2i.RIGHT)
	sim.grant_cats(1)
	# Assignment is manual now, so staff the machine the way a player would.
	var cat: Sim.Cat = sim.cats[0]
	sim.carried_cat = cat
	_assert(sim.place_cat(cell), "the cat is placed on the miner by hand")

	# Working costs 1/18 of a belly every ten seconds.
	var before: float = cat.hunger
	for step in 100:
		sim.tick(0.1)      # ten seconds
	var spent: float = before - cat.hunger
	_assert(absf(spent - Defs.HUNGER_PER_SECOND * 10.0) < 0.005,
		"열 초의 노동이 정확히 %.4f 를 쓴다" % (Defs.HUNGER_PER_SECOND * 10.0))
	# Slow on purpose: a fed cat works about twelve minutes, which is four days.
	# It used to be three minutes -- inside the first day, before there was a
	# factory for the hunger to be a problem with.
	var minutes: float = (1.0 / Defs.HUNGER_PER_SECOND) / 60.0
	_assert(minutes > 8.0, "배부른 고양이가 %.0f분 일한다 — 서서히 배고파진다" % minutes)

	# Starving halves nothing -- it thirds the rate -- and sends the cat to eat,
	# but only once there is a bin to walk to. There is none at the start of a
	# run: a feeding station standing four days before any cat is hungry is a
	# solution parked next to a problem that has not happened.
	cat.hunger = 0.0
	sim.food_placed = false
	sim.tick(0.1)
	_assert(cat.state != Defs.CAT_TO_FOOD, "밥통이 없으면 먹으러 가지 않는다")
	sim.stock[Defs.ITEM_HEATSTONE] = 20
	_assert(sim.craft_food_bin(), "기지에서 사료 상자를 만든다")
	_assert(sim.food_placed and sim.blocks_player(sim.food_cell), "그리고 세워진다")
	sim.tick(0.1)
	_assert(cat.state == Defs.CAT_TO_FOOD, "an empty cat walks to the food bin")

	var food_before: int = sim.food
	for step in 600:
		sim.tick(0.1)
		if cat.state == Defs.CAT_TO_MINER or cat.state == Defs.CAT_WORKING:
			break
	_assert(cat.hunger >= 1.0, "the cat eats until full")
	_assert(sim.food == food_before - 3, "a full belly costs three units of food")
	_assert(cat.state == Defs.CAT_TO_MINER or cat.state == Defs.CAT_WORKING,
		"and then goes back to its machine")
	sim.free()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("WORKERS_TEST: FAIL - " + message)
		failures += 1

## Machines are bought with materials from an unlocked hotbar, so a test that
## wants to build has to open and fund the base first.
func _open(sim) -> void:
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	sim.unlocked[Defs.M_MINER] = true
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
