extends Node2D

## Composition root. Builds the Simulation, then the views that show it, and
## hands each view the simulation it reads -- nothing is reached through a
## global. Owns the frame loop: real time in, simulated time out.

var sim: Simulation
var projection: IsoProjection
var bridge := WebBridge.new()
var camera: Camera2D
var cameras: CameraController
var router: InputRouter
var island: IslandRenderer
var ocean: OceanRenderer
var sky: SkyRenderer
var ambient: CanvasModulate
var day_night: DayNight
var hud: Hud
var panel: ContextPanel
var marker: SelectionMarker
var building_views: BuildingViews
var momo_views: MomoViews
var momo_panel: MomoPanel
var momo_drag: MomoDrag
var selection: SelectionController
var land_preview: LandPreview
var land_mode: LandMode
var placement_preview: PlacementPreview
var placement: PlacementMode
var build_menu: BuildMenu
var status_panel: StatusPanel
## Status, store, money and records, as tabs of one frame.
var status_frame: PanelFrame
var inventory_view: InventoryView
var economy_view: EconomyView
var stats_view: StatsView
## Everything about one building, opened from its name.
var detail_frame: PanelFrame
var detail_view: BuildingDetailView
## The technology tree, one tab per industry.
var research_frame: PanelFrame
var research_views: Array[ResearchView] = []
## Momo Letters.
var mail_frame: PanelFrame
var mailbox_view: MailboxView
## Persistence: where the island is saved, whether saving is on (tests turn it
## off with Engine meta "momonium_no_save" and may point it elsewhere with
## "momonium_save_path"), what loading found, and what happened while away.
var save_path := SaveService.DEFAULT_PATH
## localStorage key of the save's synchronous mirror on the web.
const MIRROR_KEY := "momonium_save"
var persist := true
var load_status := ""
var save_blocked := false
var offline_report: Dictionary = {}
var away_frame: PanelFrame
var away_view: AwayView
## Preferences apart from the island (language, tutorial seen).
var settings: SettingsStore
var settings_frame: PanelFrame
var settings_view: SettingsView
var tutorial: Tutorial
## The demo island (Settings) is never saved; Engine meta "momonium_demo"
## survives the scene reload that switches to it and back.
var in_demo := false
var _demo_badge: Label
var saves_written := 0
var _autosave_left := 0.0
var _last_wall := 0.0
## The last few HUD actions, newest last (for the browser bridge and tests).
var hud_actions: Array[String] = []
var entities: EntityLayer
var _version_label: Label


