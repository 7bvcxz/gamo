extends SceneTree

## Four cells, one node: every question about a seam has one answer whichever of
## its cells it is asked about (World Visual Pass 01).
##
## Identity, type, yield, purity and period are asked of each cell of every node
## in a real world and must agree with the node. And the node is written and
## taken away whole: `erase_ore_at` on any quarter removes all four, `put_ore`
## over a node replaces it rather than leaving a quarter of the old one -- the
## state a per-cell dictionary could always get into and nothing could see.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_every_cell_answers_for_its_node()
	_test_written_and_erased_whole()
	_test_no_cell_guesses()
	if failures == 0:
		print("PASS test_ore_cells_share_node_identity")
	else:
		print("FAIL test_ore_cells_share_node_identity (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_every_cell_answers_for_its_node() -> void:
	var disagreements := 0
	var checked := 0
	for index in 20:
		var sim := Sim.new()
		sim.setup(3300 + index)
		for origin: Vector2i in sim.ore_nodes:
			var type: int = int(sim.ore_nodes[origin])
			for cell: Vector2i in Sim.ore_cells(origin):
				checked += 1
				if sim.ore_origin_at(cell) != origin or sim.ore_type_at(cell) != type \
						or sim.ore_item(cell) != Defs.ore_output(type) \
						or sim.purity_of(cell) != sim.purity_of(origin) \
						or not is_equal_approx(sim.seam_period(cell), sim.seam_period(origin)) \
						or sim.post_anchor(cell) != origin:
					disagreements += 1
		sim.free()
	_assert(checked > 0, "노드 칸을 물어봤다 (%d칸)" % checked)
	_assert(disagreements == 0, "노드의 네 칸이 정체·종류·산출·순도·속도·거점에서 같은 답을 한다 (%d건 불일치)"
		% disagreements)

func _test_written_and_erased_whole() -> void:
	var sim := Sim.new()
	sim.setup(12)
	sim.clear_ore()
	sim.put_ore(Vector2i(10, 10), Defs.ITEM_COPPER)
	_assert(sim.ore_nodes.size() == 1 and sim.ore_errors().is_empty(), "노드 하나를 놓으면 네 칸이 생긴다")
	# Erased by its bottom-right quarter: all of it goes.
	_assert(sim.erase_ore_at(Vector2i(11, 11)), "아무 칸으로나 지울 수 있다")
	var left := 0
	for cell: Vector2i in Sim.ore_cells(Vector2i(10, 10)):
		if sim.has_ore(cell):
			left += 1
	_assert(left == 0 and sim.ore_nodes.is_empty(), "지우면 네 칸이 모두 사라진다 (%d칸 남음)" % left)
	# Put over a node: the old one goes whole, never leaving a quarter behind.
	sim.put_ore(Vector2i(10, 10), Defs.ITEM_COPPER)
	sim.put_ore(Vector2i(11, 11), Defs.ITEM_IRON)
	_assert(not sim.ore_nodes.has(Vector2i(10, 10)), "겹쳐 놓으면 옛 노드는 통째로 사라진다")
	_assert(not sim.has_ore(Vector2i(10, 10)), "옛 노드의 한 칸도 남지 않는다")
	_assert(sim.ore_type_at(Vector2i(12, 12)) == Defs.ITEM_IRON, "새 노드가 선다")
	_assert(sim.ore_errors().is_empty(), "자료가 어긋나지 않는다 %s" % str(sim.ore_errors()))
	sim.free()

## The runtime code asks the API, not the storage: no script reads the node
## table by a cell it did not get from the API. `ore` itself is gone, so an old
## `ore.has(cell)` cannot answer for one cell in four.
func _test_no_cell_guesses() -> void:
	var offenders: Array[String] = []
	var dir := DirAccess.open("res://scripts")
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string("res://scripts/" + file)
		var regex := RegEx.new()
		regex.compile("\\bore(\\.has|\\.get|\\[|\\.erase|\\.keys)")
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			if regex.search(line) != null:
				offenders.append("%s: %s" % [file, line.strip_edges()])
	_assert(offenders.is_empty(), "스크립트가 광맥을 칸으로 직접 읽지 않는다 %s" % str(offenders.slice(0, 3)))
