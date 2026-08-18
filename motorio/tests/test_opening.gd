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
	_test_feeding_the_fire()
	_test_save_mid_opening()
	_test_finish_tutorial()
	if failures == 0:
		print("PASS test_opening")
	else:
		print("FAIL test_opening (%d)" % failures)
	quit(failures)


## Search the case and pick up everything it dropped. The opening is two searches
## and four objects on the snow; every test below this one is about what happens
## *after* that, so it is done in one line rather than four every time.
func _empty_kit(sim) -> void:
	sim.search_kit()
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
	# The case tips onto the snow rather than into her hands. The first thing the
	# game ever gives the player used to arrive as a word in the corner of the
	# screen; two objects lying below the case are two things to walk over, and
	# picking a thing up is how you find out what it is.
	# The ground below the case, cleared. Where the seams fall is seeded and the
	# run seed is different every time, so on some worlds the four cells under the
	# case are taken and the drops legitimately go beside it instead -- which made
	# this a test that failed about one run in five for a reason that was not the
	# thing being tested. What is being tested is the preference, so the
	# preference is given somewhere to go.
	for offset: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(-1, 2)]:
		sim.ore.erase(sim.kit_cell + offset)
		sim.mined_rocks[sim.kit_cell + offset] = true
	# One thing, and it is the fire. The build gun used to come out at the same
	# moment, which put a tool she cannot use for another ten minutes -- nothing
	# to build and nothing to build it with -- beside the one object the opening
	# is about, and made the first thing she ever sees a choice of two.
	var first: Array[int] = sim.search_kit()
	_assert(first.size() == 1, "첫 조사에서 하나만 떨어진다: %d" % first.size())
	_assert(_kit_always_gives(), "그리고 200회차 모두 무언가가 나온다")
	_assert(first.has(Sim.DROP_KIT_BASE), "긴급기지키트다")
	_assert(not first.has(Sim.DROP_GUN), "건설총은 아직 나오지 않는다")
	_assert(sim.carried_kit == Defs.KIT_NONE, "아직 손에는 아무것도 없다")
	_assert(not sim.has_gun, "줍기 전에는 총도 없다")
	_assert(sim.drops.size() == 1, "바닥에 하나가 놓여 있다")
	# Below the case, which is where she is standing to face it.
	for cell: Vector2i in sim.drops:
		_assert(cell.y > sim.kit_cell.y, "상자 아래쪽에 떨어진다: %s" % str(cell))

	var second: Array[int] = sim.search_kit()
	_assert(second.size() == 3, "두 번째 조사에서 셋이 더 떨어진다: %d" % second.size())
	_assert(second.has(Sim.DROP_KIT_SHELTER) and second.has(Sim.DROP_PICKAXE)
		and second.has(Sim.DROP_GUN), "긴급숙소키트와 곡괭이와 건설총이다")
	_assert(sim.search_kit().is_empty(), "세 번째는 없다 — 빈 상자다")

	# Picking them up is what grants them.
	for cell: Vector2i in sim.drops.keys():
		var kind: int = int(sim.drops[cell])
		if kind == Sim.DROP_GUN:
			_assert(sim.collect_drop(cell) == Sim.DROP_GUN, "총을 줍는다")
			_assert(sim.has_gun, "그때 총이 생긴다")
		elif kind == Sim.DROP_PICKAXE:
			_assert(sim.collect_drop(cell) == Sim.DROP_PICKAXE, "곡괭이를 줍는다")
			_assert(sim.has_pickaxe, "그때 곡괭이가 생긴다")
	# Both hands: a kit cannot be scooped up while something is already in them.
	sim.carried_frozen = true
	for cell: Vector2i in sim.drops.keys():
		_assert(sim.collect_drop(cell) == -1, "손이 차 있으면 키트는 못 줍는다")
	sim.carried_frozen = false
	for cell: Vector2i in sim.drops.keys():
		_assert(sim.collect_drop(cell) >= 0, "손이 비면 줍는다")
		break
	_assert(sim.kit_searched == 2, "두 번 뒤진 것으로 남는다")

# --- Putting the fire down --------------------------------------------------

