extends SceneTree

## The core and the hut are one tile each.
##
## They always were, in the only place it decides anything: the core is one
## machine blocking one cell and `is_structure` blocks exactly the cell the hut
## stands on. The pictures were 2.7 and 2.2 tiles across -- three times the size
## of the thing they stood for -- so they hung over the tiles their neighbours
## are built on and over the mouth a belt feeds.

const MachineLayerScript := preload("res://scripts/MachineLayer.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_one_tile()
	_test_the_sim_agrees()
	_test_shelter_no_go()
	if failures == 0:
		print("BUILDINGS: PASS")
	else:
		print("BUILDINGS: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_one_tile() -> void:
	var tile := float(Grid.TILE)
	_assert(is_equal_approx(MachineLayerScript.CORE_DRAW, tile),
		"기지가 한 칸이다: %.0f / %.0f" % [MachineLayerScript.CORE_DRAW, tile])
	_assert(is_equal_approx(MachineLayerScript.SHELTER_DRAW, tile),
		"숙소가 한 칸이다: %.0f / %.0f" % [MachineLayerScript.SHELTER_DRAW, tile])
	# Both are drawn from real art rather than from shapes, and at twice the drawn
	# size so zooming in stays soft rather than blocky.
	for art: Texture2D in [MachineLayerScript.CORE_ART, MachineLayerScript.SHELTER_ART]:
		_assert(art != null and art.get_width() >= int(tile) * 2,
			"그림이 그리는 크기의 두 배 이상이다: %d" % art.get_width())

func _test_the_sim_agrees() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.carried_kit = Defs.KIT_BASE
	sim.place_base(sim.core_cell)
	sim.shelter_placed = true
	# Every cell of each footprint is solid, and the cell just past each wall is
	# walkable. Grid v2 made the base eight cells by eight and the hut six by
	# eight; what has not changed is that the solid part is exactly the building
	# -- a player who walks around the picture must be walking around something.
	for cell: Vector2i in Grid.cells_in(sim.base_rect()):
		if not sim.blocks_player(cell):
			_assert(false, "기지 칸 %s 은 막힌다" % str(cell))
	_assert(sim.blocks_player(sim.core_cell), "기지 칸은 막힌다")
	for cell: Vector2i in Grid.cells_in(sim.shelter_rect()):
		if not sim.blocks_player(cell):
			_assert(false, "숙소 칸 %s 은 막힌다" % str(cell))
	_assert(sim.blocks_player(sim.shelter_cell), "숙소 칸도 막힌다")
	var base: Rect2i = sim.base_rect()
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var beside: Vector2i = Grid.front_cell(base, step, sim.core_cell)
		if sim.machine_at(beside) != null or sim.ore.has(beside):
			continue
		_assert(not sim.blocks_player(beside),
			"기지 옆 %s 칸은 지나갈 수 있다" % str(step))
	sim.free()

## The red patch round the fire, while the hut is in her arms.
##
## The world layer paints it and `place_shelter` enforces it, and the two read
## the same predicate on purpose -- a rule drawn from one place and refused from
## another is a rule that drifts, and the drawn version is the one the player
## believes.
func _test_shelter_no_go() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	var mismatches := 0
	var painted := 0
	var gap: int = Grid.SCALE * int(Defs.SHELTER_CLEARANCE - 1.0)
	var band: Rect2i = sim.base_rect().grow(gap)
	# Anchors all round the base, near and far (Grid v2: the hut's anchor, and a
	# footprint six by eight around it).
	for dy in range(-12, 13, 2):
		for dx in range(-12, 13, 2):
			var cell: Vector2i = sim.core_cell + Vector2i(dx, dy)
			var blocked: bool = sim.shelter_too_close(cell)
			if blocked:
				painted += 1
			# The rule is the footprint against the band, nothing else.
			if blocked != Grid.footprint(cell, Defs.SHELTER_SIZE).intersects(band):
				mismatches += 1
			# What the rule says, tested through the door the player uses.
			sim.shelter_placed = false
			sim.carried_kit = Defs.KIT_SHELTER
			var placed: bool = sim.place_shelter(cell)
			if placed and blocked:
				mismatches += 1
			if placed:
				sim.shelter_placed = false
	_assert(mismatches == 0, "붉게 칠한 칸에는 실제로 놓을 수 없다 (%d건)" % mismatches)
	_assert(painted > 0, "기지 둘레가 칠해진다 (%d칸)" % painted)
	# A hut whose west wall stands SHELTER_CLEARANCE tiles past the base's east
	# wall -- one tile of bare ground between them -- is not too close.
	var clear_x: int = sim.base_rect().end.x + gap
	var anchor: Vector2i = Vector2i(clear_x, sim.core_cell.y) + Grid.default_anchor(Defs.SHELTER_SIZE)
	_assert(not sim.shelter_too_close(anchor), "한 타일 띄우면 칠하지 않는다")
	_assert(sim.shelter_too_close(anchor - Vector2i(1, 0)), "한 칸만 더 붙어도 칠한다")
	sim.free()
