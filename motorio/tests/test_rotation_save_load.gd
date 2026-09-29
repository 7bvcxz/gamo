extends SceneTree

## A turned machine stays turned (Factory Interaction Pass 01): machines built
## facing east and turned with R to each other direction are saved, a different
## world is made, and the save read back -- each faces where it was turned and
## pours where its turned output port says.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test()
	if failures == 0:
		print("PASS test_rotation_save_load")
	else:
		print("FAIL test_rotation_save_load (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


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
	for type: int in [Defs.M_MANUFACTURER, Defs.M_ASSEMBLER, Defs.M_BELT, Defs.M_SPLITTER]:
		for turns in range(1, 4):
			var cell: Vector2i = Factory.at(sim, Vector2i(2 + index % 4 * 5, 2 + index / 4 * 5))
			index += 1
			_assert(sim.build(type, cell, Vector2i.RIGHT), "%s" % Defs.machine_name(type))
			for n in turns:
				sim.rotate_machine(cell)
			var machine: Sim.Machine = sim.machine_at(cell)
			before[cell] = [machine.dir, sim.output_cell(machine)]
	_assert(main.save_game(false), "저장한다")
	main._start_run(99)
	_assert(main.load_game(), "불러온다")
	sim = main.sim
	var same := 0
	for cell: Vector2i in before:
		var machine: Sim.Machine = sim.machine_at(cell)
		if machine != null and machine.dir == before[cell][0] and sim.output_cell(machine) == before[cell][1]:
			same += 1
	_assert(same == before.size(), "%d/%d 기계가 돌린 방향과 출구 그대로 돌아온다" % [same, before.size()])
	main.clear_save()
	main.free()
