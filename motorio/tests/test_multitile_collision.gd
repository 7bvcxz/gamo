extends SceneTree

## Walking into a building stops at its wall -- the whole wall, not one cell of
## it -- and nothing can be built into a building's footprint.
##
## The walk is the real one: her `_physics_process` with the pad held, ticked
## until she has stopped, against the base (8x8), the hut (6x8) and a mining post
## (4x4). Her body box may never overlap a footprint on any tick, she must come
## to rest against the wall rather than short of it, and pushing diagonally into
## a wall slides her along it.

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
	_test_walls()
	_test_slide()
	_test_no_overlap_rules()
	if failures == 0:
		print("PASS test_multitile_collision")
	else:
		print("FAIL test_multitile_collision (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## Walks her from `start` along `dir` until she stops; returns how many ticks her
## body overlapped `span`, and leaves her where she stopped.
func _walk(start: Vector2, dir: Vector2, span: Rect2, ticks: int = 240) -> int:
	var player: Node2D = main.player
	player.position = start
	player.velocity = Vector2.ZERO
	player.warmth = 100.0
	player.locked = false
	player.modal = false
	player.touch_direction = dir
	var overlaps := 0
	var r: float = Defs.PLAYER_RADIUS
	for _tick in ticks:
		player._physics_process(1.0 / 60.0)
		var body := Rect2(player.position - Vector2(r, r), Vector2(r, r) * 2.0)
		if body.intersects(span):
			overlaps += 1
	player.touch_direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	return overlaps

## Nothing generated in the corridor she walks.
func _clear_corridor(rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.ore.erase(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)
	sim.kit_cell = Sim.NONE

func _test_walls() -> void:
	var r: float = Defs.PLAYER_RADIUS
	# The base, from the east.
	var base: Rect2 = Grid.rect_px(sim.base_rect())
	_clear_corridor(Rect2i(sim.base_rect().end.x, sim.base_rect().position.y, 12, 8))
	var row: float = base.get_center().y + 4.0
	var hit: int = _walk(Vector2(base.end.x + 90.0, row), Vector2.LEFT, base)
	_assert(hit == 0, "기지 벽을 한 번도 뚫지 않는다 (%d틱 겹침)" % hit)
	_assert(main.player.position.x - r - base.end.x < 2.0,
		"그리고 벽 바로 앞에 멈춘다 (틈 %.1fpx)" % (main.player.position.x - r - base.end.x))
	# From the south, off-centre: every column of the wall is wall.
	_clear_corridor(Rect2i(sim.base_rect().position.x, sim.base_rect().end.y, 8, 10))
	for column: float in [base.position.x + 10.0, base.get_center().x, base.end.x - 10.0]:
		hit = _walk(Vector2(column, base.end.y + 100.0), Vector2.UP, base)
		_assert(hit == 0, "기지 남쪽 벽 x=%.0f 도 막힌다 (%d틱 겹침)" % [column, hit])
		_assert(main.player.position.y - r - base.end.y < 2.0, "벽 앞에 멈춘다 x=%.0f" % column)
	# The hut, from the south: its door is below it and the door is not a hole.
	var hut: Rect2 = Grid.rect_px(sim.shelter_rect())
	_clear_corridor(Rect2i(sim.shelter_rect().position.x, sim.shelter_rect().end.y, 6, 10))
	for column: float in [hut.position.x + 10.0, hut.get_center().x, hut.end.x - 10.0]:
		hit = _walk(Vector2(column, hut.end.y + 100.0), Vector2.UP, hut)
		_assert(hit == 0, "숙소 벽 x=%.0f 을 뚫지 않는다 (%d틱 겹침)" % [column, hit])
		_assert(main.player.position.y - r - hut.end.y < 2.0, "숙소 벽 앞에 멈춘다 x=%.0f" % column)
	# A mining post, from the west.
	var seam: Vector2i = sim.core_cell + Vector2i(30, 12)
	_clear_corridor(Rect2i(seam - Vector2i(14, 4), Vector2i(20, 9)))
	sim.ore[seam] = Defs.ITEM_CRYSTAL
	sim.machines.erase(seam)
	var post := Sim.Machine.new()
	post.type = Defs.M_MINER
	post.cell = seam
	sim.add_machine(post)
	var span: Rect2 = Grid.rect_px(sim.machine_rect(post))
	for lane: float in [span.position.y + 6.0, span.get_center().y, span.end.y - 6.0]:
		hit = _walk(Vector2(span.position.x - 120.0, lane), Vector2.RIGHT, span)
		_assert(hit == 0, "채굴기 벽 y=%.0f 를 뚫지 않는다 (%d틱 겹침)" % [lane, hit])
		_assert(span.position.x - (main.player.position.x + r) < 2.0, "채굴기 앞에 멈춘다 y=%.0f" % lane)

## Pushing diagonally into a wall runs her along it, not into it and not stuck.
func _test_slide() -> void:
	var base: Rect2 = Grid.rect_px(sim.base_rect())
	var start := Vector2(base.end.x + 10.0, base.position.y + 20.0)
	var hit: int = _walk(start, Vector2(-1.0, 1.0).normalized(), base, 60)
	_assert(hit == 0, "대각선으로 밀어도 벽 안으로 들어가지 않는다")
	_assert(main.player.position.y > start.y + 20.0, "벽을 따라 미끄러진다 (%.0fpx)"
		% (main.player.position.y - start.y))

## No footprint may be built into another, whichever cell of it overlaps.
func _test_no_overlap_rules() -> void:
	sim.unlocked[Defs.M_MINER] = true
	sim.unlocked[Defs.M_BELT] = true
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
	var seam: Vector2i = sim.core_cell + Vector2i(30, 12)
	var rect: Rect2i = Defs.machine_footprint(Defs.M_MINER, seam)
	# A second post whose footprint shares a single corner cell.
	var corner_seam: Vector2i = rect.end + Vector2i(1, 1) - Vector2i.ONE
	sim.ore[corner_seam] = Defs.ITEM_CRYSTAL
	var overlap: Rect2i = Defs.machine_footprint(Defs.M_MINER, corner_seam).intersection(rect)
	_assert(overlap.get_area() == 1, "두 번째 채굴기는 모서리 한 칸만 겹친다")
	_assert(sim.can_build(Defs.M_MINER, corner_seam) != "", "한 칸이라도 겹치면 거부된다")
	sim.ore.erase(corner_seam)
	# A belt on any cell of the post.
	var refused := 0
	for cell: Vector2i in Grid.cells_in(rect):
		if sim.can_build(Defs.M_BELT, cell) == "이미 설비가 있습니다":
			refused += 1
	_assert(refused == 16, "채굴기의 16칸 어디에도 벨트를 놓을 수 없다 (%d)" % refused)
	# A post whose footprint would reach into the base, the hut, or a block of ice.
	# The post's west column is the base's east column.
	var by_base: Vector2i = Vector2i(sim.base_rect().end.x, sim.core_cell.y)
	sim.ore[by_base] = Defs.ITEM_CRYSTAL
	_assert(sim.can_build(Defs.M_MINER, by_base) != "", "기지에 한 칸 걸치는 채굴기는 거부된다")
	sim.ore.erase(by_base)
	var by_hut: Vector2i = Vector2i(sim.shelter_rect().position.x - 2, sim.shelter_cell.y)
	# Only the hut in the way: the world is a random seed, and one seed in a few
	# puts a seam of its own inside this footprint, which is refused first and
	# for a different reason -- the check then failed on a sentence, not a rule.
	for cell: Vector2i in Grid.cells_in(Defs.machine_footprint(Defs.M_MINER, by_hut)):
		sim.ore.erase(cell)
	sim.ore[by_hut] = Defs.ITEM_CRYSTAL
	_assert(sim.can_build(Defs.M_MINER, by_hut) == "막혀 있습니다",
		"숙소에 한 칸 걸치는 채굴기도 거부된다: '%s'" % sim.can_build(Defs.M_MINER, by_hut))
	sim.ore.erase(by_hut)
	var ice_seam: Vector2i = seam + Vector2i(0, 12)
	_clear_corridor(Rect2i(ice_seam - Vector2i(4, 4), Vector2i(9, 9)))
	sim.ore[ice_seam] = Defs.ITEM_CRYSTAL
	sim.frozen_cats[ice_seam + Vector2i(2, 2)] = 0
	_assert(sim.can_build(Defs.M_MINER, ice_seam) == "막혀 있습니다",
		"얼어붙은 고양이에 걸치는 채굴기도 거부된다")
