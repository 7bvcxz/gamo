extends SceneTree

## A mining post covers exactly one whole node: its anchor is the node's origin,
## its four cells are the node's four (World Visual Pass 01).
##
## Checked on the rules (`can_build`), on the build, and on the hand. On bare
## ground it is refused; anchored on any other cell of the node it would hang
## half off it and is refused; anywhere it would straddle a second node it is
## refused; no other building goes on a node at all. From the hand, facing any
## cell of a node from anywhere she can reach it, the gun snaps to the node --
## and past her reach it does not slide over onto one.

var failures := 0

const SITE := Vector2i(36, 0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rules()
	_test_every_kind()
	await _test_aimed()
	if failures == 0:
		print("PASS test_mining_post_exactly_covers_ore")
	else:
		print("FAIL test_mining_post_exactly_covers_ore (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	for type: int in Defs.MINER_MACHINES + [Defs.M_BELT]:
		sim.unlocked[type] = true
	for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON,
			Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE, Defs.ITEM_ELECTRIC_MOTOR]:
		sim.stock[item] = 500
	return sim

func _clear(sim: Sim, rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.erase_ore_at(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)

func _test_rules() -> void:
	var sim := _sim()
	var node: Vector2i = sim.core_cell + SITE
	_clear(sim, Rect2i(node - Vector2i(8, 8), Vector2i(17, 17)))
	_assert(sim.can_build(Defs.M_MINER, node) == "광맥 위에만 설치할 수 있습니다",
		"맨땅에는 채굴기를 지을 수 없다")
	_assert(not sim.build(Defs.M_MINER, node, Vector2i.RIGHT), "짓기도 거부된다")
	sim.put_ore(node, Defs.ITEM_HEATSTONE)
	_assert(sim.can_build(Defs.M_MINER, node) == "", "노드의 원점에는 지을 수 있다")
	# Anchored anywhere else near it, the post would cover part of the node, or
	# none of it, or it and a neighbour: all refused.
	var off := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var anchor: Vector2i = node + Vector2i(dx, dy)
			if anchor == node:
				continue
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.UP]:
				if sim.can_build(Defs.M_MINER, anchor, dir) == "":
					off += 1
	_assert(off == 0, "원점이 아닌 어느 자리에서도 노드 일부만 덮는 채굴기는 서지 않는다 (%d건)" % off)
	# A second node pushed against it: a post can never cover both.
	sim.put_ore(node + Vector2i(2, 0), Defs.ITEM_COPPER)
	var straddle := 0
	for dy in range(-1, 2):
		for dx in range(-1, 4):
			var anchor: Vector2i = node + Vector2i(dx, dy)
			if sim.can_build(Defs.M_MINER, anchor) == "":
				var rect: Rect2i = Defs.machine_footprint(Defs.M_MINER, anchor)
				if rect.intersects(Sim.ore_rect(node)) and rect.intersects(Sim.ore_rect(node + Vector2i(2, 0))):
					straddle += 1
	_assert(straddle == 0, "두 노드에 걸치는 채굴기는 서지 않는다 (%d건)" % straddle)
	sim.erase_ore_at(node + Vector2i(2, 0))
	_assert(sim.build(Defs.M_MINER, node, Vector2i.RIGHT), "짓는다")
	var post: Sim.Machine = sim.machine_at(node)
	_assert(post.cell == node and sim.machine_rect(post) == Sim.ore_rect(node),
		"채굴기는 노드를 정확히 덮는다")
	_assert(sim.ore_nodes.has(node) and sim.ore_errors().is_empty(), "노드 자료는 지워지지 않는다")
	# Not a belt: a node is not a floor to lay one on, on any of its cells.
	var other: Vector2i = node + Vector2i(0, 10)
	sim.put_ore(other, Defs.ITEM_HEATSTONE)
	for cell: Vector2i in Sim.ore_cells(other):
		_assert(sim.can_build(Defs.M_BELT, cell) == "광맥 위에는 설치할 수 없습니다",
			"노드의 %s 칸에 벨트는 놓지 못한다" % (cell - other))
	sim.free()

## Every kind of node takes a post, and every kind of mining machine asks it.
func _test_every_kind() -> void:
	var sim := _sim()
	var node: Vector2i = sim.core_cell + SITE + Vector2i(0, 20)
	_clear(sim, Rect2i(node - Vector2i(8, 8), Vector2i(17, 17)))
	for type: int in Defs.MINER_MACHINES:
		for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON]:
			sim.put_ore(node, item)
			_assert(sim.footprint_problems(type, node).is_empty(),
				"%s 는 %s 노드에 선다" % [Defs.MACHINE_NAMES[type], Defs.ITEM_NAMES[item]])
		sim.erase_ore_at(node)
		_assert(sim.footprint_problems(type, node).get(node, "") == "광맥 위에만 설치할 수 있습니다",
			"%s 도 맨땅은 거부한다" % Defs.MACHINE_NAMES[type])
	sim.free()

