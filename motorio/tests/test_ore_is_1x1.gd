extends SceneTree

## A seam is one cell -- an independent node -- and never a block.
##
## The world keeps every two nodes at least ORE_PITCH cells apart, which is the
## spacing at which every node can carry a four-by-four post of its own without
## covering a neighbour. Checked over two hundred worlds, because a spacing rule
## that holds on one seed is a spacing rule that has not been tested.

const WorldLayerScript := preload("res://scripts/WorldLayer.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_spacing_over_seeds()
	_test_a_node_is_one_cell()
	_test_drawn_a_cell_across()
	if failures == 0:
		print("PASS test_ore_is_1x1")
	else:
		print("FAIL test_ore_is_1x1 (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_spacing_over_seeds() -> void:
	var crowded := 0
	var shared_posts := 0
	var empty_worlds := 0
	var nodes := 0
	var reach: int = Defs.ORE_PITCH - 1
	for index in 200:
		var sim := Sim.new()
		sim.setup(91000 + index)
		if sim.ore.is_empty():
			empty_worlds += 1
		for cell: Vector2i in sim.ore:
			nodes += 1
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					if (dx != 0 or dy != 0) and sim.ore.has(cell + Vector2i(dx, dy)):
						crowded += 1
			# The post this node would carry covers it and no other node.
			var inside := 0
			for covered: Vector2i in Grid.cells_in(Defs.machine_footprint(Defs.M_MINER, cell)):
				if sim.ore.has(covered):
					inside += 1
			if inside != 1:
				shared_posts += 1
		sim.free()
	_assert(empty_worlds == 0, "모든 세계에 광맥이 있다")
	_assert(crowded == 0, "200회차 %d개 노드 중 %d칸 거리 안에 붙은 노드가 없다 (%d건)"
		% [nodes, Defs.ORE_PITCH, crowded])
	_assert(shared_posts == 0, "어느 노드의 채굴기 발자국에도 다른 노드가 들어가지 않는다 (%d건)"
		% shared_posts)

func _test_a_node_is_one_cell() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		if sim.can_touch(cell) and sim.machine_at(cell) == null:
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "닿는 광맥이 있다")
	var item: int = int(sim.ore[seam])
	# The cells beside it are ground, not more of the same seam.
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1)]:
		_assert(not sim.ore.has(seam + step), "옆 칸 %s 은 광맥이 아니다" % step)
	# Terrain: walked on, not walked round.
	_assert(not sim.blocks_player(seam), "광맥은 밟고 지나가는 땅이다")
	# Dug by hand, it yields and stays -- and the cell next to it yields nothing.
	var got: int = -1
	for _swing in 200:
		got = sim.hand_mine(seam, 0.05)
		if got >= 0:
			break
	_assert(got == item, "그 한 칸을 캐면 그 광석이 나온다")
	_assert(sim.ore.has(seam), "광맥은 그대로 남는다")
	var beside: Vector2i = seam + Vector2i.RIGHT
	var nothing: int = -1
	for _swing in 200:
		nothing = sim.hand_mine(beside, 0.05)
	_assert(nothing == -1 and not sim.can_hand_mine(beside) or sim.has_rock(beside),
		"바로 옆 칸은 캘 것이 없다")
	sim.free()

## The marks are drawn at the node's size, around its middle.
func _test_drawn_a_cell_across() -> void:
	_assert(is_equal_approx(WorldLayerScript.NODE_SCALE * float(Grid.TILE), float(Grid.CELL)),
		"광맥 그림은 한 칸(16px) 크기로 그려진다")
