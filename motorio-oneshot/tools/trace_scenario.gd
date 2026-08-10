extends SceneTree

## The standard scenario, three days, printed once every thirty seconds.
##
## The browser runs say what a player sees; this says why. A crystal count that
## stops climbing looks the same on screen whether the cats went to eat, went
## home, or the miners jammed -- and the frames cannot tell those apart, because
## a cat standing next to its miner and a cat walking past it are the same
## picture. Here every cat's state and every miner's stall flag are readable.
##
##   godot --headless --path motorio-oneshot --script res://tools/trace_scenario.gd

const MainScene := preload("res://scenes/Main.tscn")

func _init() -> void:
	# Into the tree properly, or _view_rect's get_viewport_rect() fails on every
	# frame; and then processing off, so the engine does not tick the same timers
	# the loop below ticks. A manual tick loop next to a live _process measured a
	# three second cutscene as 2.45 seconds once already.
	await process_frame
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.clear_save()
	main._start_run()
	# _start_run prepares a world; it does not start playing. The title screen is
	# what does that, and without it every tick below lands in `State.TITLE: pass`
	# and the trace reads as a game where nothing whatsoever happens.
	main.touch_primary()
	main.debug_scenario()

	var sim = main.sim
	var step: float = 1.0 / 30.0
	var elapsed: float = 0.0
	var last_crystal: int = int(sim.stock.get(Defs.ITEM_CRYSTAL, 0))
	var stalled_seconds: float = 0.0
	print("t     수정   증가  바닥 고양이상태                     허기      채굴기")
	while elapsed < 3.0 * (Defs.DAY_SECONDS + 70.0):
		main._process(step)
		# The summary card waits for a key. Nobody is here to press one, so
		# without this the trace stops at the end of day one and reads as a world
		# that froze -- which is exactly the symptom being investigated.
		if main.state == main.State.RESULT:
			main.touch_primary()
		elapsed += step
		if fmod(elapsed, 30.0) >= step:
			continue
		var crystal: int = int(sim.stock.get(Defs.ITEM_CRYSTAL, 0))
		var states: PackedStringArray = []
		var hungers: PackedStringArray = []
		for cat in sim.cats:
			states.append(_cat_state(cat.state))
			hungers.append("%.2f" % cat.hunger)
		var miners: PackedStringArray = []
		for cell: Vector2i in sim.machines:
			var machine = sim.machines[cell]
			if machine.type != Defs.M_MINER:
				continue
			miners.append("%s%s" % ["돎" if machine.operated else "섬",
				"(막힘)" if machine.stalled else ""])
		if crystal == last_crystal:
			stalled_seconds += 30.0
		print("%5.0f %d일 %5d %+5d %4d  %-26s %-9s %s" % [elapsed, main.day_number, crystal, crystal - last_crystal,
			sim.ground.size(), ", ".join(states), " ".join(hungers), " ".join(miners)])
		last_crystal = crystal
	print("정지 구간 합계 %.0f초 / %.0f초" % [stalled_seconds, elapsed])
	quit()

func _cat_state(state: int) -> String:
	match state:
		Defs.CAT_IDLE: return "놈"
		Defs.CAT_WORKING: return "일함"
		Defs.CAT_TO_MINER: return "일터로"
		Defs.CAT_TO_FOOD: return "밥통으로"
		Defs.CAT_EATING: return "먹는중"
		Defs.CAT_TO_SHELTER: return "귀가"
		Defs.CAT_HAUL_TO_ITEM: return "주우러"
		Defs.CAT_HAUL_TO_BASE: return "나름"
		Defs.CAT_ASLEEP: return "잠"
	return "상태%d" % state
