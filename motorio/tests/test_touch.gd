extends SceneTree

## The touch layer, driven through the same entry points a thumb uses.
##
## This exists because a phone could not mine. The hotbar row used to hold
## machines and the tap handler set `selected_index` accordingly; when the
## pickaxe arrived the row became tools and the keyboard moved to `tool_index`,
## but the tap handler did not. On a phone the pickaxe could therefore never be
## held -- and hand mining checks holding_pickaxe() before anything else, so the
## first thing the game asks for was unobtainable. Every desktop test passed the
## whole time, because every one of them sets tool_index directly.
##
## So the rule this file holds is: touch and keyboard must arrive at the same
## state, and the checks go through touch_hud() rather than through the
## variables it is supposed to set.

var failures := 0

func _init() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	# The pad is hidden on a desktop; the hit-testing does not care, but the HUD
	# lays itself out differently, so it is switched on for the layout to match
	# what a phone gets.
	main.touch.set_controls_visible(true)
	main.hud._apply_scale()
	main.hud._layout()

	_tools(main)
	_mining(main)
	_gacha_button(main)
	_same_as_keyboard(main)

	print("TOUCH: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## Tapping the row picks a tool, the same tool the number key would pick.
func _tools(main: Node2D) -> void:
	var rects: Array[Rect2] = main.hud.hotbar_rects
	_check(rects.size() == main.TOOLS.size(),
		"핫바 칸이 도구 수와 같다: %d / %d" % [rects.size(), main.TOOLS.size()])
	if rects.size() < 2:
		return
	var loaded_before: int = main.selected_index

	_tap(main, rects[main.TOOL_PICKAXE].get_center())
	_check(main.tool_index == main.TOOL_PICKAXE,
		"곡괭이 칸을 누르면 곡괭이를 든다: tool_index=%d" % main.tool_index)
	_check(main.holding_pickaxe(), "그리고 holding_pickaxe()가 참이다")
	_check(main.selected_index == loaded_before,
		"장전된 기계는 건드리지 않는다: %d" % main.selected_index)

	_tap(main, rects[main.TOOL_BUILD_GUN].get_center())
	_check(main.tool_index == main.TOOL_BUILD_GUN, "건설총 칸을 누르면 건설총을 든다")
	_check(main.holding_build_gun(), "그리고 holding_build_gun()이 참이다")

	# Tapping the tool already in hand opens what it chooses from. Without this a
	# phone cannot reach the build list at all -- there is no B key on it.
	_check(not main.build_menu_open, "아직 목록은 닫혀 있다")
	_tap(main, rects[main.TOOL_BUILD_GUN].get_center())
	_check(main.build_menu_open, "이미 든 건설총을 다시 누르면 건설 목록이 열린다")
	main.build_menu_open = false

	# The pickaxe chooses from nothing, so tapping it twice must not open a menu.
	_tap(main, rects[main.TOOL_PICKAXE].get_center())
	_tap(main, rects[main.TOOL_PICKAXE].get_center())
	_check(not main.build_menu_open, "곡괭이를 두 번 눌러도 목록은 열리지 않는다")

## The mine button is a hold, and the whole chain from it to a swing has to work
## with the pickaxe selected the way a phone selects it.
func _mining(main: Node2D) -> void:
	var sim: Sim = main.sim
	sim.setup(4242)
	var seam: Vector2i = Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) == Defs.ITEM_CRYSTAL:
			seam = cell
			break
	_check(seam != Vector2i(9999, 9999), "수정 광맥이 있다")
	if seam == Vector2i(9999, 9999):
		return
	# Stand one cell south of the seam, facing it, exactly as a player would.
	main.player.position = sim.cell_centre(seam + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	main.player.locked = false

	# Pick the pickaxe the way a phone does, not by assignment.
	main.hud._layout()
	_tap(main, (main.hud.hotbar_rects[main.TOOL_PICKAXE] as Rect2).get_center())
	_check(main.holding_pickaxe(), "터치로 곡괭이를 들었다")

	# Through the pad button rather than the controller method, because the wiring
	# between them is the thing that was wrong: the pad sent Z as a press with no
	# hold, so mining -- which is a hold -- could not be done with it at all, and
	# a separate 캐기 button did the holding.
	main.touch._press_button(1, true)
	_check(main.mine_held, "Z 버튼이 눌린 상태가 된다")
	main._update_hand_mining(0.5)
	_check(sim.hand_progress > 0.0,
		"그리고 실제로 캐기 시작한다: 진행 %.2f" % sim.hand_progress)

	# Long enough to finish a swing, in the same per-frame path the game uses.
	for _frame in 30:
		main._update_hand_mining(0.5)
	_check(int(sim.stock.get(Defs.ITEM_CRYSTAL, 0)) > 0 or not sim.ground.is_empty(),
		"수정조각이 나온다: 보유 %d, 바닥 %d"
		% [int(sim.stock.get(Defs.ITEM_CRYSTAL, 0)), sim.ground.size()])

	main.touch._press_button(1, false)
	_check(not main.mine_held, "손을 떼면 멈춘다")
	main._update_hand_mining(0.1)
	_check(is_zero_approx(main.player.mining), "스윙도 멈춘다")

## The pad says what the keyboard says.
##
## Not a comparison of labels -- a comparison of what each button does. The pad
## used to carry a verb no key had, and a phone player following the game's own
## hint ("press Z") found that Z did half of what it says on a desktop.
func _same_as_keyboard(main: Node2D) -> void:
	var sim = main.sim
	main.state = main.State.PLAY
	main.player.locked = false
	var labels: Array = TouchControls.BUTTON_LABELS
	_check(labels.size() == 4 and labels[1] == "Z" and labels[2] == "X" and labels[3] == "C",
		"버튼이 Run/Z/X/C다: %s" % str(labels))

	# C opens the panel and does not dig, exactly as on a keyboard.
	var machine_cell := Vector2i(9999, 9999)
	for cell: Vector2i in sim.machines:
		machine_cell = cell
		break
	if machine_cell != Vector2i(9999, 9999):
		main.player.position = sim.cell_centre(machine_cell + Vector2i(0, 1))
		main.player.facing = Vector2i.UP
		main.meter_cell = Vector2i(9999, 9999)
		main.mine_held = false
		main.touch._press_button(3, true)
		_check(main.meter_cell == machine_cell, "C 버튼이 계기를 연다")
		_check(not main.mine_held, "그리고 캐기를 시작하지 않는다")
		main.touch._press_button(3, false)
		main.touch._press_button(3, true)
		_check(main.meter_cell == Vector2i(9999, 9999), "다시 누르면 닫힌다")
		main.touch._press_button(3, false)

	# X demolishes, which is what X does on a keyboard.
	main.tool_index = main.TOOL_BUILD_GUN
	var spare: Vector2i = sim.core_cell + Vector2i(7, 7)
	sim.machines.erase(spare)
	sim.unlocked[Defs.M_BELT] = true
	sim.stock[Defs.ITEM_COPPER] = 500
	if sim.build(Defs.M_BELT, spare, Vector2i.RIGHT):
		main.player.position = sim.cell_centre(spare + Vector2i(0, 1))
		main.player.facing = Vector2i.UP
		main.touch._press_button(2, true)
		_check(sim.machine_at(spare) == null, "X 버튼이 설비를 회수한다")

## The corner button a thumb reaches for, on both sides of the switch.
##
## The slot machine is off for the Vertical Slice and kept in the code, and a
## half-removed feature usually shows up exactly here: the key stops working, the
## legend stops mentioning it, and the button is still sitting in the corner
## waiting for a thumb. So this checks that it is gone, and then that it comes
## back working when the switch is flipped.
func _gacha_button(main: Node2D) -> void:
	var was: bool = Defs.GACHA_ENABLED

	Defs.GACHA_ENABLED = false
	main.hud._layout()
	main.gacha_open = false
	var absent: Rect2 = main.hud.gacha_button_rect
	_check(absent.size.x <= 0.0, "꺼져 있으면 버튼 자리가 없다: %s" % absent)
	# The corner it used to own. A tap there must fall through to the world
	# rather than opening a window that is supposed to be gone.
	_tap(main, Vector2(main.hud.MARGIN + 20.0, main.hud.size.y - main.hud.bottom_reserved() - 20.0))
	_check(not main.gacha_open, "꺼져 있으면 그 자리를 눌러도 열리지 않는다")

	Defs.GACHA_ENABLED = true
	main.hud._layout()
	_tap(main, (main.hud.gacha_button_rect as Rect2).get_center())
	_check(main.gacha_open, "켜면 가챠 버튼을 눌러 창이 열린다")
	# The pad must not be sitting on top of it.
	var reserved: float = main.hud.bottom_reserved()
	_check((main.hud.gacha_button_rect as Rect2).end.y <= main.hud.size.y - reserved + 0.01,
		"버튼이 엄지 버튼들 위에 있다")

	main.gacha_open = false
	Defs.GACHA_ENABLED = was
	main.hud._layout()

## A tap in HUD-local coordinates, converted back to the viewport the way a real
## touch arrives, so hud_local() is exercised rather than bypassed.
func _tap(main: Node2D, local: Vector2) -> void:
	main.touch_hud(local * maxf(main.hud.scale.x, 0.01))

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	print("  FAIL: ", message)
	failures += 1
