extends SceneTree

## What she can reach is as far away as it always was.
##
## Her hands reach one tile ahead -- the old front cell -- and a tile across; a
## thing two tiles ahead is out of reach. The hut answers from the same distance
## off its walls, the fire thaws the ice at the same distance off its walls, and
## the case can be put down as far from the landing as before. All of it
## measured in world pixels, since the cell those rules were written against is
## gone.

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
	_test_hands_reach_a_tile()
	_test_underfoot_is_a_tile()
	_test_hut_reach()
	_test_thaw_reach()
	_test_case_reach()
	if failures == 0:
		print("PASS test_interaction_world_distance_preserved")
	else:
		print("FAIL test_interaction_world_distance_preserved (%d)" % failures)
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
		sim.ground.erase(cell)
		sim.drops.erase(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)

## A block of ice a tile across, one tile ahead of her tile, is what she faces;
## two tiles ahead it is not. Checked from anywhere inside her tile.
func _test_hands_reach_a_tile() -> void:
	var here: Vector2i = Grid.tile_of(sim.core_cell) + Vector2i(14, 0)
	_clear(Rect2i(Grid.from_tile(here) - Vector2i(8, 8), Vector2i(18, 18)))
	var near_ok := 0
	var far_ok := 0
	var tried := 0
	for facing: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		for nudge: Vector2 in [Vector2.ZERO, Vector2(6.0, 6.0), Vector2(-6.0, -6.0), Vector2(6.0, -6.0)]:
			tried += 1
			main.player.position = Grid.tile_centre(here) + nudge
			main.player.facing = facing
			var near: Vector2i = Grid.from_tile(here + facing)
			sim.frozen_cats[near] = 0.0
			if sim.frozen_key(main.target_cell()) == near:
				near_ok += 1
			sim.frozen_cats.erase(near)
			var far: Vector2i = Grid.from_tile(here + facing * 2)
			sim.frozen_cats[far] = 0.0
			if sim.frozen_key(main.target_cell()) != far:
				far_ok += 1
			sim.frozen_cats.erase(far)
	_assert(near_ok == tried, "한 칸(타일) 앞의 얼음은 손이 닿는다 (%d/%d)" % [near_ok, tried])
	_assert(far_ok == tried, "두 칸 앞의 얼음은 닿지 않는다 (%d/%d)" % [far_ok, tried])
	# The reach itself: a tile deep and a tile wide.
	main.player.position = Grid.tile_centre(here)
	main.player.facing = Vector2i.RIGHT
	var span := Rect2()
	for cell: Vector2i in main.player.reach_cells():
		var px: Rect2 = Grid.rect_px(Rect2i(cell, Vector2i.ONE))
		span = px if span.size == Vector2.ZERO else span.merge(px)
	_assert(span.size == Vector2(32.0, 32.0), "손이 닿는 땅은 32x32px — 옛 앞칸 하나 (%s)" % span.size)
	_assert(is_equal_approx(span.position.x, Grid.tile_centre(here).x + 16.0),
		"그리고 그녀의 타일 바로 앞에서 시작한다")
	# A cat standing there is the cat she faces.
	sim.grant_cats(1)
	var cat: Sim.Cat = sim.cats[-1]
	cat.state = Defs.CAT_IDLE
	cat.pos = Grid.tile_centre(here + Vector2i.RIGHT)
	_assert(sim.cat_on(main.target_cell()) == cat, "한 칸 앞에 선 고양이를 마주 본다")
	cat.pos = Grid.tile_centre(here + Vector2i.RIGHT * 2)
	_assert(sim.cat_on(main.target_cell()) == null, "두 칸 앞의 고양이는 아니다")

## Underfoot is the tile-sized block around her, for picking things up.
func _test_underfoot_is_a_tile() -> void:
	var here: Vector2 = Grid.tile_centre(Grid.tile_of(sim.core_cell) + Vector2i(14, 4))
	var block: Array[Vector2i] = Grid.near_block(here + Vector2(3.0, -2.0))
	var span := Rect2()
	for cell: Vector2i in block:
		var px: Rect2 = Grid.rect_px(Rect2i(cell, Vector2i.ONE))
		span = px if span.size == Vector2.ZERO else span.merge(px)
	_assert(span.size == Vector2(32.0, 32.0), "발밑은 32x32px 이다")
	_assert(span.has_point(here + Vector2(3.0, -2.0)), "그리고 그녀가 그 안에 서 있다")

## The hut answers when she is within SHELTER_REACH of where its door-side wall
## was -- measured off the walls, as it was measured off a one-tile hut's middle
## less half a tile.
func _test_hut_reach() -> void:
	var span: Rect2 = Grid.rect_px(sim.shelter_rect())
	var reach: float = Defs.SHELTER_REACH - float(Grid.TILE) * 0.5
	main.player.position = Vector2(span.get_center().x, span.end.y + reach - 1.0)
	_assert(main.shelter_nearby(), "숙소 벽에서 %.0fpx 안이면 숙소 곁이다" % reach)
	main.player.position = Vector2(span.get_center().x, span.end.y + reach + 1.0)
	_assert(not main.shelter_nearby(), "그보다 멀면 아니다")
	_assert(is_equal_approx(Defs.SHELTER_REACH, 62.0), "숙소 손닿는 거리는 62px 그대로")

## The fire thaws ice set down against the base or one tile off it, not two.
func _test_thaw_reach() -> void:
	var base: Rect2i = sim.base_rect()
	_clear(Rect2i(base.end.x, base.position.y, 10, 8))
	var against := Vector2i(base.end.x, sim.core_cell.y)
	var gap_one: Vector2i = against + Vector2i(Grid.SCALE, 0)
	var gap_two: Vector2i = against + Vector2i(Grid.SCALE * 2, 0)
	for origin: Vector2i in [against, gap_one, gap_two]:
		sim.frozen_cats[origin] = 0.0
	_assert(sim.can_thaw(against), "기지 벽에 붙인 얼음은 녹는다")
	_assert(sim.can_thaw(gap_one), "한 칸(타일) 떨어져도 녹는다")
	_assert(not sim.can_thaw(gap_two), "두 칸 떨어지면 녹지 않는다")
	_assert(is_equal_approx(sim.tiles_from_base_at(sim.prop_centre(gap_one)), 1.5),
		"거리는 벽에서 잰다 (한 칸 떨어진 얼음의 가운데는 1.5칸)")
	for origin: Vector2i in [against, gap_one, gap_two]:
		sim.frozen_cats.erase(origin)

## The case goes down within BASE_PLACE_RADIUS tiles of where it would unfold.
func _test_case_reach() -> void:
	var world := Sim.new()
	world.setup(4242)
	world.begin_crash()
	var centre: Vector2 = world.core_centre()
	var limit: float = Grid.px(Defs.BASE_PLACE_RADIUS)
	_assert(is_equal_approx(limit, 64.0), "기지를 내려놓을 수 있는 거리는 64px (2칸)")
	world.carried_kit = Defs.KIT_BASE
	var far: Vector2i = world.core_cell + Vector2i(Grid.SCALE * 3, 0)
	_assert(Grid.centre(far).distance_to(centre) > limit, "세 칸 밖은 너무 멀다")
	_assert(not world.place_base(far), "그래서 거기엔 놓이지 않는다")
	var near: Vector2i = world.core_cell + Vector2i(Grid.SCALE, 0)
	_assert(Grid.centre(near).distance_to(centre) <= limit, "한 칸 옆은 된다")
	_assert(world.place_base(near), "그래서 거기엔 놓인다")
	world.free()
