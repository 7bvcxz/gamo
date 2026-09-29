extends SceneTree

## Heat stone goes into a generator by hand (Factory Interaction Pass 01): one,
## five, or all that fits -- the bag and the drum change by the same number, the
## drum stops at GENERATOR_FUEL_CAP, other materials are refused, and a generator
## fed only by hand makes power. Then through the game: Z at the generator opens
## its window and the rows do the same.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_sim()
	await _test_window()
	if failures == 0:
		print("PASS test_generator_manual_heatstone")
	else:
		print("FAIL test_generator_manual_heatstone (%d)" % failures)
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

func _test_sim() -> void:
	var sim: Sim = Factory.world()
	var generator: Sim.Machine = Factory.put(sim, Defs.M_GENERATOR, Factory.at(sim, Vector2i(6, 6)), Vector2i.RIGHT)
	_assert(generator != null, "발전기")
	var fuel: int = Defs.GENERATOR_FUEL
	sim.stock[fuel] = 12
	_assert(sim.insert_by_hand(generator, fuel, 1) == 1, "한 개 넣는다")
	_assert(int(generator.buffer[fuel]) == 1 and int(sim.stock[fuel]) == 11, "가방 -1, 드럼 +1")
	_assert(sim.insert_by_hand(generator, fuel, 5) == 5, "다섯 개 넣는다")
	var room: int = Defs.GENERATOR_FUEL_CAP - 6
	_assert(sim.insert_by_hand(generator, fuel, -1) == room, "전부: 들어가는 만큼 (%d)" % room)
	_assert(int(generator.buffer[fuel]) == Defs.GENERATOR_FUEL_CAP, "드럼이 가득 찼다")
	_assert(int(sim.stock[fuel]) == 12 - Defs.GENERATOR_FUEL_CAP, "가방에서 정확히 그만큼 빠졌다")
	_assert(sim.insert_by_hand(generator, fuel, 1) == 0, "가득 차면 더 들어가지 않는다")
	_assert(int(sim.stock[fuel]) == 12 - Defs.GENERATOR_FUEL_CAP, "그리고 가방도 그대로다")
	_assert(sim.insert_by_hand(generator, Defs.ITEM_COPPER, 1) == 0, "구리는 받지 않는다")
	Factory.run(sim, 1.0)
	_assert(sim.power_capacity > 0.0, "손으로만 넣은 발전기가 전력을 낸다 (%.1f)" % sim.power_capacity)
	sim.free()

func _test_window() -> void:
	var main: Node2D = await _main()
	var sim: Sim = main.sim
	var front: Vector2i = _stand(main)
	_assert(sim.build(Defs.M_GENERATOR, front, Vector2i.RIGHT), "그녀 앞에 발전기")
	var generator: Sim.Machine = sim.machine_at(front)
	sim.stock[Defs.GENERATOR_FUEL] = 20
	_assert(main.active_prompt() == "HANDFEED", "앞에 서면 [Z] 넣기 (%s)" % main.active_prompt())
	main._primary_action()
	_assert(main.machine_menu_open, "Z 로 창이 열린다")
	var rows: Array[Dictionary] = main.machine_rows()
	_assert(rows.size() == 3, "한 개·다섯 개·전부 (%d줄)" % rows.size())
	for index in [0, 1, 2]:
		main.menu_index = index
		main._machine_menu_confirm()
	_assert(main.machine_menu_open, "넣어도 창은 열려 있다")
	_assert(int(generator.buffer[Defs.GENERATOR_FUEL]) == Defs.GENERATOR_FUEL_CAP,
		"세 줄을 누르니 드럼이 찼다 (%d)" % int(generator.buffer[Defs.GENERATOR_FUEL]))
	_assert(int(sim.stock[Defs.GENERATOR_FUEL]) == 20 - Defs.GENERATOR_FUEL_CAP, "가방은 그만큼 줄었다")
	_assert(main.hud.generator_sentence(generator).contains("타고") or generator.operated == false,
		"창은 발전기 상태를 문장으로 말한다")
	generator.buffer.clear()
	generator.operated = false
	_assert(main.hud.generator_sentence(generator).contains("연료가 없어 멈춰 있다"), "빈 발전기: 연료가 없어 멈춰 있다")
	main.close_machine_menu()
	_assert(main.active_prompt() != "HANDFEED", "한 번 넣고 나면 안내는 다시 뜨지 않는다")
	main.clear_save()
	main.free()