func _ready() -> void:
	settings = SettingsStore.open()
	sim = _load_or_new()
	projection = IsoProjection.from_data(sim.data)

	var back := CanvasLayer.new()
	back.name = "Background"
	back.layer = -10
	add_child(back)
	sky = SkyRenderer.new()
	sky.name = "Sky"
	back.add_child(sky)
	ocean = OceanRenderer.new()
	ocean.name = "Ocean"
	back.add_child(ocean)

	var world_root := Node2D.new()
	world_root.name = "World"
	add_child(world_root)
	ambient = CanvasModulate.new()
	ambient.name = "Ambient"
	world_root.add_child(ambient)
	island = IslandRenderer.new()
	island.name = "Island"
	world_root.add_child(island)
	island.setup(sim, projection)
	marker = SelectionMarker.new()
	marker.name = "SelectionMarker"
	marker.projection = projection
	world_root.add_child(marker)
	land_preview = LandPreview.new()
	land_preview.name = "LandPreview"
	world_root.add_child(land_preview)
	land_preview.setup(sim, projection)
	placement_preview = PlacementPreview.new()
	placement_preview.name = "PlacementPreview"
	world_root.add_child(placement_preview)
	entities = EntityLayer.new(projection)
	entities.name = "Entities"
	world_root.add_child(entities)
	camera = Camera2D.new()
	camera.name = "Camera"
	world_root.add_child(camera)
	camera.make_current()
	cameras = CameraController.new()
	cameras.name = "CameraController"
	add_child(cameras)
	cameras.setup(camera, projection, sim.system(&"world"))
	ocean.setup(sim, camera, projection)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sim, sky, ocean, ambient)
	router = InputRouter.new()
	router.name = "InputRouter"
	add_child(router)
	router.setup(cameras)

	var chosen := String(settings.get_value("language"))
	LocaleService.apply(chosen if chosen != "" else LocaleService.detect())
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	# One root Control for every piece of UI, so they all inherit the HUD's
	# theme and font: a CanvasLayer does not pass a theme on, and without it
	# panels fell back to the engine's grey boxes and its font, which has no
	# Hangul or kana -- fine on a desktop with system fonts, empty boxes on the web.
	var ui := Control.new()
	ui.name = "Root"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var lib := SpriteLibrary.load_atlas()
	panel = ContextPanel.new()
	ui.add_child(panel)
	panel.setup(sim, lib)
	hud = Hud.new()
	ui.add_child(hud)
	hud.setup(sim, lib)
	# The same Theme object: the HUD swaps its font when the language changes.
	ui.theme = hud.theme
	hud.action.connect(_on_hud_action)
	hud.layout_changed.connect(func() -> void: panel.set_reserved(hud.bottom_left_end + 8.0, hud.bottom_margin))
	panel.set_reserved(hud.bottom_left_end + 8.0, hud.bottom_margin)
	building_views = BuildingViews.new()
	building_views.name = "BuildingViews"
	add_child(building_views)
	building_views.setup(sim, entities, lib)
	momo_views = MomoViews.new()
	momo_views.name = "MomoViews"
	add_child(momo_views)
	momo_views.setup(sim, entities, lib)
	selection = SelectionController.new()
	selection.name = "Selection"
	add_child(selection)
	selection.setup(sim, projection, building_views, marker, panel, router)
	selection.momo_views = momo_views
	momo_panel = MomoPanel.new()
	ui.add_child(momo_panel)
	momo_panel.setup(sim, lib)
	momo_panel.resized.connect(_place_momo_panel)
	momo_panel.visibility_changed.connect(_place_momo_panel)
	momo_panel.release_requested.connect(func(id: int) -> void:
		selection.last_result = sim.execute({"type": "momo.unassign", "momo": id}))
	selection.momo_panel = momo_panel
	momo_drag = MomoDrag.new()
	momo_drag.setup(sim, projection, momo_views, building_views)
	router.add_drag_handler(momo_drag)
	land_mode = LandMode.new()
	ui.add_child(land_mode)
	land_mode.setup(sim, land_preview, projection, lib)
	selection.land_mode = land_mode
	placement_preview.setup(sim, projection, lib)
	placement = PlacementMode.new()
	ui.add_child(placement)
	placement.setup(sim, placement_preview, projection, lib)
	placement.placed.connect(func(id: int) -> void: selection.select_building(id))
	selection.placement = placement
	build_menu = BuildMenu.new()
	ui.add_child(build_menu)
	build_menu.setup(sim, lib)
	build_menu.picked.connect(func(type: String) -> void:
		land_mode.close()
		selection.deselect()
		placement.open(type))
	build_menu.resized.connect(_place_build_menu)
	build_menu.hire_requested.connect(func() -> void:
		var r := sim.execute({"type": "momo.hire"})
		if r["ok"]:
			selection.select_momo(int(r["id"])))
	status_frame = _frame(ui, "StatusFrame")
	status_panel = StatusPanel.new()
	status_panel.setup(sim, lib)
	status_frame.add_tab("panel.tab.status", status_panel)
	inventory_view = InventoryView.new()
	inventory_view.setup(sim, lib)
	status_frame.add_tab("panel.tab.store", inventory_view)
	economy_view = EconomyView.new()
	economy_view.setup(sim, lib)
	status_frame.add_tab("panel.tab.economy", economy_view)
	stats_view = StatsView.new()
	stats_view.setup(sim, lib)
	status_frame.add_tab("panel.tab.records", stats_view)
	detail_frame = _frame(ui, "DetailFrame")
	detail_view = BuildingDetailView.new()
	detail_view.setup(sim, lib)
	detail_frame.add_tab("", detail_view)
	detail_view.gone.connect(detail_frame.close)
	mail_frame = _frame(ui, "MailFrame")
	mailbox_view = MailboxView.new()
	mailbox_view.setup(sim, lib)
	mail_frame.add_tab("hud.mailbox", mailbox_view)
	mail_frame.closed.connect(mailbox_view.show_list)
	research_frame = _frame(ui, "ResearchFrame")
	for industry: String in (sim.system(&"research") as ResearchSystem).industries():
		var rv := ResearchView.new()
		rv.setup(sim, lib, industry)
		research_views.append(rv)
		research_frame.add_tab("research.industry.global" if industry == "global" else "mastery." + industry, rv)
	research_frame.set_title(tr("hud.research"))
	panel.details_pressed.connect(open_details)
	_place_frames()
	hud.layout_changed.connect(_place_frames)
	_version_label = Label.new()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0")
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_version_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(_version_label)
	get_viewport().size_changed.connect(_layout)
	_layout()
	cameras.frame_island()
	away_frame = _frame(ui, "AwayFrame")
	away_view = AwayView.new()
	away_view.setup(sim, lib)
	away_frame.add_tab("", away_view)
	away_frame.set_title(tr("away.title"))
	_last_wall = Time.get_unix_time_from_system()
	_autosave_left = sim.data.get_float("balance", "offline.autosave_seconds", 15.0)
	_tell_about_return.call_deferred(offline_report)
	settings_frame = _frame(ui, "SettingsFrame")
	settings_view = SettingsView.new()
	settings_view.setup(sim, lib)
	settings_view.in_demo = in_demo
	settings_frame.add_tab("", settings_view)
	settings_frame.set_title(tr("hud.settings"))
	settings_view.language_chosen.connect(func(code: String) -> void:
		LocaleService.apply(code)
		settings.set_value("language", code)
		settings_frame.set_title(tr("hud.settings"))
		settings_view.refresh())
	settings_view.replay_tutorial.connect(func() -> void:
		_close_frames()
		tutorial.start())
	settings_view.demo_requested.connect(enter_demo)
	settings_view.leave_demo_requested.connect(leave_demo)
	_demo_badge = Label.new()
	_demo_badge.name = "DemoBadge"
	_demo_badge.add_theme_font_size_override("font_size", 18)
	_demo_badge.add_theme_color_override("font_color", Color("#ffe27a"))
	_demo_badge.visible = in_demo
	ui.add_child(_demo_badge)
	_layout()
	tutorial = Tutorial.new()
	ui.add_child(tutorial)
	tutorial.setup(sim, hud, build_menu, placement, cameras, projection, building_views, panel)
	tutorial.finished.connect(func(_skipped: bool) -> void: settings.set_value("tutorial_done", true))
	_place_frames()

	bridge.attach(sim, _version_label.text.trim_prefix("v"))
	_maybe_start_tutorial.call_deferred()
	bridge.register_query("save_roundtrip", _save_roundtrip)
	bridge.register_query("tutorial", _tutorial_info)
	bridge.register_query("tutorial_start", func(_a: Variant) -> Dictionary:
		_close_frames()
		tutorial.start()
		return _tutorial_info(null))
	bridge.register_query("settings_ui", _settings_info)
	bridge.register_query("art_info", _art_info)
	bridge.register_query("cell_screen", _cell_screen)
	bridge.register_query("logical_screen", _logical_screen)
	bridge.register_query("camera", _camera_info)
	bridge.register_query("dev_grow_island", _dev_grow_island)
	bridge.register_query("sky", func(_a: Variant) -> Dictionary: return day_night.describe())
	bridge.register_query("dev_advance_to", _dev_advance_to)
	bridge.register_query("dev_advance_ms", func(ms: Variant) -> Dictionary:
		sim.advance_ms(int(ms))
		return {"now_ms": sim.now_ms(), "day": sim.clock.day_number()})
	bridge.register_query("hud", _hud_info)
	bridge.register_query("dev_place_building", func(arg: Variant) -> Dictionary:
		var id := (sim.system(&"buildings") as BuildingSystem).place_instant(String(arg[0]), Vector2i(int(arg[1]), int(arg[2])))
		return {"id": id})
	bridge.register_query("selection", _selection_info)
	bridge.register_query("dev_add_money", func(amount: Variant) -> Dictionary:
		(sim.system(&"economy") as EconomySystem).earn(int(amount), "dev")
		return {"money": (sim.system(&"economy") as EconomySystem).money})
	bridge.register_query("land_mode", _land_mode_info)
	bridge.register_query("build_ui", _build_ui_info)
	bridge.register_query("status", _status_info)
	bridge.register_query("panels", _panels_info)
	bridge.register_query("mail", _mail_info)
	bridge.register_query("research", _research_info)
	bridge.register_query("save_now", func(_a: Variant) -> Dictionary:
		return {"err": save_now(), "path": save_path, "persist": persist, "written": saves_written,
			"userfs_persistent": OS.is_userfs_persistent()})
	bridge.register_query("persistence", func(_a: Variant) -> Dictionary:
		return {"status": load_status, "persist": persist, "blocked": save_blocked, "report": offline_report,
			"away_open": away_frame.visible, "away_lines": away_view.lines().map(func(l: Array) -> String: return "%s|%s" % l)})
	bridge.register_query("dev_away", func(ms: Variant) -> Dictionary:
		var r := OfflineProgress.catch_up(sim, int(ms))
		_tell_about_return(r)
		return r)
	bridge.register_query("dev_research_done", func(ids: Variant) -> Dictionary:
		var research: ResearchSystem = sim.system(&"research")
		for id: Variant in ids:
			research.completed[String(id)] = sim.now_ms()
		sim.bus.emit(&"research_completed", {"id": String(ids[-1]) if not ids.is_empty() else ""})
		return {"completed": research.completed.keys()})
	bridge.register_query("details", func(_a: Variant) -> Dictionary:
		var vp := get_viewport()
		var out := {"open": detail_frame.visible, "varieties": {}, "workers": [], "research": [], "window": []}
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		out["window"] = [win.x, win.y]
		for c: Node in detail_view.variety_box.get_children():
			var r := (c as Control).get_global_rect()
			var a: Vector2 = vp.get_final_transform() * r.position
			var b: Vector2 = vp.get_final_transform() * r.end
			out["varieties"][String(c.get_meta("variety"))] = {"rect": [a.x, a.y, b.x - a.x, b.y - a.y], "disabled": (c as Button).disabled}
		for c: Node in detail_view.workers_box.get_children():
			out["workers"].append(String(c.get_meta("who", "")))
		for c: Node in detail_view.research_box.get_children():
			out["research"].append((c as Label).text)
		return out)
	bridge.register_query("momos", _momo_info)
	bridge.register_query("momo_poses", func(_a: Variant) -> Dictionary:
		var out := {}
		for id: int in momo_views.actors:
			var a: MomoActor = momo_views.actors[id]
			out[str(id)] = {"state": a.rig.state, "blinking": a.rig.blinking, "back": a.rig.is_back_view()}
		return out)
	bridge.register_query("set_language", func(code: Variant) -> Dictionary:
		LocaleService.apply(String(code))
		return {"locale": LocaleService.current()})


