extends SceneTree

## The agent harness walks round buildings, not through them, and stands where
## its hands reach the whole of what it means.
##
## Its planner (tools/agent/nav.gd) and its legs (tools/agent/body.gd) are
## driven here for real: plans are checked against every footprint, the body
## walks them through the player's own mover, and from where it stops the
## player's own `target_cell` must land on the building it was sent to.
##
## Grid v2 made a cell narrower than her. A one-cell gap is open ground her body
## does not fit through, so the planner must never route through one -- and the
## lane between the fire and the first posts has to be wide enough that it does
## not have to.

const Body := preload("res://tools/agent/body.gd")

var failures := 0
var main: Node2D
var sim: Sim
var body

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
	sim.has_gun = true
	sim.unlocked[Defs.M_MINER] = true
	sim.unlocked[Defs.M_BELT] = true
	for item: int in [Defs.ITEM_CRYSTAL, Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 5000
	# Warm everywhere this walks: out in the cold she freezes, is carried home
	# and wakes up in the hut, which is a different test.
	sim.stones_in = int(Defs.BASE_LEVELS[-1]["stones"])
	sim._refresh_radius()
	body = Body.new(main, null)
	_test_plan_round_the_base()
	_test_face_what_it_was_sent_to()
	_test_one_cell_gap_is_a_wall()
	_test_starter_lane()
	if failures == 0:
		print("PASS test_agent_pathfinding_multitile")
	else:
		print("FAIL test_agent_pathfinding_multitile (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _clear(rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.ore.erase(cell)
		var machine: Sim.Machine = sim.machine_at(cell)
		if machine != null and machine.type != Defs.M_CORE:
			sim.remove_machine(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)
	sim.kit_cell = Sim.NONE

func _park(cell: Vector2i) -> void:
	main.player.position = Grid.centre(cell)
	main.player.velocity = Vector2.ZERO
	main.player.warmth = 100.0

## From west of the base to east of it: the plan never enters the base and every
## step of it is one her body can take -- and the body walks it to the end.
func _test_plan_round_the_base() -> void:
	var base: Rect2i = sim.base_rect()
	_clear(Rect2i(base.position - Vector2i(2, 12), Vector2i(base.size.x + 14, base.size.y + 24)))
	# East to north-east: past the base's corner, not across it.
	var start := Vector2i(base.end.x + 3, sim.core_cell.y)
	var goal := Vector2i(base.position.x + 1, base.position.y - 4)
	_park(start)
	var route: Array[Vector2i] = body.nav.path(start, goal)
	_assert(not route.is_empty(), "기지를 돌아가는 길이 있다 (%d칸)" % route.size())
	var inside := 0
	var bad_steps := 0
	var previous: Vector2i = start
	for cell: Vector2i in route:
		if base.has_point(cell):
			inside += 1
		if not body.nav.can_step(previous, cell):
			bad_steps += 1
		previous = cell
	_assert(inside == 0, "계획이 기지 칸을 지나지 않는다 (%d)" % inside)
	_assert(bad_steps == 0, "모든 걸음이 몸이 들어가는 폭이다 (%d)" % bad_steps)
	_assert(body.move_to(goal, 60.0) == Body.OK, "그리고 몸이 그 길을 끝까지 걷는다")
	var span: Rect2 = Grid.rect_px(base)
	var r: float = Defs.PLAYER_RADIUS
	var box := Rect2(main.player.position - Vector2(r, r), Vector2(r, r) * 2.0)
	_assert(not box.intersects(span.grow(-0.5)), "도착한 자리는 기지 바깥이다")

## Sent to the base, a post, a block of ice: it stops outside each, facing it,
## and what the player's Z would act on is that thing.
func _test_face_what_it_was_sent_to() -> void:
	# The base.
	_park(Vector2i(sim.base_rect().end.x + 6, sim.core_cell.y + 2))
	_assert(body.move_near(sim.core_cell) == Body.OK, "기지 곁으로 간다")
	_assert(not sim.base_rect().has_point(main.player.cell()), "기지 안이 아니라 곁에 선다")
	_assert(sim.is_base(main.target_cell()), "그 자리에서 Z 는 기지를 향한다")
	# A post, built by the harness's own verb.
	var seam: Vector2i = sim.core_cell + Vector2i(30, 0)
	_clear(Rect2i(seam - Vector2i(10, 10), Vector2i(21, 21)))
	sim.ore[seam] = Defs.ITEM_HEATSTONE
	_park(seam + Vector2i(-8, 6))
	_assert(body.place_machine(Defs.M_MINER, seam, Vector2i.UP) == Body.OK, "하네스가 채굴기를 짓는다")
	var post: Sim.Machine = sim.machine_at(seam)
	_assert(post != null, "채굴기가 섰다")
	if post != null:
		var rect: Rect2i = sim.machine_rect(post)
		var inside := 0
		for cell: Vector2i in main.body_cells():
			if rect.has_point(cell):
				inside += 1
		_assert(inside == 0, "짓는 동안 발자국 밖에 서 있었다")
		_park(seam + Vector2i(8, 8))
		_assert(body.move_near(seam) == Body.OK, "채굴기 곁으로 간다")
		_assert(not rect.has_point(main.player.cell()), "발자국 바깥에 선다")
		_assert(sim.machine_at(main.target_cell()) == post, "Z 는 그 채굴기를 향한다")
	# A block of ice a tile across.
	var ice: Vector2i = seam + Vector2i(0, 12)
	_clear(Rect2i(ice - Vector2i(4, 4), Vector2i(10, 10)))
	sim.frozen_cats[ice] = 0.0
	_park(ice + Vector2i(6, 6))
	_assert(body.move_near(ice) == Body.OK, "얼음 곁으로 간다")
	_assert(sim.frozen_key(main.target_cell()) == ice, "Z 는 그 얼음을 향한다")
	sim.frozen_cats.erase(ice)

## Two posts a cell apart: open ground between them, and no way through for her.
## Two cells apart: a way through.
func _test_one_cell_gap_is_a_wall() -> void:
	var origin: Vector2i = sim.core_cell + Vector2i(-40, 24)
	_clear(Rect2i(origin - Vector2i(14, 14), Vector2i(40, 50)))
	for gap in [1, 2]:
		var left: Vector2i = origin + Vector2i(0, (gap - 1) * 14)
		var right: Vector2i = left + Vector2i(4 + gap, 0)
		for seam: Vector2i in [left, right]:
			sim.ore[seam] = Defs.ITEM_HEATSTONE
			var machine := Sim.Machine.new()
			machine.type = Defs.M_MINER
			machine.cell = seam
			sim.add_machine(machine)
		var column: int = sim.machine_rect(sim.machine_at(left)).end.x
		var north := Vector2i(column, left.y - 5)
		var south := Vector2i(column, left.y + 6)
		var route: Array[Vector2i] = body.nav.path(north, south)
		var through := 0
		for cell: Vector2i in route:
			if cell.x >= column and cell.x < column + gap and absi(cell.y - left.y) <= 1:
				through += 1
		if gap == 1:
			_assert(not body.nav.walkable(Vector2i(column, left.y)), "한 칸 틈은 설 수 없는 땅이다")
			_assert(through == 0, "한 칸 틈으로는 지나가지 않는다 (%d)" % through)
			_assert(route.size() > 11, "돌아간다 (%d칸)" % route.size())
		else:
			_assert(body.nav.walkable(Vector2i(column, left.y)), "두 칸 틈은 설 수 있다")
			_assert(through > 0, "두 칸 틈으로는 지나간다")
			_park(north)
			var verdict: String = body.move_to(south, 30.0)
			_assert(verdict == Body.OK, "몸도 실제로 두 칸 틈을 지나간다 (%s, %s)"
				% [verdict, main.player.cell()])

## The lane between the fire and its first three posts is a way through, and
## the harness can lay the belt home in the middle of it.
func _test_starter_lane() -> void:
	var base: Rect2i = sim.base_rect()
	for offset: Vector2i in Sim.STARTER_PATCH:
		var seam: Vector2i = sim.core_cell + offset
		sim.ore[seam] = Defs.ITEM_HEATSTONE
		if sim.machine_at(seam) == null:
			var why: String = sim.can_build(Defs.M_MINER, seam, Vector2i.UP)
			_assert(sim.build(Defs.M_MINER, seam, Vector2i.UP), "시작 광맥 %s 에 채굴기 %s" % [offset, why])
	# From the open ground east of the last post to the mouth of the lane west of
	# the first one (the hut stands further west).
	var lane_y: int = base.end.y
	var east := Vector2i(sim.core_cell.x + Sim.STARTER_PATCH[2].x + 4, lane_y)
	var west := Vector2i(sim.core_cell.x + Sim.STARTER_PATCH[0].x - 2, lane_y + 1)
	_assert(body.nav.walkable(east) and body.nav.walkable(west), "통로 양 끝은 설 수 있는 땅이다")
	var route: Array[Vector2i] = body.nav.path(east, west)
	var detour := 0
	for cell: Vector2i in route:
		if cell.y > lane_y + 1 or cell.y < lane_y:
			detour += 1
	_assert(not route.is_empty() and detour == 0,
		"불과 첫 채굴기들 사이 통로로 곧장 지나간다 (%d칸 중 %d칸 벗어남)" % [route.size(), detour])
	_park(east)
	var walked: String = body.move_to(west, 30.0)
	_assert(walked == Body.OK, "몸도 그 통로를 지나간다 (%s, %s)" % [walked, main.player.cell()])
	# The middle post pours into the lane; the belt home goes on its mouth.
	var middle: Sim.Machine = sim.machine_at(sim.core_cell + Sim.STARTER_PATCH[1])
	var mouth: Vector2i = sim.output_cell(middle)
	_assert(mouth.y == lane_y + 1, "가운데 채굴기는 통로에 쏟는다")
	var first: String = body.place_machine(Defs.M_BELT, mouth, Vector2i.UP)
	var second: String = body.place_machine(Defs.M_BELT, mouth + Vector2i.UP, Vector2i.UP)
	_assert(first == Body.OK and second == Body.OK,
		"하네스가 통로 한가운데에 기지로 가는 벨트를 깐다 (%s, %s)" % [first, second])
	_assert(sim.base_rect().has_point(sim.output_cell(sim.machine_at(mouth + Vector2i.UP))),
		"그 벨트는 기지 벽으로 들어간다")
