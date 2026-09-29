extends SceneTree

## Heat stone, copper and iron each come out of their own node by hand
## (Factory Interaction Pass 01) -- the pickaxe, through Main, the way she does it.
##
## The report was "copper ore mined by hand gives heat stone". The pickaxe aimed
## right when she stood in front of a node; what went wrong was the fallback: out
## of reach of the node she was looking at, it swung at the node under her feet.
## So this node has a node of another kind one pitch away on every side, and she
## stands in front of it from every side (the swing gives 철) and on the near
## row of each neighbour looking across at it (the swing gives nothing -- she has
## to step closer -- and never the neighbour's ore).

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
	_test_by_hand()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_iron_direct_mining_outputs_iron")
	else:
		print("FAIL test_iron_direct_mining_outputs_iron (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_by_hand() -> void:
	OrePost.fresh(main)
	var sim: Sim = main.sim
	var node: Vector2i = OrePost.field(main, Defs.ITEM_IRON, Vector2i(20, -4), Defs.ITEM_HEATSTONE)
	var seconds: float = Defs.HAND_MINE_PERIOD * 1.6
	for stance: Dictionary in OrePost.stances(node):
		var got: Dictionary = OrePost.swing(main, stance["at"], stance["facing"], seconds)
		var where: String = "%s 쪽 %s" % [-(stance["facing"] as Vector2i), "앞에서" if bool(stance["reach"]) else "이웃 노드 위에서"]
		if bool(stance["reach"]):
			_assert(got.keys() == [Defs.ITEM_IRON] and int(got[Defs.ITEM_IRON]) >= 1,
				"철 노드를 %s 캐면 철을 얻는다 (%s)" % [where, str(got)])
		else:
			_assert(not got.has(Defs.ITEM_HEATSTONE), "%s 철 노드를 보고 있으면 이웃의 열석을 캐지 않는다 (%s)" % [where, str(got)])
	# And the node is what the world says it is, from any of its cells.
	for cell: Vector2i in Sim.ore_cells(node):
		var record: Dictionary = sim.ore_node_at(cell)
		_assert(int(record.get("ore_type", -1)) == Defs.ITEM_IRON and int(record.get("resource_item", -1)) == Defs.ITEM_IRON,
			"노드의 %s 칸이 철 노드라고 답한다" % (cell - node))
