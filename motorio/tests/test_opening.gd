extends SceneTree

## The first thirteen minutes: a crash site with nothing on it, a case in the
## snow, and four missions that end with a cat.
##
## What this is really guarding is that the opening is a *state of the world*
## rather than a script. Every rung is decided by asking the world what is
## standing on it, so there is no flag to set twice and none to miss when the
## player does the thing some other way -- and every one of these has more than
## one way to happen. The assertions below drive the world, never the mission
## number, and then ask what the mission became.

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
	_test_crash_site()
	_test_clock_is_held()
	_test_searching_the_kit()
	_test_placing_the_base()
	_test_placing_the_shelter()
	_test_missions_follow_the_world()
	_test_cold_ends_it()
	_test_the_gun_comes_from_the_fire()
	_test_feeding_the_fire()
	_test_save_mid_opening()
	_test_finish_tutorial()
	if failures == 0:
		print("PASS test_opening")
	else:
		print("FAIL test_opening (%d)" % failures)
	quit(failures)


## Through the opening's first two sentences: the case unfolds into the base,
## and the fire makes the shelter kit, which lands beside it and is picked up.
## Every test below this one is about what happens *after* that.
func _open_and_hold_shelter(sim) -> void:
	sim.search_kit()
	sim.craft_shelter_kit()
	for cell: Vector2i in sim.drops.keys():
		sim.collect_drop(cell)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## Somewhere the hut will actually go. The world is generated fresh per run and
## heat stone is scattered from three tiles out, so a hardcoded cell is a seam
## one run in several -- which is the shape of flake this repository has been
## bitten by before, and it fails as "the mission did not advance".
func _shelter_spot(sim) -> Vector2i:
	for radius in range(int(Defs.SHELTER_CLEARANCE) + 1, 7):
		for step in 16:
			var angle: float = TAU * float(step) / 16.0
			var cell: Vector2i = sim.core_cell + Vector2i(
				roundi(cos(angle) * float(radius)), roundi(sin(angle) * float(radius)))
			if sim.ore.has(cell) or sim.machines.has(cell) or cell == sim.kit_cell:
				continue
			if Vector2(cell - sim.core_cell).length() <= Defs.SHELTER_CLEARANCE:
				continue
			return cell
	return sim.core_cell + Vector2i(-4, 0)

## A fresh crash, every time. The opening is the one part of the game whose
## whole subject is the state it starts in.
func _crash() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY

# --- What she wakes up to ---------------------------------------------------

func _test_crash_site() -> void:
	_crash()
	var sim = main.sim
	_assert(not sim.base_placed, "기지가 없다")
	_assert(not sim.shelter_placed, "거처도 없다")
	_assert(sim.machine_at(sim.core_cell) == null, "코어가 세계에 없다")
	_assert(main.mission == main.Mission.BASE, "첫 임무는 긴급기지다")
	_assert(is_equal_approx(main.player.warmth, Defs.CRASH_WARMTH),
		"체온 %.0f 으로 시작한다" % Defs.CRASH_WARMTH)
	_assert(is_equal_approx(sim.warm_radius, Defs.CRASH_SIGHT),
		"보이는 것은 %.0f칸뿐" % Defs.CRASH_SIGHT)
	# Nothing is warm, including the tile the fire will stand on. A radius that
	# still warms without a fire in it is the bug this pair is here to stop.
	_assert(not sim.is_warm(sim.core_cell), "불이 없으니 어디도 따뜻하지 않다")
	_assert(not sim.is_warm(sim.core_cell + Vector2i(1, 0)), "옆 칸도 마찬가지다")
	# The kit has to be visible from where she is standing. At three tiles of
	# sight, "go and look for it" is not an instruction.
	var reach: float = Vector2(sim.kit_cell - sim.core_cell).length()
	_assert(reach <= Defs.CRASH_SIGHT, "긴급생존키트가 시야 안에 있다 (%.1f칸)" % reach)
	_assert(sim.kit_searched == 0, "아직 열지 않았다")
	# Reach, not aim. The kit is the first thing the player touches and there is
	# nothing within three tiles it could be confused with, so standing beside it
	# is enough whichever way she happens to be looking. The browser run found
	# this the hard way: it walked to the kit, held Z, and nothing happened,
	# because the last arrow pressed had been Down.
	main.player.position = sim.cell_centre(sim.kit_cell + Vector2i(-1, 0))
	for facing: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		main.player.facing = facing
		_assert(main._facing_kit(), "옆에 서면 어느 쪽을 보든 열 수 있다 %s" % facing)
	main.player.position = sim.cell_centre(sim.kit_cell + Vector2i(3, 0))
	_assert(not main._facing_kit(), "멀면 안 된다")
	main.player.position = sim.cell_centre(sim.core_cell)
	# And the buildings that are not there must not be walls either.
	_assert(not sim.blocks_player(sim.shelter_cell), "없는 거처는 길을 막지 않는다")
	_assert(not sim.blocks_player(sim.food_cell), "없는 밥통도 마찬가지다")

