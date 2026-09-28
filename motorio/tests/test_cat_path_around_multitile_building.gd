extends SceneTree

## A cat walks round a building -- the whole footprint -- and never through it.
##
## The base is eight cells across, the hut six by eight, a row of posts a wall
## thirty cells long. A cat that only knew about anchors would cut through the
## other cells; this walks cats past each through the real mover
## (`_step_toward`) and checks every step against every footprint.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_across_the_base()
	_test_across_the_hut()
	_test_round_a_row_of_posts()
	if failures == 0:
		print("PASS test_cat_path_around_multitile_building")
	else:
		print("FAIL test_cat_path_around_multitile_building (%d)" % failures)
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
	sim.cats.clear()
	sim.unlocked[Defs.M_MINER] = true
	for item: int in [Defs.ITEM_CRYSTAL, Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 5000
	return sim

func _clear(sim: Sim, rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.erase_ore_at(cell)
		var machine: Sim.Machine = sim.machine_at(cell)
		if machine != null and machine.type != Defs.M_CORE:
			sim.remove_machine(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)
	sim.kit_cell = Sim.NONE
	sim._grid_dirty = true

## Walks one cat from `from` to `goal`; returns [ticks spent inside `rects`,
## arrived?, path length in pixels].
func _walk(sim: Sim, from: Vector2, goal: Vector2, rects: Array[Rect2i]) -> Array:
	var cat := Sim.Cat.new()
	cat.pos = from
	cat.state = Defs.CAT_TO_MINER
	sim.cats.append(cat)
	var inside := 0
	var walked := 0.0
	var arrived := false
	for _tick in 4000:
		var before: Vector2 = cat.pos
		if sim._step_toward(cat, goal, 0.05):
			arrived = true
			break
		walked += before.distance_to(cat.pos)
		# Every point along the step, not only where it ends.
		for sample in 5:
			var point: Vector2 = before.lerp(cat.pos, float(sample + 1) / 5.0)
			for rect: Rect2i in rects:
				if Grid.rect_px(rect).grow(-0.5).has_point(point):
					inside += 1
	sim.cats.erase(cat)
	return [inside, arrived, walked]

func _test_across_the_base() -> void:
	var sim := _sim()
	var base: Rect2i = sim.base_rect()
	_clear(sim, base.grow(8))
	var span: Rect2 = Grid.rect_px(base)
	# North of it to south of it, and west to east, straight through the middle.
	var runs: Array = [
		[Vector2(span.get_center().x, span.position.y - 40.0), Vector2(span.get_center().x, span.end.y + 40.0)],
		[Vector2(span.end.x + 40.0, span.get_center().y + 6.0), Vector2(span.position.x - 20.0, span.get_center().y + 6.0)],
	]
	for run: Array in runs:
		var result: Array = _walk(sim, run[0], run[1], [base] as Array[Rect2i])
		_assert(int(result[0]) == 0, "기지를 가로지르지 않는다 (%d번 안에 들어감)" % int(result[0]))
		_assert(bool(result[1]), "그리고 건너편에 닿는다")
		var straight: float = (run[0] as Vector2).distance_to(run[1])
		_assert(float(result[2]) > straight + 32.0, "돌아서 간다 (%.0fpx vs 직선 %.0fpx)"
			% [float(result[2]), straight])
	sim.free()

func _test_across_the_hut() -> void:
	var sim := _sim()
	var hut: Rect2i = sim.shelter_rect()
	var span: Rect2 = Grid.rect_px(hut)
	_clear(sim, Rect2i(hut.position - Vector2i(8, 8), Vector2i(hut.size.x + 8, hut.size.y + 16)))
	var result: Array = _walk(sim, Vector2(span.get_center().x, span.position.y - 40.0),
		Vector2(span.get_center().x, span.end.y + 40.0), [hut, sim.base_rect()] as Array[Rect2i])
	_assert(int(result[0]) == 0, "숙소도 기지도 가로지르지 않는다 (%d)" % int(result[0]))
	_assert(bool(result[1]), "그리고 문간 쪽에 닿는다")
	sim.free()

## Seven posts on a field, a node's pitch apart: two-cell lanes between them
## (World Visual Pass 01 -- the posts used to be four by four and stood edge to
## edge). A cat crosses the row through a lane, never over a post.
##
## And seven posts pushed edge to edge by hand, a wall fourteen cells long with
## no gap: that one it walks round the end of.
func _test_round_a_row_of_posts() -> void:
	for pitch: int in [Defs.ORE_PITCH, Defs.ORE_NODE_SIZE.x]:
		var sim := _sim()
		var origin: Vector2i = sim.core_cell + Vector2i(30, 10)
		_clear(sim, Rect2i(origin - Vector2i(12, 14), Vector2i(Defs.ORE_PITCH * 7 + 24, 28)))
		var rects: Array[Rect2i] = []
		for index in 7:
			var node: Vector2i = origin + Vector2i(index * pitch, 0)
			sim.put_ore(node, Defs.ITEM_HEATSTONE)
			_assert(sim.build(Defs.M_MINER, node, Vector2i.DOWN), "채굴기 %d" % index)
			rects.append(sim.machine_rect(sim.machine_at(node)))
		var middle: Vector2 = Grid.rect_centre(rects[3])
		var result: Array = _walk(sim, middle + Vector2(0.0, -80.0), middle + Vector2(0.0, 80.0), rects)
		_assert(int(result[0]) == 0, "채굴기 줄을 뚫지 않는다 (간격 %d, %d번)" % [pitch, int(result[0])])
		_assert(bool(result[1]), "건너편에 닿는다 (간격 %d)" % pitch)
		if pitch == Defs.ORE_PITCH:
			_assert(float(result[2]) < 160.0 + 64.0, "채굴기 사이 통로로 건너간다 (%.0fpx)" % float(result[2]))
		else:
			_assert(float(result[2]) > 160.0 + 100.0, "빈틈없는 줄은 끝까지 돌아간다 (%.0fpx)" % float(result[2]))
		sim.free()
