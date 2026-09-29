extends SceneTree

## One side blocked, the other takes everything (Factory Interaction Pass 01):
## with A's belt jammed, every item goes to B and the splitter never stalls.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_splitter_uses_open_output")
	else:
		print("FAIL test_splitter_uses_open_output (%d)" % failures)
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
	var rig: Array = _rig(Vector2i.UP)
	var sim: Sim = rig[0]
	var splitter: Sim.Machine = rig[1]
	var a: Sim.Machine = rig[2]
	var b: Sim.Machine = rig[3]
	# A's belt full and going nowhere: its own way out is a wall of ore.
	if not sim.has_ore(a.cell + a.dir):
		sim.put_ore(a.cell + a.dir, Defs.ITEM_IRON)
	for n in Defs.belt_cell_capacity():
		a.items.append({"type": Defs.ITEM_IRON, "t": 1.0 - float(n) * Defs.belt_gap_cells()})
	var held: int = a.items.size()
	var seen: Vector2i = _pour(sim, splitter, a, b, 6, false, true)
	_assert(seen.y == 6, "B 로 여섯 개가 다 나갔다 (%s)" % seen)
	_assert(a.items.size() == held, "막힌 A 에는 더 올라가지 않았다")
	_assert(not splitter.stalled, "분배기는 막혔다고 하지 않는다")
	sim.free()