# --- The day does not start until the opening is over -----------------------

func _test_clock_is_held() -> void:
	_crash()
	var before: float = main.time_left
	for _step in 120:
		main._process_play(1.0 / 60.0)
	_assert(is_equal_approx(main.time_left, before),
		"오프닝 동안 하루가 흐르지 않는다 (%.1f초 그대로)" % main.time_left)
	main.finish_tutorial()
	for _step in 120:
		main._process_play(1.0 / 60.0)
	_assert(main.time_left < before - 1.5,
		"끝나면 다시 흐른다 (%.1f초 남음)" % main.time_left)

# --- The case ---------------------------------------------------------------

func _test_searching_the_kit() -> void:
	_crash()
	var sim = main.sim
	# One search, and the search *is* the fire. Nothing drops, nothing is
	# carried; the case unfolds into the base on the crash anchor and the case
	# itself stays standing beside it as the box it is. The old two-search flow
	# -- base kit, then shelter and pickaxe -- is the exact regression the
	# golden path work removed, so its absence is asserted by name.
	var first: Array[int] = sim.search_kit()
	_assert(first.is_empty(), "조사에서 아무것도 떨어지지 않는다")
	_assert(sim.machine_at(sim.core_cell) != null, "그리고 코어가 서 있다")
	_assert(sim.base_placed, "조사가 곧 기지다")
	_assert(sim.kit_searched == 1, "조사는 한 번이다")
	_assert(sim.drops.is_empty(), "눈 위에는 아무것도 없다")
	_assert(not sim.has_gun and not sim.has_pickaxe, "도구는 상자에서 나오지 않는다")
	_assert(not sim.can_search_kit(), "두 번째 조사는 없다")
	_assert(sim.search_kit().is_empty(), "빈 상자다")
	_assert(not main._facing_kit(), "Z도 더는 상자를 가리키지 않는다")

	# The shelter kit is a craft now, and picking it up needs empty hands.
	_assert(sim.craft_shelter_kit(), "불이 숙소 키트를 만든다")
	_assert(not sim.craft_shelter_kit(), "하나가 눈에 있는 동안 둘째는 없다")
	sim.carried_frozen = true
	for cell: Vector2i in sim.drops.keys():
		_assert(sim.collect_drop(cell) == -1, "손이 차 있으면 키트는 못 줍는다")
	sim.carried_frozen = false
	for cell: Vector2i in sim.drops.keys():
		_assert(sim.collect_drop(cell) == Sim.DROP_KIT_SHELTER, "손이 비면 줍는다")
	_assert(sim.carried_kit == Defs.KIT_SHELTER, "이제 들고 있다")

# --- Putting the fire down --------------------------------------------------

