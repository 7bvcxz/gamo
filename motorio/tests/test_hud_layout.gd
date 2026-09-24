extends SceneTree

## The five places, after the 1.0.41 HUD pass.
##
## Top-left is her (warmth, the day, what she owns), top-right is the world (time
## of day, weather, what she is after), bottom-left is what just happened and the
## key for right now, bottom-right is the round map, bottom-centre is her hands.
## What is asserted here is the part a screenshot cannot hold still: that the
## five never sit on each other at any size a screen or the player's setting can
## make, that each is where its corner says it is, and that the things this pass
## took away -- the banner in the middle, the prompt over her head, a second
## panel style -- are gone rather than switched off.

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
	_test_one_style()
	_test_zones_hold_apart()
	_test_feed_replaces_the_banner()
	_test_prompt_in_the_corner()
	_test_minimap()
	_test_world_card()
	_test_hotbar()
	_test_text_tone()
	main.clear_save()
	if failures == 0:
		print("PASS test_hud_layout")
	else:
		print("FAIL test_hud_layout (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)

## The body of one function, for checking what a drawing calls.
func _body(source: String, name: String) -> String:
	var start: int = source.find("func %s(" % name)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + 1)
	return source.substr(start, (next if next > 0 else source.length()) - start)

## A run past the opening with a factory in it: the ledger has rows, the hotbar
## has three tools, a quest is open.
func _world() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.debug_scenario()
	main.messages.clear()
	main.hud._layout()

# --- One style ------------------------------------------------------------------

func _test_one_style() -> void:
	var hud: String = _source("res://scripts/HUD.gd")
	# Every window frame goes through the shared plate.
	_assert(_body(hud, "_frame").contains("HudStyle.panel"), "창 테두리가 공용 판을 쓴다")
	# And the five places draw their plates through it too, never a rectangle
	# typed on the spot.
	for name: String in ["_draw_status", "_draw_world", "_draw_feed", "_draw_hotbar",
			"_draw_prompt", "_draw_direction_chip"]:
		var body: String = _body(hud, name)
		_assert(body != "", "%s 가 있다" % name)
		_assert(not body.contains("_panel(") and not body.contains("draw_rect("),
			"%s 는 판을 직접 그리지 않는다" % name)
	# The tokens exist and are the ones the layout uses.
	_assert(main.hud.MARGIN == HudStyle.OUTER_MARGIN, "바깥 여백은 토큰 하나다")
	for token: float in [HudStyle.PANEL_PADDING, HudStyle.ITEM_GAP, HudStyle.SECTION_GAP,
			HudStyle.CORNER_RADIUS, HudStyle.BORDER_WIDTH, HudStyle.ICON_SMALL,
			HudStyle.ICON_NORMAL]:
		_assert(token > 0.0, "토큰이 양수다: %.1f" % token)
	_assert(HudStyle.TEXT_SMALL < HudStyle.TEXT_NORMAL and HudStyle.TEXT_NORMAL < HudStyle.TEXT_TITLE,
		"글자 크기는 작음 < 보통 < 제목")
	# One rounded-rectangle and one key cap for the game, not one per script.
	var player: String = _source("res://scripts/PlayerActor.gd")
	_assert(not player.contains("func _rounded") and not player.contains("func _draw_cap"),
		"주인공 스크립트에 두 번째 둥근 판·키캡이 없다")
	_assert(_body(hud, "_draw_cap").contains("HudStyle.keycap"), "가이드의 키캡도 같은 키캡이다")

# --- Five places, apart ---------------------------------------------------------

func _zones() -> Dictionary:
	var hud = main.hud
	var slots := Rect2()
	for rect: Rect2 in hud.hotbar_rects:
		if rect.size.x > 0.0:
			slots = rect if slots.size.x <= 0.0 else slots.merge(rect)
	var span: Vector2 = hud.hotbar_span()
	var hands := Rect2(span.x, hud.hotbar_top(), span.y - span.x, slots.end.y - hud.hotbar_top())
	return {
		"status": hud.status_card_rect(),
		"world": hud.world_card_rect(),
		"feed": hud.feed_rect(),
		"map": hud.minimap_rect,
		"hands": hands,
	}

