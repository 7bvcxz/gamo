extends SceneTree

## 냥마을 is a hidden route as of 2026-09-01: `story_enabled` is off on the main
## path and this file flips it on, because what it guards is the village itself
## -- that when the route exists, everything in it is where the sign says.
## 냥마을, the signpost, and the tracks between them.
##
## Three kinds of claim, and only the first is about arithmetic. The second is
## that the square is *empty* of everything the generator scattered before anyone
## decided it was a village -- and that one is checked across two hundred seeds,
## because a seeded world bug is invisible in one run and the shelter doorstep
## has already taught this repository that lesson once. The third is that the
## trail is a path: an unbroken line from the board to the gate, with nothing
## standing on it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_layout()
	_test_solid()
	_test_clear_across_seeds()
	_test_trail()
	await _test_reading()
	if failures == 0:
		print("VILLAGE: PASS")
	quit(failures)

func _sim() -> Node:
	var sim = load("res://scripts/Sim.gd").new()
	sim.story_enabled = true
	sim.setup(4242)
	return sim

## What is in it, and where it is. The counts are the design read back: four
## houses, one well, one fire, one way in, seven cats in the ice.
func _test_layout() -> void:
	var sim = _sim()
	var counts := {}
	for cell: Vector2i in sim.village:
		var piece: int = int(sim.village[cell])
		counts[piece] = int(counts.get(piece, 0)) + 1
		_assert(sim.in_village(cell), "모든 구성품이 마을 안에 있다: %s" % str(cell))
	_assert(int(counts.get(Defs.VILLAGE_HOUSE, 0)) == 4, "집 4채")
	_assert(int(counts.get(Defs.VILLAGE_WELL, 0)) == 1, "우물 1개")
	_assert(int(counts.get(Defs.VILLAGE_FIRE, 0)) == 1, "화롯불 1개")
	_assert(int(counts.get(Defs.VILLAGE_GATE, 0)) == 1, "입구 1개")
	# Eleven tiles by eleven, laid out a tile at a time (Grid v2: each is a block
	# of build cells, and everything here is a tile across).
	_assert(sim.village_rect.size == Vector2i(11, 11) * Grid.SCALE, "11 x 11")

	var frozen := 0
	for cell: Vector2i in sim.frozen_cats:
		if sim.in_village(cell):
			frozen += 1
	_assert(frozen == 7, "얼어붙은 고양이 7마리 (%d)" % frozen)

	# The two distances the sign is quoting. Northwest at about twenty, then due
	# north from there -- the arrow on the board is only honest if the village is
	# straight up the trail from it.
	var to_sign: float = sim.prop_tiles_from_core(sim.sign_cell)
	_assert(to_sign > 18.0 and to_sign < 22.0, "표지판은 기지에서 20칸쯤 (%.1f)" % to_sign)
	_assert(sim.sign_cell.x < sim.core_cell.x and sim.sign_cell.y < sim.core_cell.y,
		"그리고 북서쪽이다")
	var centre: Vector2i = Grid.tile_of(sim.village_rect.position) + Vector2i(5, 5)
	var sign: Vector2i = Grid.tile_of(sim.sign_cell)
	_assert(centre.x == sign.x, "마을은 표지판 바로 북쪽에 있다 (↑)")
	var walk: int = sign.y - centre.y
	_assert(walk > 25 and walk < 29, "그리고 27칸쯤 떨어져 있다 (%d)" % walk)
	sim.free()

## Houses are buildings. The gate is not -- an entrance you cannot walk through
## is a wall with a picture of a gate on it.
func _test_solid() -> void:
	var sim = _sim()
	for cell: Vector2i in sim.village:
		var piece: int = int(sim.village[cell])
		var blocked: bool = sim.blocks_player(cell)
		if piece == Defs.VILLAGE_GATE:
			_assert(not blocked, "입구는 지나갈 수 있다")
		else:
			_assert(blocked, "%s 은(는) 막힌다" % str(cell))
	sim.free()

