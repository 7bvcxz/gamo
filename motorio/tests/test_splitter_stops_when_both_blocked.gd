extends SceneTree

## Both sides blocked, it holds (Factory Interaction Pass 01): the item stays on
## the splitter, the splitter says it is stalled, nothing is lost or made, and it
## starts again the moment one side opens.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_splitter_stops_when_both_blocked")
	else:
		print("FAIL test_splitter_stops_when_both_blocked (%d)" % failures)
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
	var rig: Array = _rig(Vector2i.LEFT)
	var sim: Sim = rig[0]
	var splitter: Sim.Machine = rig[1]
	var a: Sim.Machine = rig[2]
	var b: Sim.Machine = rig[3]
	for belt: Sim.Machine in [a, b]:
		if not sim.has_ore(belt.cell + belt.dir):
			sim.put_ore(belt.cell + belt.dir, Defs.ITEM_IRON)
		for n in Defs.belt_cell_capacity():
			belt.items.append({"type": Defs.ITEM_IRON, "t": 1.0 - float(n) * Defs.belt_gap_cells()})
	var back: Vector2i = splitter.cell - splitter.dir
	_assert(sim._push_into(splitter.cell, Defs.ITEM_COPPER, back), "하나 들어간다")
	Factory.run(sim, 3.0)
	_assert(splitter.items.size() == 1, "분배기가 그것을 들고 있다")
	_assert(splitter.stalled, "그리고 막혔다고 말한다")
	var total: int = splitter.items.size() + a.items.size() + b.items.size()
	_assert(total == 1 + 2 * Defs.belt_cell_capacity(), "없어지거나 생긴 것이 없다 (%d)" % total)
	b.items.clear()
	Factory.run(sim, 1.0)
	_assert(splitter.items.is_empty() and not splitter.stalled, "한쪽이 열리자 다시 나간다")
	sim.free()
