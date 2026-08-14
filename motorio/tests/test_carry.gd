extends SceneTree

## A cat in the player's arms must stop being driven by the simulation.
##
## The bug: only three of the nine cat handlers checked for the carried cat.
## Hauling did; walking to a miner, working, walking to the food bowl and eating
## did not. So a cat picked up on its way to eat kept walking to the bowl while
## it was being carried -- carry_at put it in the player's hands every frame and
## _step_toward pulled it back toward the food every tick, and the sprite jumped
## between the two. It could also change state in mid-air, and a carried cat
## still counted as standing at its miner, running a machine from the player's
## arms.
##
## Guarding each handler is what produced the bug in the first place, so the
## check belongs in one place: _tick_cats skips the carried cat entirely.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500

	var cat = sim.Cat.new()
	sim.cats.append(cat)
	var hands := Vector2(1000.0, 1000.0)

	# Every state a cat can be in, carried. None of them may move it, and none of
	# them may change what it is doing: the player decides where a carried cat
	# goes and what it does next.
	var states: Array[int] = [
		Defs.CAT_IDLE, Defs.CAT_TO_MINER, Defs.CAT_WORKING, Defs.CAT_TO_FOOD,
		Defs.CAT_EATING, Defs.CAT_HAUL_TO_ITEM, Defs.CAT_HAUL_TO_BASE,
		Defs.CAT_TO_SHELTER,
	]
	# A real assignment and something to fetch, so the handlers have somewhere to
	# walk to. Without these most of them bail out early and prove nothing.
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) == Defs.ITEM_CRYSTAL:
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "the map has a seam to assign a cat to")
	sim.build(Defs.M_MINER, seam, Vector2i.RIGHT)
	_assert(sim.machine_at(seam) != null, "and a miner standing on it")
	var loose: Vector2i = sim.core_cell + Vector2i(6, 6)
	sim.ground[loose] = Defs.ITEM_CRYSTAL
	sim.food = 50

	for state: int in states:
		sim.carried_cat = cat
		cat.assigned = seam
		cat.haul_target = loose
		cat.hunger = 0.0
		cat.state = state
		sim.carry_at(hands, Vector2.DOWN)
		var held: Vector2 = cat.pos
		var miner = sim.machine_at(seam)
		miner.operated = false
		for step in 20:
			sim.tick(0.05)
		_assert(cat.pos.is_equal_approx(held),
			"a carried cat in state %d is not walked anywhere: %s -> %s" % [state, held, cat.pos])
		_assert(cat.state == state,
			"and does not change its own state: %d became %d" % [state, cat.state])
		_assert(not miner.operated,
			"and does not work a miner from the player's arms (state %d)" % state)

	# Put down, it resumes normally. The guard must stop the cat being simulated,
	# not permanently detach it.
	sim.carried_cat = null
	cat.state = Defs.CAT_TO_MINER
	cat.pos = sim.cell_centre(seam) + Vector2(120.0, 0.0)
	var before: float = cat.pos.distance_to(sim.cell_centre(seam))
	for step in 20:
		sim.tick(0.05)
	_assert(cat.pos.distance_to(sim.cell_centre(seam)) < before,
		"a cat that has been put down walks again")

	# Arrival must not teleport. _step_toward used to snap the last ten pixels
	# onto the goal, which at a cat's walking pace is a fifth of a second of
	# travel appearing in one frame -- visible as the sprite jumping.
	cat.state = Defs.CAT_TO_MINER
	cat.pos = sim.cell_centre(seam) + Vector2(Defs.CAT_AWAY + 1.0, 0.0)
	var step_limit: float = Defs.CAT_SPEED * 0.05 + 0.01
	var previous: Vector2 = cat.pos
	var worst: float = 0.0
	for step in 40:
		sim.tick(0.05)
		worst = maxf(worst, previous.distance_to(cat.pos))
		previous = cat.pos
	_assert(worst <= step_limit,
		"a cat never moves further in one tick than it can walk: %.2f > %.2f" % [worst, step_limit])

	sim.free()
	if failures == 0:
		print("CARRY_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("CARRY_TEST: FAIL - " + message)
		failures += 1
