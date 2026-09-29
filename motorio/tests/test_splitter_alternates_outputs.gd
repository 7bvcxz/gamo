extends SceneTree

## A, then B, then A (Factory Interaction Pass 01): ten items in, five out each
## side, and in strict turns.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_splitter_alternates_outputs")
	else:
		print("FAIL test_splitter_alternates_outputs (%d)" % failures)
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
	var rig: Array = _rig(Vector2i.RIGHT)
	var sim: Sim = rig[0]
	var splitter: Sim.Machine = rig[1]
	var a: Sim.Machine = rig[2]
	var b: Sim.Machine = rig[3]
	var order: Array[String] = []
	var back: Vector2i = splitter.cell - splitter.dir
	for n in 10:
		sim._push_into(splitter.cell, Defs.ITEM_COPPER, back)
		for step in 30:
			sim.tick(0.05)
			if splitter.items.is_empty():
				break
		if not a.items.is_empty():
			order.append("a")
		if not b.items.is_empty():
			order.append("b")
		a.items.clear()
		b.items.clear()
	_assert(order.size() == 10, "열 개가 다 나왔다 (%s)" % str(order))
	var alternating := true
	for index in range(1, order.size()):
		if order[index] == order[index - 1]:
			alternating = false
	_assert(alternating, "번갈아 나간다 (%s)" % "".join(order))
	_assert(order.count("a") == 5 and order.count("b") == 5, "다섯씩")
	sim.free()
