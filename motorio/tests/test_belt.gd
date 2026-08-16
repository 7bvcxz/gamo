extends SceneTree

## Belts, with no generator anywhere.
##
## This is the bug this file exists for: belts drew 0.1 power each, and the
## supply ratio every belt multiplied its speed by was capacity/draw. Before the
## first generator that is 0/0.1 -- exactly zero -- so a belt built in the
## ordinary early game never moved a single tile, and whatever fed it reported a
## blocked output. The belt unlocks on the first copper; the generator costs ten
## of it plus crystals to burn. Logistics required the tier logistics leads to.
##
## Every existing belt test called a `_power()` helper first, so all of them ran
## in a world that had already solved the problem. The unpowered case -- which is
## every player's first hour -- was never once exercised. So the rule here is
## that nothing in this file is allowed to build a generator.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_unpowered_belt_moves()
	_test_unpowered_line_delivers()
	_test_dead_end_backs_up()
	_test_batch_output_is_not_destroyed()
	if failures == 0:
		print("BELT_TEST: PASS")
	quit(failures)

## The plain fact the bug broke: an item put on a belt travels.
func _test_unpowered_belt_moves() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_open(sim)
	_assert(sim.machine_count(Defs.M_GENERATOR) == 0, "no generator exists")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 0), Vector2i.RIGHT), "a belt goes down")
	var belt: Sim.Machine = sim.machine_at(Vector2i(-1, 0))
	sim.tick(0.05)
	_assert(is_equal_approx(sim.power_draw, 0.0), "and asks the grid for nothing")
	_assert(is_equal_approx(sim.power_capacity, 0.0), "there being no grid to ask")

	_assert(sim._push_into(Vector2i(-1, 0), Defs.ITEM_CRYSTAL, Vector2i(-2, 0)),
		"the belt accepts an item")
	var start: float = float(belt.items[0]["t"])
	# One second of travel, which at any sane belt speed is a visible distance.
	for step in 20:
		sim.tick(0.05)
	var moved: float = float(belt.items[0]["t"]) - start
	_assert(moved > 0.0, "and the item actually travels: moved %.3f of a tile in 1s" % moved)
	_assert(absf(moved - Defs.belt_speed(belt.tier)) < 0.02,
		"at the rated speed: %.3f vs %.3f tiles/s" % [moved, Defs.belt_speed(belt.tier)])
	sim.free()

## The whole point of a belt: production reaching the base without a cat carrying
## it. Exchanger -> belt -> core, and nothing on the map generating electricity.
func _test_unpowered_line_delivers() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_open(sim)
	var source := Vector2i(-2, 0)
	_assert(sim.build(Defs.M_EXCHANGER, source, Vector2i.RIGHT), "an exchanger goes down")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 0), Vector2i.RIGHT), "with a belt into the core")
	var exchanger: Sim.Machine = sim.machine_at(source)
	var delivered_before: int = int(sim.delivered.get(Defs.ITEM_ENERGY, 0))

	# Long enough for a few batches plus the trip: one recipe period per item and
	# one tile of belt, derived rather than guessed.
	var recipe: Dictionary = Defs.RECIPES[exchanger.recipe]
	var window: float = float(recipe["period"]) * 3.0 + 1.0 / Defs.belt_speed(0) + 2.0
	var elapsed: float = 0.0
	while elapsed < window:
		# Kept fed by hand: this is a test of the belt, not of the supply chain.
		for item_type: int in recipe["in"]:
			exchanger.buffer[item_type] = 8
		sim.tick(0.05)
		elapsed += 0.05

	var delivered: int = int(sim.delivered.get(Defs.ITEM_ENERGY, 0)) - delivered_before
	_assert(delivered > 0, "the line delivers to the core without electricity: %d" % delivered)
	_assert(not exchanger.stalled, "and the exchanger never reports a blocked output")
	_assert(sim.meter_status(exchanger) == "가동 중",
		"the panel agrees it is running: '%s'" % sim.meter_status(exchanger))
	sim.free()

