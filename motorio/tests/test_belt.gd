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
## it. Miner -> belt -> core, and nothing on the map generating electricity.
##
## Written around the exchanger until 1.0.8, which was the only machine that made
## one material out of another. It is gone, and the producer these tests need is
## the thing that was always the first one: a seam with a machine on it.
func _test_unpowered_line_delivers() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_open(sim)
	var source := Vector2i(-2, 0)
	sim.ore[source] = Defs.ITEM_CRYSTAL
	_assert(sim.build(Defs.M_MINER, source, Vector2i.RIGHT), "a miner goes down on a seam")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 0), Vector2i.RIGHT), "with a belt into the core")
	var miner: Sim.Machine = sim.machine_at(source)
	# A cat works it. That is what makes this an *unpowered* line: no generator
	# anywhere, and the belt is not supposed to need one either.
	sim.grant_cats(1)
	sim.cats[0].pos = sim.cell_centre(source)
	sim.cats[0].assigned = source
	sim.cats[0].state = Defs.CAT_WORKING
	var delivered_before: int = int(sim.delivered.get(Defs.ITEM_CRYSTAL, 0))
	var window: float = Defs.MINER_PERIOD * 3.0 + 1.0 / Defs.belt_speed(0) + 2.0
	var elapsed: float = 0.0
	while elapsed < window:
		sim.tick(0.05)
		elapsed += 0.05
	var delivered: int = int(sim.delivered.get(Defs.ITEM_CRYSTAL, 0)) - delivered_before
	_assert(delivered > 0, "the line delivers to the core without electricity: %d" % delivered)
	_assert(not miner.stalled, "and the miner never reports a blocked output")
	_assert(is_equal_approx(sim.power_capacity, 0.0), "there being no grid at all")
	sim.free()

## A belt that leads nowhere fills up and stops the machine feeding it. That is
## correct -- it is how a player finds a line they forgot to finish -- and it is
## pinned here so it is never confused with the bug above.
func _test_dead_end_backs_up() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_open(sim)
	var source := Vector2i(-2, 5)
	sim.ore[source] = Defs.ITEM_CRYSTAL
	_assert(sim.build(Defs.M_MINER, source, Vector2i.RIGHT), "a miner goes down")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 5), Vector2i.RIGHT), "with a belt to nowhere")
	var miner: Sim.Machine = sim.machine_at(source)
	var belt: Sim.Machine = sim.machine_at(Vector2i(-1, 5))
	sim.grant_cats(1)
	sim.cats[0].pos = sim.cell_centre(source)
	sim.cats[0].assigned = source
	sim.cats[0].state = Defs.CAT_WORKING
	var guard: int = 0
	while not miner.stalled and guard < 8000:
		sim.tick(0.05)
		guard += 1
	_assert(miner.stalled, "the miner eventually stalls on a dead-end belt")
	_assert(belt.items.size() == Defs.BELT_CAPACITY,
		"and only once the belt is genuinely full: %d of %d" % [belt.items.size(), Defs.BELT_CAPACITY])
	_assert(sim.meter_status(miner) == "출력 막힘", "which the panel names")
	sim.free()

func _open(sim) -> void:
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	sim.unlocked[Defs.M_MINER] = true
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.power_ever = true
	sim._check_unlocks()
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("BELT_TEST: FAIL - " + message)
		failures += 1
