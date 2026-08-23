extends SceneTree
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
	_assert(sim.village_rect.size == Vector2i(11, 11), "11 x 11")

	var frozen := 0
	for cell: Vector2i in sim.frozen_cats:
		if sim.in_village(cell):
			frozen += 1
	_assert(frozen == 7, "얼어붙은 고양이 7마리 (%d)" % frozen)

	# The two distances the sign is quoting. Northwest at about twenty, then due
	# north from there -- the arrow on the board is only honest if the village is
	# straight up the trail from it.
	var to_sign: float = Vector2(sim.sign_cell - sim.core_cell).length()
	_assert(to_sign > 18.0 and to_sign < 22.0, "표지판은 기지에서 20칸쯤 (%.1f)" % to_sign)
	_assert(sim.sign_cell.x < sim.core_cell.x and sim.sign_cell.y < sim.core_cell.y,
		"그리고 북서쪽이다")
	var centre: Vector2i = sim.village_rect.position + Vector2i(5, 5)
	_assert(centre.x == sim.sign_cell.x, "마을은 표지판 바로 북쪽에 있다 (↑)")
	var walk: int = sim.sign_cell.y - centre.y
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
		sim.setup(seed_value)
		for y in Defs.VILLAGE_CELLS.y:
			for x in Defs.VILLAGE_CELLS.x:
				var cell: Vector2i = sim.village_rect.position + Vector2i(x, y)
				var junk: String = ""
				if sim.ore.has(cell):
					junk = "광맥"
				elif sim.has_rock(cell):
					junk = "바위"
				elif sim.debris.has(cell):
					junk = "잔해"
				elif sim.frozen_cats.has(cell) and not sim.village.has(cell) \
					and not _is_village_ice(sim, cell):
					junk = "떠도는 얼음"
				if junk != "":
					dirty += 1
					worst = "seed %d · %s · %s" % [seed_value, str(cell), junk]
	_assert(dirty == 0, "200개 시드에서 마을 안이 비어 있다 (%d칸, 예: %s)" % [dirty, worst])
	sim.free()

func _is_village_ice(sim, cell: Vector2i) -> bool:
	for local: Vector2i in Defs.VILLAGE_FROZEN:
		if sim.village_rect.position + local == cell:
			return true
	return false

## A path, not a scatter of dots: every row between the board and the gate has a
## mark on it, each mark touches the one before, and nothing is standing on any
## of them.
func _test_trail() -> void:
	var sim = _sim()
	var gate := Vector2i(9999, 9999)
	for cell: Vector2i in sim.village:
		if int(sim.village[cell]) == Defs.VILLAGE_GATE:
			gate = cell
	_assert(gate != Vector2i(9999, 9999), "입구가 있다")
	_assert(sim.blocks_player(sim.sign_cell), "표지판은 통과할 수 없다")
	var rows := {}
	for cell: Vector2i in sim.trail:
		_assert(not rows.has(cell.y), "한 줄에 자국 하나: %d" % cell.y)
		rows[cell.y] = cell
		_assert(not sim.has_rock(cell) and not sim.ore.has(cell)
			and not sim.debris.has(cell), "자국 위에는 아무것도 없다: %s" % str(cell))
	for y in range(gate.y, sim.sign_cell.y):
		_assert(rows.has(y), "표지판과 입구 사이가 끊기지 않는다: %d" % y)
	var previous: Vector2i = sim.sign_cell
	for y in range(sim.sign_cell.y - 1, gate.y - 1, -1):
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
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim = main.sim
	main.player.position = sim.cell_centre(sim.sign_cell + Vector2i(0, 1))
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
	main.player.position = sim.cell_centre(sim.sign_cell + Vector2i(0, 3))
	main._update_sign_label(1.0 / 60.0)
	_assert(main.sign_label < 1.0 and main.sign_label > 0.5,
		"멀어지면 한 프레임에 사라지지 않고 (%.2f)" % main.sign_label)
	for step in 60:
		main._update_sign_label(1.0 / 60.0)
	_assert(is_zero_approx(main.sign_label), "이내 사라진다 (%.2f)" % main.sign_label)
	# Standing at it again does not bring it back on its own: the board is read,
	# not overheard.
	main.player.position = sim.cell_centre(sim.sign_cell + Vector2i(0, 1))
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
	var behind: Vector2i = sim.sign_cell + Vector2i(0, 2)
	sim.ore.erase(behind)
	sim.mined_rocks[behind] = true
	sim.frozen_cats.erase(behind)
	sim.debris.erase(behind)
	sim.shards.erase(behind)
	sim.ground.erase(behind)
	sim.drops.erase(behind)
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

