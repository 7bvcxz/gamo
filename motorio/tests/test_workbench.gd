extends SceneTree

## The fire's window as a small workbench (1.0.42).
##
## The window is the same interface as the rest of the HUD -- HudStyle's plate,
## row, badge and gaps -- and each row says what state it is in. Things made once
## leave the list the moment they exist and go to the "만든 것" line, and that is
## read from the world, so it survives a save without a key of its own. Starting
## a make says nothing in the middle of the screen: the fire wears a ring, and
## the ring leaves a pulse when it fills.

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
	_test_workbench_uses_shared_theme()
	_test_workbench_recipe_states()
	_test_one_time_recipe_disappears_after_completion()
	_test_craft_has_no_center_progress_text()
	_test_base_shows_world_craft_progress()
	_test_save_load_preserves_one_time_recipe_completion()
	main.clear_save()
	if failures == 0:
		print("PASS test_workbench")
	else:
		print("FAIL test_workbench (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _body(source: String, name: String) -> String:
	var start: int = source.find("func %s(" % name)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + 1)
	return source.substr(start, (next if next > 0 else source.length()) - start)

func _craft_index(id: String) -> int:
	for index in Defs.BASE_CRAFTS.size():
		if String(Defs.BASE_CRAFTS[index]["id"]) == id:
			return index
	return -1

func _offered(id: String) -> bool:
	for row: Dictionary in main.base_rows():
		if String(row["kind"]) == "craft" \
				and String(Defs.BASE_CRAFTS[int(row["craft"])]["id"]) == id:
			return true
	return false

## A run with the fire just lit: the window holds the shelter and nothing else.
func _fire() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.sim.search_kit()
	main.messages.clear()

func _run_seconds(seconds: float) -> void:
	var step: float = 1.0 / 30.0
	var left: float = seconds
	while left > 0.0:
		main._process_play(step)
		left -= step

func _stand_hut() -> void:
	for cell: Vector2i in main.sim.drops.keys():
		if int(main.sim.drops[cell]) == Sim.DROP_KIT_SHELTER:
			main.sim.drops.erase(cell)
	main.sim.carried_kit = Defs.KIT_NONE
	main.sim.shelter_placed = true
	main.sim.shelter_cell = main.sim.core_cell + Defs.SHELTER_CELL

# --- test_workbench_uses_shared_theme ------------------------------------------

func _test_workbench_uses_shared_theme() -> void:
	var hud: String = _source("res://scripts/HUD.gd")
	for name: String in ["_draw_base_menu", "_draw_base_row"]:
		var body: String = _body(hud, name)
		_assert(body != "", "%s 가 있다" % name)
		_assert(not body.contains("draw_rect(") and not body.contains("_panel("),
			"%s 는 판을 직접 그리지 않는다" % name)
		_assert(body.contains("HudStyle."), "%s 는 HudStyle 을 지난다" % name)
	# The same plate every window uses, and the same lit plate the hand slot uses.
	_assert(_body(hud, "_draw_base_menu").contains("_frame("), "창 테두리는 공용 _frame 이다")
	_assert(_body(hud, "_draw_base_row").contains("HudStyle.BUTTON_ON"),
		"고른 줄은 공용 강조 판이다")
	_assert(_body(hud, "_draw_base_row").contains("HudStyle.badge"), "상태는 공용 배지다")
	# No numbers of its own: the width and row are HudStyle tokens.
	_fire()
	main._open_base_menu()
	var hudnode = main.hud
	hudnode._layout()
	var card: Rect2 = hudnode.base_menu_rect()
	_assert(card.size.x <= HudStyle.WINDOW_W_SMALL + 0.5, "작은 창이다 (%.0f)" % card.size.x)
	var row: Rect2 = hudnode.base_menu_row_rect(0)
	_assert(is_equal_approx(row.size.y + 2.0, HudStyle.ROW_LARGE), "줄 높이는 공용 토큰이다")
	_assert(card.size.y < hudnode.size.y * 0.6, "화면 대부분을 가리지 않는다")
	for index in main.base_rows().size():
		_assert(card.encloses(hudnode.base_menu_row_rect(index)), "%d 번 줄이 창 안에 있다" % index)
	# Every craft row names its own picture, so no row borrows the torch again.
	for craft: Dictionary in Defs.BASE_CRAFTS:
		_assert(String(craft.get("icon", "")) != "", "%s 에 제 그림이 있다" % String(craft["id"]))
	main.close_base_menu()