## Two hundred worlds, because one world is not evidence about a world that is
## generated differently every run. A seam under a house, a boulder in the
## square or a piece of the ship in the well is a village nobody can walk into.
func _test_clear_across_seeds() -> void:
	var sim = load("res://scripts/Sim.gd").new()
	var dirty := 0
	var worst := ""
	for seed_value in range(1, 201):
		sim.story_enabled = true
		sim.setup(seed_value)
		# Every build cell of the square (Grid v2).
		for cell: Vector2i in Grid.cells_in(sim.village_rect):
			var junk: String = ""
			var ice: Vector2i = sim.frozen_key(cell)
			if sim.ore.has(cell):
				junk = "광맥"
			elif sim.has_rock(cell):
				junk = "바위"
			elif sim.debris_key(cell) != Sim.NONE:
				junk = "잔해"
			elif ice != Sim.NONE and not sim.village.has(ice) and not _is_village_ice(sim, ice):
				junk = "떠도는 얼음"
			if junk != "":
				dirty += 1
				worst = "seed %d · %s · %s" % [seed_value, str(cell), junk]
	_assert(dirty == 0, "200개 시드에서 마을 안이 비어 있다 (%d칸, 예: %s)" % [dirty, worst])
	sim.free()

func _is_village_ice(sim, cell: Vector2i) -> bool:
	for local: Vector2i in Defs.VILLAGE_FROZEN:
		if sim.village_rect.position + local * Grid.SCALE == cell:
			return true
	return false

## A path, not a scatter of dots: every row between the board and the gate has a
## mark on it, each mark touches the one before, and nothing is standing on any
## of them.
func _test_trail() -> void:
	var sim = _sim()
	# Walked a tile at a time, like everything the village is laid out in: every
	# row of tiles between the board and the gate has a mark (Grid v2).
	var gate := Vector2i(9999, 9999)
	for cell: Vector2i in sim.village:
		if int(sim.village[cell]) == Defs.VILLAGE_GATE:
			gate = Grid.tile_of(cell)
	_assert(gate != Vector2i(9999, 9999), "입구가 있다")
	_assert(sim.blocks_player(sim.sign_cell), "표지판은 통과할 수 없다")
	var sign: Vector2i = Grid.tile_of(sim.sign_cell)
	var rows := {}
	for cell: Vector2i in sim.trail:
		var tile: Vector2i = Grid.tile_of(cell)
		_assert(not rows.has(tile.y), "한 줄에 자국 하나: %d" % tile.y)
		rows[tile.y] = tile
		for covered: Vector2i in Grid.cells_in(Grid.tile_rect(tile)):
			_assert(not sim.has_rock(covered) and not sim.ore.has(covered)
				and sim.debris_key(covered) == Sim.NONE,
				"자국 위에는 아무것도 없다: %s" % str(covered))
	for y in range(gate.y, sign.y):
		_assert(rows.has(y), "표지판과 입구 사이가 끊기지 않는다: %d" % y)
	var previous: Vector2i = sign
	for y in range(sign.y - 1, gate.y - 1, -1):
		var here: Vector2i = rows[y]
		_assert(absi(here.x - previous.x) <= 1, "자국은 한 칸씩 이어진다: %s" % str(here))
		previous = here
	sim.free()

