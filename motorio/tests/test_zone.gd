extends SceneTree
## Two places, and the rules that are supposed to stay in one of them.
##
## Every bug this file exists for looked different and was the same bug: a field
## rule reading a world coordinate six hundred cells from the fire and answering
## about a warm lit room. Freezing at her own hearth, the outdoor toolbelt under
## the floorboards, and "땅과 얼어붙었다" over her own floor once every three
## seconds -- procedural rock exists under a fair share of every cell in the
## world, including the ones the shelter stands on.
##
## So the table is checked for completeness (a missing key is a silent false,
## which is the shape all of them had), and then the room is actually stood in
## for a few seconds with the whole frame running.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_table()
	await _test_indoors()
	await _test_outdoors_again()
	if failures == 0:
		print("ZONE: PASS")
	quit(failures)

## Both rows answer every question. Adding a rule to one place and forgetting the
## other is how `false` gets to mean "nobody wrote this down".
func _test_table() -> void:
	var keys: Array = Zone.RULES[Zone.FIELD].keys()
	for zone: int in Zone.RULES:
		var row: Dictionary = Zone.RULES[zone]
		_assert(row.keys().size() == keys.size(), "모든 장소가 같은 항목을 갖는다")
		for key: String in keys:
			_assert(row.has(key), "%s 에 %s 규칙이 있다" % [Zone.id(zone), key])
	_assert(Zone.of(false) == Zone.FIELD and Zone.of(true) == Zone.HOME, "실내는 HOME 이다")
	_assert(Zone.freezes(Zone.FIELD) and not Zone.freezes(Zone.HOME), "추위는 눈밭에만")
	_assert(Zone.clock_runs(Zone.FIELD) and not Zone.clock_runs(Zone.HOME), "시간은 눈밭에만")
	_assert(Zone.darkens(Zone.FIELD) and not Zone.darkens(Zone.HOME), "밤은 눈밭에만")
	_assert(Zone.has_world(Zone.FIELD) and not Zone.has_world(Zone.HOME), "월드는 눈밭에만")
	_assert(Zone.has_weather(Zone.FIELD) and not Zone.has_weather(Zone.HOME), "바람은 눈밭에만")
	_assert(Zone.score(Zone.HOME) == "home", "숙소에는 숙소 곡이 있다")

func _test_indoors() -> void:
	var main: Node2D = await _main()
	var sim = main.sim
	main.open_room()
	_assert(main.zone() == Zone.HOME, "숙소에 들어가면 HOME 이다")

	# The floor the bug was standing on. It used to be a boulder: rock was
	# procedural, so it was under the room too, and every plateau rule that reads
	# a world cell found it there.
	#
	# Boulders are gone as of 1.0.28 and the room is 600 cells north of anything
	# the generator scatters, so there is nothing under it any more -- and a test
	# whose precondition never holds is a test that passes without looking at
	# anything. So the seam is *put* there rather than looked for. The premise is
	# still a fact about the world ("there is a seam under the room"), which is
	# the form that survives the thing being fixed; what changed is that this
	# world does not supply one on its own.
	var trap: Vector2i = Defs.room_to_world(Vector2i(int(Defs.ROOM_CELLS.x) / 2,
		int(Defs.ROOM_CELLS.y) / 2))
	sim.ore[trap] = Defs.ITEM_HEATSTONE
	_assert(sim.ore.has(trap), "방 밑에 월드를 깔아 둔다 (없으면 이 테스트는 아무것도 지키지 않는다)")
	# Stated as distance rather than as `can_touch`, because the room answers
	# `can_touch` for itself now -- writing the premise in terms of the rule
	# being tested is what the paragraph above is about, and it was written the
	# wrong way here once already.
	var far: float = Vector2(trap - sim.core_cell).length()
	_assert(far > Defs.WARM_MAX,
		"그리고 그것은 불에서 %.0f칸이라 온기(최대 %.0f칸)가 절대 닿지 않는다"
		% [far, Defs.WARM_MAX])
	main.player.position = sim.cell_centre(trap)

	# Night, so the clock and the dark have something to leak.
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	main.player.warmth = 40.0
	var clock_before: float = main.time_left
	var warmth_before: float = main.player.warmth
	var logged: int = main.play_log.size()

	for step in 240:
		main._process(1.0 / 60.0)

	_assert(is_equal_approx(main.time_left, clock_before),
		"시간이 멈춘다 (%.2f -> %.2f)" % [clock_before, main.time_left])
	_assert(main.player.warmth > warmth_before,
		"체온이 오른다 (%.1f -> %.1f)" % [warmth_before, main.player.warmth])
	_assert(is_zero_approx(main.night_level()), "밤이 오지 않는다 (%.2f)" % main.night_level())
	_assert(not main.cold_fog.visible, "안개가 없다")
	var frozen_lines: int = 0
	for entry: Dictionary in main.play_log:
		if String(entry["text"]).contains("얼어붙"):
			frozen_lines += 1
	_assert(frozen_lines == 0, "'땅과 얼어붙었다'가 뜨지 않는다 (%d줄)" % frozen_lines)
	var said: Array = []
	for index in (main.play_log.size() - logged):
		said.append(String(main.play_log[index]["text"]))
	_assert(main.play_log.size() == logged, "아무 말도 하지 않는다 (%s)" % ", ".join(said))
	_assert(main.active_prompt() == "", "바깥 키 안내가 뜨지 않는다")
	_assert(main.audio.bed_level("wind") < 0.05 and main.audio.bed_level("cold") < 0.05,
		"바람과 냉기가 멎는다 (%.2f / %.2f)" % [main.audio.bed_level("wind"), main.audio.bed_level("cold")])
	_assert(main.music.requested_score() == "home", "숙소 곡이 흐른다")
	main.clear_save()
	main.free()

## And the plateau is unchanged: every one of those has to come back, or the fix
## is that the game stopped doing them anywhere.
func _test_outdoors_again() -> void:
	var main: Node2D = await _main()
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	main.player.warmth = 40.0
	main.player.position = main.sim.cell_centre(main.sim.core_cell + Vector2i(40, 0))
	var clock_before: float = main.time_left
	for step in 120:
		main._process(1.0 / 60.0)
	_assert(main.zone() == Zone.FIELD, "밖은 FIELD 다")
	_assert(main.time_left < clock_before, "시간이 흐른다")
	_assert(main.player.warmth < 40.0, "추위가 온다 (%.1f)" % main.player.warmth)
	_assert(main.night_level() > 0.9, "밤이 온다 (%.2f)" % main.night_level())
	_assert(main.cold_fog.visible, "안개가 있다")
	_assert(main.audio.bed_level("wind") > 0.2, "바람이 분다 (%.2f)" % main.audio.bed_level("wind"))
	_assert(main.music.requested_score() == "", "곡은 없다")
	main.clear_save()
	main.free()

func _main() -> Node2D:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	return main

func _assert(condition: bool, message: String) -> void:
	print("  %s %s" % ["ok  " if condition else "FAIL", message])
	if not condition:
		failures += 1