func _test_placing_the_base() -> void:
	_crash()
	var sim = main.sim
	var crash: Vector2i = sim.core_cell
	sim.search_kit()
	_assert(sim.base_placed and sim.machine_at(crash) != null, "코어가 앵커에 선다")
	_assert(sim.shelter_cell == crash + Defs.SHELTER_CELL, "거처 자리가 정해져 있다")
	_assert(sim.is_warm(crash), "그 자리가 따뜻하다")
	_assert(sim.warm_radius >= Defs.WARM_BASE,
		"온기 반경이 열린다 (%.1f칸)" % sim.warm_radius)
	_assert(sim.carried_kit == Defs.KIT_NONE, "손이 비었다")
	sim.carried_kit = Defs.KIT_BASE
	_assert(not sim.place_base(crash + Vector2i(1, 0)), "두 번째 기지는 없다")
	sim.carried_kit = Defs.KIT_NONE

# --- And the hut ------------------------------------------------------------

func _test_placing_the_shelter() -> void:
	_crash()
	var sim = main.sim
	_open_and_hold_shelter(sim)
	_assert(sim.carried_kit == Defs.KIT_SHELTER, "긴급거처를 들었다")
	_assert(not sim.place_shelter(sim.core_cell + Vector2i(1, 0)),
		"기지에 붙여서는 세울 수 없다")
	_assert(not sim.place_shelter(sim.core_cell + Vector2i(40, 0)),
		"온기 밖에도 세울 수 없다")
	var spot: Vector2i = _shelter_spot(sim)
	_assert(sim.place_shelter(spot), "그 사이라면 세울 수 있다")
	_assert(sim.shelter_placed and sim.shelter_cell == spot, "고른 자리에 선다")
	_assert(sim.blocks_player(spot), "그리고 이제 건물이다 — 통과할 수 없다")

# --- The ladder -------------------------------------------------------------

func _test_missions_follow_the_world() -> void:
	_crash()
	var sim = main.sim
	_assert(main.mission == main.Mission.BASE, "1. 긴급기지")
	sim.search_kit()
	main._advance_mission()
	_assert(main.mission == main.Mission.SURVIVE, "2. 생존 준비")
	sim.craft_shelter_kit()
	for cell: Vector2i in sim.drops.keys():
		sim.collect_drop(cell)
	_assert(sim.place_shelter(_shelter_spot(sim)), "거처를 세운다")
	main._advance_mission()
	# Two missions, and then the game. There were four; the last two told the
	# player to go and mine and go and explore at exactly the point the game
	# should have stopped talking.
	_assert(main.mission == main.Mission.DONE, "거처가 서면 오프닝이 끝난다")
	# The one-line card is finished with. What the player is working towards from
	# here is three things at once -- the fire, the animals, the factory -- and a
	# single line meant they took turns evicting each other. The count the fire
	# is owed moved onto the fire, where someone deciding whether to walk out for
	# one more stone is already looking.
	_assert(String(main.objective_data()["text"]).is_empty(),
		"오프닝이 끝나면 한 줄짜리 카드가 비워진다: '%s'"
			% String(main.objective_data()["text"]))
	var progress: Array[int] = main.upgrade_progress()
	_assert(progress == [0, Defs.OPENING_STONES],
		"기지 위의 숫자는 0에서 시작하고 필요 수는 고정이다: %s" % str(progress))
	main.sim.delivered[Defs.ITEM_HEATSTONE] = 1
	main.sim.stones_in = 1
	main.sim._refresh_radius()
	_assert(main.upgrade_progress() == [1, Defs.OPENING_STONES],
		"하나 넣으면 1/%d 이 된다: %s" % [Defs.OPENING_STONES, str(main.upgrade_progress())])
	main.sim.stones_in = 0
	main.sim._refresh_radius()
	# The card has to say something at every rung, and never the same thing twice
	# in a row -- a ladder that repeats itself is a ladder the player thinks is
	# stuck.
	var seen: Dictionary[String, bool] = {}
	_crash()
	seen[String(main.objective_data()["text"])] = true
	main.sim.search_kit()
	main._advance_mission()
	seen[String(main.objective_data()["text"])] = true
	main.sim.craft_shelter_kit()
	for cell: Vector2i in main.sim.drops.keys():
		main.sim.collect_drop(cell)
	seen[String(main.objective_data()["text"])] = true
	_assert(seen.size() == 3, "세 상황이 세 가지 문구를 낸다 (%d)" % seen.size())