func _test_zones_hold_apart() -> void:
	_world()
	main.player.prompt = "TOOL"
	main._notify("공장이 돌아가기 시작했다.", Defs.COL_CORE)
	main._notify("고양이가 광맥을 파기 시작했다.", Defs.COL_CORE)
	var hud = main.hud
	var shapes: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1024, 600),
		Vector2(390, 844)]
	for shape: Vector2 in shapes:
		var phone: bool = shape.x < shape.y
		# The window itself, so the touch pad lays itself out for this screen:
		# the strip it reserves along the bottom is measured in viewport pixels.
		root.size = Vector2i(int(shape.x), int(shape.y))
		main.touch.visible = phone
		main.touch.call("_update_layout")
		for value: float in [Defs.UI_SCALE_MIN, Defs.UI_SCALE_DEFAULT, Defs.UI_SCALE_MAX]:
			main.ui_scale = value
			# The HUD's own logical size for this screen at this scale -- what the
			# viewport would hand it, through the same function the game uses.
			# In canvas units, not window pixels: the project stretches, so a
			# 390-wide phone window is a 960-wide viewport, and that is what the
			# HUD is handed.
			var view: Vector2 = root.get_visible_rect().size
			var want: float = hud.scale_for(view, phone, value)
			hud.scale = Vector2(want, want)
			hud.size = view / want
			hud._layout()
			var zones: Dictionary = _zones()
			var tag: String = "%.0fx%.0f UI %.2f" % [shape.x, shape.y, value]
			var names: Array = zones.keys()
			for a in names.size():
				var one: Rect2 = zones[names[a]]
				if one.size.x <= 0.0 or one.size.y <= 0.0:
					continue
				_assert(one.position.x >= -0.5 and one.position.y >= -0.5
					and one.end.x <= hud.size.x + 0.5 and one.end.y <= hud.size.y + 0.5,
					"%s: %s 가 화면 안에 있다" % [tag, names[a]])
				for b in range(a + 1, names.size()):
					var two: Rect2 = zones[names[b]]
					if two.size.x <= 0.0 or two.size.y <= 0.0:
						continue
					_assert(not one.intersects(two),
						"%s: %s 와 %s 가 겹치지 않는다" % [tag, names[a], names[b]])
			# And each corner is its corner: the status top-left, the map
			# bottom-right, the feed on the left, the hands centred.
			var map: Rect2 = zones["map"]
			var feed: Rect2 = zones["feed"]
			_assert(map.get_center().x > hud.size.x * 0.5 and map.get_center().y > hud.size.y * 0.5,
				"%s: 지도는 오른쪽 아래" % tag)
			_assert(feed.position.x <= hud.MARGIN + 0.5, "%s: 기록은 왼쪽 가장자리" % tag)
			if not phone:
				var world: Rect2 = zones["world"]
				_assert(world.end.x >= hud.size.x - hud.MARGIN - 0.5 and world.position.y <= hud.MARGIN + 0.5,
					"%s: 월드 카드는 오른쪽 위" % tag)
	main.touch.visible = false
	main.ui_scale = Defs.UI_SCALE_DEFAULT
	hud._apply_scale()

# --- The banner went to the corner ------------------------------------------------

