extends SceneTree

## A save has to bring back the things the player built and earned, including
## the workers, and it must refuse data it no longer understands.

var failures := 0
const PATH := "user://motorio_save.cfg"
## Where the staged factory stands, in build cells (Grid v2): a post on the
## middle starter node south of the base, and the belt home from it.
##
## A node the world generates, not one the test puts down. Ore is not in the
## save -- a load regenerates it from the seed -- so a post on a hand-placed seam
## comes back standing on bare snow. This test used to do exactly that and still
## saw the factory "keep running", because the old tick made crystal out of
## nothing when its seam was missing (World Visual Pass 01).
const MINER := Vector2i(1, 8)
const BELT := Vector2i(1, 5)
const ICE := Vector2i(10, -6)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.remove_absolute(PATH)
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame

	# Build a distinctive state: a staffed miner, a belt with cargo, materials,
	# a cat in her arms, a part-eaten food bin and a second day in progress.
	var seed_before: int = main.run_seed
	# Past the opening first. A world with a staffed miner and a belt full of
	# cargo but no fire is not a world this game can reach, and leaning on it
	# meant "the core still exists" was really asking about the core `setup`
	# leaves behind rather than the one the case unfolds into.
	main.finish_tutorial()
	_open(main.sim)
	# A post facing the base, and the belt from its output up the lane.
	_assert(main.sim.ore_type_at(MINER) == Defs.ITEM_HEATSTONE, "(the starter node is there)")
	main.sim.build(Defs.M_MINER, MINER, Vector2i.UP)
	var out: Vector2i = main.sim.output_cell(main.sim.machine_at(MINER))
	for y in range(BELT.y, out.y + 1):
		main.sim.build(Defs.M_BELT, Vector2i(BELT.x, y), Vector2i.UP)
	(main.sim.machine_at(BELT) as Sim.Machine).items.append({"type": Defs.ITEM_COPPER, "t": 0.4})
	main.sim.carried_frozen = true
	main.sim.frozen_cats.clear()
	main.sim.frozen_cats[ICE] = 0.62
	main.sim.food = 137
	main.sim.delivered[Defs.ITEM_COPPER] = 9
	main.sim.stones_in = 321
	main.sim.cats.clear()
	var cat := Sim.Cat.new()
	cat.assigned = MINER
	cat.state = Defs.CAT_WORKING
	cat.hunger = 0.42
	cat.pos = main.sim.post_stand(MINER)
	main.sim.cats.append(cat)
	main.day_number = 3
	main.time_left = 88.0
	main.player.warmth = 61.0
	main.player.position = Vector2(123, 456)
	main.sim.thawed[Vector2i(9, -7)] = true

	_assert(main.save_game(false), "the game writes a save file")

	# Wipe everything, then restore.
	main.sim.setup(999999)
	main.day_number = 1
	main.player.warmth = 100.0
	_assert(main.load_game(), "the save loads back")

	_assert(main.run_seed == seed_before, "the world seed is restored, so terrain matches")
	_assert(main.day_number == 3, "the day number survives")
	_assert(is_equal_approx(main.time_left, 88.0), "time left in the day survives")
	_assert(main.sim.stones_in == 321, "the stones burnt into the circle survive")
	_assert(int(main.sim.delivered[Defs.ITEM_COPPER]) == 9, "copper count survives")
	_assert(main.sim.food == 137, "the food bin level survives")
	_assert(main.sim.carried_frozen, "the frozen cat in her arms survives")
	_assert(is_equal_approx(float(main.sim.frozen_cats.get(ICE, 0.0)), 0.62),
		"and one half-melted on the ground keeps its progress")

	var miner: Sim.Machine = main.sim.machine_at(MINER)
	_assert(miner != null and miner.type == Defs.M_MINER, "the miner is rebuilt")
	var belt: Sim.Machine = main.sim.machine_at(BELT)
	_assert(belt != null and belt.items.size() == 1, "cargo on the belt is rebuilt")
	_assert(int(belt.items[0]["type"]) == Defs.ITEM_COPPER, "and it is the same cargo")
	_assert(main.sim.machine_at(main.sim.core_cell) != null, "the core still exists exactly once")

	_assert(main.sim.cats.size() == 1, "the workforce is restored")
	var restored: Sim.Cat = main.sim.cats[0]
	_assert(restored.assigned == MINER, "a cat remembers its machine")
	_assert(absf(restored.hunger - 0.42) < 0.01, "a cat remembers how hungry it is")
	_assert(restored.state == Defs.CAT_WORKING, "a cat remembers what it was doing")

	_assert(is_equal_approx(main.player.warmth, 61.0), "body warmth survives")
	# Five seconds with a torch is work. A reload that put the ice back would be
	# a theft of it.
	_assert(bool(main.sim.thawed.get(Vector2i(9, -7), false)),
		"melted ground stays melted across a save")
	_assert(main.player.position.distance_to(Vector2(123, 456)) < 0.5, "the player is where they left off")

	# A restored miner must actually resume producing: heat stone up the belt
	# and into the fire.
	var produced_before: int = int(main.sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) \
		+ main.sim.stones_in
	for step in int(Defs.MINER_PERIOD / 0.1) * 4:
		main.sim.tick(0.1)
	_assert(int(main.sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) + main.sim.stones_in > produced_before,
		"the restored factory keeps running")

	# An unknown schema must be refused rather than half-applied.
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("motorio", "schema", 999)
	config.save(PATH)
	_assert(not main.load_game(), "a save from another schema is refused")

	main.clear_save()
	_assert(not main.load_game(), "a cleared save does not come back")

	# Refused, but kept: since Grid v2 a save from any other schema is copied
	# aside before anything can write over it, and clearing does not touch the
	# copy. This test made that copy on every run and left it in the real user
	# folder, so it checks the copy is there and then takes it away itself.
	var kept: String = main.backup_path(0, 999)
	_assert(FileAccess.file_exists(kept), "the refused save was copied aside, and clearing kept it")
	DirAccess.remove_absolute(kept)

	if failures == 0:
		print("SAVE_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SAVE_TEST: FAIL - " + message)
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
	sim.power_ever = true
	sim._check_unlocks()
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