# --- The cold is a clock, not a wall ----------------------------------------

func _test_cold_ends_it() -> void:
	_crash()
	var warmth: float = main.player.warmth
	for _step in 60:
		main._update_warmth(1.0 / 60.0)
	var lost: float = warmth - main.player.warmth
	_assert(absf(lost - Defs.CRASH_DRAIN) < 0.05,
		"1초에 %.2f씩 떨어진다 (%.2f)" % [Defs.CRASH_DRAIN, lost])
	# All the way down, and that is the end of the run as of 1.0.6.
	#
	# It used to wake her up at the crash site with her forty degrees back, which
	# made the opening's one danger something that happened to a bar rather than
	# to her: standing in the snow cost nothing and could be done forever. The
	# clock is thirteen seconds now and running it out ends the game.
	main.player.position = main.sim.cell_centre(main.sim.core_cell + Vector2i(9, 9))
	var guard := 0
	while main.player.warmth > 0.0 and guard < 20000:
		main._update_warmth(1.0 / 60.0)
		guard += 1
	main._update_warmth(1.0 / 60.0)
	_assert(main.player.warmth <= 0.0, "체온이 바닥난다 (%.0f)" % main.player.warmth)
	_assert(main.state == main.State.GAMEOVER, "그리고 게임이 끝난다")
	_assert(main.day_number == 1, "하루가 넘어가지도 않는다")

# --- The world the rest of the game expects ---------------------------------

## Mined heat stone had no way into the fire. It went into the base's ledger --
## which is where machines are bought from -- and stopped there, so the third
## mission counted deliveries that could never happen and the opening could not
## be finished by hand at all.
func _test_feeding_the_fire() -> void:
	_crash()
	var sim = main.sim
	main.finish_tutorial()
	sim.delivered[Defs.ITEM_HEATSTONE] = 0
	sim.stock[Defs.ITEM_HEATSTONE] = 0
	_assert(not sim.has_fuel(), "빈손으로는 넣을 것이 없다")
	_assert(sim.deposit_fuel().is_empty(), "그리고 아무 일도 일어나지 않는다")

	sim.stock[Defs.ITEM_HEATSTONE] = Defs.OPENING_STONES
	sim.stock[Defs.ITEM_CRYSTAL] = 4
	_assert(sim.has_fuel(), "열석이 있으면 넣을 것이 있다")
	var stones_before: int = sim.stones_in
	var moved: Dictionary = sim.deposit_fuel()
	_assert(int(moved.get(Defs.ITEM_HEATSTONE, 0)) == Defs.OPENING_STONES,
		"열석이 전부 들어간다")
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == 0, "손에서는 사라진다")
	_assert(sim.stones_in == stones_before + Defs.OPENING_STONES,
		"불에 들어간 열석이 그만큼 오른다")
	_assert(int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) == Defs.OPENING_STONES,
		"임무가 세는 숫자가 오른다")
	# Materials are not fuel and must not be swallowed. `stock` is the base's
	# store, so crystal is already in the base -- taking it away to "deliver" it
	# would be spending it on nothing.
	_assert(int(sim.stock.get(Defs.ITEM_CRYSTAL, 0)) == 4, "수정은 그대로 남는다")

	# And the step it exists for: three stones takes the circle to nine, which is
	# exactly where the first frozen cat is lying.
	_assert(sim.base_level >= 1, "기지가 한 단계 오른다")
	_assert(absf(sim.warm_radius - Defs.OPENING_WARM_RADIUS) < 0.01,
		"온기가 정확히 %.0f칸이 된다 (%.2f)" % [Defs.OPENING_WARM_RADIUS, sim.warm_radius])
	var visible := 0
	for cell: Vector2i in sim.frozen_cats:
		if sim.is_warm(cell):
			visible += 1
	_assert(visible >= 1, "그 순간 얼어붙은 고양이가 온기 안에 들어온다 (%d마리)" % visible)
	# It must not shrink back when heat is later spent or recomputed.
	sim._refresh_radius()
	_assert(sim.warm_radius >= Defs.OPENING_WARM_RADIUS, "다시 계산해도 줄지 않는다")

