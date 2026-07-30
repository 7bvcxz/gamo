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
	sim.carried_boxes = Defs.BOXES_PER_CAT * 3
	sim.adopt_cats()
	_assert(sim.cats.size() == 3, "three cats adopted")

	sim.dispatch_cats()
	var assigned := 0
	var idle := 0
	for cat: Sim.Cat in sim.cats:
		if cat.has_job():
			assigned += 1
			_assert(cat.state == Defs.CAT_TO_MINER, "an assigned cat sets off walking")
		else:
			idle += 1
	_assert(assigned == 2, "one cat per miner, no doubling up")
	_assert(idle == 1, "the spare cat stays at the shelter")

	# Nothing is produced until the walk finishes.
	sim.tick(0.05)
	_assert(sim.machine_at(Vector2i(-1, 0)).operated == false, "mining waits for arrival")
	for step in 200:
		sim.tick(0.1)
		var all_there := true
		for cat: Sim.Cat in sim.cats:
			if cat.has_job() and cat.state != Defs.CAT_WORKING:
				all_there = false
		if all_there:
			break
	for cat: Sim.Cat in sim.cats:
		if cat.has_job():
			_assert(cat.state == Defs.CAT_WORKING, "cats reach their machine and start work")
			_assert(cat.pos.distance_to(sim.cell_centre(cat.assigned)) <= Defs.CAT_ARRIVE,
				"a working cat is actually standing at its machine")
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
	sim.dispatch_cats()
	var cat: Sim.Cat = sim.cats[0]
	cat.pos = sim.cell_centre(cell)
	cat.state = Defs.CAT_WORKING

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
