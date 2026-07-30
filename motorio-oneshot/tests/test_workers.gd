extends SceneTree

## The worker system: miners are machines, cats are the labour that runs them,
## crates are how labour is acquired, and food is what keeps it running.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_miner_needs_operator()
	_test_crates_and_adoption()
	_test_morning_dispatch()
	_test_hunger_and_feeding()
	if failures == 0:
		print("WORKERS_TEST: PASS")
	quit(failures)

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(31415)
	sim.heat = 400
	return sim

# --- 5-1 -------------------------------------------------------------------

func _test_miner_needs_operator() -> void:
	var sim := _sim()
	var cell := Vector2i(-1, 0)
	sim.ore[cell] = Defs.ITEM_FROST
	_assert(sim.build(Defs.M_MINER, cell, Vector2i.RIGHT), "a miner can be built on ore")
	for step in 100:
		sim.tick(0.1)
	_assert(sim.delivered[Defs.ITEM_FROST] == 0, "an unstaffed miner produces nothing at all")
	_assert(not sim.machine_at(cell).operated, "and it reports itself unoperated")

	var cat := Sim.Cat.new()
	cat.assigned = cell
	cat.state = Defs.CAT_WORKING
	cat.pos = sim.cell_centre(cell)
	sim.cats.append(cat)
	for step in 100:
		sim.tick(0.1)
	_assert(sim.delivered[Defs.ITEM_FROST] > 0, "a staffed miner produces")
	_assert(sim.machine_at(cell).operated, "and reports itself operated")
	sim.free()

# --- 5-2 -------------------------------------------------------------------

func _test_crates_and_adoption() -> void:
	var sim := _sim()
	var starter := 0
	for cell: Vector2i in sim.cat_boxes:
		if Vector2(cell - sim.core_cell).length() <= Defs.WARM_BASE:
			starter += 1
	_assert(starter >= Defs.STARTER_CAT_BOXES,
		"three crates start inside the opening warm radius")
	_assert(sim.cat_boxes.size() > Defs.STARTER_CAT_BOXES * 3,
		"more crates are strewn further out, so exploring buys workers")

	var first: Vector2i = sim.cat_boxes.keys()[0]
	_assert(sim.collect_box_at(first), "walking over a crate collects it")
	_assert(not sim.cat_boxes.has(first), "the crate leaves the world")
	_assert(sim.carried_boxes == 1, "the crate is now carried")
	_assert(not sim.collect_box_at(first), "an empty tile collects nothing")

	_assert(sim.adopt_cats() == 0, "fewer than three crates adopts nobody")
	sim.carried_boxes = Defs.BOXES_PER_CAT * 2
	_assert(sim.adopt_cats() == 2, "six crates adopt two cats")
	_assert(sim.cats.size() == 2, "the cats exist")
	_assert(sim.carried_boxes == 0, "the crates are spent")
	for cat: Sim.Cat in sim.cats:
		_assert(cat.pos.distance_to(sim.cell_centre(sim.shelter_cell)) < 1.0,
			"a new cat starts at the shelter")
	sim.free()

# --- 5-3 -------------------------------------------------------------------

func _test_morning_dispatch() -> void:
	var sim := _sim()
	sim.ore[Vector2i(-1, 0)] = Defs.ITEM_FROST
	sim.ore[Vector2i(0, -1)] = Defs.ITEM_FROST
	sim.build(Defs.M_MINER, Vector2i(-1, 0), Vector2i.RIGHT)
	sim.build(Defs.M_MINER, Vector2i(0, -1), Vector2i.DOWN)
	sim.carried_boxes = Defs.BOXES_PER_CAT * 2
	sim.adopt_cats()
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

	# Morning sends assigned cats back to their own machine, on foot.
	sim.dispatch_cats()
	_assert(second.state == Defs.CAT_TO_MINER, "an assigned cat walks back each morning")
	second.pos = sim.cell_centre(sim.shelter_cell)
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
	sim.ore[cell] = Defs.ITEM_FROST
	sim.build(Defs.M_MINER, cell, Vector2i.RIGHT)
	sim.carried_boxes = Defs.BOXES_PER_CAT
	sim.adopt_cats()
	# Assignment is manual now, so staff the machine the way a player would.
	var cat: Sim.Cat = sim.cats[0]
	sim.carried_cat = cat
	_assert(sim.place_cat(cell), "the cat is placed on the miner by hand")

	# Working costs 1/18 of a belly every ten seconds.
	var before: float = cat.hunger
	for step in 100:
		sim.tick(0.1)      # ten seconds
	var spent: float = before - cat.hunger
	_assert(absf(spent - 1.0 / 18.0) < 0.005, "ten seconds of work costs one eighteenth")

	# Starving halves nothing -- it thirds the rate -- and sends the cat to eat.
	cat.hunger = 0.0
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
