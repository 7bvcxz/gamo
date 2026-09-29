extends SceneTree

## The agent fuels a generator by hand, the way a player does (Factory
## Interaction Pass 01): it walks to a generator no belt reaches, presses Z, picks
## "5개 넣기" and then "전부 넣기" in the window, and the grid comes up -- with
## the bag down by exactly what went into the drum.

const Factory := preload("res://tests/helpers/factory.gd")
const Body := preload("res://tools/agent/body.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _world()
	_test()
	_finish()
	if failures == 0:
		print("PASS test_agent_can_manual_fuel_generator")
	else:
		print("FAIL test_agent_can_manual_fuel_generator (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


var main: Node2D
var sim: Sim
var body

## The world the agent tests share: past the opening, warm everywhere it walks,
## everything open, the bag full, the test area east of the fire cleared, and the
## game's own process stopped so only the body drives it (as in
## test_agent_pathfinding_multitile).
func _world() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run(5150)
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.process_mode = Node.PROCESS_MODE_DISABLED
	sim = main.sim
	sim.has_gun = true
	for type: int in Defs.BUILDABLE:
		sim.unlocked[type] = true
	for item_id: int in range(Defs.ITEM_NAMES.size()):
		sim.stock[item_id] = 60
		sim.held_items[item_id] = true
	sim.stones_in = int(Defs.BASE_LEVELS[-1]["stones"])
	sim._refresh_radius()
	Factory.clear(sim, Rect2i(sim.core_cell + Factory.AREA.position, Factory.AREA.size))
	body = Body.new(main, null)

func _finish() -> void:
	main.clear_save()
	main.free()

func _test() -> void:
	var cell: Vector2i = Factory.at(sim, Vector2i(10, 10))
	_assert(sim.build(Defs.M_GENERATOR, cell, Vector2i.RIGHT), "벨트가 닿지 않는 곳의 발전기")
	var generator: Sim.Machine = sim.machine_at(cell)
	var fuel: int = Defs.GENERATOR_FUEL
	var bag: int = int(sim.stock[fuel])
	var five: int = body.fuel_generator(cell, 5)
	_assert(five == 5, "창에서 다섯 개를 넣었다 (%d)" % five)
	var rest: int = body.fuel_generator(cell, -1)
	_assert(five + rest == Defs.GENERATOR_FUEL_CAP, "전부 넣기로 드럼을 채웠다 (%d)" % (five + rest))
	_assert(int(sim.stock[fuel]) == bag - Defs.GENERATOR_FUEL_CAP, "가방은 정확히 그만큼 줄었다")
	body.run(1.0, "watching the generator")
	_assert(generator.operated or sim.power_capacity > 0.0, "발전기가 돈다 (전력 %.1f)" % sim.power_capacity)
