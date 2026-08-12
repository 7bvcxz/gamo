extends SceneTree

## Eight cats, working, eating and going home, measured every tick.
##
## The reported symptom was the gauge, the body and the shadow drifting apart
## whenever a cat crossed the map. All three are positioned from one cat, so they
## can only disagree if something in the chain depends on where the cat is -- and
## something did: the breathing phase and the walk frame were offset by
## cat.pos.x. Breathing scales the sprite, whatever hangs over the cat is placed
## from the scaled height, and the shadow is not scaled, so the gauge slid
## against the shadow at walking speed.
##
## test_animation pins that with a synthetic walk. This runs the real thing: the
## crowded scenario, real ticks, cats deciding on their own to leave a miner for
## the bowl and to head home at dusk. Those transitions are where it was seen, so
## they are what is measured -- and screenshots cannot do it, because eight cats
## in one base put a dozen shadows under any gauge you try to measure against.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.touch_primary()          # the title screen is what starts play
	main.debug_crowd()
	main.process_mode = Node.PROCESS_MODE_DISABLED   # one source of ticks, not two

	var sim = main.sim
	_assert(sim.cats.size() >= 8, "고양이 8마리 이상 (%d)" % sim.cats.size())
	var working: int = 0
	for cat: Sim.Cat in sim.cats:
		if cat.has_job():
			working += 1
	_assert(working >= 2, "여러 마리가 채굴기에서 일한다 (%d)" % working)

	# Every cat gets its own baseline, and every tick has to reproduce it. The
	# clock is passed in rather than read from the layer so the measurement is of
	# the cat moving, not of time passing.
	var clock: float = 5.0
	var base_gap: Dictionary[int, float] = {}
	var base_height: Dictionary[int, float] = {}
	var worst_gap: float = 0.0
	var worst_height: float = 0.0
	var states_seen: Dictionary[int, bool] = {}
	var travelled: float = 0.0

	var step: float = 1.0 / 30.0
	var elapsed: float = 0.0
	var last: Dictionary[int, Vector2] = {}
	while elapsed < 200.0:
		main._process(step)
		if main.state == main.State.RESULT:
			main.touch_primary()
		elapsed += step
		for index in sim.cats.size():
			var cat: Sim.Cat = sim.cats[index]
			states_seen[cat.state] = true
			if last.has(index):
				travelled += cat.pos.distance_to(last[index])
			last[index] = cat.pos
			var puff: float = MachineLayer.cat_breathe(cat, clock)
			var shape: Rect2 = MachineLayer.cat_rect(cat.pos, puff, false, 0.0)
			var gauge: Rect2 = MachineLayer.cat_hunger_bar(cat.pos, shape)
			var gap: float = MachineLayer.cat_shadow_at(cat.pos).y - gauge.position.y
			var height: float = absf(shape.size.y)
			if not base_gap.has(index):
				base_gap[index] = gap
				base_height[index] = height
			worst_gap = maxf(worst_gap, absf(gap - base_gap[index]))
			worst_height = maxf(worst_height, absf(height - base_height[index]))

	# The run has to have actually contained the thing being tested.
	_assert(travelled > 2000.0, "고양이들이 실제로 돌아다녔다 (%.0fpx)" % travelled)
	_assert(states_seen.has(Defs.CAT_TO_FOOD) or states_seen.has(Defs.CAT_EATING),
		"밥을 먹으러 가는 구간이 포함됐다")
	_assert(states_seen.has(Defs.CAT_TO_SHELTER) or states_seen.has(Defs.CAT_ASLEEP),
		"귀가하는 구간이 포함됐다")

	_assert(worst_gap < 0.01, "게이지와 그림자 간격이 한 번도 흔들리지 않았다 (%.4fpx)" % worst_gap)
	_assert(worst_height < 0.01, "몸 높이가 위치에 따라 변하지 않았다 (%.4fpx)" % worst_height)

	print("CROWD: 고양이 %d마리, %.0f초, 이동 %.0fpx, 상태 %d종"
		% [sim.cats.size(), elapsed, travelled, states_seen.size()])
	main.clear_save()
	if failures == 0:
		print("CROWD_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("  FAIL: ", message)
		failures += 1
