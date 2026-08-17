extends SceneTree

## A cat may never jump.
##
## One day, three cats on miners and one left alone, every cat's position read
## once a second. A cat walks at CAT_SPEED, so a second of walking is CAT_SPEED
## pixels and anything past that is the animal being moved rather than walking --
## which is what a player sees as a teleport, and what makes its gauge, its body
## and its shadow look like they came apart even when they are all drawn from the
## same point.
##
## Reported twice from play: cats blinking while delivering to the base, worse
## when they come at it from the right. Sampling at one second rather than every
## tick is deliberate -- it is the rate a person notices at, and a jump small
## enough to hide inside one tick is not what was reported.

var failures := 0

const SAMPLE := 1.0
## What one second of walking can cover, with room for the frame the sample lands
## in. Anything above this was assigned, not walked.
const ALLOWED := Defs.CAT_SPEED * SAMPLE + 4.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.touch_primary()
	main.debug_scenario()
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var sim = main.sim
	# Three on machines, one idle: the arrangement asked for. debug_scenario
	# staffs whatever miners it built, so the rest is topped up here.
	while sim.cats.size() < 4:
		sim.grant_cats(1)
	for cell: Vector2i in sim.idle_miner_cells():
		var spare = null
		for cat: Sim.Cat in sim.cats:
			if not cat.has_job():
				spare = cat
				break
		if spare == null:
			break
		sim.carried_cat = spare
		sim.place_cat(cell)
	var staffed := 0
	var idle := 0
	for cat: Sim.Cat in sim.cats:
		if cat.has_job():
			staffed += 1
		else:
			idle += 1
	print("WALK: 고양이 %d마리 (배치 %d, 유휴 %d)" % [sim.cats.size(), staffed, idle])
	_assert(idle >= 1, "가만히 두는 고양이가 있다")

	# One worker starts away from its machine and has to walk in. Without this the
	# approach never runs: debug_scenario puts cats on their miners with
	# place_cat, which sets the position exactly, so a day that contains no meal
	# never exercises walking to a machine at all -- and a centring check that
	# only ever sees cats that were placed there passes against code that stops
	# ten pixels short.
	var walker: Sim.Cat = null
	for cat: Sim.Cat in sim.cats:
		if cat.has_job():
			walker = cat
			break
	_assert(walker != null, "걸어올 작업자가 있다")
	if walker != null:
		walker.pos = sim.cell_centre(walker.assigned) + Vector2(0.0, 64.0)
		walker.state = Defs.CAT_TO_MINER

	# Items east of the base, because that is the case that was reported: a cat
	# delivering from the right blinking twice. An idle cat picks the nearest one
	# up on its own, so the run below actually contains the approach being
	# accused rather than whatever route the map happened to produce.
	for offset in range(2, 7):
		sim.ground[sim.core_cell + Vector2i(offset, 0)] = Defs.ITEM_CRYSTAL
		sim.ground[sim.core_cell + Vector2i(offset, 1)] = Defs.ITEM_CRYSTAL
	var hauled_from_east := false

	var step: float = 1.0 / 30.0
	var elapsed: float = 0.0
	var since: float = 0.0
	var last: Dictionary[int, Vector2] = {}
	var last_state: Dictionary[int, int] = {}
	var jumps: Array[String] = []
	var worst: float = 0.0
	# Sampling once a second is the rate a person notices at, and it is also a
	# sieve: a 40 pixel snap hides under one second of legitimate walking. So
	# every tick is checked as well, where the ceiling is one step and anything
	# above it was assigned rather than walked. The two together mean a teleport
	# has nowhere to be small enough to survive.
	var tick_last: Dictionary[int, Vector2] = {}
	var tick_state: Dictionary[int, int] = {}
	var snaps: Array[String] = []
	var worked: int = 0
	var off_centre: float = 0.0
	var tick_ceiling: float = Defs.CAT_SPEED * step + 0.01
	while elapsed < Defs.DAY_SECONDS:
		main._process(step)
		if main.state == main.State.RESULT:
			break                      # one day, as asked
		elapsed += step
		since += step
		for index in sim.cats.size():
			var cat: Sim.Cat = sim.cats[index]
			if cat == sim.carried_cat:
				tick_last.erase(index)
				continue
			if tick_last.has(index):
				var hop: float = cat.pos.distance_to(tick_last[index])
				if hop > tick_ceiling:
					snaps.append("%.1f초 %d번 %.1fpx (%d -> %d)"
						% [elapsed, index, hop, tick_state.get(index, -1), cat.state])
			if cat.state == Defs.CAT_HAUL_TO_BASE and cat.pos.x > sim.cell_centre(sim.core_cell).x:
				hauled_from_east = true
			# Checked while it is happening, not at the end. The first version of
			# this looked for working cats after the loop, by which time the day
			# had ended and every cat was asleep -- so it asserted nothing and
			# passed against the very code it was written to catch.
			if cat.state == Defs.CAT_WORKING:
				worked += 1
				var feet: Vector2 = cat.pos + Vector2(0.0, Defs.CAT_FOOT_DROP)
				off_centre = maxf(off_centre, feet.distance_to(sim.cell_centre(cat.assigned)))
			tick_last[index] = cat.pos
			tick_state[index] = cat.state
		if since < SAMPLE:
			continue
		since -= SAMPLE
		for index in sim.cats.size():
			var cat: Sim.Cat = sim.cats[index]
			if cat == sim.carried_cat:
				last.erase(index)
				continue
			if last.has(index):
				var moved: float = cat.pos.distance_to(last[index])
				worst = maxf(worst, moved)
				if moved > ALLOWED:
					jumps.append("%.0f초 %d번 고양이 %.0fpx (%d -> %d) %s -> %s"
						% [elapsed, index, moved, last_state.get(index, -1), cat.state,
						str(last[index].round()), str(cat.pos.round())])
			last[index] = cat.pos
			last_state[index] = cat.state

	_assert(jumps.is_empty(), "1초 단위로 순간이동이 없다. %d건: %s"
		% [jumps.size(), "; ".join(jumps.slice(0, 6))])
	_assert(snaps.is_empty(), "한 틱에 걸을 수 있는 거리를 넘지 않는다. %d건: %s"
		% [snaps.size(), "; ".join(snaps.slice(0, 8))])
	_assert(hauled_from_east, "오른쪽에서 기지로 나르는 경로가 실제로 포함됐다")
	print("WALK: %.0f초, 1초당 최대 이동 %.1fpx (허용 %.1f)" % [elapsed, worst, ALLOWED])

	# And a working cat stands on the middle of its machine, not near it: the
	# drill it holds is drawn from the same point, so an animal that stopped ten
	# pixels short works beside the seam instead of on it.
	#
	# Measured at the feet. A cat's position is its torso and the drawing puts the
	# feet CAT_FOOT_DROP below it, so a cat placed at the middle of a tile stood a
	# third of a tile south of the machine -- 19 screen pixels at full zoom.
	_assert(worked > 1000, "작업 중인 순간이 충분히 관측됐다 (%d틱)" % worked)
	_assert(off_centre < 0.01,
		"작업 중인 고양이의 발이 채굴기 정중앙을 딛는다 (최대 %.2fpx 벗어남)" % off_centre)

	main.clear_save()
	if failures == 0:
		print("WALK_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("  FAIL: ", message)
		failures += 1
