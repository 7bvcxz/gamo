extends "res://tests/framework/test_case.gd"

## Step 81 (design/PANELS81.md): the Research and Status panels on phones held
## upright and sideways and a desktop window, at every UI scale, in English
## and Korean -- the card inside the window and clear of every HUD piece, the
## tabs wholly in their own row (the chosen one never cut), nothing drawn
## under a scroll bar, one vertical bar at a time; a touch anywhere on the card
## never reaches the island; the tab dots inside their tabs.
##
## The rectangles come from the same query the browser test reads
## (`panel_layout`, window pixels), and the checks are written here apart from
## the layout code (`PanelFrame._layout`), so they measure it, not repeat it.

const MainScene := preload("res://scenes/main.tscn")

const WINDOWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(780, 1688), Vector2i(1688, 780), Vector2i(1280, 800)]
const SCALES: Array[float] = [0.85, 1.0, 1.25]

var main: Node
var sim: Simulation
var settings: SettingsStore
var was_size: Vector2i


func before_each() -> void:
	was_size = tree.root.size
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	with_starter_momo(sim)
	settings = main.get("settings")
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 20:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	LocaleService.apply("en")
	await tree.process_frame


func after_each() -> void:
	settings.set_value("ui_scale", 1.0)
	tree.root.size = was_size
	main.call("apply_options")
	LocaleService.apply("en")
	main.queue_free()
	await tree.process_frame


func _shape(win: Vector2i, scale: float, lang: String) -> void:
	tree.root.size = win
	settings.set_value("ui_scale", scale)
	LocaleService.apply(lang)
	main.call("apply_options")
	await tree.process_frame
	main.call("_layout")
	await tree.process_frame


func _inter(a: Array, b: Array) -> float:
	var w := minf(a[0] + a[2], b[0] + b[2]) - maxf(a[0], b[0])
	var h := minf(a[1] + a[3], b[1] + b[3]) - maxf(a[1], b[1])
	return maxf(w, 0.0) * maxf(h, 0.0)


## What is wrong with the open panel, as the player would see it.
func _problems(L: Dictionary, win: Vector2i) -> Array[String]:
	var out: Array[String] = []
	if not bool(L["open"]):
		return ["not open"]
	var c: Array = L["card"]
	if c[0] < -0.5 or c[1] < -0.5 or c[0] + c[2] > win.x + 0.5 or c[1] + c[3] > win.y + 0.5:
		out.append("card off the window %s" % [c])
	for h: Array in L["hud"]:
		if _inter(c, h) > 1.0:
			out.append("card over the HUD %s" % [h])
	var ts: Array = L["tab_scroll"]
	for t: Dictionary in L["tabs"]:
		if not bool(t["visible"]):
			continue
		var r: Array = t["rect"]
		if not ts.is_empty():
			if r[1] < ts[1] - 0.5 or r[1] + r[3] > ts[1] + ts[3] + 0.5:
				out.append("tab %s cut top or bottom" % t["text"])
			var shown := minf(r[0] + r[2], ts[0] + ts[2]) - maxf(r[0], ts[0])
			if shown > 0.0 and shown < r[2] - 0.5 and (bool(t["selected"]) or not bool(L["tab_overflow"])):
				out.append("tab %s cut sideways" % t["text"])
			if shown > 1.0 and _inter(r, L["close"]) > 1.0:
				out.append("tab %s under the close button" % t["text"])
		if _inter(r, L["scroll"]) > 1.0:
			out.append("tab %s over the body" % t["text"])
	for u: Dictionary in L["under_bar"]:
		out.append("%s under a scroll bar" % u["node"])
	if bool(L["bar_visible"]):
		for h: Array in L["hud"]:
			if _inter(L["bar"], h) > 0.0:
				out.append("the body's bar on the HUD")
	if bool(L.get("tree_bar_visible", false)) and bool(L["bar_visible"]):
		out.append("two vertical bars")
	if bool(L.get("tree_bar_visible", false)) and _inter(L["tree_bar"], L["detail"]) > 0.0:
		out.append("the tree's bar over the details")
	return out


func _layout() -> Dictionary:
	return main.call("_panel_layout", null)


