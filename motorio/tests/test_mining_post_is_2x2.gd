extends SceneTree

## A mining post is two cells by two, exactly the node it stands on (World
## Visual Pass 01). It was four by four round a one-cell seam.
##
## Its size comes from the machine table, never from the placement code: the
## same `Defs.machine_footprint` answers for building it, drawing it, pathing
## round it and taking it down. Every direction covers the same four cells --
## turning a post changes where its output goes and nothing else -- its output
## leaves past its front edge in the anchor's line, it is solid to her, it comes
## down from any of its cells, and its picture stays on its cells.

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
		print("PASS test_mining_post_is_2x2")
	else:
		print("FAIL test_mining_post_is_2x2 (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_size_is_data() -> void:
	for type: int in Defs.MINER_MACHINES:
		var name: String = Defs.MACHINE_NAMES[type]
		_assert(Defs.machine_size(type) == Defs.ORE_NODE_SIZE, "%s 는 표에 노드 크기(2×2)로 적혀 있다" % name)
		_assert(Defs.machine_anchor(type) == Grid.AUTO, "%s 는 기본 앵커 규칙을 쓴다 (왼쪽 위)" % name)
		for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			_assert(Defs.machine_footprint(type, Vector2i(10, 10), dir) == Sim.ore_rect(Vector2i(10, 10)),
				"%s %s: 발자국은 앵커를 원점으로 한 노드와 같다" % [name, dir])

## What the post draws covers no more than what it blocks. Posts on neighbouring
## nodes stand a two-cell lane apart, and a picture that hangs over its own cells
## closes that lane to the eye.
##
## Measured on the picture's opaque pixels, read from the source file rather than
## the imported texture (the headless renderer has no image to give back).
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
	var opaque := Rect2(Vector2.ONE * -drawn * 0.5 + Vector2(used.position) * per_pixel,
		Vector2(used.size) * per_pixel)
	var cells := Rect2(-footprint * 0.5, footprint)
	_assert(cells.grow(0.01).encloses(opaque),
		"채굴기 그림이 2×2 발자국 안에 그려진다 (그림 %.1f..%.1f × %.1f..%.1f, 발자국 ±%.0f)"
			% [opaque.position.x, opaque.end.x, opaque.position.y, opaque.end.y, footprint.x * 0.5])
	# And it fills it: a post drawn as a speck in the middle of its cells is a
	# post nobody can find. Its long side most of the way across, its short side
	# well over half (the rig is taller than it is wide).
	var larger: float = maxf(opaque.size.x, opaque.size.y) / footprint.x
	var smaller: float = minf(opaque.size.x, opaque.size.y) / footprint.x
	_assert(larger >= 0.88 and smaller >= 0.65, "그리고 발자국을 채운다 (%.0f%% × %.0f%%)"
		% [larger * 100.0, smaller * 100.0])

func _test_every_direction() -> void:
	var headings: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for type: int in Defs.MINER_MACHINES:
		for index in headings.size():
			var dir: Vector2i = headings[index]
			var sim := _sim()
			var node: Vector2i = sim.core_cell + SITE + Vector2i(0, index * 10)
			_ground(sim, node)
			var label: String = "%s %s" % [Defs.MACHINE_NAMES[type], dir]
			_assert(sim.can_build(type, node, dir) == "", "%s: 지을 수 있다" % label)
			_assert(sim.build(type, node, dir), "%s: 지어진다" % label)
			var post: Sim.Machine = sim.machine_at(node)
			var rect: Rect2i = sim.machine_rect(post)
			_assert(rect == Sim.ore_rect(node), "%s: 발자국이 노드와 정확히 같다 %s" % [label, rect])
			_assert(Grid.rect_px(rect).size == Vector2(32.0, 32.0), "%s: 월드에서 32px (한 타일)" % label)
			var same := 0
			var solid := 0
			for cell: Vector2i in Grid.cells_in(rect):
				if sim.machine_at(cell) == post and sim.post_anchor(cell) == node:
					same += 1
				if sim.blocks_player(cell):
					solid += 1
			_assert(same == 4, "%s: 네 칸 모두 같은 채굴기이고 같은 노드를 가리킨다 (%d)" % [label, same])
			_assert(solid == 4, "%s: 네 칸 모두 막힌다 (%d)" % [label, solid])
			var out: Vector2i = sim.output_cell(post)
			_assert(not rect.has_point(out), "%s: 출구는 발자국 바깥이다 %s" % [label, out])
			_assert(rect.grow(1).has_point(out), "%s: 그리고 벽 바로 바깥이다" % label)
			_assert((out - node) * Vector2i(absi(dir.y), absi(dir.x)) == Vector2i.ZERO,
				"%s: 출구는 앵커와 같은 줄에 있다" % label)
			var lane: int = (out - node).x if dir.y == 0 else (out - node).y
			_assert(signi(lane) == signi(dir.x + dir.y), "%s: 그리고 앞쪽이다" % label)
			_assert(sim.ore_nodes.has(node), "%s: 노드는 채굴기 밑에 그대로 있다" % label)
			sim.free()

func _test_taken_down_from_any_cell() -> void:
	var sim := _sim()
	var node: Vector2i = sim.core_cell + SITE
	_ground(sim, node)
	sim.build(Defs.M_MINER, node, Vector2i.RIGHT)
	var rect: Rect2i = sim.machine_rect(sim.machine_at(node))
	var corner: Vector2i = rect.end - Vector2i.ONE
	_assert(corner != node, "모서리 칸은 앵커가 아니다")
	_assert(sim.demolish(corner), "모서리 칸을 보고 회수해도")
	var left := 0
	for cell: Vector2i in Grid.cells_in(rect):
		if sim.machine_at(cell) != null:
			left += 1
	_assert(left == 0, "채굴기 전체가 사라진다 (%d칸 남음)" % left)
	_assert(sim.ore_nodes.has(node), "노드는 남는다")
	_assert(sim.can_build(Defs.M_MINER, node) == "", "같은 자리에 다시 지을 수 있다")
	sim.free()

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	for type: int in Defs.MINER_MACHINES:
		sim.unlocked[type] = true
	for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON,
			Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE, Defs.ITEM_ELECTRIC_MOTOR]:
		sim.stock[item] = 500
	return sim

## One node on bare ground: nothing the world generated within a few tiles.
func _ground(sim: Sim, node: Vector2i) -> void:
	var area := Rect2i(node - Vector2i(6, 6), Vector2i(13, 13))
	for cell: Vector2i in Grid.cells_in(area):
		sim.erase_ore_at(cell)
		sim.ground.erase(cell)
		sim.drops.erase(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(area):
				props.erase(origin)
	sim.put_ore(node, Defs.ITEM_HEATSTONE)