func _process(delta: float) -> void:
	# Time the frame loop did not see (a hidden browser tab stops drawing) is
	# caught up the same way as time with the game closed.
	var wall := Time.get_unix_time_from_system()
	var gap := wall - _last_wall - delta
	_last_wall = wall
	if gap > 5.0 and sim.time_scale > 0.0:
		_tell_about_return(OfflineProgress.catch_up(sim, int(gap * 1000.0 * sim.time_scale)))
	sim.advance_seconds(delta)
	if persist:
		_autosave_left -= delta
		if _autosave_left <= 0.0:
			_autosave_left = sim.data.get_float("balance", "offline.autosave_seconds", 15.0)
			save_now()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if sim != null:
				save_now()


## Loads the island (with what happened while away) or starts a new one --
## or, when the demo was asked for, the demo island (never saved).
func _load_or_new() -> Simulation:
	in_demo = Engine.has_meta("momonium_demo")
	persist = not Engine.has_meta("momonium_no_save") and not in_demo
	if in_demo:
		load_status = "demo"
		return DemoWorld.build()
	if Engine.has_meta("momonium_save_path"):
		save_path = String(Engine.get_meta("momonium_save_path"))
	if not persist:
		return Simulation.new_game()
	var r := SaveService.load_save(save_path)
	if WebStorage.available():
		var mirror := WebStorage.get_item(MIRROR_KEY)
		if mirror != "":
			r = SaveService.newest(r, SaveService.decode(mirror))
	load_status = String(r["status"])
	if load_status in ["ok", "backup"]:
		var loaded := Simulation.from_save(r["state"])
		var saved := int(r.get("saved_unix", 0))
		if saved > 0:
			offline_report = OfflineProgress.catch_up(loaded, int((Time.get_unix_time_from_system() - saved) * 1000.0))
		return loaded
	save_blocked = load_status == "too_new"
	return Simulation.new_game()


