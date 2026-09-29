extends SceneTree

## A splitter works the same whichever way it faces (Factory Interaction Pass 01):
## in each of the four directions it takes from its back, puts out to its right
## (A) and its left (B), and both of those are the cells beside it -- never its
## front or its back.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_splitter_four_orientations")
	else:
		print("FAIL test_splitter_four_orientations (%d)" % failures)
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
	for dir: Vector2i in DIRS:
		var rig: Array = _rig(dir)
		var sim: Sim = rig[0]
		var splitter: Sim.Machine = rig[1]
		_assert(splitter != null, "%s 분배기" % dir)
		var ins: Array[Dictionary] = sim.machine_input_ports(splitter)
		var outs: Array[Dictionary] = sim.machine_output_ports(splitter)
		_assert(ins.size() == 1 and ins[0]["outside"] == splitter.cell - dir, "%s: 입력은 뒤" % dir)
		_assert(outs.size() == 2, "%s: 출력 둘" % dir)
		_assert(outs[0]["dir"] == Vector2i(-dir.y, dir.x) and String(outs[0]["name"]) == "a",
			"%s: A 는 오른쪽" % dir)
		_assert(outs[1]["dir"] == Vector2i(dir.y, -dir.x) and String(outs[1]["name"]) == "b",
			"%s: B 는 왼쪽" % dir)
		var seen: Vector2i = _pour(sim, splitter, rig[2], rig[3], 6)
		_assert(seen.x + seen.y == 6, "%s: 여섯 개가 다 나왔다 (%s)" % [dir, seen])
		_assert(seen.x > 0 and seen.y > 0, "%s: 양쪽으로 나갔다 (%s)" % [dir, seen])
		sim.free()