func _test_feed_replaces_the_banner() -> void:
	var hud_src: String = _source("res://scripts/HUD.gd")
	_assert(not hud_src.contains("func _draw_message"), "화면 가운데 알림 판이 없다")
	_world()
	main._notify("불이 더 커졌다.", Defs.COL_CORE)
	var hud = main.hud
	hud._layout()
	var feed: Rect2 = hud.feed_rect()
	_assert(feed.size.y > 0.0, "알림은 좌하단 기록에 선다")
	_assert(feed.get_center().x < hud.size.x * 0.5 and feed.get_center().y > hud.size.y * 0.5,
		"왼쪽 아래 사분면이다")
	# Two to four lines, newest nearest the prompt.
	for index in 6:
		main._notify("줄 %d" % index, Defs.COL_TEXT)
	_assert(hud._feed_entries().size() <= hud.FEED_LINES, "기록은 네 줄을 넘지 않는다")
	_assert(String(hud._feed_entries()[-1]["text"]) == "줄 5", "가장 새 줄이 마지막이다")
	# Long enough to be read where it is now.
	_assert(main.MESSAGE_LIFE >= 3.5, "모서리의 줄은 읽을 만큼 머문다 (%.1f초)" % main.MESSAGE_LIFE)

# --- The key prompt ----------------------------------------------------------------

func _test_prompt_in_the_corner() -> void:
	_world()
	var hud = main.hud
	main.player.prompt = ""
	_assert(hud.prompt_rect().size.x == 0.0, "물을 것이 없으면 안내도 없다")
	main.player.prompt = "MINE"
	hud._layout()
	var chip: Rect2 = hud.prompt_rect()
	_assert(chip.size.x > 0.0 and chip.size.y > 0.0, "안내가 자리를 차지한다")
	_assert(chip.position.x <= hud.MARGIN + 0.5 and chip.get_center().y > hud.size.y * 0.5,
		"안내는 좌하단에 있다")
	_assert(chip.end.y <= hud.feed_bottom() + 0.5, "기록 줄의 바닥 위에 선다")
	# One prompt, from the one table.
	_assert(hud._prompt_row() == Defs.key_prompt("MINE"), "안내는 KEY_PROMPTS 에서 온다")
	main.player.prompt = ""

# --- The round map ----------------------------------------------------------------

func _test_minimap() -> void:
	var hud = main.hud
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	hud._layout()
	_assert(not hud.minimap_visible(), "불이 서기 전에는 지도가 없다")
	main.sim.search_kit()
	hud._layout()
	_assert(hud.minimap_visible(), "불이 서면 지도가 선다")
	var map: Rect2 = hud.minimap_rect
	_assert(is_equal_approx(map.size.x, map.size.y), "지도는 둥글다 (정사각 틀)")
	_assert(map.end.x <= hud.size.x - hud.MARGIN + 0.5 and map.end.y <= hud.floor_y() + 0.5,
		"오른쪽 아래 모서리에 있다")
	# A tap opens the full map: a phone has no M key.
	main.map_open = false
	_assert(main.touch_hud(map.get_center() * hud.scale.x), "지도를 누르면 처리된다")
	_assert(main.map_open, "그리고 큰 지도가 열린다")
	main.map_open = false
	# And indoors there is no world to map.
	_assert(hud.minimap_visible(), "밖에서는 보인다")

# --- The world card ---------------------------------------------------------------

func _test_world_card() -> void:
	var hud = main.hud
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	hud._layout()
	_assert(hud.phase_label() == "낮", "첫날 아침은 낮이다")
	_assert(hud.weather_label().begins_with("눈"), "밖의 날씨는 눈이다: %s" % hud.weather_label())
	_assert(hud.weather_label().contains("추움"), "불이 서기 전에는 춥다")
	# The opening's first line is the first quest.
	_assert(hud.quest_hud_text() == Defs.mission_line("M1"), "첫 임무가 카드에 있다")
	main.finish_tutorial()
	main.time_left = (Defs.DUSK_SECONDS + Defs.NIGHT_SECONDS) * 0.5
	_assert(hud.phase_label() == "해질녘", "해질녘을 말한다: %s" % hud.phase_label())
	_assert(not hud.world_note().is_empty(), "해질녘에는 할 일을 말한다")
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	_assert(hud.phase_label() == "밤", "밤을 말한다")
	main.time_left = Defs.DAY_SECONDS
	# No more than three quests on the card, and a finished one only for a breath.
	_assert(hud.world_quests().size() <= hud.QUEST_SHOWN, "임무는 세 줄까지다")
	main.quest_done_flash = 0.0
	for row: Dictionary in hud.world_quests():
		_assert(not bool(row["done"]), "끝난 임무는 남지 않는다: %s" % String(row["title"]))
	# The carried hut's hint rides along under the quests, once.
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.sim.search_kit()
	main.sim.carried_kit = Defs.KIT_SHELTER
	_assert(hud.world_hint() == Defs.mission_line("M2-HOLD"),
		"숙소를 들고 있으면 어디에 세울지 한 줄 덧붙인다: '%s'" % hud.world_hint())
	main.sim.carried_kit = Defs.KIT_NONE