func _test_save_mid_opening() -> void:
	_crash()
	var sim = main.sim
	var anchor: Vector2i = sim.core_cell
	_open_and_hold_shelter(sim)
	main._advance_mission()
	main.player.warmth = 44.0
	_assert(main.save_game(false), "오프닝 도중에 저장된다")

	main._start_run()
	main.finish_tutorial()
	_assert(main.load_game(), "다시 불러온다")
	_assert(main.mission == main.Mission.SURVIVE, "임무 2로 돌아온다")
	_assert(main.sim.base_placed and not main.sim.shelter_placed,
		"기지는 서 있고 거처는 아직 없다")
	_assert(main.sim.core_cell == anchor, "기지 자리가 살아난다")
	_assert(main.sim.machine_at(anchor) != null, "그 자리에 코어가 있다")
	_assert(main.sim.carried_kit == Defs.KIT_SHELTER, "손에 든 거처도 그대로다")
	_assert(main.sim.kit_searched == 1, "상자는 이미 뒤진 것으로 남는다")
	_assert(absf(main.player.warmth - 44.0) < 0.5, "체온도 그대로다")
	main.clear_save()

func _test_finish_tutorial() -> void:
	_crash()
	main.finish_tutorial()
	var sim = main.sim
	_assert(sim.base_placed and sim.machine_at(sim.core_cell) != null, "코어가 선다")
	_assert(sim.shelter_placed, "거처도 선다")
	_assert(sim.shelter_cell == sim.core_cell + Defs.SHELTER_CELL, "숙소는 제자리에")
	# The bin is not part of the shelter kit. It is made at the fire, when a cat
	# working at a third speed makes the player ask why.
	_assert(not sim.food_placed, "밥통은 아직 없다")
	_assert(main.mission == main.Mission.DONE, "오프닝이 끝난 상태다")
	_assert(sim.kit_searched == 1, "상자는 비어 있다")
	_assert(sim.carried_kit == Defs.KIT_NONE, "손에는 아무것도 없다")
	_assert(is_equal_approx(main.player.warmth, 100.0), "체온은 가득이다")


func _test_the_gun_comes_from_the_fire() -> void:
	_crash()
	var sim = main.sim
	# Through the opening as far as the fire being lit.
	sim.search_kit()
	_assert(not sim.gun_dropped, "상자에서는 총이 나오지 않는다")
	_assert(not sim.has_gun, "펼쳐지는 것만으로는 아직이다")

	# The first upgrade. Through the real door, so what the player does is what
	# is being tested.
	sim.stock[Defs.ITEM_HEATSTONE] = sim.stones_to_next()
	main._deposit_at_core()
	_assert(sim.base_level >= 1, "기지가 한 단계 올랐다")
	_assert(sim.gun_dropped, "그때 총이 떨어진다")
	var where := Vector2i(9999, 9999)
	for cell: Vector2i in sim.drops:
		if int(sim.drops[cell]) == Sim.DROP_GUN:
			where = cell
	_assert(where != Vector2i(9999, 9999), "실제로 바닥에 놓인다")
	_assert(Vector2(where - sim.core_cell).length() <= 3.0,
		"기지 옆이다: %s" % str(where))
	_assert(sim.collect_drop(where) == Sim.DROP_GUN and sim.has_gun,
		"주우면 손에 들어온다")

	# And a second upgrade does not put a second one on the snow.
	sim.stock[Defs.ITEM_HEATSTONE] = sim.stones_to_next()
	main._deposit_at_core()
	var guns := 0
	for cell: Vector2i in sim.drops:
		if int(sim.drops[cell]) == Sim.DROP_GUN:
			guns += 1
	_assert(guns == 0, "두 번째 업그레이드는 총을 또 주지 않는다")