## The first-run tutorial starts by itself only on a brand-new island, once,
## never in the demo and never under the browser test bridge (tests start it
## when they want it).
func _maybe_start_tutorial() -> void:
	var tests_want_it := bridge.e2e and bool(JavaScriptBridge.eval("!!window.MOMONIUM_E2E_TUTORIAL", true))
	if in_demo or (bridge.e2e and not tests_want_it) or not persist or load_status != "missing" or bool(settings.get_value("tutorial_done")):
		return
	tutorial.start()


## Switches to the demo island: saves the player's island first, then
## reloads the scene in demo mode. Nothing of the demo is ever saved.
func enter_demo() -> void:
	save_now()
	Engine.set_meta("momonium_demo", true)
	get_tree().reload_current_scene.call_deferred()


func leave_demo() -> void:
	Engine.remove_meta("momonium_demo")
	get_tree().reload_current_scene.call_deferred()


func save_now() -> Error:
	if not persist or save_blocked or sim == null:
		return ERR_UNAVAILABLE
	var text := SaveService.encode(sim)
	var err := SaveService.write_text(text, save_path)
	WebStorage.set_item(MIRROR_KEY, text)
	if err == OK:
		saves_written += 1
	return err


## The welcome-back card, when there is something worth saying.
func _tell_about_return(report: Dictionary) -> void:
	var notice := load_status in ["backup", "corrupt", "too_new"] and not away_frame.visible and saves_written == 0
	if not notice and (report.is_empty() or not OfflineProgress.worth_telling(report, sim.data.get_float("balance", "offline.report_seconds", 60.0))):
		return
	_close_frames()
	away_view.show_report(report, load_status if notice else "")
	away_frame.open()


