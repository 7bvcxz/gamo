extends SceneTree

## A cat sent to a post walks to a place outside it and works it from there.
##
## A post is four cells by four and solid, so "go to the machine" is "go to the
## cell against its back wall, in line with the seam". That place has to be
## outside the footprint, standable (feet and torso both on open ground), next
## to the post, and reachable -- whichever way the post faces, and when its
## neighbours crowd it on both sides.

var failures := 0

const SITE := Vector2i(30, 10)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_each_facing()
	_test_crowded_row()
	_test_from_the_hut()
	if failures == 0:
		print("PASS test_cat_can_reach_mining_post_work_position")
	else:
		print("FAIL test_cat_can_reach_mining_post_work_position (%d)" % failures)
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
	for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 5000
	return sim

func _clear(sim: Sim, rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.erase_ore_at(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)
	sim._grid_dirty = true

## The place is outside, standable, and against the post.
func _check_place(sim: Sim, seam: Vector2i, label: String) -> void:
	var post: Sim.Machine = sim.machine_at(seam)
	var rect: Rect2i = sim.machine_rect(post)
	var cell: Vector2i = sim.work_cell(seam)
	var stand: Vector2 = sim.post_stand(seam)
	_assert(not rect.has_point(cell), "%s: 일하는 칸은 채굴기 바깥이다" % label)
	_assert(sim._can_stand(cell), "%s: 발도 몸통도 빈 땅이다" % label)
	_assert(rect.grow(2).has_point(cell), "%s: 채굴기에 붙어 있다" % label)
	_assert(cell != sim.output_cell(post), "%s: 출구를 막고 서지 않는다" % label)
	_assert(not Grid.rect_px(rect).has_point(stand), "%s: 서 있는 점도 바깥이다" % label)

## Puts a cat down at `from` with a job at `seam` and runs the sim until it is
## working; returns the seconds it took, or -1, and counts ticks inside a
## footprint.
func _send(sim: Sim, seam: Vector2i, from: Vector2, rects: Array[Rect2i]) -> Array:
	var cat := Sim.Cat.new()
	cat.pos = from
	cat.assigned = seam
	cat.state = Defs.CAT_TO_MINER
	sim.cats.append(cat)
	var inside := 0
	var elapsed := 0.0
	while elapsed < 120.0:
		sim.tick(0.05)
		elapsed += 0.05
		for rect: Rect2i in rects:
			if Grid.rect_px(rect).grow(-0.5).has_point(cat.pos):
				inside += 1
		if cat.state == Defs.CAT_WORKING:
			break
	var at: Vector2 = cat.pos
	return [elapsed if cat.state == Defs.CAT_WORKING else -1.0, inside, at]

func _test_each_facing() -> void:
	var headings: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for dir: Vector2i in headings:
		var sim := _sim()
		var seam: Vector2i = sim.core_cell + SITE
		_clear(sim, Rect2i(seam - Vector2i(12, 12), Vector2i(25, 25)))
		sim.put_ore(seam, Defs.ITEM_HEATSTONE)
		sim.build(Defs.M_MINER, seam, dir)
		_check_place(sim, seam, "%s 향" % dir)
		var rect: Rect2i = sim.machine_rect(sim.machine_at(seam))
		# From the far side: the cat has to walk round the post to its back.
		var far: Vector2 = Grid.centre(seam) + Vector2(dir) * 90.0
		var result: Array = _send(sim, seam, far, [rect] as Array[Rect2i])
		_assert(float(result[0]) > 0.0, "%s 향: 반대편에서 온 고양이가 일을 시작한다 (%.1f초)"
			% [dir, float(result[0])])
		_assert(int(result[1]) == 0, "%s 향: 오는 길에 채굴기를 통과하지 않는다 (%d)" % [dir, int(result[1])])
		_assert((result[2] as Vector2).distance_to(sim.post_stand(seam)) < 0.5,
			"%s 향: 일하는 자리에 정확히 선다" % dir)
		sim.free()

## Posts shoulder to shoulder: the side walls are someone else's, so the back
## is the only way in -- and it has to be free.
func _test_crowded_row() -> void:
	var sim := _sim()
	var origin: Vector2i = sim.core_cell + SITE
	_clear(sim, Rect2i(origin - Vector2i(12, 12), Vector2i(Defs.ORE_PITCH * 5 + 24, 25)))
	var seams: Array[Vector2i] = []
	var rects: Array[Rect2i] = []
	for index in 5:
		var seam: Vector2i = origin + Vector2i(index * Defs.ORE_PITCH, 0)
		sim.put_ore(seam, Defs.ITEM_HEATSTONE)
		sim.build(Defs.M_MINER, seam, Vector2i.DOWN)
		seams.append(seam)
		rects.append(sim.machine_rect(sim.machine_at(seam)))
	var places: Dictionary = {}
	for seam: Vector2i in seams:
		_check_place(sim, seam, "줄 %s" % seam)
		places[sim.work_cell(seam)] = true
	_assert(places.size() == seams.size(), "다섯 채굴기의 일하는 칸이 서로 다르다")
	# The middle one, from below: round the end of the row and back along the top.
	var middle: Vector2i = seams[2]
	var result: Array = _send(sim, middle, Grid.centre(middle) + Vector2(0.0, 90.0), rects)
	_assert(float(result[0]) > 0.0, "가운데 채굴기에도 줄을 돌아 닿는다 (%.1f초)" % float(result[0]))
	_assert(int(result[1]) == 0, "어느 채굴기도 통과하지 않는다 (%d)" % int(result[1]))
	sim.free()

## The real morning: every cat leaves the hut's doorstep for its own post.
func _test_from_the_hut() -> void:
	var sim := _sim()
	var seams: Array[Vector2i] = []
	for offset: Vector2i in Sim.STARTER_PATCH:
		var seam: Vector2i = sim.core_cell + offset
		if sim.can_build(Defs.M_MINER, seam, Vector2i.UP) == "":
			sim.build(Defs.M_MINER, seam, Vector2i.UP)
			seams.append(seam)
	_assert(seams.size() == Sim.STARTER_PATCH.size(), "시작 광맥 셋에 모두 채굴기가 선다")
	sim.grant_cats(seams.size())
	for index in seams.size():
		sim.cats[index].assigned = seams[index]
	sim.dispatch_cats()
	var rects: Array[Rect2i] = [sim.base_rect(), sim.shelter_rect()]
	for seam: Vector2i in seams:
		rects.append(sim.machine_rect(sim.machine_at(seam)))
	var inside := 0
	var elapsed := 0.0
	var working := 0
	while elapsed < 90.0:
		sim.tick(0.05)
		elapsed += 0.05
		working = 0
		for cat: Sim.Cat in sim.cats:
			if cat.state == Defs.CAT_WORKING:
				working += 1
			for rect: Rect2i in rects:
				if Grid.rect_px(rect).grow(-0.5).has_point(cat.pos):
					inside += 1
		if working == seams.size():
			break
	_assert(working == seams.size(), "아침에 모두 제 채굴기에 가서 일한다 (%d/%d, %.0f초)"
		% [working, seams.size(), elapsed])
	_assert(inside == 0, "숙소·기지·채굴기를 통과한 고양이가 없다 (%d)" % inside)
	sim.free()