func test_every_shape_scale_and_language_lays_the_panels_out_clear() -> void:
	var bad := 0
	var seen := 0
	for win: Vector2i in WINDOWS:
		for scale: float in SCALES:
			for lang: String in ["en", "ko"]:
				await _shape(win, scale, lang)
				var tag := "%dx%d x%.2f %s" % [win.x, win.y, scale, lang]
				# Research, as the HUD opens it, then two topics deep in long trees.
				main.call("_on_hud_action", &"research")
				await tree.process_frame
				for topic: String in ["", "momo_training", "seed_drill"]:
					if topic != "":
						main.call("open_research", topic)
					await tree.process_frame
					var p := _problems(_layout(), win)
					seen += 1
					if not p.is_empty():
						bad += 1
						assert_eq(p, [] as Array[String], "%s research %s" % [tag, topic])
				main.call("_on_hud_action", &"research")
				# Status, every tab.
				main.call("_on_hud_action", &"status")
				var frame: PanelFrame = main.get("status_frame")
				for t in frame.tabs.size():
					frame.show_tab(t)
					await tree.process_frame
					var p := _problems(_layout(), win)
					seen += 1
					if not p.is_empty():
						bad += 1
						assert_eq(p, [] as Array[String], "%s status %d" % [tag, t])
				frame.close()
	assert_eq(bad, 0, "no problem in %d panel states" % seen)
	assert_true(seen >= WINDOWS.size() * SCALES.size() * 2 * 10, "every state looked at (%d)" % seen)


## The checks themselves catch what 0.80 did: a card under the HUD, a tab
## under the close button, text under a bar (so a clean pass means something).
func test_the_checks_fail_a_broken_layout() -> void:
	await _shape(Vector2i(720, 1280), 1.0, "en")
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	var L := _layout()
	var win := Vector2i(720, 1280)
	assert_eq(_problems(L, win), [] as Array[String], "as laid out: clean")
	var under_hud := L.duplicate(true)
	var h: Array = L["hud"][0]
	under_hud["card"] = [h[0], h[1], 400.0, 600.0]
	assert_false(_problems(under_hud, win).is_empty(), "a card over the top-left card is caught")
	var under_close := L.duplicate(true)
	var tab: Dictionary = under_close["tabs"][0]
	tab["rect"] = (L["close"] as Array).duplicate()
	under_close["tab_scroll"] = (L["close"] as Array).duplicate()
	assert_false(_problems(under_close, win).is_empty(), "a tab under the close button is caught")
	var under_bar := L.duplicate(true)
	under_bar["under_bar"] = [{"node": "Label", "over": 4.0}]
	assert_false(_problems(under_bar, win).is_empty(), "text under a bar is caught")


## The panel follows the screen: turned from upright to sideways and back,
## and the text made larger while it is open, it lays itself out again.
func test_it_lays_out_again_when_the_screen_turns_or_the_text_grows() -> void:
	await _shape(Vector2i(720, 1280), 1.0, "en")
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	var upright: Array = _layout()["card"]
	await _shape(Vector2i(1688, 780), 1.0, "en")
	var L := _layout()
	assert_true(bool(L["open"]), "still open after turning")
	assert_eq(_problems(L, Vector2i(1688, 780)), [] as Array[String], "sideways: clear")
	assert_true(float(L["card"][3]) < float(upright[3]), "a shorter card in a shorter window")
	await _shape(Vector2i(1688, 780), 1.25, "ko")
	assert_eq(_problems(_layout(), Vector2i(1688, 780)), [] as Array[String], "larger text, Korean: clear")
	var frame: PanelFrame = main.get("research_frame")
	assert_eq(frame.title_label.text, tr("hud.research"), "the title follows the language")
	await _shape(Vector2i(720, 1280), 1.0, "en")
	assert_eq(_problems(_layout(), Vector2i(720, 1280)), [] as Array[String], "upright again: clear")


func _tap(p: Vector2) -> void:
	var vp := main.get_viewport()
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		vp.push_input(t, true)