func _layout() -> void:
	var size := get_viewport_rect().size
	_version_label.position = size - Vector2(84, 28)
	if _demo_badge != null:
		_demo_badge.text = tr("hud.demo")
		_demo_badge.reset_size()
		_demo_badge.position = Vector2((size.x - _demo_badge.size.x) * 0.5, 22.0)
	if cameras.fit_zoom > 0.0 and camera.is_inside_tree():
		cameras.on_resize()


## E2E: proves the platform's user:// (IndexedDB on the web) can hold a save and
## give the same world back. Writes to its own file, never the player's save.
func _save_roundtrip(_arg: Variant) -> Dictionary:
	var path := "user://e2e_roundtrip.json"
	var err := SaveService.write(sim, path)
	var restored := Simulation.from_save(SaveService.read(path))
	var same := JSON.stringify(restored.snapshot()) == JSON.stringify(sim.snapshot())
	DirAccess.remove_absolute(path)
	return {"write": err, "equal": same, "now_ms": restored.now_ms()}


## E2E: the exported build carries the atlas and its metadata.
func _art_info(_arg: Variant) -> Dictionary:
	var lib := SpriteLibrary.load_atlas()
	return {"sprites": lib.sprites.size(), "size": [lib.size.x, lib.size.y],
		"texture": [lib.texture.get_width(), lib.texture.get_height()] if lib.texture else [0, 0],
		"momo_origin": [lib.pivot("momo_front").x, lib.pivot("momo_front").y]}


## E2E: where a cell's centre is in window pixels, so a browser test can tap it.
## The test scales by canvas CSS size / window size.
func _cell_screen(arg: Variant) -> Dictionary:
	return _logical_screen([float(arg[0]) + 0.5, float(arg[1]) + 0.5, 0.0])


## E2E: window position of a logical ground point [x, y, z] (z in tile edges).
func _logical_screen(arg: Variant) -> Dictionary:
	var world_pos := projection.to_screen(Vector2(float(arg[0]), float(arg[1])), float(arg[2]) if arg.size() > 2 else 0.0)
	var vp := get_viewport()
	var window_pos: Vector2 = vp.get_final_transform() * (vp.get_canvas_transform() * world_pos)
	var win := DisplayServer.window_get_size()
	return {"x": window_pos.x, "y": window_pos.y, "window": [win.x, win.y]}


## E2E: the camera, for pan/zoom checks.
func _camera_info(_arg: Variant) -> Dictionary:
	return {"x": camera.position.x, "y": camera.position.y, "zoom": camera.zoom.x,
		"fit": cameras.fit_zoom, "min": cameras.min_zoom(), "max": cameras.max_zoom()}


## E2E (browser test mode only): grows the island to an n x n square so large
## worlds can be looked at and timed without playing for an hour.
func _dev_grow_island(arg: Variant) -> Dictionary:
	var n := int(arg)
	var world: WorldSystem = sim.system(&"world")
	for ring in range(2, n):
		for i in range(0, ring + 1):
			world.add_land(Vector2i(ring, i))
			world.add_land(Vector2i(i, ring))
	cameras.frame_island()
	return {"cells": world.owned_count()}


## E2E (browser test mode only): runs the simulation forward to a given
## fraction of a given day, through the normal event loop.
func _dev_advance_to(arg: Variant) -> Dictionary:
	var day := int(arg[0])
	var target := int(((day - 1) + float(arg[1])) * sim.clock.day_ms)
	if target > sim.now_ms():
		sim.advance_to(target)
	day_night.apply()
	return {"now_ms": sim.now_ms(), "day": sim.clock.day_number()}


