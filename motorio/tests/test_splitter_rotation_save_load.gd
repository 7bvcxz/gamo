extends SceneTree

## A turned splitter is still turned after a save (Factory Interaction Pass 01):
## four splitters in four directions, holding an item and partway through their
## A/B turn, come back facing the same way with the same ports, the same item and
## the same next side.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test()
	if failures == 0:
		print("PASS test_splitter_rotation_save_load")
	else:
		print("FAIL test_splitter_rotation_save_load (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)



const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## A splitter at `hub` facing `dir`, with a belt leading away from each output
## port. Returns [sim, splitter, belt_a, belt_b].
func _rig(dir: Vector2i) -> Array:
	var sim: Sim = Factory.world()
	var hub: Vector2i = Factory.at(sim, Vector2i(14, 14))
	var splitter: Sim.Machine = Factory.put(sim, Defs.M_SPLITTER, hub, dir)
	var belts: Array = [sim, splitter]
	for port: Dictionary in sim.machine_output_ports(splitter):
		belts.append(Factory.put(sim, Defs.M_BELT, port["outside"], port["dir"]))
	return belts

## Feeds `count` items in at the back one at a time and counts where they went.
func _pour(sim: Sim, splitter: Sim.Machine, a: Sim.Machine, b: Sim.Machine, count: int,
		clear_a: bool = true, clear_b: bool = true) -> Vector2i:
	var back: Vector2i = splitter.cell - splitter.dir
	var seen := Vector2i.ZERO
	for n in count:
		sim._push_into(splitter.cell, Defs.ITEM_COPPER, back)
		for step in 30:
			sim.tick(0.05)
			if splitter.items.is_empty():
				break
		seen.x += a.items.size()
		seen.y += b.items.size()
		if clear_a:
			a.items.clear()
		if clear_b:
			b.items.clear()
	return seen

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
	sim.stock[Defs.ITEM_COPPER] = 500
	Factory.clear(sim, Rect2i(sim.core_cell + Factory.AREA.position, Factory.AREA.size))
	var before: Dictionary = {}
	var index := 0
	for dir: Vector2i in DIRS:
		var cell: Vector2i = Factory.at(sim, Vector2i(4 + index * 5, 6))
		index += 1
		var splitter: Sim.Machine = Factory.put(sim, Defs.M_SPLITTER, cell, dir)
		_assert(splitter != null, "%s 분배기" % dir)
		splitter.next_out = index % 2
		splitter.items.append({"type": Defs.ITEM_COPPER, "t": 0.0})
		before[cell] = [dir, sim.machine_ports(splitter), splitter.next_out]
	_assert(main.save_game(false), "저장한다")
	main._start_run(99)
	_assert(main.load_game(), "불러온다")
	sim = main.sim
	for cell: Vector2i in before:
		var splitter: Sim.Machine = sim.machine_at(cell)
		_assert(splitter != null and splitter.type == Defs.M_SPLITTER, "%s 분배기가 돌아온다" % cell)
		if splitter == null:
			continue
		_assert(splitter.dir == before[cell][0], "방향 그대로 (%s)" % splitter.dir)
		_assert(sim.machine_ports(splitter) == before[cell][1], "포트 그대로")
		_assert(splitter.next_out == before[cell][2], "다음 차례 그대로")
		_assert(splitter.items.size() == 1, "들고 있던 것 그대로")
	main.clear_save()
	main.free()