## A belt that leads nowhere fills up and stops the machine feeding it. That is
## correct -- it is how a player finds a line they forgot to finish -- and it is
## pinned here so it is never confused with the bug above.
func _test_dead_end_backs_up() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_open(sim)
	var source := Vector2i(-2, 5)
	_assert(sim.build(Defs.M_EXCHANGER, source, Vector2i.RIGHT), "an exchanger goes down")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 5), Vector2i.RIGHT), "with a belt to nowhere")
	var exchanger: Sim.Machine = sim.machine_at(source)
	var belt: Sim.Machine = sim.machine_at(Vector2i(-1, 5))
	var recipe: Dictionary = Defs.RECIPES[exchanger.recipe]
	var guard: int = 0
	while not exchanger.stalled and guard < 4000:
		for item_type: int in recipe["in"]:
			exchanger.buffer[item_type] = 8
		sim.tick(0.05)
		guard += 1
	_assert(exchanger.stalled, "the exchanger eventually stalls on a dead-end belt")
	_assert(belt.items.size() == Defs.BELT_CAPACITY,
		"and only once the belt is genuinely full: %d of %d" % [belt.items.size(), Defs.BELT_CAPACITY])
	_assert(sim.meter_status(exchanger) == "출력 막힘", "which the panel names")
	sim.free()

## A recipe that makes three at once cannot fit them all onto one belt tile in
## the same instant. The leftovers have to survive: consuming the inputs and
## dropping two of the three outputs is a loss the player cannot see happening
## and cannot explain afterwards.
func _test_batch_output_is_not_destroyed() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_open(sim)
	sim.unlocked_recipes[Defs.RECIPE_ALLOY] = true
	var source := Vector2i(-2, 9)
	_assert(sim.build(Defs.M_EXCHANGER, source, Vector2i.RIGHT), "an exchanger goes down")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 9), Vector2i.RIGHT), "feeding a belt")
	var exchanger: Sim.Machine = sim.machine_at(source)
	_assert(sim.cycle_recipe(source) == Defs.RECIPE_ALLOY, "set to the three-output recipe")
	var recipe: Dictionary = Defs.RECIPES[exchanger.recipe]
	_assert(int(recipe["out"]) > 1, "which really does make more than one at a time")

	# Exactly one batch of inputs and no more, so what comes out can be compared
	# against what the recipe promises. Comparing the meter against the world
	# would prove nothing: the meter only counts items that were successfully
	# emitted, so it agrees with itself even when the rest were dropped.
	for item_type: int in recipe["in"]:
		exchanger.buffer[item_type] = int(recipe["in"][item_type])
	var before: int = _energy_in_world(sim)
	var elapsed: float = 0.0
	while elapsed < float(recipe["period"]) * 4.0:
		sim.tick(0.05)
		elapsed += 0.05
	var produced: int = _energy_in_world(sim) - before

	var consumed := true
	for item_type: int in recipe["in"]:
		if int(exchanger.buffer.get(item_type, 0)) > 0:
			consumed = false
	if consumed:
		_assert(produced == int(recipe["out"]),
			"one batch of inputs yields the whole batch of outputs: expected %d, got %d"
			% [int(recipe["out"]), produced])
	else:
		# It kept the inputs instead of half-making the batch, which is the other
		# acceptable answer -- nothing was consumed, so nothing can be lost.
		_assert(produced == 0, "a batch it could not finish did not part-produce: %d" % produced)
	sim.free()

## Energy crystals anywhere they can be: on belts, on the floor, banked.
func _energy_in_world(sim) -> int:
	var total: int = int(sim.delivered.get(Defs.ITEM_ENERGY, 0))
	for cell: Vector2i in sim.ground:
		if int(sim.ground[cell]) == Defs.ITEM_ENERGY:
			total += sim.ground_count(cell)
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		for item: Dictionary in machine.items:
			if int(item["type"]) == Defs.ITEM_ENERGY:
				total += 1
		total += int(machine.buffer.get(Defs.ITEM_ENERGY, 0))
	return total

func _open(sim) -> void:
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
	sim.stock[Defs.ITEM_ENERGY] = 500

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("BELT_TEST: FAIL - " + message)
		failures += 1