## Corner buttons. Each opens its panel as later steps add them; until then
## pressing one is recorded and does nothing else.
func _on_hud_action(action_name: StringName) -> void:
	hud_actions.append(String(action_name))
	if hud_actions.size() > 20:
		hud_actions.pop_front()
	match action_name:
		&"land":
			selection.deselect()
			placement.close()
			build_menu.visible = false
			_close_frames()
			land_mode.toggle()
		&"settings":
			build_menu.visible = false
			land_mode.close()
			placement.close()
			var was := settings_frame.visible
			_close_frames()
			if not was:
				settings_view.refresh()
				settings_frame.open()
		&"shop", &"build":
			land_mode.close()
			placement.close()
			_close_frames()
			build_menu.toggle()
			_place_build_menu()
		&"status":
			build_menu.visible = false
			land_mode.close()
			placement.close()
			detail_frame.close()
			mail_frame.close()
			research_frame.close()
			status_frame.toggle(0)
		&"research":
			build_menu.visible = false
			land_mode.close()
			placement.close()
			status_frame.close()
			detail_frame.close()
			mail_frame.close()
			research_frame.toggle(0)
		&"mailbox":
			build_menu.visible = false
			land_mode.close()
			placement.close()
			status_frame.close()
			detail_frame.close()
			research_frame.close()
			open_mailbox()


## E2E: HUD texts, button rectangles (window pixels) and recent actions.
func _hud_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var to_window := func(r: Rect2) -> Array:
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var buttons := {}
	for key: StringName in hud.buttons:
		buttons[String(key)] = to_window.call((hud.buttons[key] as Control).get_global_rect())
	var win := DisplayServer.window_get_size()
	return {"day": hud._day_label.text, "seconds": hud._seconds_label.text, "money": hud._money_label.text,
		"level": hud._level_label.text, "exp": hud._exp_label.text, "buttons": buttons,
		"labels": hud.buttons.keys().map(func(k: StringName) -> String: return (hud.buttons[k] as HudButton)._label.text),
		"actions": hud_actions, "window": [win.x, win.y], "locale": LocaleService.current()}


## E2E: what is selected, the panel's cards (window pixels) and the last tap result.
func _selection_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var cards: Array = []
	for r: Rect2 in panel.card_rects():
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		cards.append([a.x, a.y, b.x - a.x, b.y - a.y])
	var win := DisplayServer.window_get_size()
	var enabled: Array = panel.cards.map(func(c: Button) -> bool: return not c.disabled)
	return {"kind": selection.kind, "id": selection.selected_id, "cell": [selection.selected_cell.x, selection.selected_cell.y],
		"cards": cards, "enabled": enabled, "result": selection.last_result, "window": [win.x, win.y]}


## E2E: land mode state and its buttons (window pixels).
func _land_mode_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var rect := func(c: Control) -> Array:
		var a: Vector2 = vp.get_final_transform() * c.get_global_rect().position
		var b: Vector2 = vp.get_final_transform() * c.get_global_rect().end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var win := DisplayServer.window_get_size()
	return {"active": land_mode.active, "chosen": [land_mode.chosen.x, land_mode.chosen.y],
		"buy": rect.call(land_mode.buy_button), "buy_disabled": land_mode.buy_button.disabled,
		"close": rect.call(land_mode.close_button), "cost": (sim.system(&"land") as LandSystem).next_cost(),
		"result": land_mode.last_result, "window": [win.x, win.y]}


func _place_build_menu() -> void:
	if build_menu == null:
		return
	# The catalog wraps: as many columns as fit beside the side buttons, so
	# cards form rows rather than one long strip off the screen.
	var room := get_viewport_rect().size.x - 32.0 - (get_viewport_rect().size.x - hud.side_buttons[0].position.x if not hud.side_buttons.is_empty() else 0.0)
	build_menu.list.columns = clampi(int((room - 24.0) / 160.0), 2, 4)
	build_menu.custom_minimum_size.x = 0.0
	build_menu.reset_size()
	var size := get_viewport_rect().size
	build_menu.position = Vector2(16.0 + maxf((room - build_menu.size.x) * 0.5, 0.0), size.y - build_menu.size.y - 104)


## E2E: shop cards, placement bar and state (window pixels).
func _build_ui_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var rect := func(c: Control) -> Array:
		var a: Vector2 = vp.get_final_transform() * c.get_global_rect().position
		var b: Vector2 = vp.get_final_transform() * c.get_global_rect().end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var cards := {}
	for type: String in build_menu.cards:
		cards[type] = rect.call(build_menu.cards[type])
	var win := DisplayServer.window_get_size()
	return {"menu_open": build_menu.visible, "cards": cards, "placing": placement.active, "type": placement.type,
		"anchor": [placement.anchor.x, placement.anchor.y], "valid": placement.check.get("ok", false),
		"reason": placement.check.get("reason", ""), "build": rect.call(placement.build_button),
		"result": placement.last_result, "panel_cards": panel.card_rects().map(func(r: Rect2) -> Array:
			var a: Vector2 = vp.get_final_transform() * r.position
			var b: Vector2 = vp.get_final_transform() * r.end
			return [a.x, a.y, b.x - a.x, b.y - a.y]), "window": [win.x, win.y]}


