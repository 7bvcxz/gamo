extends SceneTree

## Exercises the state machine of the real Main scene: title, play, pause,
## end-of-run and restart. Running a full five-minute day per check is not
## practical, so the clock is advanced directly.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	# Main loads any save it finds on _ready, and sibling tests leave them behind.
	# Absolute day numbers and a clean factory both depend on starting fresh.
	main.clear_save()
	main._start_run()
	main.finish_tutorial()

	_assert(main.state == main.State.TITLE, "the game opens on the title screen")
	_assert(main.hud.get("main") == main, "the HUD is wired to the orchestrator")
	_assert(main.sim.machine_at(main.sim.core_cell) != null, "the core exists at run start")

	# Any key leaves the title -- into the opening, because this run is new.
	# test_cutscene owns the scene itself; what matters here is that the two
	# presses in a row reach the game, and that the second one is Escape rather
	# than a key that also means something in play.
	_press(main, KEY_SPACE)
	_assert(main.state == main.State.OPENING, "새 게임은 타이틀에서 컷씬으로 간다")
	_press(main, KEY_ESCAPE)
	_assert(main.state == main.State.PLAY, "Esc 로 컷씬을 건너뛰면 게임이다")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS), "the run starts with a full day")
	# 처음부터 builds a fresh world, which is the point of it -- so the state this
	# test set up before pressing it is gone. Everything below is about a running
	# game with things to build, so it is set up again on this side of the door.
	main.finish_tutorial()
	main.debug_unlock_all()

	# Esc opens settings. There is no separate pause screen: settings already
	# stops the world, so a second stopped screen was one more thing to build and
	# keep consistent for behaviour nobody was missing.
	_press(main, KEY_ESCAPE)
	_assert(main.state == main.State.SETTINGS, "Esc opens the settings panel")
	var frozen: float = main.time_left
	main._process(0.5)
	_assert(is_equal_approx(main.time_left, frozen), "and the clock stops while it is up")
	_press(main, KEY_ESCAPE)
	_assert(main.state == main.State.PLAY, "Esc closes it again")
	main._process(0.25)
	_assert(main.time_left < frozen, "the clock runs again afterwards")

	# The two actions the panel now carries. Saving is immediate; restarting asks
	# once, because it is the only button in the game that can destroy a factory
	# and a mis-tap has no undo.
	_press(main, KEY_ESCAPE)
	# Saving and loading both go through a slot list. Which slot holds what is
	# exactly what you need to see whether you are about to write over one or
	# read one, so one list serves both.
	main.settings_save()
	_assert(main.hud.slot_picker == 1, "저장하기 opens the slot list")
	_assert(main.hud.slot_index != 0,
		"and never starts on the autosave, which the timer owns")
	main.confirm_slot(2)
	_assert(main.hud.saved_flash > 0.0, "confirming a slot writes it")
	var cards: Array[Dictionary] = main.slot_cards()
	_assert(cards.size() == main.SAVE_SLOTS, "the list has a row per slot")
	_assert(main.SAVE_SLOTS >= 31, "thirty manual slots plus the autosave")
	# Thirty-one rows do not fit on a card, so the list is a window that follows
	# the cursor. Every visible row has to map back to the right slot number --
	# an off-by-one here overwrites the wrong save, which is unrecoverable.
	main.hud.slot_index = 0
	main.hud.slot_scroll = 0
	main.hud._layout_slots()
	_assert(main.hud.slot_rects.size() == main.hud.slot_page(),
		"the list publishes a rect per visible row, not per slot")
	_assert(main.hud.slot_row_at((main.hud.slot_rects[0] as Rect2).get_center()) == 0,
		"the top row is slot 0 while the window is at the top")
	main.hud.slot_index = main.SAVE_SLOTS - 1
	main.hud._layout_slots()
	_assert(main.hud.slot_scroll > 0, "selecting the last slot scrolls the window")
	var last_row: int = main.hud.slot_rects.size() - 1
	_assert(main.hud.slot_row_at((main.hud.slot_rects[last_row] as Rect2).get_center())
		== main.SAVE_SLOTS - 1,
		"and the bottom row now maps to the last slot")
	_assert(main.hud.slot_row_at(Vector2(-500, -500)) == -1, "a point off the list hits nothing")
	main.hud.slot_index = 1
	main.hud.slot_scroll = 0
	main.hud._layout_slots()
	_assert(bool(cards[2]["exists"]), "slot 2 now holds a save")
	_assert(int(cards[2]["day"]) == main.day_number, "carrying the day it was written on")
	_assert(float(cards[2]["saved_at"]) > 0.0, "and when")
	_assert(main.slot_when(float(cards[2]["saved_at"])) != "", "which reads as a date")
	_assert(not bool(cards[3]["exists"]), "an untouched slot reports empty rather than vanishing")

	# Loading drops straight back into play: a menu that has already done the
	# thing and still needs closing is a menu in the way.
	main.settings_load()
	_assert(main.hud.slot_picker == 2, "불러오기 opens the same list")
	main.confirm_slot(2)
	_assert(main.state == main.State.PLAY, "loading a slot resumes the run")
	_assert(main.hud.slot_picker == 0, "and closes the list")
	_press(main, KEY_ESCAPE)
	main.settings_restart()
	_assert(main.state == main.State.SETTINGS, "처음부터 does not fire on the first press")
	_assert(main.hud.restart_armed > 0.0, "it arms itself and says so")
	main.settings_restart()
	# 처음부터 means from the top: the story of how she got there is part of the
	# beginning, so the run restarts at the first panel of the cutscene and then
	# at the crash. The rest of this file is about the game after all that, so it
	# skips forward again.
	_assert(main.state == main.State.OPENING, "처음부터 는 컷씬부터 다시 시작한다")
	_assert(main.cutscene_panel == 0, "첫 장부터")
	_assert(main.day_number == 1, "at day one")
	_assert(main.mission == main.Mission.BASE, "그리고 오프닝의 첫 임무로 돌아간다")
	_assert(not main.sim.base_placed, "기지도 다시 없다")
	main._end_cutscene()
	main.finish_tutorial()
	_assert(is_zero_approx(main.hud.restart_armed), "and disarms itself afterwards")

	# The row opens on the pickaxe. It used to open on the build gun, from when
	# the game began with a factory standing -- which meant slot one was a tool
	# the player could not use for the first ten minutes.
	_assert(main.holding_pickaxe(), "the run opens with the pickaxe in hand")
	_assert(main.TOOLS[0] == main.TOOL_PICKAXE, "and the pickaxe is slot 1")
	# And slot 2 has to be earned: the gun is an object she picks up off the snow
	# when the fire first grows. Owning it is the whole condition -- it also used
	# to ask whether anything was buildable, and in 1.0.8 that deadlocked, since
	# the miner opens on the gun being held.
	# `finish_tutorial` hands both tools over, so this asks the rule directly:
	# owning the gun is the whole condition for the slot.
	var had_gun: bool = main.sim.has_gun
	main.sim.has_gun = false
	_assert(not main.tool_unlocked(main.TOOL_BUILD_GUN), "총이 없으면 슬롯도 없다")
	main.sim.has_gun = true
	_assert(main.tool_unlocked(main.TOOL_BUILD_GUN),
		"주우면 그때 생긴다 — 지을 것이 있는지는 묻지 않는다")
	main.sim.has_gun = had_gun
	main.sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	main.sim.unlocked[Defs.M_MINER] = true
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	_assert(main.holding_build_gun(), "and it is slot 2 once it is")
	_press(main, KEY_B)
	_assert(main.build_menu_open, "B opens the build menu")
	# Nothing in the list names a material she has never held. Checked as "no row
	# is locked-by-a-material" rather than by counting, so adding a machine to
	# the table cannot quietly reopen the hole.
	for index: int in main.build_list():
		var type: int = Defs.BUILDABLE[index]
		_assert(main.sim.is_unlocked(type) or Defs.machine_previewed(type),
			"본 적 없는 자원의 기계는 목록에 없다: %s" % Defs.MACHINE_NAMES[type])
	# The list only mentions machines the player has a reason to know about. With
	# copper unseen that is the miner alone -- and a cursor in a one-row list has
	# nowhere to go, so the arrows are checked on a list with somewhere to walk.
	_assert(main.build_list().size() == 1,
		"구리를 보기 전에는 채굴기 한 줄뿐이다: %d" % main.build_list().size())
	main.sim.note_resource_seen(Defs.ITEM_COPPER)
	main.sim.power_ever = true
	main.sim._check_unlocks()
	_assert(main.build_list().size() > 1,
		"구리를 본 뒤에 나머지가 나타난다: %d" % main.build_list().size())
	var browse_from: int = main.menu_index
	_press(main, KEY_DOWN)
	_assert(main.menu_index != browse_from, "arrows move the cursor")
	_assert(main.selected_index == browse_from,
		"but browsing does not change what the gun is loaded with")
	_press(main, KEY_B)
	_assert(not main.build_menu_open, "B closes it again")
	_press(main, KEY_B)
	_press(main, KEY_ESCAPE)
	_assert(not main.build_menu_open, "and so does Esc")

	# Loading. Everything is unlocked here so the pick is allowed to land.
	_open(main.sim)
	main.build_menu_open = true
	main.menu_index = 1
	_press(main, KEY_Z)
	_assert(main.selected_type() == Defs.BUILDABLE[1], "Z loads the machine under the cursor")
	_assert(not main.build_menu_open, "and closes the menu")

	# A locked machine can be looked at but not loaded: seeing what is coming is
	# half of why the list exists.
	main.sim.unlocked.clear()
	var was: int = main.selected_index
	main.build_menu_open = true
	main.menu_index = 0
	_press(main, KEY_Z)
	_assert(main.selected_index == was, "a locked machine cannot be loaded")
	_assert(main.build_menu_open,
		"and the menu stays open, so the player can pick something else")
	main.build_menu_open = false
	_open(main.sim)
	var before_dir: Vector2i = main.build_dir
	_press(main, KEY_R)
	_assert(main.build_dir != before_dir, "R rotates the build direction")

	# Mobile: a tap must be able to start the game, pick a machine and rotate it.
	# Without these the pad has no way to reach half the verbs.
	main.state = main.State.TITLE
	_assert(main.touch_anywhere_starts(), "a tap anywhere leaves the title on a phone")
	main.touch_primary()
	_assert(main.state == main.State.OPENING, "폰에서도 타이틀 다음은 컷씬이다")
	# And the pad can get out of it: a phone has no Escape, so tapping through
	# has to reach the game on its own.
	for _tap in Defs.CUTSCENE_PANELS.size():
		main.touch_primary()
	_assert(main.state == main.State.PLAY, "탭으로 끝까지 넘기면 게임이 시작된다")
	# That tap went through the title menu, and 처음부터 builds a fresh world --
	# which is the point of it. Everything below is about a running game with
	# things to build and a fire to stand next to, so it is set up again here.
	main.finish_tutorial()
	_open(main.sim)
	# Including what is in her hand: a fresh run opens on the pickaxe, and the
	# hold-to-rotate below is a build-gun verb.
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	main._process(0.0)
	_assert(main.hud.hotbar_rects.size() == main.TOOLS.size(), "the HUD publishes a rect per tool slot")
	main.selected_index = 0
	# The pad reports raw viewport coordinates while the HUD publishes rects in
	# its own scaled space, so every tap has to cross that boundary. Feeding the
	# rects back in unconverted is what used to hide the bug.
	var to_view := func(rect: Rect2) -> Vector2: return rect.get_center() * main.hud.scale.x
	_assert(main.hud.scale.x > 0.0, "the HUD reports a usable scale")
	_assert(main.hud_local(to_view.call(main.hud.direction_rect))
		.distance_to((main.hud.direction_rect as Rect2).get_center()) < 0.5,
		"viewport coordinates convert back to HUD space")
	# Touch has no B key, so the menu has to be reachable by tapping. Every row
	# is a target; a tap anywhere else closes it.
	main.build_menu_open = true
	main._process(0.0)
	var row: Rect2 = main.hud.build_menu_row_rect(1)
	_assert(main.hud.build_menu_row_at(row.get_center()) == 1, "menu rows are hit-testable")
	_assert(main.touch_hud(row.get_center() * main.hud.scale.x), "tapping a row is handled")
	_assert(main.selected_index == 1, "and loads that machine")
	_assert(not main.build_menu_open, "closing the menu behind it")
	var dir_before: Vector2i = main.build_dir
	_assert(main.touch_hud(to_view.call(main.hud.direction_rect)),
		"tapping the direction chip is handled")
	_assert(main.build_dir != dir_before, "tapping the direction chip rotates the output")
	_assert(not main.touch_hud(Vector2(-500, -500)), "taps outside the HUD fall through to the pad")

	# Touch and keyboard must share one interaction path, or a verb added for the
	# keyboard silently goes missing on phones.
	main.state = main.State.PLAY
	main.sim.grant_cats(1)
	_assert(main.sim.cats.size() >= 1, "a cat exists to be carried")
	var kitty = main.sim.cats[0]
	# Interaction targets the faced tile, not the one underfoot.
	kitty.pos = main.sim.cell_centre(main.player.facing_cell())
	# With the pickaxe in hand. The build gun outranks a cat as of 1.0.8 -- a
	# player aiming a gun at a cell they can build on has said what they mean --
	# so with the gun selected this tap would put a machine down instead, which
	# is the rule below rather than a failure here.
	main.tool_index = 0
	main.touch_primary()
	_assert(main.sim.carried_cat == kitty, "a touch tap can pick up a cat")
	main.touch_primary()
	_assert(main.sim.carried_cat == null, "a second tap puts it down again")

	# And the rule itself: gun in hand, buildable cell, cat standing on it.
	main.tool_index = 1
	main.selected_index = 0
	var spot: Vector2i = main.player.facing_cell()
	main.sim.ore[spot] = Defs.ITEM_HEATSTONE
	main.sim.machines.erase(spot)
	main.sim.unlocked[Defs.M_MINER] = true
	main.sim.stock[Defs.ITEM_HEATSTONE] = 50
	kitty.pos = main.sim.cell_centre(spot)
	main.touch_primary()
	_assert(main.sim.machine_at(spot) != null, "건설총을 들었으면 고양이가 있어도 건설한다")
	_assert(main.sim.carried_cat == null, "그리고 고양이를 들지 않는다")

	# Z builds and does nothing else. Holding it used to turn the ghost a quarter
	# turn every 0.4 seconds, which made one key mean two things -- and the second
	# arrived by accident, since a Z held a moment too long is an ordinary way to
	# press a key. R turns, and only R.
	main.state = main.State.PLAY
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	var dir_start: Vector2i = main.build_dir
	main.build_held = true
	# A full second of real frames, two and a half times the threshold the old
	# rotate-on-hold used. Driven through `_process` rather than through the
	# helper it used to call: that helper was emptied in 1.0.25 and deleted in
	# 1.0.29, and a test that holds a key by calling one function only ever
	# proves that one function is quiet.
	for step in 10:
		main._process(0.1)
	_assert(main.build_dir == dir_start, "Z 를 아무리 오래 눌러도 방향은 그대로다")
	main.build_held = false
	_press(main, KEY_R)
	_assert(main.build_dir != dir_start, "R 이 방향을 돌린다")
	_assert(main.sim.has_learned("ROTATE"), "그리고 한 번 돌리면 안내는 끝난다")

	# Night: the warm pool alone must stop being enough, which is what sends the
	# player indoors instead of camping next to the core.
	_open(main.sim)
	main.sim.build(Defs.M_BELT, Vector2i(0, 2), Vector2i.UP)
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	_assert(main.is_night(), "night begins before the clock runs out")
	main.player.position = Vector2(main.sim.core_cell) * float(Defs.TILE)
	_assert(main.sim.is_warm(main.player.cell()), "the test stands the player inside the warm radius")
	main.player.warmth = 100.0
	main._update_warmth(1.0)
	_assert(main.player.warmth < 100.0, "at night even the warm radius loses body heat")

	# Standing at the shelter slows the loss but does not stop it.
	main.player.position = main.shelter_position()
	_assert(main.shelter_nearby(), "the shelter is reachable beside the core")
	var near_loss: float = main.player.warmth
	main._update_warmth(1.0)
	_assert(main.player.warmth < near_loss, "the shelter porch is still cold")
	_assert(main.sleep_available(), "Z offers sleep once night has fallen and you are home")

	main.sim.stones_in = 140
	main._sleep()
	# Bedtime is a sequence now, not a cut: the workforce walks home and the hut
	# lights up before the summary appears.
	_assert(main.state == main.State.NIGHTFALL, "sleeping starts the night sequence")
	_assert(main.indoors() or main.night_phase == main.Phase.GATHER,
		"and it opens with everyone still walking home")
	_assert(_settle(main, main.State.RESULT), "the night sequence ends on the day summary")
	_assert(main.day_stones() == 140, "the summary reports what this day earned")
	_assert(main.player.locked, "the player is locked while the day summary is up")

	# Continuing must carry the world forward, not restart it: that is the whole
	# point of days accumulating.
	var radius_before: float = main.sim.warm_radius
	_press(main, KEY_ENTER)
	_assert(main.state == main.State.DAYBREAK, "Enter opens the morning sequence")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS),
		"the clock is already reset while the sun comes up")
	_assert(main.night_level() > 0.5,
		"but the world is still dark, because the clock cannot say what the sky is doing")
	_assert(_settle(main, main.State.PLAY), "and hands control back once it is morning")
	_assert(is_zero_approx(main.night_level()), "morning is fully lit")
	_assert(main.day_number == 2, "the day counter advances")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS), "the new day has a full clock")
	_assert(main.sim.stones_in == 140, "cumulative stones carry into the next day")
	_assert(is_equal_approx(main.sim.warm_radius, radius_before), "the warm radius carries over")
	_assert(main.sim.machine_at(Vector2i(0, 2)) != null, "the factory survives the night")
	_assert(not main.player.locked, "the player can move again in the morning")
	_assert(main.day_stones() == 0, "the daily total starts fresh each morning")

	# The morning card lists what the day brought in, material by material. It
	# used to lead with lifetime totals, which is a ledger rather than a report:
	# the number that says whether a day was any good is what came out of the
	# ground on it.
	_assert(main.day_collected().is_empty(), "새 아침에는 아직 모은 것이 없다")
	main.sim._gain(Defs.ITEM_HEATSTONE, 4)
	main.sim._gain(Defs.ITEM_COPPER, 2)
	var report: Array = main.day_collected()
	_assert(report.size() == 2, "모은 자원만 줄이 생긴다: %d" % report.size())
	var lines := {}
	for entry: Array in report:
		lines[int(entry[0])] = int(entry[1])
	_assert(int(lines.get(Defs.ITEM_HEATSTONE, 0)) == 4, "열석 4")
	_assert(int(lines.get(Defs.ITEM_COPPER, 0)) == 2, "구리 2")
	# Spending does not erase the day's work: the report counts gains, and a day
	# where she mined forty and built with forty is not an empty day.
	main.sim.stock[Defs.ITEM_HEATSTONE] = 0
	_assert(main.day_collected().size() == 2, "쓴 것과 모은 것은 다른 이야기다")

	# Daytime inside the warm radius must still recover heat, or the night rule
	# would simply be a permanent drain.
	main.player.position = Vector2(main.sim.core_cell) * float(Defs.TILE)
	main.player.warmth = 50.0
	main._update_warmth(1.0)
	_assert(main.player.warmth > 50.0, "daylight inside the warm radius restores body heat")
	_assert(not main.sleep_available(), "you cannot go to bed in the middle of the day")

	# A second day counts only its own earnings, and nothing anywhere keeps a
	# record of the best one. The best-day and best-total counters were removed
	# on 2026-08-14 when the game was settled as long-form: a high score is an
	# instruction to replay the day, which is the opposite of what this game
	# asks for.
	main.sim.stones_in = 160
	main.time_left = 0.05
	main._process(0.2)
	_assert(main.day_stones() == 20, "the second day counts only its own earnings")
	_assert(_settle(main, main.State.RESULT), "running out of time also plays the night out")
	_assert(not ("best_day_stones" in main), "최고 하루 기록이 남아 있지 않다")
	_assert(not ("best_heat" in main), "최고 누적 기록이 남아 있지 않다")

	# The summary card cannot throw the run away.
	#
	# It used to: N started a fresh game from here, one keypress, no confirmation.
	# This is the screen a player presses through at the end of every day without
	# reading it, which makes it the worst place in the game for that key --
	# starting over lives in settings, where it asks twice. The line is gone and
	# so is the key, because leaving the key with the label removed is the worse
	# of the two: a run lost with nothing on screen to explain it.
	var day_before: int = main.day_number
	var stones_before: int = main.sim.stones_in
	_press(main, KEY_N)
	_assert(main.state == main.State.RESULT, "정산 화면에서 N은 아무 일도 하지 않는다")
	_assert(main.day_number == day_before, "날짜가 되돌아가지 않는다")
	_assert(main.sim.stones_in == stones_before, "불에 넣은 열석이 사라지지 않는다")
	_assert(main.sim.machine_at(Vector2i(0, 2)) != null, "공장이 그대로 남는다")

	if failures == 0:
		print("FLOW_TEST: PASS")
	quit(failures)

## Runs the night sequence forward until it reaches the state being waited for.
## The sequence advances on _process, so a test cannot skip it by calling the
## transition directly -- and it must not be able to, since the point of every
## phase having a timeout is that the sequence always terminates.
func _settle(main: Node2D, want: int) -> bool:
	for step in 500:
		if main.state == want:
			return true
		main._process(0.05)
	return main.state == want

func _press(main: Node2D, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	main._unhandled_input(event)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FLOW_TEST: FAIL - " + message)
		failures += 1

## Machines are bought with materials from an unlocked hotbar, so a test that
## wants to build has to open and fund the base first.
func _open(sim) -> void:
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	sim.unlocked[Defs.M_MINER] = true
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.power_ever = true
	sim._check_unlocks()
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
