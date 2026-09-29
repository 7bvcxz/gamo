extends SceneTree

## R turns a standing machine through all four directions (Factory Interaction
## Pass 01): every machine with a facing, built and turned in place four times --
## each turn a quarter clockwise, its ports turned with it, what it holds kept,
## and the fourth turn back where it started. A machine without a facing (the
## generator) refuses. Then the same through the key: Main's R turns the machine
## she faces rather than the ghost.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_sim()
	await _test_key()
	if failures == 0:
		print("PASS test_machine_rotation_four_directions")
	else:
		print("FAIL test_machine_rotation_four_directions (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

func _test_sim() -> void:
	var sim: Sim = Factory.world()
	var index := 0
	for type: int in Defs.DIRECTIONAL_MACHINES:
		var name: String = Defs.machine_name(type)
		var cell: Vector2i = Factory.at(sim, Vector2i(2 + index * 5, 4))
		index += 1
		if Defs.machine_mines(type):
			sim.put_ore(cell, Defs.ITEM_COPPER)
		var machine: Sim.Machine = Factory.put(sim, type, cell, Vector2i.RIGHT)
		_assert(machine != null, "%s 를 짓는다" % name)
		if machine == null:
			continue
		machine.buffer[Defs.ITEM_IRON] = 3
		machine.outbox[Defs.ITEM_IRON_PLATE] = 2
		var rect: Rect2i = sim.machine_rect(machine)
		for turn in 4:
			var expect: Vector2i = DIRS[(turn + 1) % 4]
			_assert(sim.rotate_machine(cell), "%s: %d번째로 돌린다" % [name, turn + 1])
			_assert(machine.dir == expect, "%s: %s 를 향한다" % [name, expect])
			_assert(sim.machine_at(cell) == machine and sim.machine_rect(machine) == rect,
				"%s: 같은 칸들 위의 같은 기계다" % name)
			var outs: Array[Dictionary] = sim.machine_output_ports(machine)
			if not outs.is_empty() and type != Defs.M_SPLITTER:
				_assert(outs[0]["dir"] == expect, "%s: 출력이 함께 돌았다" % name)
		_assert(machine.dir == Vector2i.RIGHT, "%s: 네 번이면 제자리" % name)
		_assert(int(machine.buffer.get(Defs.ITEM_IRON, 0)) == 3
			and int(machine.outbox.get(Defs.ITEM_IRON_PLATE, 0)) == 2, "%s: 들고 있던 것 그대로" % name)
	var generator: Sim.Machine = Factory.put(sim, Defs.M_GENERATOR, Factory.at(sim, Vector2i(4, 14)),
		Vector2i.RIGHT)
	_assert(generator != null and not sim.rotate_machine(generator.cell), "방향 없는 발전기는 돌지 않는다")
	sim.free()

func _test_key() -> void:
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
		sim.stock[item_id] = 500
	sim.stones_in = maxi(sim.stones_in, int(Defs.BASE_LEVELS[-1]["stones"]))
	sim._refresh_radius()
	# In the cleared test area, facing east, with a manufacturer right in front.
	Factory.clear(sim, Rect2i(sim.core_cell + Factory.AREA.position, Factory.AREA.size))
	var player: Node2D = main.player
	player.position = Grid.centre(Factory.at(sim, Vector2i(6, 10)))
	player.set("facing", Vector2i.RIGHT)
	var target: Vector2i = main.target_cell()
	_assert(sim.build(Defs.M_MANUFACTURER, target, Vector2i.RIGHT), "그녀 앞에 제조기")
	var machine: Sim.Machine = sim.machine_at(target)
	var ghost: Vector2i = main.build_dir
	main.rotate_pressed()
	_assert(machine != null and machine.dir == Vector2i.DOWN, "R 은 바라보는 기계를 돌린다")
	_assert(main.build_dir == ghost, "고스트 방향은 그대로다")
	sim.remove_machine(target)
	main.rotate_pressed()
	_assert(main.build_dir == Vector2i(-ghost.y, ghost.x), "앞에 기계가 없으면 고스트를 돌린다")
	main.clear_save()
	main.free()