func _test_placing_the_base() -> void:
	_crash()
	var sim = main.sim
	var crash: Vector2i = sim.core_cell
	_empty_kit(sim)
	_assert(not sim.place_base(crash + Vector2i(6, 0)),
		"추락 지점에서 멀면 놓을 수 없다")
	_assert(not sim.base_placed, "그래서 아직 불이 없다")
	var chosen: Vector2i = crash + Vector2i(1, 1)
	_assert(sim.place_base(chosen), "%d칸 안이면 놓을 수 있다" % int(Defs.BASE_PLACE_RADIUS))
	_assert(sim.base_placed and sim.machine_at(chosen) != null, "코어가 그 자리에 선다")
	# The base is the centre of everything the world already has, so it takes
	# those with it rather than leaving them behind at the crash site.
	_assert(sim.core_cell == chosen, "세계의 중심이 그리로 옮겨간다")
	_assert(sim.shelter_cell == chosen + Defs.SHELTER_CELL, "거처 자리도 따라온다")
	_assert(sim.is_warm(chosen), "이제 그 자리가 따뜻하다")
	_assert(sim.warm_radius >= Defs.WARM_BASE,
		"온기 반경이 열린다 (%.1f칸)" % sim.warm_radius)
	_assert(sim.carried_kit == Defs.KIT_NONE, "손이 비었다")
	_assert(not sim.place_base(chosen + Vector2i(1, 0)), "두 번째 기지는 없다")

# --- And the hut ------------------------------------------------------------

func _test_placing_the_shelter() -> void:
	_crash()
	var sim = main.sim
	_empty_kit(sim)
	sim.place_base(sim.core_cell)
	sim.carried_kit = Defs.KIT_NONE
	_empty_kit(sim)
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
	_empty_kit(sim)
	sim.place_base(sim.core_cell)
	main._advance_mission()
	_assert(main.mission == main.Mission.SURVIVE, "2. 생존 준비")
	sim.carried_kit = Defs.KIT_NONE
	_empty_kit(sim)
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
	_empty_kit(main.sim)
	seen[String(main.objective_data()["text"])] = true
	main.sim.place_base(main.sim.core_cell)
	main._advance_mission()
	seen[String(main.objective_data()["text"])] = true
	main.sim.carried_kit = Defs.KIT_NONE
	_empty_kit(main.sim)
	seen[String(main.objective_data()["text"])] = true
	_assert(seen.size() == 4, "네 상황이 네 가지 문구를 낸다 (%d)" % seen.size())

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
	_empty_kit(sim)
	var chosen: Vector2i = sim.core_cell + Vector2i(1, 0)
	sim.place_base(chosen)
	main._advance_mission()
	sim.carried_kit = Defs.KIT_NONE
	_empty_kit(sim)
	main.player.warmth = 44.0
	_assert(main.save_game(false), "오프닝 도중에 저장된다")

	main._start_run()
	main.finish_tutorial()
	_assert(main.load_game(), "다시 불러온다")
	_assert(main.mission == main.Mission.SURVIVE, "임무 2로 돌아온다")
	_assert(main.sim.base_placed and not main.sim.shelter_placed,
		"기지는 서 있고 거처는 아직 없다")
	# The one that would have gone wrong quietly: the base moves the centre of
	# the world, so a save that forgot where it went would put the fog, the hut's
	# spot and the ore rings somewhere other than the fire on screen.
	_assert(main.sim.core_cell == chosen, "옮겨 놓은 기지 자리가 살아난다")
	_assert(main.sim.machine_at(chosen) != null, "그 자리에 코어가 있다")
	_assert(main.sim.carried_kit == Defs.KIT_SHELTER, "손에 든 거처도 그대로다")
	_assert(main.sim.kit_searched == 2, "상자를 두 번 뒤진 것도")
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
	_assert(sim.kit_searched == 2, "상자는 비어 있다")
	_assert(sim.carried_kit == Defs.KIT_NONE, "손에는 아무것도 없다")
	_assert(is_equal_approx(main.player.warmth, 100.0), "체온은 가득이다")


## The case has to open on every world.
##
## Its contents used to land on one of eight cells and nowhere else, so a boulder
## cluster over the case meant the search came back empty: no fire, and a run
## that cannot be started. One seed proves nothing about that -- the map is
## different every time and most maps are fine -- so this walks two hundred.
func _kit_always_gives() -> bool:
	var empty := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(70000 + index)
		sim.begin_crash()
		if sim.search_kit().size() != 1 or sim.drops.size() != 1:
			empty += 1
		sim.free()
	if empty > 0:
		print("   상자가 빈 회차: %d/200" % empty)
	return empty == 0
