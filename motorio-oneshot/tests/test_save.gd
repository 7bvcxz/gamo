extends SceneTree

## A save has to bring back the things the player built and earned, including
## the workers, and it must refuse data it no longer understands.

var failures := 0
const PATH := "user://motorio_oneshot_save.cfg"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.remove_absolute(PATH)
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame

	# Build a distinctive state: a staffed miner, a belt with cargo, materials,
	# crates in hand, a part-eaten food bin and a second day in progress.
	var seed_before: int = main.run_seed
	main.sim.ore[Vector2i(-1, 0)] = Defs.ITEM_FROST
	main.sim.heat = 400
	main.sim.build(Defs.M_MINER, Vector2i(-1, 0), Vector2i.RIGHT)
	main.sim.build(Defs.M_BELT, Vector2i(0, 2), Vector2i.UP)
	# Set the balance after building, since building spends it.
	main.sim.heat = 250
	(main.sim.machine_at(Vector2i(0, 2)) as Sim.Machine).items.append({"type": Defs.ITEM_COPPER, "t": 0.4})
	main.sim.carried_boxes = 2
	main.sim.food = 137
	main.sim.delivered[Defs.ITEM_COPPER] = 9
	main.sim.delivered[Defs.ITEM_IRON] = 4
	main.sim.total_heat = 321
	main.sim.carried_boxes = 2
	main.sim.cats.clear()
	var cat := Sim.Cat.new()
	cat.assigned = Vector2i(-1, 0)
	cat.state = Defs.CAT_WORKING
	cat.hunger = 0.42
	cat.pos = main.sim.cell_centre(Vector2i(-1, 0))
	main.sim.cats.append(cat)
	main.day_number = 3
	main.time_left = 88.0
	main.player.warmth = 61.0
	main.player.position = Vector2(123, 456)

	_assert(main.save_game(false), "the game writes a save file")

	# Wipe everything, then restore.
	main.sim.setup(999999)
	main.day_number = 1
	main.player.warmth = 100.0
	_assert(main.load_game(), "the save loads back")

	_assert(main.run_seed == seed_before, "the world seed is restored, so terrain matches")
	_assert(main.day_number == 3, "the day number survives")
	_assert(is_equal_approx(main.time_left, 88.0), "time left in the day survives")
	_assert(main.sim.heat == 250 and main.sim.total_heat == 321, "the economy survives")
	_assert(int(main.sim.delivered[Defs.ITEM_COPPER]) == 9, "copper count survives")
	_assert(int(main.sim.delivered[Defs.ITEM_IRON]) == 4, "iron count survives")
	_assert(main.sim.food == 137, "the food bin level survives")
	_assert(main.sim.carried_boxes == 2, "crates in hand survive")

	var miner: Sim.Machine = main.sim.machine_at(Vector2i(-1, 0))
	_assert(miner != null and miner.type == Defs.M_MINER, "the miner is rebuilt")
	var belt: Sim.Machine = main.sim.machine_at(Vector2i(0, 2))
	_assert(belt != null and belt.items.size() == 1, "cargo on the belt is rebuilt")
	_assert(int(belt.items[0]["type"]) == Defs.ITEM_COPPER, "and it is the same cargo")
	_assert(main.sim.machine_at(main.sim.core_cell) != null, "the core still exists exactly once")

	_assert(main.sim.cats.size() == 1, "the workforce is restored")
	var restored: Sim.Cat = main.sim.cats[0]
	_assert(restored.assigned == Vector2i(-1, 0), "a cat remembers its machine")
	_assert(absf(restored.hunger - 0.42) < 0.01, "a cat remembers how hungry it is")
	_assert(restored.state == Defs.CAT_WORKING, "a cat remembers what it was doing")

	_assert(is_equal_approx(main.player.warmth, 61.0), "body warmth survives")
	_assert(main.player.position.distance_to(Vector2(123, 456)) < 0.5, "the player is where they left off")

	# A restored miner must actually resume producing.
	var produced_before: int = int(main.sim.delivered[Defs.ITEM_FROST])
	for step in 100:
		main.sim.tick(0.1)
	_assert(int(main.sim.delivered[Defs.ITEM_FROST]) > produced_before,
		"the restored factory keeps running")

	# An unknown schema must be refused rather than half-applied.
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("motorio_oneshot", "schema", 999)
	config.save(PATH)
	_assert(not main.load_game(), "a save from another schema is refused")

	main.clear_save()
	_assert(not main.load_game(), "a cleared save does not come back")

	if failures == 0:
		print("SAVE_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SAVE_TEST: FAIL - " + message)
		failures += 1
