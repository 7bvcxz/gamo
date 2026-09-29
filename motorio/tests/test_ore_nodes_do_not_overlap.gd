extends SceneTree

## Nodes never overlap, and every node has room for its post and a lane beside
## it -- over two hundred worlds, because a spacing rule that holds on one seed is
## a spacing rule that has not been tested (World Visual Pass 01).
##
## Origins stand at least ORE_PITCH cells apart, which leaves two cells -- a
## tile, her width and a belt's -- between any two nodes. A node is never under
## the base, the hut, the bin or the opening's belt lanes, and the promised
## seams are still there: the three under the fire, the one due north.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_over_seeds()
	if failures == 0:
		print("PASS test_ore_nodes_do_not_overlap")
	else:
		print("FAIL test_ore_nodes_do_not_overlap (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_over_seeds() -> void:
	var overlaps := 0
	var tight := 0
	var in_buildings := 0
	var shared_posts := 0
	var missing_promises := 0
	var nodes := 0
	var empty_worlds := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(91000 + index)
		if sim.ore_nodes.is_empty():
			empty_worlds += 1
		var owner: Dictionary = {}
		for origin: Vector2i in sim.ore_nodes:
			nodes += 1
			var rect: Rect2i = Sim.ore_rect(origin)
			for cell: Vector2i in Sim.ore_cells(origin):
				if owner.has(cell):
					overlaps += 1
				owner[cell] = origin
			for other: Vector2i in sim.ore_nodes:
				if other != origin and Grid.steps(other, origin) < Defs.ORE_PITCH:
					tight += 1
			if rect.intersects(sim.base_rect()) or rect.intersects(sim.shelter_rect()) \
					or rect.intersects(sim.food_rect()):
				in_buildings += 1
			# The post it would carry covers it and nothing else of the ore.
			var foreign := 0
			for covered: Vector2i in Grid.cells_in(Defs.machine_footprint(Defs.M_MINER, origin)):
				var there: Vector2i = sim.ore_origin_at(covered)
				if there != Sim.NONE and there != origin:
					foreign += 1
			if foreign > 0:
				shared_posts += 1
		for offset: Vector2i in Sim.STARTER_PATCH + Sim.STARTER_NORTH:
			if not sim.ore_nodes.has(sim.core_cell + offset):
				missing_promises += 1
		sim.free()
	_assert(empty_worlds == 0, "모든 세계에 광맥이 있다")
	_assert(overlaps == 0, "200회차 %d개 노드 중 겹치는 칸이 없다 (%d건)" % [nodes, overlaps])
	_assert(tight == 0, "노드 원점끼리 %d칸 이상 떨어진다 — 사이에 두 칸 통로 (%d건)"
		% [Defs.ORE_PITCH, tight])
	_assert(in_buildings == 0, "기지·숙소·사료통 밑에 노드가 없다 (%d건)" % in_buildings)
	_assert(shared_posts == 0, "어느 노드의 채굴기 발자국에도 다른 노드가 들어가지 않는다 (%d건)"
		% shared_posts)
	_assert(missing_promises == 0, "약속한 시작 노드(불 아래 셋, 북쪽 하나)가 모두 있다 (%d건 빠짐)"
		% missing_promises)