# --- The hands -------------------------------------------------------------------

func _test_hotbar() -> void:
	_world()
	var hud = main.hud
	var slot: Vector2 = hud.hotbar_slot()
	_assert(is_equal_approx(slot.x, slot.y), "칸은 정사각이다")
	var shown := 0
	for index in main.TOOLS.size():
		var rect: Rect2 = hud.hotbar_rects[index]
		if rect.size.x > 0.0:
			shown += 1
	_assert(shown == main.unlocked_tools().size(), "가진 도구만 칸을 차지한다 (%d)" % shown)
	_assert(main.TOOLS.size() <= 9, "번호는 1~9 안에 있다")
	# The output-direction chip only while the gun is out with a machine that
	# has a front; a thumb above the row must not turn a machine it cannot see.
	main.tool_index = main.TOOL_PICKAXE
	_assert(not hud.direction_visible(), "곡괭이를 들면 방향 칩이 없다")
	var before: Vector2i = main.build_dir
	main.touch_hud(hud.direction_rect.get_center() * hud.scale.x)
	_assert(main.build_dir == before, "보이지 않는 칩은 누를 수 없다")
	main.tool_index = main.TOOL_BUILD_GUN
	main.selected_index = 0
	_assert(hud.direction_visible() == Defs.DIRECTIONAL_MACHINES.has(main.selected_type()),
		"총을 들면 방향이 있는 기계에만 칩이 선다")
	_assert(hud.hotbar_caption().begins_with(main.TOOL_NAMES[main.TOOL_BUILD_GUN]),
		"손에 든 것의 이름이 위에 적힌다: %s" % hud.hotbar_caption())
	main.tool_index = main.TOOL_PICKAXE

# --- Words -----------------------------------------------------------------------

func _test_text_tone() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.finish_tutorial()
	# The state lines are her thoughts, not a manual: no "습니다", no distances.
	var lines: Array[String] = []
	main.player.warmth = Defs.FROST_STAGES[2] - 1.0
	lines.append(main.info())
	main.player.warmth = 100.0
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	lines.append(main.info())
	main.time_left = (Defs.DUSK_SECONDS + Defs.NIGHT_SECONDS) * 0.5
	lines.append(main.info())
	main.time_left = Defs.DAY_SECONDS
	for line: String in lines:
		_assert(line != "", "상태 줄이 있다")
		_assert(not line.contains("습니다") and not line.contains("칸"),
			"기계적인 말투가 아니다: %s" % line)
	# And what she is holding is described, not specified.
	for tool: int in [main.TOOL_PICKAXE, main.TOOL_TORCH]:
		main.tool_index = tool
		var caption: String = main.hud.hotbar_caption()
		var digits := RegEx.new()
		digits.compile("[0-9]")
		_assert(digits.search(caption) == null, "도구 설명에 숫자가 없다: %s" % caption)
	main.tool_index = main.TOOL_PICKAXE
	var torch: Dictionary = {}
	for row: Dictionary in Defs.BASE_CRAFTS:
		if String(row["id"]) == "torch":
			torch = row
	_assert(not String(torch["note"]).contains("칸") and not String(torch["note"]).contains("초"),
		"횃불 설명에 칸·초가 없다: %s" % String(torch["note"]))
