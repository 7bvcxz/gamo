extends SceneTree

## The placement ghost is the whole footprint, and the cells that refuse it are
## named one by one.
##
## Read from Main's `_update_preview`, which is what the world layer draws: the
## rectangle the building would cover, and a cell -> reason map of the ones in
## the way. The ghost and the build must agree -- a green ghost that then
## refuses, or a building that lands somewhere other than the ghost, is a ghost
## that lies.

var failures := 0
var main: Node2D
var sim: Sim

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.process_mode = Node.PROCESS_MODE_DISABLED
	sim = main.sim
	_open()
	_test_post_ghost()
	_test_belt_ghost()
	_test_carried_hut()
	if failures == 0:
		print("PASS test_multitile_placement_preview")
	else:
		print("FAIL test_multitile_placement_preview (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _open() -> void:
	sim.has_gun = true
	sim.unlocked[Defs.M_MINER] = true
	sim.unlocked[Defs.M_BELT] = true
	for item: int in [Defs.ITEM_CRYSTAL, Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 500

func _clear(rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.erase_ore_at(cell)
		var machine: Sim.Machine = sim.machine_at(cell)
		if machine != null and machine.type != Defs.M_CORE:
			sim.remove_machine(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)

func _hold_gun(type: int) -> void:
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	main.selected_index = Defs.BUILDABLE.find(type)
	main.build_dir = Vector2i.RIGHT

func _test_post_ghost() -> void:
	var seam: Vector2i = sim.core_cell + Vector2i(30, 0)
	_clear(Rect2i(seam - Vector2i(8, 8), Vector2i(17, 17)))
	sim.put_ore(seam, Defs.ITEM_HEATSTONE)
	_hold_gun(Defs.M_MINER)
	var rect: Rect2i = Defs.machine_footprint(Defs.M_MINER, seam)
	# South of where the post would stand, looking north at the seam.
	main.player.position = Grid.centre(Vector2i(seam.x, rect.end.y))
	main.player.facing = Vector2i.UP
	main._update_preview()
	var layer: Node2D = main.machine_layer
	_assert(layer.preview_cell == seam, "고스트는 광맥을 겨눈다")
	_assert(layer.preview_rect == rect and rect == Sim.ore_rect(seam),
		"고스트는 노드를 덮는 2×2 발자국 전체다: %s" % layer.preview_rect)
	_assert(layer.preview_problems.is_empty(), "빈 땅이면 막힌 칸이 없다")
	_assert(layer.preview_valid, "그리고 초록이다")
	# Something already standing on one corner -- a belt a v12 save left over
	# the node's edge, say: that cell, and only that cell, is named. (A second
	# node cannot be under a post any more: nodes stand two cells apart.)
	var corner: Vector2i = rect.end - Vector2i.ONE
	var stray := Sim.Machine.new()
	stray.type = Defs.M_BELT
	stray.cell = corner
	sim.add_machine(stray)
	main._update_preview()
	_assert(layer.preview_problems.size() == 1, "겹치는 칸 하나만 빨갛다 (%d)" % layer.preview_problems.size())
	_assert(String(layer.preview_problems.get(corner, "")) == "이미 설비가 있습니다",
		"그 칸의 이유가 적혀 있다: '%s'" % String(layer.preview_problems.get(corner, "")))
	_assert(not layer.preview_valid, "고스트 전체가 거부 상태다")
	sim.remove_machine(corner)
	# A block of ice over two cells of the far side.
	var ice := Vector2i(rect.end.x - 1, seam.y)
	sim.frozen_cats[ice] = 0.0
	main._update_preview()
	var blocked := 0
	for cell: Vector2i in layer.preview_problems:
		if String(layer.preview_problems[cell]) == "막혀 있습니다":
			blocked += 1
	_assert(blocked == 2, "얼음이 덮은 두 칸이 막혀 있다고 표시된다 (%d)" % blocked)
	sim.frozen_cats.erase(ice)
	# Green again, and pressing the key builds exactly the ghost.
	main._update_preview()
	_assert(layer.preview_valid, "치우면 다시 초록이다")
	var ghost: Rect2i = layer.preview_rect
	main._primary_action()
	var built: Sim.Machine = sim.machine_at(seam)
	_assert(built != null and built.type == Defs.M_MINER, "Z 를 누르면 지어진다")
	if built != null:
		_assert(sim.machine_rect(built) == ghost, "지어진 자리가 고스트와 같다")
	# Aimed at it now, the ghost's occupant is the whole standing post.
	main._update_preview()
	_assert(layer.preview_standing == ghost, "서 있는 채굴기의 발자국 전체가 회수 대상으로 표시된다")

func _test_belt_ghost() -> void:
	var spot: Vector2i = sim.core_cell + Vector2i(30, 20)
	_clear(Rect2i(spot - Vector2i(4, 4), Vector2i(9, 9)))
	_hold_gun(Defs.M_BELT)
	main.player.position = Grid.centre(spot + Vector2i(-2, 0))
	main.player.facing = Vector2i.RIGHT
	main._update_preview()
	var layer: Node2D = main.machine_layer
	_assert(layer.preview_rect.size == Vector2i.ONE, "벨트 고스트는 한 칸이다")
	_assert(layer.preview_problems.is_empty() and layer.preview_valid, "빈 땅이면 초록")
	sim.put_ore(layer.preview_cell, Defs.ITEM_CRYSTAL)
	main._update_preview()
	_assert(layer.preview_problems.size() == 1 and not layer.preview_valid,
		"광맥 위면 그 한 칸이 빨갛다")
	sim.erase_ore_at(layer.preview_cell)

## The hut in her arms shows the forty-eight cells it would cover, red where the
## fire is too close.
func _test_carried_hut() -> void:
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	sim.shelter_placed = false
	sim.carried_kit = Defs.KIT_SHELTER
	var base: Rect2i = sim.base_rect()
	_clear(Rect2i(base.end.x, base.position.y - 4, 14, 16))
	# Right beside the base's east wall, facing away from it.
	main.player.position = Grid.centre(Vector2i(base.end.x, sim.core_cell.y))
	main.player.facing = Vector2i.RIGHT
	main._update_preview()
	var layer: Node2D = main.machine_layer
	_assert(layer.carry_rect.size == Vector2i(6, 8), "들고 있는 숙소는 6x8 로 표시된다")
	_assert(layer.carry_rect == Grid.footprint(main.kit_anchor(), Defs.SHELTER_SIZE),
		"놓일 자리 그대로다")
	var close := 0
	for cell: Vector2i in layer.carry_problems:
		if String(layer.carry_problems[cell]) == "불에 너무 가깝습니다":
			close += 1
	_assert(close > 0, "불에 가까운 칸이 빨갛다 (%d칸)" % close)
	_assert(close < 48, "전부가 아니라 가까운 칸만 (%d칸)" % close)
	# Further out: every cell clear, and putting it down lands on the ghost.
	main.player.position = Grid.centre(Vector2i(base.end.x + 2, sim.core_cell.y))
	main._update_preview()
	_assert(layer.carry_problems.is_empty(), "한 걸음 물러서면 모든 칸이 초록이다: %s"
		% str(layer.carry_problems.values()))
	var ghost: Rect2i = layer.carry_rect
	main._place_kit(main.target_cell())
	_assert(sim.shelter_placed, "그리고 놓인다")
	_assert(sim.shelter_rect() == ghost, "고스트가 있던 자리에")
