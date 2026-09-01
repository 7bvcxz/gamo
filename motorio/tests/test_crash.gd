extends SceneTree

## The first minute is a race against the cold now, so it has to be a race a
## player can win.
##
## Three numbers decide that and they live in three different places: how warm
## she wakes (40), how fast it drains (3 a second) and how long the errand takes
## -- walk to the case, hold Z, pick the fire up, put it down. Written down
## separately they can drift apart without anything failing, and the failure when
## it comes is "the opening is impossible", which is not a bug report anyone can
## act on.
##
## So this plays it. Optimal play, at the speed the cold actually leaves her.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_the_opening_is_winnable()
	await _test_freezing_ends_the_run()
	if failures == 0:
		print("CRASH: PASS")
	else:
		print("CRASH: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _main(seed_value: int) -> Node2D:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	# A named world rather than whatever `randi` handed out. The walk below is a
	# straight line and she has a body, so on some maps a boulder stands between
	# her and the case -- which makes the harness fail in the same way an
	# unwinnable opening would. Fixed seeds, several of them, and the answer is
	# the worst of them.
	main.run_seed = seed_value
	main.sim.setup(seed_value)
	main.sim.begin_crash()
	main.player.position = main.sim.cell_centre(main.sim.core_cell)
	main.player.warmth = Defs.CRASH_WARMTH
	main.player.velocity = Vector2.ZERO
	main.state = main.State.PLAY
	return main

## Walk toward a point, a frame at a time, until she is on it or the clock runs
## out. Returns the seconds spent. Movement goes through `touch_direction`
## because that is the one input path a test can hold down.
func _walk_to(main: Node2D, target: Vector2, limit: float) -> float:
	var spent := 0.0
	var step: float = 1.0 / 60.0
	var was: Vector2 = main.player.position
	var stuck := 0.0
	var detour := Vector2.ZERO
	var detour_left := 0.0
	var side := 1.0
	while spent < limit and main.player.position.distance_to(target) > 10.0:
		var want: Vector2 = (target - main.player.position).normalized()
		if detour_left > 0.0:
			want = detour
			detour_left -= step
		main.player.touch_direction = want
		main.player.touch_sprint = true
		_tick(main, step)
		spent += step
		# Something solid is in the way and pressing into it moves her nowhere.
		# A player steps round it; a straight line does not, and a harness that
		# cannot get past one box reports the box as an unwinnable opening. The
		# case itself became solid in 1.0.26 and stands between her and what
		# tipped out of it, so this is now the ordinary path rather than the
		# unlucky one.
		if main.player.position.distance_to(was) < 0.2 and detour_left <= 0.0:
			stuck += step
			if stuck > 0.12:
				detour = Vector2(-want.y, want.x) * side
				detour_left = 0.32
				side = -side
				stuck = 0.0
		else:
			stuck = 0.0
		was = main.player.position
	main.player.touch_direction = Vector2.ZERO
	main.player.touch_sprint = false
	return spent

## Walking is in `_physics_process` and everything else is in `_process`, and a
## node ticked by hand gets neither for free. Both, from one place, so a loop
## cannot quietly drive half the game -- which is what "she never reached the
## case in thirteen seconds" turned out to mean the first time this ran.
func _tick(main: Node2D, step: float) -> void:
	main.player._physics_process(step)
	main._process(step)

func _hold(main: Node2D, seconds: float) -> void:
	var spent := 0.0
	var step: float = 1.0 / 60.0
	while spent < seconds:
		main.mine_held = true
		_tick(main, step)
		spent += step
	main.mine_held = false

func _test_the_opening_is_winnable() -> void:
	var budget: float = Defs.CRASH_WARMTH / Defs.CRASH_DRAIN
	var worst := 0.0
	var coldest := 100.0
	var lost := 0
	for index in 5:
		var main: Node2D = await _main(4200 + index * 17)
		var sim = main.sim
		var spent := 0.0
		# To the case. She wakes at 40% and the cold slows her the whole way
		# down, so this is not the distance divided by her top speed.
		spent += _walk_to(main, sim.cell_centre(sim.kit_cell + Vector2i(0, 1)), budget)
		# Open it. A hold, and the hold is the whole errand now: the moment the
		# search ends the case unfolds into the base on the crash anchor. No
		# walking over drops, no choosing a spot, no second search.
		_hold(main, Defs.KIT_SEARCH_SECONDS + 0.3)
		spent += Defs.KIT_SEARCH_SECONDS + 0.3
		if not sim.base_placed or main.state != main.State.PLAY:
			lost += 1
		worst = maxf(worst, spent)
		coldest = minf(coldest, main.player.warmth)
		main.clear_save()
		main.free()
	_assert(lost == 0, "다섯 회차 모두 불을 피운다 (실패 %d)" % lost)
	# Margin, not a photo finish. The opening has to survive a player who reads
	# the two lines on screen before moving, and a run that only just makes it is
	# a run a slower reader loses.
	_assert(worst < budget * 0.65,
		"가장 느린 회차도 여유가 있다: %.1f초 / %.1f초" % [worst, budget])
	print("CRASH: 최적 플레이 최악 %.1f초 · 예산 %.1f초 · 남은 체온 %.0f%%"
		% [worst, budget, coldest])

func _test_freezing_ends_the_run() -> void:
	var main: Node2D = await _main(4242)
	# Standing still in the snow. It used to wake her up again at the crash site
	# with her forty degrees back, so the opening's one danger could be waited out.
	main.player.warmth = 4.0
	var waited := 0.0
	while main.state != main.State.GAMEOVER and waited < 5.0:
		_tick(main, 1.0 / 60.0)
		waited += 1.0 / 60.0
	_assert(main.state == main.State.GAMEOVER, "체온이 0이 되면 게임이 끝난다")
	_assert(main.player.locked, "그리고 움직일 수 없다")
	# Five seconds from the frame the card appears, and then the title. Timed
	# from there rather than from the start of the test, or the warmth that had
	# to run out first is counted as part of the wait.
	var spent := 0.0
	while main.state == main.State.GAMEOVER and spent < Defs.GAMEOVER_SECONDS * 2.0:
		_tick(main, 1.0 / 60.0)
		spent += 1.0 / 60.0
	_assert(main.state == main.State.TITLE, "%.1f초 뒤 메인화면으로 간다" % spent)
	_assert(absf(spent - Defs.GAMEOVER_SECONDS) < 0.5,
		"기다리는 시간은 %.0f초다 (%.1f초)" % [Defs.GAMEOVER_SECONDS, spent])
	# And the run it ended is not sitting behind 이어하기 a moment later.
	_assert(not main.resumed, "끝난 회차가 이어하기에 남지 않는다")
	main.free()
