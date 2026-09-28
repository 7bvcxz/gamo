extends SceneTree

## An ore node is two cells by two -- a tile -- and one thing (World Visual Pass
## 01, 2026-09-28). It was a single cell, a pebble beside a post four cells
## across.
##
## Every node in a real world covers exactly its four cells, all four answer
## with the same material, she can walk over any of them, and a swing at any of
## them is a swing at the node: it yields the node's ore and the node stays.
## Drawn a node across, around the node's middle.

const WorldLayerScript := preload("res://scripts/WorldLayer.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_the_size_is_data()
	_test_every_node_is_four_cells()
	_test_one_swing_whichever_quarter()
	_test_drawn_a_node_across()
	if failures == 0:
		print("PASS test_ore_node_is_2x2")
	else:
		print("FAIL test_ore_node_is_2x2 (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_the_size_is_data() -> void:
	_assert(Defs.ORE_NODE_SIZE == Vector2i(2, 2), "광맥 노드는 2×2 칸이다 (%s)" % Defs.ORE_NODE_SIZE)
	_assert(Sim.ore_rect(Vector2i(5, -3)) == Rect2i(Vector2i(5, -3), Defs.ORE_NODE_SIZE),
		"노드의 칸은 원점에서 ORE_NODE_SIZE 만큼이다")
	_assert(Sim.ore_cells(Vector2i.ZERO).size() == 4, "노드 하나는 네 칸이다")

func _test_every_node_is_four_cells() -> void:
	var wrong_size := 0
	var errors: Array[String] = []
	var nodes := 0
	for index in 40:
		var sim := Sim.new()
		sim.setup(71000 + index)
		errors.append_array(sim.ore_errors())
		for origin: Vector2i in sim.ore_nodes:
			nodes += 1
			var covered := 0
			for cell: Vector2i in Sim.ore_cells(origin):
				if sim.ore_origin_at(cell) == origin:
					covered += 1
			if covered != 4:
				wrong_size += 1
		sim.free()
	_assert(nodes > 0, "노드가 있다 (%d개)" % nodes)
	_assert(wrong_size == 0, "40회차 %d개 노드가 모두 정확히 네 칸을 덮는다 (%d건 아님)" % [nodes, wrong_size])
	_assert(errors.is_empty(), "광맥 자료가 서로 맞는다 %s" % str(errors.slice(0, 3)))

func _test_one_swing_whichever_quarter() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	var origin := Sim.NONE
	for cell: Vector2i in sim.ore_nodes:
		if sim.can_touch(cell) and sim.machine_at(cell) == null:
			origin = cell
			break
	_assert(origin != Sim.NONE, "닿는 노드가 있다")
	var item: int = sim.ore_item(origin)
	for cell: Vector2i in Sim.ore_cells(origin):
		_assert(not sim.blocks_player(cell), "노드의 %s 칸은 밟고 지나가는 땅이다" % (cell - origin))
		_assert(sim.can_hand_mine(cell), "노드의 %s 칸도 캘 수 있다" % (cell - origin))
	# A swing that moves from one quarter to another is still one swing.
	var cells: Array[Vector2i] = Sim.ore_cells(origin)
	var got: int = -1
	var swings := 0
	while got < 0 and swings < 400:
		got = sim.hand_mine(cells[swings % cells.size()], 0.05)
		swings += 1
	_assert(got == item, "어느 칸을 겨눠도 그 노드의 광석이 나온다 (%d)" % got)
	_assert(float(swings) * 0.05 <= Defs.HAND_MINE_PERIOD + 0.11,
		"칸을 옮겨 가며 캐도 한 번의 채굴이다 (%.2f초)" % (float(swings) * 0.05))
	_assert(sim.has_ore(origin) and sim.ore_nodes.has(origin), "노드는 그대로 남는다")
	# The ground past it is not more of it.
	for step: Vector2i in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-1, 0), Vector2i(0, -1)]:
		_assert(sim.ore_origin_at(origin + step) != origin, "%s 은 노드 밖이다" % step)
	sim.free()

## The marks are drawn at the node's size, around its middle.
func _test_drawn_a_node_across() -> void:
	_assert(is_equal_approx(WorldLayerScript.NODE_SCALE * float(Grid.TILE),
		float(Defs.ORE_NODE_SIZE.x * Grid.CELL)),
		"광맥 그림은 노드 크기(32px)로 그려진다")
	var sim := Sim.new()
	sim.setup(4242)
	for origin: Vector2i in sim.ore_nodes:
		_assert(sim.ore_centre(origin + Vector2i(1, 1)) == Grid.rect_centre(Sim.ore_rect(origin)),
			"노드의 어느 칸에서 물어도 노드 한가운데가 답이다")
		break
	sim.free()
