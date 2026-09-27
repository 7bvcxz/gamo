extends SceneTree

## The survival kit becoming the base (Quality Pass 01).
##
## * The search is a hold on Z, and letting go of that hold opened the workbench:
##   the release fell through to "Z facing the base", and the base was the case
##   she had just opened. The window came up over the moment the fire first lit.
##   A hold that did something is not a tap -- here, and for wreckage and thawing.
## * The base unfolds rather than appears: the case's size up to its own, the
##   light last, a latch, a creak and the fire catching -- no fanfare.
## * The heat is real at once. Only the painting of the circle spreads, so the
##   show cannot cost her warmth.
## * She steps out of the building that appeared around her, rather than being
##   put down outside it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_release_does_not_open_the_workbench()
	if failures == 0:
		print("PASS test_deploy")
	else:
		print("FAIL test_deploy (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _key(pressed: bool) -> InputEvent:
	var event: InputEvent = (InputMap.action_get_events("build")[0] as InputEvent).duplicate()
	(event as InputEventKey).pressed = pressed
	return event

func _test_release_does_not_open_the_workbench() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	var sim = main.sim
	# Beside the case, facing it -- where the opening puts her.
	main.player.position = sim.prop_centre(sim.kit_cell) + Vector2(-Grid.px(1.0), 0.0)
	main.player.facing = Vector2i.RIGHT
	_assert(main._facing_kit(), "상자 앞에 서 있다")
	var finish_before: int = int(main.audio.started.get("finish", 0))
	main._unhandled_input(_key(true))
	var dt := 1.0 / 60.0
	var frames := 0
	while not sim.base_placed and frames < 600:
		main._process(dt)
		frames += 1
	_assert(sim.base_placed, "Z 를 누르고 있으면 상자가 기지가 된다 (%d 프레임)" % frames)
	# The first frame of the base.
	_assert(sim.is_warm(sim.cell_of(main.player.position)) or sim.warm_radius >= Defs.WARM_BASE,
		"온기는 그 순간부터 진짜다 (반경 %.1f)" % sim.warm_radius)
	_assert(sim.shown_radius < sim.warm_radius,
		"그림만 퍼진다 (그려진 %.1f < 실제 %.1f)" % [sim.shown_radius, sim.warm_radius])
	_assert(main.machine_layer.core_unfold < 0.2, "상자가 펼쳐지기 시작한다 (%.2f)" % main.machine_layer.core_unfold)
	_assert(int(main.audio.started.get("latch", 0)) >= 1, "걸쇠 소리로 시작한다")
	var target: Vector2 = main.slide_to
	var inside: bool = sim.blocks_player(sim.cell_of(main.player.position))
	# Let go of Z.
	main._unhandled_input(_key(false))
	_assert(not main.base_menu_open and not main.modal_open(),
		"손을 떼도 작업대가 열리지 않는다")
	for step in int(1.2 / dt):
		main._process(dt)
		main.player._physics_process(dt)
	_assert(not main.base_menu_open, "1초 뒤에도 작업대는 닫혀 있다")
	_assert(main.machine_layer.core_unfold == 1.0, "기지가 다 펼쳐졌다")
	_assert(int(main.audio.started.get("creak", 0)) >= 1 and int(main.audio.started.get("whoomp", 0)) >= 1,
		"경첩이 삐걱이고 불이 붙는다")
	_assert(int(main.audio.started.get("finish", 0)) == finish_before, "팡파르는 없다")
	_assert(absf(sim.shown_radius - sim.warm_radius) < 0.5, "그림도 곧 따라잡는다")
	_assert(not sim.blocks_player(sim.cell_of(main.player.position)), "그녀는 기지 밖에 서 있다")
	if inside:
		_assert(main.player.position.distance_to(target) < 0.5, "기지에서 걸어 나와 그 자리에 섰다")
	# And a real tap on the base still opens it -- the fix is about holds.
	main.player.position = sim.core_centre() + Vector2(0.0, Grid.px(2.6))
	main.player.facing = Vector2i.UP
	main._unhandled_input(_key(true))
	main._process(dt)
	main._unhandled_input(_key(false))
	_assert(main.base_menu_open, "기지를 보고 Z 를 톡 누르면 작업대가 열린다")
	main.clear_save()
	main.free()
