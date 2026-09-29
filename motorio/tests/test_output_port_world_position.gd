extends SceneTree

## Where things come out, as world cells, in all four directions (Factory
## Interaction Pass 01): a post and a manufacturer put out one cell past the front
## edge in the anchor's lane -- the cell every save's belts were laid against --
## `output_cell` is that port, and it leaves from the edge cell next to it.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test(Defs.M_MINER)
	_test(Defs.M_MANUFACTURER)
	_test(Defs.M_ASSEMBLER)
	_test(Defs.M_BELT)
	if failures == 0:
		print("PASS test_output_port_world_position")
	else:
		print("FAIL test_output_port_world_position (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

func _test(type: int) -> void:
	var name: String = Defs.machine_name(type)
	for dir: Vector2i in DIRS:
		var anchor := Vector2i(40, 40)
		var rect: Rect2i = Defs.machine_footprint(type, anchor, dir)
		var ports: Array[Dictionary] = Defs.resolve_ports(Defs.machine_port_specs(type), rect, dir)
		var outs: Array[Dictionary] = []
		for port: Dictionary in ports:
			if String(port["kind"]) == Defs.PORT_OUTPUT:
				outs.append(port)
		_assert(outs.size() == 1, "%s %s: 출력 칸은 하나" % [name, dir])
		if outs.is_empty():
			continue
		var legacy: Vector2i = Grid.front_cell(rect, dir, anchor)
		_assert(outs[0]["outside"] == legacy, "%s %s: 출력은 앞 가장자리 너머 앵커 줄 (%s == %s)"
			% [name, dir, outs[0]["outside"], legacy])
		_assert(outs[0]["inside"] == legacy - dir, "%s %s: 출력은 바로 옆 가장자리 칸에서 나간다" % [name, dir])
		_assert(outs[0]["dir"] == dir, "%s %s: 출력 방향은 기계가 향하는 쪽" % [name, dir])
	# And through a real machine: output_cell is the port.
	var sim: Sim = Factory.world()
	var cell: Vector2i = Factory.at(sim, Vector2i(6, 6))
	if Defs.machine_mines(type):
		sim.put_ore(cell, Defs.ITEM_COPPER)
	var machine: Sim.Machine = Factory.put(sim, type, cell, Vector2i.DOWN)
	_assert(machine != null, "%s%s 남쪽으로 짓는다" % [name, Defs.object_of(name)])
	if machine != null:
		_assert(sim.output_cell(machine) == sim.machine_output_ports(machine)[0]["outside"],
			"%s: output_cell 은 출력 포트다" % name)
	sim.free()
