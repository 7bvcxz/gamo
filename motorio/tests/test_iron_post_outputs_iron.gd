extends SceneTree

## A post on 철 puts out 철, and only 철 (World Visual Pass 01).
##
## Built the way she builds it: standing in front of the node, with the anchor
## the gun picks. Around the node sit four nodes of 열석, one pitch away on
## every side -- the layout in which the gun used to skip the node she faced and
## put the post on the one behind it (the reported "copper post puts out heat
## stone"). From every side, one to three cells off, the gun must aim at this
## node or at nothing; then a cat works the post in the running game and every
## item that lands on its output is counted.

const OrePost := preload("res://tests/helpers/ore_post.gd")

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	for type: int in [Defs.M_MINER, Defs.M_MINER_MK2]:
		_test_post(type)
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_iron_post_outputs_iron")
	else:
		print("FAIL test_iron_post_outputs_iron (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_post(type: int) -> void:
	OrePost.fresh(main)
	var sim: Sim = main.sim
	var node: Vector2i = OrePost.field(main, Defs.ITEM_IRON, Vector2i(20, -4), Defs.ITEM_HEATSTONE)
	var rig: String = Defs.MACHINE_NAMES[type]
	var strays: Array[String] = OrePost.stray_aims(main, node, type)
	_assert(strays.is_empty(), "%s: 철 노드를 겨누면 늘 그 노드다 — 뒤의 열석으로 넘어가지 않는다 %s"
		% [rig, str(strays.slice(0, 2))])
	var run: Dictionary = OrePost.run_post(main, node, type, 70.0)
	_assert(bool(run["built"]), "%s: 철 노드 위에 선다 (%s)" % [rig, sim.can_build(type, run["anchor"], Vector2i.UP)])
	_assert(run["anchor"] == node, "%s: 앵커가 그 노드의 원점이다" % rig)
	var post: Sim.Machine = sim.machine_at(node)
	_assert(post != null and post.ore_node == node, "%s: 목표 노드를 기억한다" % rig)
	var out: Dictionary = run["out"]
	_assert(int(out.get(Defs.ITEM_IRON, 0)) > 0, "%s: 철을 낸다 (%s)" % [rig, str(out)])
	_assert(out.size() == 1, "%s: 철 말고는 아무것도 내지 않는다 (%s)" % [rig, str(out)])
	_assert(int(out.get(Defs.ITEM_HEATSTONE, 0)) == 0, "%s: 이웃 열석은 한 개도 나오지 않는다" % rig)