## From the hand: facing any cell of a node from anywhere she can reach it, the
## gun's anchor is the node's origin.
func _test_aimed() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var sim: Sim = main.sim
	sim.has_gun = true
	sim.unlocked[Defs.M_MINER] = true
	for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 500
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	main.selected_index = Defs.BUILDABLE.find(Defs.M_MINER)
	var node: Vector2i = sim.core_cell + SITE
	_clear(sim, Rect2i(node - Vector2i(10, 10), Vector2i(21, 21)))
	sim.put_ore(node, Defs.ITEM_HEATSTONE)
	var span: Rect2 = Grid.rect_px(Sim.ore_rect(node))
	var middle: Vector2 = span.get_center()
	var aimed := 0
	var tried := 0
	# From each side, a few pixels off the node's edge, anywhere across its
	# width: her reach is a tile wide, and so is the node.
	var stands: Array = []
	for lateral: float in [-12.0, -4.0, 4.0, 12.0]:
		stands.append([Vector2(middle.x + lateral, span.end.y + 9.0), Vector2i.UP])
		stands.append([Vector2(middle.x + lateral, span.position.y - 9.0), Vector2i.DOWN])
		stands.append([Vector2(span.position.x - 9.0, middle.y + lateral), Vector2i.RIGHT])
		stands.append([Vector2(span.end.x + 9.0, middle.y + lateral), Vector2i.LEFT])
	for stand: Array in stands:
		main.player.position = stand[0]
		main.player.facing = stand[1]
		tried += 1
		if main.build_anchor(Defs.M_MINER) == node:
			aimed += 1
		else:
			print("    %s facing %s aims at %s" % [stand[0], stand[1], main.build_anchor(Defs.M_MINER)])
	_assert(aimed == tried, "사방 어디서 겨눠도 앵커는 노드의 원점이다 (%d/%d)" % [aimed, tried])
	# Past her reach the gun does not slide the post over onto the node, and it
	# does not put one down off it either: the ghost is red.
	main.player.position = Vector2(middle.x + 44.0, span.end.y + 9.0)
	main.player.facing = Vector2i.UP
	var off: Vector2i = main.build_anchor(Defs.M_MINER)
	_assert(sim.ore_origin_at(off) != node, "손이 닿지 않는 줄의 노드는 겨누지 않는다")
	_assert(sim.can_build(Defs.M_MINER, off, main.build_dir, main.body_cells()) != "",
		"그리고 그 자리는 거부된다 — 노드 밖에 채굴기가 서지 않는다")
	# Standing on the node, the post would go down on her: refused, and not
	# redirected to some other node.
	main.player.position = middle
	main.player.facing = Vector2i.UP
	var under: Vector2i = main.build_anchor(Defs.M_MINER)
	_assert(sim.ore_origin_at(under) == node or sim.ore_origin_at(under) == Sim.NONE,
		"노드 위에 서서 겨눠도 다른 노드로 넘어가지 않는다")
	main.queue_free()
	await process_frame
