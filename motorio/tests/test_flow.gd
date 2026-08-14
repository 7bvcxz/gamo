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

	_assert(main.state == main.State.TITLE, "the game opens on the title screen")
	_assert(main.hud.get("main") == main, "the HUD is wired to the orchestrator")
	_assert(main.sim.machine_at(main.sim.core_cell) != null, "the core exists at run start")

	# Any key starts the run.
	_press(main, KEY_SPACE)
	_assert(main.state == main.State.PLAY, "any key leaves the title screen")
	_assert(is_equal_approx(main.time_left, Defs.DAY_SECONDS), "the run starts with a full day")

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
	_assert(main.state == main.State.PLAY, "the second press starts a new run")
	_assert(main.day_number == 1, "at day one")
	_assert(is_zero_approx(main.hud.restart_armed), "and disarms itself afterwards")

	# The build gun. Slot 1 is a tool, not a machine, and what it is loaded with
	# is chosen from its menu -- the old five-machine hotbar had no room to say
	# what any of them did.
	_assert(main.holding_build_gun(), "the run opens with the build gun in hand")
	_press(main, KEY_B)
	_assert(main.build_menu_open, "B opens the build menu")
	var browse_from: int = main.selected_index
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
	_assert(main.state == main.State.PLAY, "touch start actually begins the run")
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
	main.sim.carried_boxes = Defs.BOXES_PER_CAT
	main.sim.adopt_cats()
	_assert(main.sim.cats.size() >= 1, "a cat exists to be carried")
	var kitty = main.sim.cats[0]
	# Interaction targets the faced tile, not the one underfoot.
	kitty.pos = main.sim.cell_centre(main.player.facing_cell())
	main.touch_primary()
	_assert(main.sim.carried_cat == kitty, "a touch tap can pick up a cat")
	main.touch_primary()
	_assert(main.sim.carried_cat == null, "a second tap puts it down again")

	# Z is tap-to-build, hold-to-rotate on PC. Nothing may happen on press alone,
	# or a held key would build and rotate at once.
	main.state = main.State.PLAY
	var dir_start: Vector2i = main.build_dir
	main.build_held = true
	main.build_hold_time = 0.0
	main.build_rotated = false
	main._update_build_hold(0.2)
	_assert(main.build_dir == dir_start, "a short hold has not rotated yet")
	_assert(not main.build_rotated, "and the tap is still eligible to build")
	main._update_build_hold(0.25)
	_assert(main.build_dir != dir_start, "passing the threshold rotates the output")
	_assert(main.build_rotated, "a rotated hold is marked so release does not also build")
	# Holding keeps turning: one quarter turn per interval, so the far side is
	# reachable without four separate presses.
	var dir_after: Vector2i = main.build_dir
	main._update_build_hold(0.4)
	_assert(main.build_dir != dir_after, "holding past another interval turns again")
	# Three more quarter turns complete the circle back to where it was.
	main._update_build_hold(1.2)
	_assert(main.build_dir == dir_after, "four intervals bring the direction full circle")
	main.build_held = false

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

	main.sim.total_heat = 140
	main._sleep()
	# Bedtime is a sequence now, not a cut: the workforce walks home and the hut
	# lights up before the summary appears.
	_assert(main.state == main.State.NIGHTFALL, "sleeping starts the night sequence")
	_assert(main.indoors() or main.night_phase == main.Phase.GATHER,
		"and it opens with everyone still walking home")
	_assert(_settle(main, main.State.RESULT), "the night sequence ends on the day summary")
	_assert(main.day_heat() == 140, "the summary reports what this day earned")
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
	_assert(main.sim.total_heat == 140, "cumulative heat carries into the next day")
	_assert(is_equal_approx(main.sim.warm_radius, radius_before), "the warm radius carries over")
	_assert(main.sim.machine_at(Vector2i(0, 2)) != null, "the factory survives the night")
	_assert(not main.player.locked, "the player can move again in the morning")
	_assert(main.day_heat() == 0, "the daily total starts fresh each morning")

	# Daytime inside the warm radius must still recover heat, or the night rule
	# would simply be a permanent drain.
	main.player.position = Vector2(main.sim.core_cell) * float(Defs.TILE)
	main.player.warmth = 50.0
	main._update_warmth(1.0)
	_assert(main.player.warmth > 50.0, "daylight inside the warm radius restores body heat")
	_assert(not main.sleep_available(), "you cannot go to bed in the middle of the day")

	# A weaker second day must not lower the recorded best day.
	main.sim.total_heat = 160
	main.time_left = 0.05
	main._process(0.2)
	_assert(main.day_heat() == 20, "the second day counts only its own earnings")
	_assert(_settle(main, main.State.RESULT), "running out of time also plays the night out")
	_assert(main.best_day_heat == 140, "a worse day does not overwrite the best day")

	# The summary card cannot throw the run away.
	#
	# It used to: N started a fresh game from here, one keypress, no confirmation.
	# This is the screen a player presses through at the end of every day without
	# reading it, which makes it the worst place in the game for that key --
	# starting over lives in settings, where it asks twice. The line is gone and
	# so is the key, because leaving the key with the label removed is the worse
	# of the two: a run lost with nothing on screen to explain it.
	var day_before: int = main.day_number
	var heat_before: int = main.sim.total_heat
	_press(main, KEY_N)
	_assert(main.state == main.State.RESULT, "정산 화면에서 N은 아무 일도 하지 않는다")
	_assert(main.day_number == day_before, "날짜가 되돌아가지 않는다")
	_assert(main.sim.total_heat == heat_before, "모아둔 열이 사라지지 않는다")
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
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
	sim.stock[Defs.ITEM_ENERGY] = 500
