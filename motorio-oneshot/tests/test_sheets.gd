extends SceneTree
## Which sheet each combination of direction and speed actually reaches. The
## selection is four branches and a screenshot cannot tell two of them apart.
func _init() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	var actor: PlayerActor = main.player
	var cases := [
		[Vector2(0, 1), false, PlayerActor.WALK_SHEET, "아래로 걷기 -> 정면 걷기"],
		[Vector2(0, 1), true, PlayerActor.RUN_SHEET, "아래로 달리기 -> 정면 달리기"],
		[Vector2(1, 0), false, PlayerActor.WALK_E_SHEET, "옆으로 걷기 -> 측면 걷기"],
		[Vector2(1, 0), true, PlayerActor.RUN_E_SHEET, "옆으로 달리기 -> 측면 달리기"],
		[Vector2(-1, 0), true, PlayerActor.RUN_E_SHEET, "왼쪽 달리기 -> 측면 달리기(반전)"],
		[Vector2(0.7, 0.7), true, PlayerActor.RUN_E_SHEET, "대각 달리기 -> 측면 달리기"],
		[Vector2(0, -1), false, PlayerActor.WALK_N_SHEET, "위로 걷기 -> 뒷모습 걷기"],
		[Vector2(0, -1), true, PlayerActor.RUN_N_SHEET, "위로 달리기 -> 뒷모습 달리기"],
		[Vector2(0.3, -1), false, PlayerActor.WALK_N_SHEET, "위쪽 대각 걷기 -> 뒷모습"],
	]
	var failures := 0
	for case in cases:
		actor.set("_walk_input", case[0])
		actor._moving(case[1])
		if actor.character.texture != case[2]:
			print("  FAIL: ", case[3]); failures += 1
		else:
			print("  ok  : ", case[3])
	# Mining, which plays only while standing and reads its direction from
	# `facing` rather than from movement -- there is no movement to read.
	actor.set("_walk_input", Vector2.ZERO)
	actor.mining = 0.5
	for m in [[Vector2i.LEFT, PlayerActor.MINE_W_SHEET, "왼쪽 채굴 -> 측면 채굴"],
			  [Vector2i.RIGHT, PlayerActor.MINE_W_SHEET, "오른쪽 채굴 -> 측면 채굴(반전)"],
			  [Vector2i.UP, PlayerActor.MINE_N_SHEET, "위쪽 채굴 -> 뒷모습 채굴"],
			  [Vector2i.DOWN, PlayerActor.MINE_SHEET, "아래쪽 채굴 -> 정면 채굴"]]:
		actor.facing = m[0]
		actor._mining()
		if actor.character.texture != m[1]:
			print("  FAIL: ", m[2]); failures += 1
		else:
			print("  ok  : ", m[2])

	# And standing still without a seam is idle, not a swing frozen mid-air.
	actor.mining = 0.0
	actor._idle()
	if actor.character.texture != PlayerActor.IDLE_SHEET:
		print("  FAIL:  채굴이 끝나면 대기로"); failures += 1
	else:
		print("  ok  :  채굴이 끝나면 대기로")

	# The cats. They only exist once boxes have been carried to the shelter, so a
	# running game shows none for a long time -- which is exactly why the choice
	# is a function rather than something buried in a draw call.
	for cat_case in [
		[Defs.CAT_HAUL_TO_ITEM, Vector2(-1, 0), MachineLayer.CAT_WALK_E_SHEET, true, "물건 주우러 -> 측면"],
		[Defs.CAT_HAUL_TO_BASE, Vector2(0, 1), MachineLayer.CAT_WALK_SHEET, false, "기지로 나르며 -> 정면"],
		[Defs.CAT_ASLEEP, Vector2(0, 1), MachineLayer.CAT_IDLE_SHEET, false, "자는 고양이 -> 서 있기"],
		[Defs.CAT_IDLE, Vector2(1, 0), MachineLayer.CAT_IDLE_SHEET, false, "쉬는 고양이 -> 서 있기"],
		[Defs.CAT_WORKING, Vector2(1, 0), MachineLayer.CAT_IDLE_SHEET, false, "일하는 고양이 -> 서 있기"],
		[Defs.CAT_TO_MINER, Vector2(1, 0), MachineLayer.CAT_WALK_E_SHEET, false, "오른쪽으로 -> 측면"],
		[Defs.CAT_TO_MINER, Vector2(-1, 0), MachineLayer.CAT_WALK_E_SHEET, true, "왼쪽으로 -> 측면(반전)"],
		[Defs.CAT_TO_FOOD, Vector2(0, -1), MachineLayer.CAT_WALK_N_SHEET, false, "위로 -> 뒷모습"],
		[Defs.CAT_TO_SHELTER, Vector2(0, 1), MachineLayer.CAT_WALK_SHEET, false, "아래로 -> 정면"],
		[Defs.CAT_TO_MINER, Vector2(0.7, 0.7), MachineLayer.CAT_WALK_E_SHEET, false, "대각 -> 측면"],
	]:
		var got: Array = MachineLayer.cat_sheet(int(cat_case[0]), cat_case[1])
		if got[0] != cat_case[2] or got[1] != cat_case[3]:
			print("  FAIL: ", cat_case[4]); failures += 1
		else:
			print("  ok  : ", cat_case[4])

	# The heading a walking cat is drawn with must be the direction it is really
	# travelling, in every travelling state. This used to be re-derived at draw
	# time from a list of states and their goals, and the list was short by two:
	# a hauling cat crossed the map facing front no matter which way it went.
	# Driving the real sim is the only way to catch that -- the draw call cannot
	# be wrong about a goal it never asks for.
	var sim: Sim = main.sim
	sim.setup(4242)
	var cat := Sim.Cat.new()
	cat.pos = sim.cell_centre(sim.core_cell) + Vector2(96.0, 0.0)
	sim.cats.append(cat)
	for travel in [
		[Vector2i(6, 0), "동쪽 목표 -> 오른쪽을 향함", Vector2(1, 0)],
		[Vector2i(-6, 0), "서쪽 목표 -> 왼쪽을 향함", Vector2(-1, 0)],
		[Vector2i(3, 8), "남쪽 목표 -> 아래를 향함", Vector2(0, 1)],
		[Vector2i(3, -8), "북쪽 목표 -> 위를 향함", Vector2(0, -1)],
	]:
		var goal: Vector2i = travel[0]
		sim.ground[goal] = 0
		cat.haul_target = goal
		cat.state = Defs.CAT_HAUL_TO_ITEM
		cat.assigned = Vector2i(9999, 9999)
		cat.pos = sim.cell_centre(goal) - Vector2(travel[2]) * 60.0
		sim._cat_fetch(cat, 0.05)
		var want: Vector2 = travel[2]
		if cat.heading.dot(want) < 0.9:
			print("  FAIL: ", travel[1], " heading=", cat.heading); failures += 1
		else:
			print("  ok  : ", travel[1])
		sim.ground.erase(goal)

	print("SHEETS: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)
