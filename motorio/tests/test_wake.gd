extends SceneTree

## Coming to in the snow (Quality Pass 01).
##
## The first frame of play used to be Grim standing, as if the crash had not
## happened, with every panel of the HUD already up. Now the run starts with her
## lying where she landed, and the player gets her only once she is standing.
## What is held here:
##
## * the story ends into the wake, not into control,
## * nothing moves her and nothing cools her while she comes to -- the crash
##   drain is the opening's clock, and a cutscene must not spend it,
## * the pose goes lying -> kneeling -> standing, in under four seconds,
## * the HUD is not there while she wakes and fades in after,
## * and a world started past the opening (every other test) is not waking.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_story_ends_into_the_wake()
	await _test_finish_tutorial_skips_it()
	_test_pose()
	if failures == 0:
		print("PASS test_wake")
	else:
		print("FAIL test_wake (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _main() -> Node2D:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	return main

func _test_story_ends_into_the_wake() -> void:
	var main: Node2D = await _main()
	main._start_new_run()
	main._end_cutscene()
	_assert(main.state == main.State.PLAY, "이야기가 끝나면 플레이 상태다")
	_assert(main.waking(), "그리고 그녀는 눈 위에서 깨어나는 중이다")
	_assert(main.player.collapse > 0.9, "첫 프레임의 그녀는 누워 있다 (%.2f)" % main.player.collapse)
	_assert(main.player.locked, "깨어나는 동안에는 조작이 없다")
	var start: Vector2 = main.player.position
	var warmth: float = main.player.warmth
	# The player leans on the stick the whole time.
	main.player.touch_direction = Vector2.RIGHT
	var dt := 1.0 / 60.0
	var kneeled := false
	var steps: int = 0
	while main.waking() and steps < 600:
		main._process(dt)
		main.player._physics_process(dt)
		if absf(main.player.collapse - Defs.WAKE_KNEEL_POSE) < 0.02:
			kneeled = true
		_assert_quiet_hud(main, steps)
		steps += 1
	var seconds: float = float(steps) * dt
	_assert(seconds >= 2.0 and seconds <= 4.0, "깨어나는 데 2~4초가 걸린다 (%.2f초)" % seconds)
	_assert(kneeled, "도중에 무릎을 꿇은 자세를 지난다")
	_assert(main.player.position.distance_to(start) < 0.5,
		"깨어나는 동안에는 밀어도 움직이지 않는다 (%.1f)" % main.player.position.distance_to(start))
	_assert(is_equal_approx(main.player.warmth, warmth),
		"깨어나는 동안에는 체온이 줄지 않는다 (%.1f -> %.1f)" % [warmth, main.player.warmth])
	_assert(not main.player.locked and main.player.collapse == 0.0, "일어서면 조작이 돌아온다")
	# The HUD comes up after, not with the first frame of control.
	_assert(main.hud_reveal < 0.2, "일어선 순간 HUD 는 아직 거의 없다 (%.2f)" % main.hud_reveal)
	for step in int((Defs.HUD_REVEAL_SECONDS + 0.2) / dt):
		main._process(dt)
		main.player._physics_process(dt)
	_assert(main.hud_reveal >= 1.0 and main.hud.modulate.a >= 0.99, "그리고 곧 HUD 가 드러난다")
	_assert(main.player.position.distance_to(start) > 4.0, "이제는 걷는다")
	_assert(main.player.warmth < warmth, "추위도 이제부터 시작된다")
	main.player.touch_direction = Vector2.ZERO
	main.clear_save()
	main.free()

var _hud_seen := false
func _assert_quiet_hud(main: Node2D, step: int) -> void:
	if main.hud.modulate.a > 0.01 and not _hud_seen:
		_hud_seen = true
		_assert(false, "깨어나는 동안 HUD 가 보인다 (%d 프레임, %.2f)" % [step, main.hud.modulate.a])

func _test_finish_tutorial_skips_it() -> void:
	var main: Node2D = await _main()
	main._start_new_run()
	main._end_cutscene()
	main.finish_tutorial()
	_assert(not main.waking() and not main.player.locked, "오프닝을 건너뛴 세계는 깨어나는 중이 아니다")
	_assert(main.hud_reveal >= 1.0, "HUD 도 그대로 있다")
	main.clear_save()
	main._start_run()
	_assert(not main.waking(), "이야기 없이 시작한 런도 깨어나는 중이 아니다")
	main.clear_save()
	main.free()

func _test_pose() -> void:
	_assert(Defs.wake_pose(0.0) >= 0.99, "누운 채 시작한다")
	_assert(Defs.wake_pose(Defs.WAKE_SECONDS) == 0.0, "선 채 끝난다")
	var stirred := false
	for index in 20:
		var t: float = Defs.WAKE_LIE * float(index) / 20.0
		if Defs.wake_pose(t) < 0.97:
			stirred = true
	_assert(stirred, "누워 있는 동안 한 번 꿈틀한다")
	var previous: float = 2.0
	var rises := true
	for index in 40:
		var t: float = Defs.WAKE_LIE + (Defs.WAKE_SECONDS - Defs.WAKE_LIE) * float(index) / 39.0
		var pose: float = Defs.wake_pose(t)
		if pose > previous + 0.001:
			rises = false
		previous = pose
	_assert(rises, "몸을 일으키는 동안 다시 눕지 않는다")
