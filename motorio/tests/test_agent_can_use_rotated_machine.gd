extends SceneTree

## The agent turns a manufacturer with R and uses it (Factory Interaction Pass
## 01): built facing east, turned to face south by pressing R where she stands,
## fed by hand through its window, powered by a hand-fuelled generator -- and the
## part comes out of the *south* face and is taken back out by hand.

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
		print("PASS test_agent_can_use_rotated_machine")
	else:
		print("FAIL test_agent_can_use_rotated_machine (%d)" % failures)
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
	var gen_cell: Vector2i = Factory.at(sim, Vector2i(4, 4))
	_assert(sim.build(Defs.M_GENERATOR, gen_cell, Vector2i.RIGHT), "발전기")
	body.fuel_generator(gen_cell, -1)
	var cell: Vector2i = Factory.at(sim, Vector2i(12, 8))
	_assert(sim.build(Defs.M_MANUFACTURER, cell, Vector2i.RIGHT), "제조기를 동쪽으로")
	var machine: Sim.Machine = sim.machine_at(cell)
	_assert(body.turn_machine(cell, Vector2i.DOWN) == Body.OK, "R 로 남쪽을 향하게 돌렸다")
	_assert(machine.dir == Vector2i.DOWN, "제조기는 남쪽을 향한다")
	var out: Vector2i = sim.output_cell(machine)
	_assert(out.y == sim.machine_rect(machine).end.y, "출구는 남쪽 면 너머다")
	var recipe: Dictionary = sim.recipe_of(machine)
	var wanted: int = int(recipe["inputs"][0]["item"])
	var made: int = int(recipe["outputs"][0]["item"])
	# The output cell blocked with a seam, so what it makes waits to be taken.
	sim.put_ore(out, Defs.ITEM_IRON)
	var moved: int = body.insert_by_hand(cell, wanted, -1)
	_assert(moved > 0, "창에서 재료를 넣었다 (%d)" % moved)
	body.run(float(recipe["seconds"]) + 1.5, "waiting for the part")
	_assert(sim.output_waiting(machine) >= 1, "만든 것이 출구에서 기다린다")
	var got: Dictionary = body.take_output(cell)
	_assert(int(got.get(made, 0)) >= 1, "창에서 꺼냈다 (%s)" % str(got))