## Reading it. Z at the board says the line and nothing else -- and it is the
## board she has to be looking at, not one she is standing near.
func _test_reading() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	main.clear_save()
	main._start_run()
	# This scene is on the hidden route: the sign has to exist to be read.
	main.sim.story_enabled = true
	main.sim._generate_village()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim = main.sim
	# A tile below the board, which is a tile across (Grid v2).
	var below: Vector2 = sim.prop_centre(sim.sign_cell) + Vector2(0.0, float(Grid.TILE))
	# Nothing else between her and the board. The world is a random seed, and in
	# about one in forty a seam, a wreck or a frozen cat lies just under the sign
	# -- nearer than the board, so Z is about that instead and this fails on the
	# world rather than on reading (found scanning 600 seeds, 2026-09-27).
	for covered: Vector2i in Grid.cells_in(Rect2i(sim.sign_cell + Vector2i(-1, 2), Vector2i(4, 4))):
		sim.ore.erase(covered)
		sim.ground.erase(covered)
		for props: Dictionary in [sim.frozen_cats, sim.debris]:
			var key: Vector2i = Sim.prop_key(props, covered)
			if key != Sim.NONE:
				props.erase(key)
	main.player.position = below
	main.player.facing = Vector2i(0, -1)
	_assert(main.active_prompt() == "SIGN", "표지판을 보면 읽으라고 한다")
	var before: int = main.play_log.size()
	main._primary_action()
	_assert(main.play_log.size() == before + 1, "Z 한 번에 한 줄")
	_assert(String(main.play_log[0]["text"]) == Defs.SIGN_LINE,
		"그 줄은 '%s' 이다: %s" % [Defs.SIGN_LINE, String(main.play_log[0]["text"])])
	_assert(main.active_prompt() != "SIGN", "한 번 읽으면 안내는 사라진다")
	# The line stays up while she is at the board. It used to be a popup, which
	# rises and fades in about a second -- long enough to notice and not long
	# enough to read, on the one piece of directions this game gives.
	for step in 60:
		main._update_sign_label(1.0 / 60.0)
	_assert(is_equal_approx(main.sign_label, 1.0),
		"문구가 표지판 위에 그대로 있다 (%.2f)" % main.sign_label)
	# And a step away puts it out -- smoothly, not in one frame.
	main.player.position = sim.prop_centre(sim.sign_cell) + Vector2(0.0, Grid.px(3.0))
	main._update_sign_label(1.0 / 60.0)
	_assert(main.sign_label < 1.0 and main.sign_label > 0.5,
		"멀어지면 한 프레임에 사라지지 않고 (%.2f)" % main.sign_label)
	for step in 60:
		main._update_sign_label(1.0 / 60.0)
	_assert(is_zero_approx(main.sign_label), "이내 사라진다 (%.2f)" % main.sign_label)
	# Standing at it again does not bring it back on its own: the board is read,
	# not overheard.
	main.player.position = below
	for step in 60:
		main._update_sign_label(1.0 / 60.0)
	_assert(is_zero_approx(main.sign_label), "돌아와도 저절로 다시 뜨지는 않는다")
	# Facing away from it. The board is a thing in a cell, like everything else
	# Z touches, and standing beside one is not reading it.
	#
	# The cell behind her is emptied first. The world is seeded differently every
	# run and Z at a boulder out past the fire says "땅과 얼어붙었다" -- which is
	# correct behaviour and a log line, so this assertion failed about one run in
	# five for a reason that had nothing to do with signposts.
	# Everything that answers "there is something out there frozen into the
	# ground", not the four that were remembered the first time this flaked. It
	# still failed about one run in six, on a crystal lying in the snow -- so the
	# emptied cell is checked against the predicate itself rather than against a
	# list of sources somebody has to keep in step with it.
	# The tile behind her, every cell of it (Grid v2: she reaches a tile deep).
	var behind_tile: Vector2i = Grid.tile_of(sim.sign_cell) + Vector2i(0, 2)
	var behind: Vector2i = Grid.from_tile(behind_tile)
	sim.mined_rocks[behind_tile] = true
	for covered: Vector2i in Grid.cells_in(Grid.tile_rect(behind_tile).grow(1)):
		sim.ore.erase(covered)
		sim.shards.erase(covered)
		sim.ground.erase(covered)
		sim.drops.erase(covered)
		for props: Dictionary in [sim.frozen_cats, sim.debris]:
			var key: Vector2i = Sim.prop_key(props, covered)
			if key != Sim.NONE:
				props.erase(key)
	_assert(not main._frozen_out_there(behind), "뒤쪽 칸에는 아무것도 없고")
	main.player.facing = Vector2i(0, 1)
	var after: int = main.play_log.size()
	main._primary_action()
	_assert(main.play_log.size() == after, "등을 돌리면 읽히지 않는다: %s"
		% (String(main.play_log[0]["text"]) if not main.play_log.is_empty() else ""))
	main.clear_save()
	main.free()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("  FAIL ", message)
		failures += 1