## A frame under the HUD, so the corner buttons stay usable over its scrim.
func _frame(ui: Control, frame_name: String) -> PanelFrame:
	var f := PanelFrame.new()
	f.name = frame_name
	ui.add_child(f)
	ui.move_child(f, hud.get_index())
	f.watch(sim)
	return f


func _close_frames() -> void:
	if away_frame != null:
		away_frame.close()
	if settings_frame != null:
		settings_frame.close()
	status_frame.close()
	detail_frame.close()
	mail_frame.close()
	research_frame.close()


## The mailbox, opening on the list of letters.
func open_mailbox() -> void:
	if mail_frame.visible:
		mail_frame.close()
		return
	mail_frame.set_title(tr("hud.mailbox"))
	mailbox_view.show_list()
	mail_frame.open()


func _place_frames() -> void:
	var size := get_viewport_rect().size
	# Keep the side buttons free.
	var reserved := size.x - hud.side_buttons[0].position.x + 8.0 if not hud.side_buttons.is_empty() else 16.0
	for f: PanelFrame in [status_frame, detail_frame, mail_frame, research_frame, away_frame, settings_frame]:
		if f == null:
			continue
		f.right_reserved = reserved
		f._layout()


func open_details(id: int) -> void:
	var b := (sim.system(&"buildings") as BuildingSystem).get_building(id)
	if b.is_empty():
		return
	status_frame.close()
	mail_frame.close()
	research_frame.close()
	build_menu.visible = false
	detail_frame.set_title(tr((sim.system(&"buildings") as BuildingSystem).type_def(b).get("name", "")))
	detail_view.show_building(id)
	detail_frame.open()


## E2E: what the panels show, read off their controls, and where to tap.
func _panels_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var rect := func(c: Control) -> Array:
		var r := c.get_global_rect()
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
	var tabs := {}
	for t: Dictionary in status_frame.tabs:
		tabs[String(t["key"]).trim_prefix("panel.tab.")] = rect.call(t["button"])
	var store := {}
	for item: String in inventory_view.rows:
		store[item] = (inventory_view.rows[item]["count"] as Label).text
	var today := {}
	for r: Node in economy_view.today_box.get_children():
		if r.has_node("Value"):
			today[String(r.name).trim_prefix("Cat_")] = (r.get_node("Value") as Label).text
	var workers: Array = []
	for c: Node in detail_view.workers_box.get_children():
		workers.append(String(c.get_meta("who", "")))
	return {
		"status_open": status_frame.visible, "tab": String(status_frame.tabs[status_frame.current]["key"]).trim_prefix("panel.tab.") if status_frame.current >= 0 else "",
		"detail_open": detail_frame.visible, "detail_title": detail_frame.title_label.text,
		"tabs": tabs, "card": rect.call(status_frame.card) if status_frame.visible else rect.call(detail_frame.card),
		"close": rect.call(status_frame.close_button) if status_frame.visible else rect.call(detail_frame.close_button),
		"context_title": rect.call(panel.title) if panel.title.visible else [],
		"store": store, "money": economy_view.money_label.text, "today": today, "records": stats_view.numbers(),
		"detail": {"state": detail_view.state_label.text, "workers": workers,
			"you": (detail_view.cycle_you.get_node("Value") as Label).text, "momo": (detail_view.cycle_momo.get_node("Value") as Label).text,
			"done": (detail_view.done_row.get_node("Value") as Label).text},
		"window": [win.x, win.y]}


## E2E: the tutorial as shown -- step, what it rings, where its buttons are.
func _tutorial_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var conv := func(r: Rect2) -> Array:
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
	return {"running": tutorial.running, "step": tutorial.step, "text": tutorial.text.text,
		"target": conv.call(tutorial.target), "target2": conv.call(tutorial.target2),
		"bubble": conv.call(tutorial.bubble.get_global_rect()),
		"skip": conv.call(tutorial.skip_button.get_global_rect()) if tutorial.skip_button.visible else [],
		"ok": conv.call(tutorial.ok_button.get_global_rect()) if tutorial.ok_button.visible else [],
		"done": bool(settings.get_value("tutorial_done")), "window": [win.x, win.y]}


## E2E: the settings panel, the demo badge and where to tap.
func _settings_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var conv := func(c: Control) -> Array:
		var r := c.get_global_rect()
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
	var langs := {}
	for code: String in settings_view.lang_buttons:
		langs[code] = conv.call(settings_view.lang_buttons[code])
	return {"open": settings_frame.visible, "in_demo": in_demo, "badge": _demo_badge.visible and _demo_badge.text != "",
		"tutorial": conv.call(settings_view.tutorial_button), "demo": conv.call(settings_view.demo_button),
		"demo_text": settings_view.demo_button.text, "langs": langs, "locale": LocaleService.current(), "window": [win.x, win.y]}


