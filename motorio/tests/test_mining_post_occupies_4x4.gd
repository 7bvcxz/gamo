extends SceneTree

## A mining post covers four cells by four -- two tiles across -- around the seam
## it stands on, and every one of those cells is the post.
##
## Its size comes from the machine table, never from the placement code: the
## same `Defs.machine_footprint` answers for building it, drawing it, pathing
## round it and taking it down.

var failures := 0

## Clear ground well east of the fire, past the first ring of anything.
const SITE := Vector2i(36, 0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_size_is_data()
	_test_every_direction()
	_test_taken_down_from_any_cell()
	_test_picture_stays_on_its_cells()
	if failures == 0:
		print("PASS test_mining_post_occupies_4x4")
	else:
		print("FAIL test_mining_post_occupies_4x4 (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_size_is_data() -> void:
	for type: int in [Defs.M_MINER, Defs.M_MINER_MK2]:
		_assert(Defs.machine_size(type) == Vector2i(4, 4), "%s 는 표에 4x4 로 적혀 있다"
			% Defs.MACHINE_NAMES[type])
		var rect: Rect2i = Defs.machine_footprint(type, Vector2i(10, 10))
		_assert(rect.position + Vector2i(1, 1) == Vector2i(10, 10),
			"%s 의 광맥 앵커는 발자국의 (1,1) — 가운데 2x2 의 왼쪽 위" % Defs.MACHINE_NAMES[type])

## What the post draws covers no more than what it blocks. Posts on neighbouring
## seams stand exactly one footprint apart (`ORE_PITCH`), so a picture that hangs
## over its own cells hangs over the next post's -- at the shared machine size it
## did, by two and a half pixels a side, and a row of posts read as one block.
##
## Measured on the picture's opaque pixels, read from the source file rather than
## the imported texture (the headless renderer has no image to give back), so a
## redrawn post in the art pass is held to the same rule without touching this.
func _test_picture_stays_on_its_cells() -> void:
	var footprint: Vector2 = Grid.rect_px(Defs.machine_footprint(Defs.M_MINER, Vector2i.ZERO)).size
	var drawn: float = MachineLayer.MINER_ART_DRAW * MachineLayer._k(footprint.x)
	var image: Image = Image.load_from_file(
		ProjectSettings.globalize_path(MachineLayer.MINER_ART.resource_path))
	_assert(image != null, "채굴기 그림을 읽는다")
	if image == null:
		return
	var used: Rect2i = image.get_used_rect()
	var per_pixel: float = drawn / float(image.get_width())
	# Centred on the footprint, the way `_object_art` places it.
	var opaque := Rect2(Vector2.ONE * -drawn * 0.5 + Vector2(used.position) * per_pixel,
		Vector2(used.size) * per_pixel)
	var cells := Rect2(-footprint * 0.5, footprint)
	_assert(cells.grow(0.01).encloses(opaque),
		"채굴기 그림이 4x4 발자국 안에 그려진다 (그림 %.1f..%.1f × %.1f..%.1f, 발자국 ±%.0f)"
			% [opaque.position.x, opaque.end.x, opaque.position.y, opaque.end.y, footprint.x * 0.5])

func _test_every_direction() -> void:
	var headings: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for index in headings.size():
		var dir: Vector2i = headings[index]
		var sim := _sim()
		var seam: Vector2i = sim.core_cell + SITE + Vector2i(0, index * 10)
		_ground(sim, seam)
		_assert(sim.can_build(Defs.M_MINER, seam, dir) == "", "%s 방향으로 지을 수 있다" % dir)
		_assert(sim.build(Defs.M_MINER, seam, dir), "그리고 지어진다 (%s)" % dir)
		var post: Sim.Machine = sim.machine_at(seam)
		var rect: Rect2i = sim.machine_rect(post)
		_assert(rect.size == Vector2i(4, 4), "%s: 4x4 그대로다 %s" % [dir, rect.size])
		_assert(rect.has_point(seam), "%s: 광맥 칸은 발자국 안이다" % dir)
		_assert(Grid.rect_px(rect).size == Vector2(64.0, 64.0), "%s: 월드에서 64px (2칸)" % dir)
		var same := 0
		var solid := 0
		for cell: Vector2i in Grid.cells_in(rect):
			if sim.machine_at(cell) == post and sim.post_anchor(cell) == seam:
				same += 1
			if sim.blocks_player(cell):
				solid += 1
		_assert(same == 16, "%s: 16칸 모두 같은 채굴기이고 같은 광맥을 가리킨다 (%d)" % [dir, same])
		_assert(solid == 16, "%s: 16칸 모두 막힌다 (%d)" % [dir, solid])
		var outside := 0
		for cell: Vector2i in Grid.edge_cells(rect.grow(1)):
			if sim.machine_at(cell) != null:
				outside += 1
		_assert(outside == 0, "%s: 벽 바로 바깥에는 아무것도 없다" % dir)
		# The output is past the front wall, in the seam's line.
		var out: Vector2i = sim.output_cell(post)
		_assert(not rect.has_point(out), "%s: 출구는 발자국 바깥이다 %s" % [dir, out])
		var lane: int = (out - seam).x if dir.y == 0 else (out - seam).y
		_assert((out - seam) * Vector2i(absi(dir.y), absi(dir.x)) == Vector2i.ZERO,
			"%s: 출구는 광맥과 같은 줄에 있다" % dir)
		_assert(signi(lane) == signi(dir.x + dir.y), "%s: 그리고 앞쪽이다" % dir)
		# The seam stays a seam under the post: the post is on it, not instead of it.
		_assert(sim.ore.has(seam), "%s: 광맥은 채굴기 밑에 그대로 있다" % dir)
		sim.free()

func _test_taken_down_from_any_cell() -> void:
	var sim := _sim()
	var seam: Vector2i = sim.core_cell + SITE
	_ground(sim, seam)
	sim.build(Defs.M_MINER, seam, Vector2i.RIGHT)
	var rect: Rect2i = sim.machine_rect(sim.machine_at(seam))
	var corner: Vector2i = rect.end - Vector2i.ONE
	_assert(corner != seam, "모서리 칸은 앵커가 아니다")
	_assert(sim.demolish(corner), "모서리 칸을 보고 회수해도")
	var left := 0
	for cell: Vector2i in Grid.cells_in(rect):
		if sim.machine_at(cell) != null:
			left += 1
	_assert(left == 0, "채굴기 전체가 사라진다 (%d칸 남음)" % left)
	_assert(sim.ore.has(seam), "광맥은 남는다")
	_assert(sim.can_build(Defs.M_MINER, seam) == "", "같은 자리에 다시 지을 수 있다")
	sim.free()

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	sim.unlocked[Defs.M_MINER] = true
	sim.unlocked[Defs.M_MINER_MK2] = true
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
	return sim

## One seam on bare ground: nothing the world generated within a few tiles.
func _ground(sim: Sim, seam: Vector2i) -> void:
	var area := Rect2i(seam - Vector2i(6, 6), Vector2i(13, 13))
	for cell: Vector2i in Grid.cells_in(area):
		sim.ore.erase(cell)
		sim.ground.erase(cell)
		sim.drops.erase(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(area):
				props.erase(origin)
	sim.ore[seam] = Defs.ITEM_CRYSTAL