# --- test_workbench_recipe_states ------------------------------------------------

func _test_workbench_recipe_states() -> void:
	_fire()
	var shelter: int = _craft_index("shelter")
	# NEW on the first visit, and the cursor starts on it.
	main._open_base_menu()
	_assert(main.craft_is_new("shelter"), "처음 본 줄은 NEW 다")
	var rows: Array[Dictionary] = main.base_rows()
	_assert(String(rows[main.menu_index]["kind"]) == "craft",
		"커서는 새로 생긴 줄에서 시작한다")
	_assert(main.craft_status(shelter) == main.Craft.AVAILABLE, "무료 키트는 만들 수 있다")
	main.close_base_menu()
	main._open_base_menu()
	_assert(not main.craft_is_new("shelter"), "다시 열면 더는 NEW 가 아니다")
	main.close_base_menu()
	# CRAFTING while the fire works on it; the other timed rows wait.
	main.craft_selected(shelter)
	_assert(main.craft_status(shelter) == main.Craft.CRAFTING, "만드는 중이다")
	_assert(main.craft_status(_craft_index("pickaxe")) == main.Craft.LOCKED,
		"불이 바쁜 동안 다른 제작은 기다린다")
	_run_seconds(3.3)
	# DONE once the kit exists, whether or not the hut is up yet.
	_assert(main.craft_status(shelter) == main.Craft.DONE, "만들어진 뒤에는 완료다")
	# LOCKED for want of material, AVAILABLE once she has it.
	var torch: int = _craft_index("torch")
	main.sim.stock[Defs.ITEM_HEATSTONE] = 0
	_assert(main.craft_status(torch) == main.Craft.LOCKED, "열석이 없으면 횃불은 잠겨 있다")
	main.sim.stock[Defs.ITEM_HEATSTONE] = 5
	_assert(main.craft_status(torch) == main.Craft.AVAILABLE, "열석이 있으면 만들 수 있다")

# --- test_one_time_recipe_disappears_after_completion ----------------------------

func _test_one_time_recipe_disappears_after_completion() -> void:
	_fire()
	_assert(_offered("shelter"), "처음에는 숙소 키트 줄이 있다")
	main.craft_selected(_craft_index("shelter"))
	_run_seconds(3.3)
	# The kit lies by the fire -- not yet a hut -- and the row is already gone:
	# a made thing sitting on the list as if it were still to be made was the fault.
	_assert(not _offered("shelter"), "키트가 생기면 줄에서 사라진다 (세우기 전에도)")
	_assert(main.crafts_made().has(_craft_index("shelter")), "'만든 것' 줄로 옮겨 간다")
	_stand_hut()
	_assert(not _offered("shelter"), "세운 뒤에도 돌아오지 않는다")
	# The pickaxe, the same way.
	_assert(_offered("pickaxe"), "숙소 다음은 곡괭이 줄이다")
	main.craft_selected(_craft_index("pickaxe"))
	_run_seconds(3.3)
	_assert(not _offered("pickaxe"), "곡괭이도 만들면 사라진다")
	_assert(main.crafts_made().has(_craft_index("pickaxe")), "곡괭이도 '만든 것'에 있다")
	# A torch is made again and again, so it stays.
	var level: Dictionary = Defs.BASE_LEVELS[2]
	main.sim.stones_in = int(level["stones"])
	main.sim._refresh_radius()
	main.sim.stock[Defs.ITEM_HEATSTONE] = 10
	_assert(_offered("torch"), "3단계에는 횃불 줄이 있다")
	main.craft_selected(_craft_index("torch"))
	_assert(_offered("torch"), "횃불은 만들어도 남는다 (일회성이 아니다)")
	_assert(not main.crafts_made().has(_craft_index("torch")), "'만든 것'에 들어가지 않는다")
	# And the table says which is which.
	for craft: Dictionary in Defs.BASE_CRAFTS:
		var id: String = String(craft["id"])
		var once: bool = bool(craft.get("one_time", false))
		_assert(once == (id != "torch"), "%s 의 one_time 표시가 맞다" % id)