## E2E: the research menu as shown -- node states, the chosen node's details, where to tap.
func _research_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var rect := func(c: Control) -> Array:
		var r := c.get_global_rect()
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
	var research: ResearchSystem = sim.system(&"research")
	var view: ResearchView = research_frame.current_view() if research_frame.current >= 0 else null
	var nodes := {}
	if view != null:
		for id: String in view.cards:
			nodes[id] = {"state": research.state_of(id), "rect": rect.call(view.cards[id])}
	var tabs := {}
	for t: Dictionary in research_frame.tabs:
		tabs[String(t["key"])] = rect.call(t["button"])
	return {"open": research_frame.visible, "nodes": nodes, "tabs": tabs, "selected": view.selected if view else "",
		"name": view.detail_name.text if view else "", "effects": view.effect_lines(view.selected) if view and view.selected != "" else [],
		"needs": view.need_lines(view.selected) if view and view.selected != "" else [],
		"button": rect.call(view.start_button) if view else [], "button_text": view.start_button.text if view else "",
		"button_disabled": view.start_button.disabled if view else true, "active": research.active, "completed": research.completed.keys(),
		"badge": (hud.buttons[&"research"] as HudButton).badge, "window": [win.x, win.y]}


## E2E: the mailbox as shown -- rows, the open letter, where to tap.
func _mail_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var rect := func(c: Control) -> Array:
		var r := c.get_global_rect()
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
	var rows: Array = []
	for row: Node in mailbox_view.list_box.get_children():
		rows.append({"id": int(String(row.name).trim_prefix("Row_")), "unread": bool(row.get_meta("unread", false)), "rect": rect.call(row)})
	var mail: MailSystem = sim.system(&"mail")
	return {"open": mail_frame.visible, "reading": mailbox_view.open_id, "rows": rows,
		"badge": (hud.buttons[&"mailbox"] as HudButton).badge, "unread": mail.unread_count(),
		"title": mailbox_view.card.title_label.text, "body": mailbox_view.card.body_label.text,
		"from": mailbox_view.card.from_label.text, "proposal": mailbox_view.proposal_label.text,
		"claim": rect.call(mailbox_view.claim_button), "claim_text": mailbox_view.claim_button.text,
		"claimed": mailbox_view.claim_button.disabled, "back": rect.call(mailbox_view.back_button),
		"envelopes": momo_views.actors.keys().filter(func(k: int) -> bool: return (momo_views.actors[k] as MomoActor).envelope.visible),
		"window": [win.x, win.y]}


## E2E: the Status panel's numbers.
func _status_info(_arg: Variant) -> Dictionary:
	var out := {"open": status_frame.visible and status_frame.current == 0, "level": status_panel.level_label.text, "exp": status_panel.exp_label.text, "mastery": {}}
	for type: String in status_panel.cards:
		var card: PanelContainer = status_panel.cards[type]
		out["mastery"][type] = (card.find_child("Exp", true, false) as Label).text
	return out


func _place_momo_panel() -> void:
	if momo_panel == null or not momo_panel.visible:
		return
	momo_panel.reset_size()
	var size := get_viewport_rect().size
	momo_panel.position = Vector2(hud.bottom_left_end + 8.0, size.y - momo_panel.size.y - hud.bottom_margin)
	if momo_panel.position.x + momo_panel.size.x > size.x - 8.0:
		momo_panel.position.x = maxf(8.0, size.x - momo_panel.size.x - 8.0)
		momo_panel.position.y -= 80.0


## E2E: Momo positions on screen (window pixels), their assignment, and the drag/selection state.
func _momo_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var out := {}
	var momos: MomoSystem = sim.system(&"momo")
	for id: int in momo_views.actors:
		var a: MomoActor = momo_views.actors[id]
		var body: Vector2 = vp.get_final_transform() * (vp.get_canvas_transform() * (a.position + Vector2(0, -35)))
		var feet: Vector2 = vp.get_final_transform() * (vp.get_canvas_transform() * a.position)
		out[str(id)] = {"body": [body.x, body.y], "feet": [feet.x, feet.y], "assigned": int(momos.get_momo(id)["assigned"]),
			"moving": momos.is_moving(id), "state": a.rig.state}
	var win := DisplayServer.window_get_size()
	return {"momos": out, "drag": momo_drag.last_result, "selected": selection.kind, "assigning": momo_panel.assigning, "window": [win.x, win.y]}