## A touch on the card -- its padding, the gap between tabs, the gap above the
## body, an empty corner of the body -- stays on the card: the island gets no
## tap, the selected Momo stays selected, the panel stays open. The scrim
## (outside the card) still closes it.
func test_nothing_on_the_card_reaches_the_island() -> void:
	await _shape(Vector2i(720, 1280), 1.0, "en")
	var router: InputRouter = main.get("router")
	var taps := [0]
	router.tapped.connect(func(_s: Vector2, _w: Vector2) -> void: taps[0] += 1)
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	var frame: PanelFrame = main.get("status_frame")
	var xf := main.get_viewport().get_final_transform()
	var card := frame.card.get_global_rect()
	var row := frame.tab_scroll.get_global_rect()
	var body := frame.scroll.get_global_rect()
	var t0 := (frame.tabs[0]["button"] as Button).get_global_rect()
	var spots: Array[Vector2] = [
		card.position + Vector2(4, card.size.y * 0.5),  # the left padding
		Vector2(t0.end.x + 1.0, t0.get_center().y),  # between two tabs
		Vector2(card.get_center().x, (row.end.y + body.position.y) * 0.5),  # above the body
		Vector2(body.end.x - 3.0, body.end.y - 3.0),  # the body's corner, the bar's gutter
		card.end - Vector2(3, 3),  # the card's last corner
	]
	for s: Vector2 in spots:
		_tap(xf * s)
		await tree.process_frame
		assert_true(frame.visible, "a touch at %s keeps the panel" % s)
	assert_eq(taps[0], 0, "and none reached the island")
	# A wheel over the card scrolls the card, never the island's zoom.
	var cams: CameraController = main.get("cameras")
	var zoom := cams.camera.zoom if cams.camera != null else Vector2.ONE
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = xf * body.get_center()
	wheel.pressed = true
	main.get_viewport().push_input(wheel, true)
	await tree.process_frame
	if cams.camera != null:
		assert_eq(cams.camera.zoom, zoom, "a wheel on the card leaves the island's zoom")
	# Outside the card, the scrim closes it.
	var outside := Vector2(card.get_center().x, minf(card.end.y + 40.0, frame.size.y - 4.0))
	_tap(xf * outside)
	await tree.process_frame
	assert_false(frame.visible, "the scrim closes it")


## The red dots on research tabs are drawn inside their tabs, so they show in
## the tab row (which clips).
func test_tab_dots_sit_inside_the_row() -> void:
	await _shape(Vector2i(720, 1280), 1.25, "en")
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	var frame: PanelFrame = main.get("research_frame")
	var row := frame.tab_scroll.get_global_rect()
	var dots := 0
	for i in frame.tabs.size():
		var b: Button = frame.tabs[i]["button"]
		if not frame.tab_dot(i) or not b.is_visible_in_tree():
			continue
		dots += 1
		var r := b.get_global_rect()
		var dot := Rect2(r.position + Vector2(r.size.x - 16.0, 4.0), Vector2(12, 12))
		assert_true(r.encloses(dot), "tab %d: the dot inside its tab" % i)
		if row.encloses(r):
			assert_true(row.encloses(dot), "tab %d: shown whole in the row" % i)
	assert_true(dots > 0, "a Lv 20 island has new topics: dots shown (%d)" % dots)


## A finger's swipe that starts on a card, a tab or a tree topic reaches the
## scroll under it: nothing inside a panel's scroll views keeps the press to
## itself (a ScrollContainer scrolls by touch only from the presses it sees),
## except a slider, whose sideways drag is its own. Headless has no touch
## screen, so the browser test swipes; this pins what makes it work.
func test_nothing_inside_a_scroll_keeps_a_swipe() -> void:
	await _shape(Vector2i(720, 1280), 1.25, "en")
	var checked := 0
	for open: StringName in [&"research", &"status", &"settings"]:
		main.call("_on_hud_action", open)
		await tree.process_frame
		await tree.process_frame
		var frame: PanelFrame = null
		for f: StringName in [&"research_frame", &"status_frame", &"settings_frame"]:
			if (main.get(f) as PanelFrame).visible:
				frame = main.get(f)
		assert_true(frame != null, "%s open" % open)
		var tabs := maxi(frame.tabs.size(), 1)
		for t in tabs:
			if frame.tabs.size() > 1:
				frame.show_tab(t)
				await tree.process_frame
			for sc: Node in frame.card.find_children("*", "ScrollContainer", true, false):
				if not (sc as Control).is_visible_in_tree():
					continue
				for n: Node in sc.find_children("*", "Control", true, false):
					var c := n as Control
					if c is ScrollContainer:
						continue
					checked += 1
					if c is Range:
						continue
					assert_true(c.mouse_filter != Control.MOUSE_FILTER_STOP, "%s: %s lets a swipe through" % [open, sc.get_path_to(c)])
		frame.close()
	assert_true(checked > 100, "controls looked at (%d)" % checked)