# --- test_craft_has_no_center_progress_text --------------------------------------

func _test_craft_has_no_center_progress_text() -> void:
	_fire()
	main._open_base_menu()
	main.messages.clear()
	main.message = ""
	main.craft_selected(_craft_index("shelter"))
	_assert(main.messages.is_empty() and main.message == "",
		"시작할 때 아무 문구도 띄우지 않는다: '%s'" % main.message)
	_assert(not main.base_menu_open, "창이 닫힌다 — 제작은 세계가 보여준다")
	var hud: String = _source("res://scripts/HUD.gd")
	for phrase: String in ["제작하고 있습니다", "만드는 중...", "만드는 중…"]:
		_assert(not hud.contains(phrase), "HUD 에 '%s' 가 없다" % phrase)
	_assert(not hud.contains("craft_left"), "HUD 는 남은 시간을 읽지 않는다")
	_assert(not hud.contains("func _draw_message"), "가운데 알림 판도 없다")
	# Halfway through: still nothing said anywhere.
	_run_seconds(1.5)
	_assert(main.messages.is_empty(), "만드는 동안에도 조용하다")

# --- test_base_shows_world_craft_progress ----------------------------------------

func _test_base_shows_world_craft_progress() -> void:
	_fire()
	_assert(is_equal_approx(main.craft_progress(), 0.0), "놀 때는 0이다")
	main.craft_selected(_craft_index("shelter"))
	_run_seconds(1.5)
	var mid: float = main.craft_progress()
	_assert(mid > 0.3 and mid < 0.7, "반쯤 찼다: %.2f" % mid)
	main._process(0.0)
	_assert(main.machine_layer.craft_progress > 0.0, "기지 위의 링이 그 값을 받는다")
	# One ring for every hold-and-watch in the world, drawn by WorldProgress.
	var layer: String = _source("res://scripts/MachineLayer.gd")
	_assert(_body(layer, "_progress_ring").contains("WorldProgress.draw"),
		"기계 레이어의 링은 WorldProgress 를 지난다")
	_assert(layer.count("_progress_ring(") >= 6, "여섯 곳이 모두 그 링이다")
	# Full, then a pulse, then gone.
	var fx = main.fx
	var rings_before: int = (fx.get("_rings") as Array).size()
	_run_seconds(1.8)
	_assert(is_equal_approx(main.craft_progress(), 0.0), "끝나면 링이 사라진다")
	_assert((fx.get("_rings") as Array).size() > rings_before, "끝나는 순간 펄스가 남는다")
	var main_src: String = _source("res://scripts/Main.gd")
	_assert(_body(main_src, "_land_craft").contains("WorldProgress.complete"),
		"완료 펄스도 공용이다")

# --- test_save_load_preserves_one_time_recipe_completion -------------------------

func _test_save_load_preserves_one_time_recipe_completion() -> void:
	_fire()
	main.craft_selected(_craft_index("shelter"))
	_run_seconds(3.3)
	_stand_hut()
	main.craft_selected(_craft_index("pickaxe"))
	_run_seconds(3.3)
	var made_before: Array[int] = main.crafts_made()
	_assert(made_before.size() >= 2, "숙소와 곡괭이를 만들었다")
	_assert(main.save_game(false), "저장된다")
	main._start_run()
	_assert(_offered("shelter") == false or not main.sim.base_placed, "새 판으로 갈아 끼웠다")
	_assert(main.load_game(), "다시 불러온다")
	_assert(not _offered("shelter") and not _offered("pickaxe"),
		"불러와도 만든 것은 목록에 돌아오지 않는다")
	_assert(main.crafts_made() == made_before, "'만든 것'이 그대로다: %s" % str(main.crafts_made()))
	_assert(main.presenting_tools.is_empty(), "공중에 떠 있던 것은 불러올 때 남지 않는다")
	main.clear_save()
