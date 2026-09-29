extends SceneTree

## Nothing is made or lost by hand (Factory Interaction Pass 01). The count of
## every material -- bag plus buffer plus output -- is the same after two hundred
## rapid mixed presses, after a save and load in the middle of it, after the
## recipe is switched with material still inside (it comes back out through the
## output and is taken), and when the machine is already full.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rapid()
	await _test_save_load()
	_test_recipe_switch()
	if failures == 0:
		print("PASS test_manual_transfer_no_duplication")
	else:
		print("FAIL test_manual_transfer_no_duplication (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _main() -> Node2D:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run(5150)
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim: Sim = main.sim
	for type: int in Defs.BUILDABLE:
		sim.unlocked[type] = true
	for item_id: int in range(Defs.ITEM_NAMES.size()):
		sim.stock[item_id] = 50
		sim.held_items[item_id] = true
	sim.stones_in = maxi(sim.stones_in, int(Defs.BASE_LEVELS[-1]["stones"]))
	sim._refresh_radius()
	Factory.clear(sim, Rect2i(sim.core_cell + Factory.AREA.position, Factory.AREA.size))
	return main

## She stands in the test area facing east; returns the cell in front of her.
func _stand(main: Node2D) -> Vector2i:
	main.player.position = Grid.centre(Factory.at(main.sim, Vector2i(6, 10)))
	main.player.set("facing", Vector2i.RIGHT)
	return main.target_cell()

func _total(sim: Sim, machine: Sim.Machine, item_type: int) -> int:
	return int(sim.stock.get(item_type, 0)) + int(machine.buffer.get(item_type, 0)) \
		+ int(machine.outbox.get(item_type, 0))

func _test_rapid() -> void:
	var sim: Sim = Factory.world()
	var generator: Sim.Machine = Factory.put(sim, Defs.M_GENERATOR, Factory.at(sim, Vector2i(2, 2)), Vector2i.RIGHT)
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, Factory.at(sim, Vector2i(8, 2)), Vector2i.RIGHT)
	var fuel: int = Defs.GENERATOR_FUEL
	var wanted: int = int(sim.recipe_of(machine)["inputs"][0]["item"])
	sim.stock[fuel] = 37
	sim.stock[wanted] = 23
	var fuel_before: int = _total(sim, generator, fuel)
	var ore_before: int = _total(sim, machine, wanted)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for press in 200:
		match rng.randi() % 4:
			0: sim.insert_by_hand(generator, fuel, [1, 5, -1][rng.randi() % 3])
			1: sim.insert_by_hand(machine, wanted, [1, 5, -1][rng.randi() % 3])
			2: sim.take_by_hand(machine)
			3:
				# Something else taking from the drum between presses: the
				# generator's own burn, done by hand here so the sum is exact.
				if int(generator.buffer.get(fuel, 0)) > 0:
					generator.buffer[fuel] = int(generator.buffer[fuel]) - 1
					sim.stock[fuel] = int(sim.stock[fuel]) + 1
	_assert(_total(sim, generator, fuel) == fuel_before, "열석 합이 그대로다 (%d)" % _total(sim, generator, fuel))
	_assert(_total(sim, machine, wanted) == ore_before, "재료 합이 그대로다")
	# Full: a press moves nothing and takes nothing from the bag.
	sim.insert_by_hand(generator, fuel, -1)
	var bag: int = int(sim.stock[fuel])
	_assert(sim.insert_by_hand(generator, fuel, 5) == 0 and int(sim.stock[fuel]) == bag,
		"가득 찬 드럼에는 들어가지도, 가방에서 빠지지도 않는다")
	sim.free()

func _test_save_load() -> void:
	var main: Node2D = await _main()
	var sim: Sim = main.sim
	var cell: Vector2i = Factory.at(sim, Vector2i(8, 8))
	_assert(sim.build(Defs.M_MANUFACTURER, cell, Vector2i.RIGHT), "제조기")
	var machine: Sim.Machine = sim.machine_at(cell)
	var wanted: int = int(sim.recipe_of(machine)["inputs"][0]["item"])
	sim.stock[wanted] = 9
	sim.insert_by_hand(machine, wanted, -1)
	machine.outbox[Defs.ITEM_IRON_PLATE] = 2
	var before: int = _total(sim, machine, wanted)
	var plates: int = _total(sim, machine, Defs.ITEM_IRON_PLATE)
	_assert(main.save_game(false), "저장한다")
	main._start_run(99)
	_assert(main.load_game(), "불러온다")
	sim = main.sim
	machine = sim.machine_at(cell)
	_assert(machine != null, "제조기가 돌아온다")
	if machine != null:
		_assert(_total(sim, machine, wanted) == before, "넣은 재료의 합이 그대로다")
		_assert(_total(sim, machine, Defs.ITEM_IRON_PLATE) == plates, "꺼내지 않은 산출도 그대로다")
		sim.take_by_hand(machine)
		_assert(_total(sim, machine, Defs.ITEM_IRON_PLATE) == plates, "불러온 뒤 꺼내도 합이 같다")
	main.clear_save()
	main.free()

func _test_recipe_switch() -> void:
	var sim: Sim = Factory.world()
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, Factory.at(sim, Vector2i(8, 14)), Vector2i.RIGHT)
	var recipes: Array[Dictionary] = Defs.recipes_for_machine(Defs.M_MANUFACTURER)
	_assert(recipes.size() >= 2, "제조기에 레시피가 둘 이상")
	sim.set_recipe(machine, String(recipes[0]["key"]))
	var wanted: int = int(recipes[0]["inputs"][0]["item"])
	sim.stock[wanted] = 10
	sim.insert_by_hand(machine, wanted, -1)
	# Nothing in front to drain into: a seam blocks the output cell.
	var ahead: Vector2i = sim.output_cell(machine)
	sim.put_ore(ahead, Defs.ITEM_IRON)
	var before: int = _total(sim, machine, wanted)
	sim.set_recipe(machine, String(recipes[1]["key"]))
	_assert(_total(sim, machine, wanted) == before, "레시피를 바꿔도 재료는 사라지지 않는다 (출력으로 돌아갔다)")
	sim.take_by_hand(machine)
	_assert(int(sim.stock[wanted]) == before, "꺼내면 가방으로 전부 돌아온다")
	sim.free()
