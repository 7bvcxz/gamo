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
	print("SHEETS: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)
