extends SceneTree

## The reworked day, as contracts: no night interrupts the first 23 minutes,
## the first sunset lands in its target window, night sends the crew home on its
## own while the grid keeps the powered half of the factory turning, sleep
## skips what is left of the night, and no summary modal ever stops the world.

var failures := 0
var main: Node2D = null

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	_run()

func _run() -> void:
	_test_no_night_during_first_23_minutes()
	_test_first_sunset_target_range()
	_test_cats_return_home_at_night()
	_test_powered_factory_continues_at_night()
	_test_unpowered_cat_machine_stops_when_cat_leaves()
	_test_sleep_skips_remaining_night()
	_test_day_record_does_not_block_world()
	if failures == 0:
		print("PASS test_golden_night")
	else:
		print("FAIL test_golden_night (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _world() -> void:
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY

# --- test_no_night_during_first_23_minutes -------------------------------------

func _test_no_night_during_first_23_minutes() -> void:
	_world()
	_assert(Defs.DAY_SECONDS - Defs.NIGHT_SECONDS > 23.0 * 60.0,
		"첫 밤은 23분 밖이다 (%.0f분에 온다)" % ((Defs.DAY_SECONDS - Defs.NIGHT_SECONDS) / 60.0))
	main.time_left = Defs.DAY_SECONDS - 23.0 * 60.0
	_assert(not main.is_night(), "23분 시점은 밤이 아니다")
	_assert(not main.is_dusk(), "해질녘도 아니다 — 골든 패스 전체가 대낮이다")

# --- test_first_sunset_target_range --------------------------------------------

func _test_first_sunset_target_range() -> void:
	var sunset: float = (Defs.DAY_SECONDS - Defs.DUSK_SECONDS) / 60.0
	var night: float = (Defs.DAY_SECONDS - Defs.NIGHT_SECONDS) / 60.0
	_assert(sunset >= 28.0 and sunset <= 32.0,
		"첫 해질녘은 28~32분 사이다 (%.0f분)" % sunset)
	_assert(night >= 30.0 and night <= 34.0,
		"첫 밤은 30~34분 사이다 (%.0f분)" % night)
	_assert(is_equal_approx(Defs.DAY_SECONDS / 60.0, 36.0),
		"한 사이클은 36분이다")
	_assert(Defs.NIGHT_SECONDS < Defs.DUSK_SECONDS, "밤은 해질녘 뒤에 온다")

# --- test_cats_return_home_at_night --------------------------------------------

func _test_cats_return_home_at_night() -> void:
	_world()
	var sim = main.sim
	sim.cats.clear()
	for index in 2:
		var cat = sim.Cat.new()
		cat.pos = sim.cell_centre(sim.core_cell + Vector2i(3 + index, 3))
		cat.state = Defs.CAT_IDLE
		sim.cats.append(cat)
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	main._process_play(1.0 / 30.0)
	for cat in sim.cats:
		_assert(cat.state == Defs.CAT_TO_SHELTER or cat.state == Defs.CAT_ASLEEP,
			"밤이 되면 스스로 집으로 걷는다 (%d)" % cat.state)
	# And a player who stays up meets them walking back out at dawn.
	for _step in 400:
		main._process_play(1.0 / 30.0)
	main.time_left = Defs.DAY_SECONDS
	main._process_play(1.0 / 30.0)
	var outbound := 0
	for cat in sim.cats:
		if cat.state != Defs.CAT_ASLEEP:
			outbound += 1
	_assert(outbound == sim.cats.size(), "아침이 오면 스스로 나온다 (%d)" % outbound)

# --- test_powered_factory_continues_at_night ------------------------------------

func _test_powered_factory_continues_at_night() -> void:
	_world()
	var sim = main.sim
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	sim.note_resource_seen(Defs.ITEM_IRON)
	sim.stock[Defs.ITEM_COPPER] = 50
	sim.stock[Defs.ITEM_ENERGY_CORE] = 2
	sim.stock[Defs.ITEM_IRON] = 50
	sim.stock[Defs.ITEM_HEATSTONE] = 50
	var gen: Vector2i = _clear(sim, sim.core_cell + Vector2i(-4, 2))
	var plant: Vector2i = _clear(sim, sim.core_cell + Vector2i(4, 2))
	_clear(sim, plant + Vector2i.RIGHT)
	_assert(sim.build(Defs.M_GENERATOR, gen, Vector2i.RIGHT), "발전기가 선다")
	_assert(sim.build(Defs.M_MANUFACTURER, plant, Vector2i.RIGHT), "제조기가 선다")
	sim.machine_at(gen).buffer[Defs.GENERATOR_FUEL] = 4
	sim.machine_at(plant).buffer[Defs.ITEM_IRON] = 4

	main.time_left = Defs.NIGHT_SECONDS - 1.0
	var before: float = sim.machine_at(plant).progress
	for _step in 60:
		main._process_play(1.0 / 30.0)
	_assert(main.is_night(), "밤이다")
	_assert(sim.machine_at(plant).progress != before or not sim.machine_at(plant).outbox.is_empty()
			or int(sim.machine_at(plant).buffer.get(Defs.ITEM_IRON, 0)) < 4,
		"전력 기계는 밤에도 돈다 — 전기는 잠들지 않는다")

# --- test_unpowered_cat_machine_stops_when_cat_leaves ----------------------------

func _test_unpowered_cat_machine_stops_when_cat_leaves() -> void:
	_world()
	var sim = main.sim
	sim.stock[Defs.ITEM_HEATSTONE] = 50
	sim.stock[Defs.ITEM_COPPER] = 50
	sim.unlocked[Defs.M_MINER] = true
	var seam: Vector2i = _clear(sim, sim.core_cell + Vector2i(0, 4))
	sim.ore[seam] = Defs.ITEM_HEATSTONE
	sim._assign_purity()
	_assert(sim.build(Defs.M_MINER, seam, Vector2i.RIGHT), "채굴기가 선다")
	var cat = sim.Cat.new()
	cat.pos = sim.post_stand(seam)
	cat.assigned = seam
	cat.state = Defs.CAT_WORKING
	sim.cats.append(cat)
	main._process_play(1.0 / 30.0)
	_assert(sim.machine_at(seam).operated, "고양이가 돌리는 낮이다")
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	for _step in 8:
		main._process_play(1.0 / 30.0)
	_assert(cat.state != Defs.CAT_WORKING, "밤이 되면 그 고양이는 떠나고")
	_assert(not sim.machine_at(seam).operated,
		"일손 잃은 기계는 멈춘다 — 전력 없는 자동화는 밤을 넘지 못한다")

# --- test_sleep_skips_remaining_night --------------------------------------------

func _test_sleep_skips_remaining_night() -> void:
	_world()
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	var day_was: int = main.day_number
	main._sleep()
	var guard := 0
	while main.state != main.State.PLAY and guard < 1200:
		main._process(0.05)
		guard += 1
	_assert(main.state == main.State.PLAY, "잠들면 아침으로 건너뛴다")
	_assert(main.day_number == day_was + 1, "다음 날이다")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS), "시계가 가득 찼다")
	main.close_room()

# --- test_day_record_does_not_block_world ----------------------------------------

func _test_day_record_does_not_block_world() -> void:
	_world()
	_assert(not "RESULT" in main.State.keys(), "정산 모달 상태 자체가 없다")
	main.time_left = 2.0
	var notes: int = main.play_log.size()
	main._sleep()
	var frames := 0
	while main.state != main.State.PLAY and frames < 1200:
		main._process(0.05)
		frames += 1
	_assert(main.state == main.State.PLAY,
		"밤 연출은 입력 없이 스스로 아침에 닿는다 (%.1f초)" % (float(frames) * 0.05))
	_assert(main.play_log.size() > notes, "기록은 로그에 남는다 — 원하면 L 로 본다")
	main.close_room()

# --- Helpers ------------------------------------------------------------------

func _clear(sim, cell: Vector2i) -> Vector2i:
	sim.ore.erase(cell)
	sim.machines.erase(cell)
	sim.debris.erase(cell)
	sim.frozen_cats.erase(cell)
	return cell
