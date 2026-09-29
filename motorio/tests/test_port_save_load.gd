extends SceneTree

## Ports survive a save because what they are made of does (Factory Interaction
## Pass 01): machines in all four directions are written, a different world is
## made, the save is read back, and every machine resolves to exactly the ports it
## had.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test()
	if failures == 0:
		print("PASS test_port_save_load")
	else:
		print("FAIL test_port_save_load (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

func _test() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run(5150)
	main.finish_tutorial()
	var sim: Sim = main.sim
	for type: int in Defs.BUILDABLE:
		sim.unlocked[type] = true
	for item_id: int in range(Defs.ITEM_NAMES.size()):
		sim.stock[item_id] = 500
	sim.stones_in = maxi(sim.stones_in, int(Defs.BASE_LEVELS[-1]["stones"]))
	sim._refresh_radius()
	Factory.clear(sim, Rect2i(sim.core_cell + Factory.AREA.position, Factory.AREA.size))
	var before: Dictionary = {}
	var index := 0
	for type: int in [Defs.M_MANUFACTURER, Defs.M_ASSEMBLER, Defs.M_SPLITTER, Defs.M_BELT]:
		for dir: Vector2i in DIRS:
			var cell: Vector2i = Factory.at(sim, Vector2i(2 + index % 4 * 5, 2 + index / 4 * 5))
			index += 1
			var machine: Sim.Machine = Factory.put(sim, type, cell, dir)
			_assert(machine != null, "%s %s 를 짓는다" % [Defs.machine_name(type), dir])
			if machine != null:
				before[cell] = sim.machine_ports(machine)
	_assert(main.save_game(false), "저장한다")
	main._start_run(99)
	_assert(main.load_game(), "불러온다")
	sim = main.sim
	var same := 0
	for cell: Vector2i in before:
		var machine: Sim.Machine = sim.machine_at(cell)
		if machine != null and sim.machine_ports(machine) == before[cell]:
			same += 1
	_assert(same == before.size(), "%d/%d 기계의 포트가 그대로다" % [same, before.size()])
	main.clear_save()
	main.free()
