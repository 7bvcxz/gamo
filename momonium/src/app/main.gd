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
## An occasional fish jumping by the shore.
var sea_life: SeaLife
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
## The selected Momo's watched tiles, and the pencil that edits them.
var watch_overlay: WatchOverlay
var watch_editor: WatchEditor
var selection: SelectionController
var land_preview: LandPreview
## Buying the sea next to the island where it is (hover/click, tap twice).
var land_buyer: LandBuyer
## The shop (bottom-left): hiring.
var shop_menu: ShopMenu
## Four choices beside a tapped empty tile: the only way to build.
var build_strip: BuildStrip
var status_panel: StatusPanel
## Status, store, money and records, as tabs of one frame.
var status_frame: PanelFrame
var inventory_view: InventoryView
var economy_view: EconomyView
var stats_view: StatsView
var life_view: LifeView
var analytics_view: AnalyticsView
## Everything about one building, opened from its name.
var detail_frame: PanelFrame
var detail_view: BuildingDetailView
## The technology tree, one tab per industry.
var research_frame: PanelFrame
var research_views: Array[ResearchView] = []
## Power at a glance (from the HUD's power pill).
## Selling the island, and placing research points.
var sale_frame: PanelFrame
var sale_view: SaleView
var rp_view: RpView
var power_frame: PanelFrame
var power_view: PowerView
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
## The last sale's result (E2E reads it).
var last_sale: Dictionary = {}
## The confetti when the settlement goes up a tier.
var celebration: TierCelebration
## Music, ambience and effects.
var audio: AudioService
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
	sea_life = SeaLife.new()
	sea_life.name = "SeaLife"
	world_root.add_child(sea_life)
	island.setup(sim, projection)
	marker = SelectionMarker.new()
	marker.name = "SelectionMarker"
	marker.projection = projection
	world_root.add_child(marker)
	watch_overlay = WatchOverlay.new()
	watch_overlay.name = "WatchOverlay"
	world_root.add_child(watch_overlay)
	land_preview = LandPreview.new()
	land_preview.name = "LandPreview"
	world_root.add_child(land_preview)
	land_preview.setup(sim, projection)
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
	sea_life.setup(sim, projection)
	watch_overlay.setup(sim, projection)
	watch_editor = WatchEditor.new()
	ui.add_child(watch_editor)
	watch_editor.setup(sim, cameras, projection, momo_views, watch_overlay)
	watch_editor.editing_changed.connect(func(on: bool) -> void:
		if on:
			momo_panel.assigning = false)
	selection.watch_editor = watch_editor
	# Before the Momo drag: while editing, a stroke paints tiles.
	router.add_drag_handler(watch_editor)
	momo_drag = MomoDrag.new()
	momo_drag.setup(sim, projection, momo_views, building_views)
	router.add_drag_handler(momo_drag)
	land_preview.font = ui.get_theme_default_font()
	land_buyer = LandBuyer.new()
	land_buyer.setup(sim, land_preview, projection)
	selection.land_buyer = land_buyer
	router.hovered.connect(func(_screen: Vector2, world_pos: Vector2) -> void:
		if not watch_editor.active:
			land_buyer.on_hover(world_pos))
	build_strip = BuildStrip.new()
	ui.add_child(build_strip)
	build_strip.setup(sim, lib, cameras, projection)
	build_strip.built.connect(func(id: int) -> void: selection.select_building(id))
	selection.build_strip = build_strip
	shop_menu = ShopMenu.new()
	ui.add_child(shop_menu)
	shop_menu.setup(sim, lib)
	shop_menu.resized.connect(_place_shop_menu)
	shop_menu.hire_requested.connect(func() -> void:
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
	life_view = LifeView.new()
	life_view.setup(sim, lib)
	status_frame.add_tab("panel.tab.life", life_view)
	analytics_view = AnalyticsView.new()
	analytics_view.setup(sim, lib)
	status_frame.add_tab("panel.tab.stats", analytics_view)
	analytics_view.building_chosen.connect(func(id: int) -> void: open_details(id))
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
		# A building industry is named as its mastery; other branches (power, general) by their own key.
		research_frame.add_tab("mastery." + industry if not sim.data.building_type(industry).is_empty() else "research.industry." + industry, rv)
	rp_view = RpView.new()
	rp_view.setup(sim, lib)
	research_frame.add_tab("rp.tab", rp_view)
	rp_view.done.connect(func() -> void:
		research_frame.close())
	research_frame.closed.connect(func() -> void:
		if (sim.system(&"prestige") as PrestigeSystem).welcome:
			sim.execute({"type": "prestige.welcomed"}))
	research_frame.set_title(tr("hud.research"))
	celebration = TierCelebration.new()
	celebration.setup()
	ui.add_child(celebration)
	sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
		if type == &"tier_promoted":
			_close_frames()
			celebration.play(tr("tier.promoted").format({"name": tr("tier." + String(p["name"]))})))
	sale_frame = _frame(ui, "SaleFrame")
	sale_view = SaleView.new()
	sale_view.setup(sim, lib)
	sale_frame.add_tab("", sale_view)
	sale_view.sell_confirmed.connect(sell_settlement)
	economy_view.sale_requested.connect(open_sale)
	power_frame = _frame(ui, "PowerFrame")
	power_view = PowerView.new()
	power_view.setup(sim, lib)
	power_frame.add_tab("", power_view)
	panel.details_pressed.connect(open_details)
	panel.demolish_pressed.connect(func(id: int) -> void:
		selection.last_result = sim.execute({"type": "building.demolish", "id": id})
		if selection.last_result["ok"]:
			_close_frames()
			selection.deselect())
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
	audio = AudioService.new()
	add_child(audio)
	audio.setup(sim, settings)
	audio.start()
	settings_view = SettingsView.new()
	settings_view.setup(sim, lib)
	settings_view.audio = audio
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
	tutorial.setup(sim, hud, build_strip, cameras, projection, building_views, panel)
	tutorial.finished.connect(func(_skipped: bool) -> void: settings.set_value("tutorial_done", true))
	_place_frames()

	bridge.attach(sim, _version_label.text.trim_prefix("v"))
	_maybe_start_tutorial.call_deferred()
	if (sim.system(&"prestige") as PrestigeSystem).welcome:
		open_rp.call_deferred()
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
	bridge.register_query("land_buy", _land_buy_info)
	bridge.register_query("build_ui", _build_ui_info)
	bridge.register_query("status", _status_info)
	bridge.register_query("panels", _panels_info)
	bridge.register_query("mail", _mail_info)
	bridge.register_query("research", _research_info)
	bridge.register_query("sale", func(_a: Variant) -> Dictionary:
		var vp := get_viewport()
		var conv := func(c: Control) -> Array:
			var r := c.get_global_rect()
			var a: Vector2 = vp.get_final_transform() * r.position
			var b: Vector2 = vp.get_final_transform() * r.end
			return [a.x, a.y, b.x - a.x, b.y - a.y]
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		var p: PrestigeSystem = sim.system(&"prestige")
		return {"open": sale_frame.visible, "appraisal": p.appraise(), "points": p.points, "sales": p.sales, "welcome": p.welcome,
			"sell": conv.call(sale_view.sell_button) if sale_frame.visible else [], "sell_text": sale_view.sell_button.text,
			"sell_disabled": sale_view.sell_button.disabled, "confirming": sale_view.confirming,
			"entry": conv.call(economy_view.sale_button) if economy_view.sale_button.is_visible_in_tree() else [],
			"last_sale": {"ok": last_sale.get("ok", false), "reason": last_sale.get("reason", ""), "gained": last_sale.get("gained", 0), "rp_issued": last_sale.get("rp_issued", 0)},
			"status": load_status, "window": [win.x, win.y]})
	bridge.register_query("rp", func(_a: Variant) -> Dictionary:
		var vp := get_viewport()
		var conv := func(c: Control) -> Array:
			var r := c.get_global_rect()
			var a: Vector2 = vp.get_final_transform() * r.position
			var b: Vector2 = vp.get_final_transform() * r.end
			return [a.x, a.y, b.x - a.x, b.y - a.y]
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		var rs: ResearchSystem = sim.system(&"research")
		var rows := {}
		for id: String in rp_view.rows:
			var r: Control = rp_view.rows[id]
			rows[id] = {"level": rs.level(id), "draft": int(rp_view.draft.get(id, 0)), "label": (r.get_node("Level") as Label).text,
				"preview": (r.find_child("Preview", true, false) as Label).text,
				"minus": conv.call(r.get_node("Minus")), "plus": conv.call(r.get_node("Plus")),
				"plus_disabled": (r.get_node("Plus") as Button).disabled}
		return {"open": research_frame.visible and research_frame.current_view() == rp_view, "earned": rs.rp_earned, "unspent": rs.rp_unspent(),
			"pending": rs.rp_pending(), "allocated": rs.allocated, "unlocked": rs.unlocked.keys(), "head": rp_view.head.text, "rows": rows,
			"confirm": conv.call(rp_view.confirm_button) if rp_view.is_visible_in_tree() else [], "confirm_disabled": rp_view.confirm_button.disabled,
			"why": rp_view.why.text, "result": rp_view.last_result, "draft": rp_view.draft,
			"profiles": range(ResearchSystem.PROFILES).map(func(i: int) -> Dictionary: return {"text": rp_view.profile_buttons[i].text,
				"load": conv.call(rp_view.profile_buttons[i]), "save": conv.call(rp_view.save_buttons[i]), "levels": rs.profiles[i]}),
			"window": [win.x, win.y]})
	bridge.register_query("route", func(_a: Variant) -> Dictionary:
		var vp := get_viewport()
		var r := momo_panel.route_button.get_global_rect()
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		var momo := momo_panel.momo_id
		return {"momo": momo, "route": (sim.system(&"momo") as MomoSystem).route_of(momo) if momo != 0 else "",
			"label": momo_panel.route_button.text, "button": [a.x, a.y, b.x - a.x, b.y - a.y] if momo_panel.route_button.is_visible_in_tree() else [],
			"compare": momo_panel.compare_label.text if momo_panel.compare_label.visible else "", "stops": watch_overlay.route(), "window": [win.x, win.y]})
	bridge.register_query("tier", func(_a: Variant) -> Dictionary:
		var vp := get_viewport()
		var tv := status_panel.tier_view
		var r := tv.promote_button.get_global_rect()
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		var tiers: TierSystem = sim.system(&"tiers")
		return {"tier": tiers.tier_name(), "slots": tiers.special_slots(), "progress": tiers.progress(), "can": tiers.can_promote(),
			"head": tv.head.text, "promote": [a.x, a.y, b.x - a.x, b.y - a.y] if tv.promote_button.is_visible_in_tree() else [],
			"promote_disabled": tv.promote_button.disabled, "celebrating": celebration.playing(), "celebration": celebration.text,
			"badge": hud.buttons[&"status"].badge, "window": [win.x, win.y]})
	# Money as if from sales (browser tests of what counts produced value).
	bridge.register_query("dev_sale", func(amount: Variant) -> Dictionary:
		(sim.system(&"economy") as EconomySystem).earn(int(amount), "sale")
		return {"money": (sim.system(&"economy") as EconomySystem).money})
	# Frame-rate profiles: cap the engine, count what it draws.
	bridge.register_query("dev_max_fps", func(fps: Variant) -> Dictionary:
		Engine.max_fps = int(fps)
		return {"max_fps": Engine.max_fps})
	bridge.register_query("frames", func(_a: Variant) -> Dictionary:
		return {"drawn": Engine.get_frames_drawn(), "fps": Engine.get_frames_per_second(), "ticks": Time.get_ticks_msec()})
	bridge.register_query("vfx", func(_a: Variant) -> Dictionary:
		var tiers := {}
		for id: int in building_views.views:
			tiers[str(id)] = (building_views.views[id] as BuildingView).pennant_tier()
		return {"night": BuildingView.night_strength(BuildingView.ambient, float(sim.data.get_value("art", "night_lights", {}).get("start", 0.25))),
			"splash": sea_life.current().keys().size() > 0, "pennants": tiers, "phase": day_night.describe()["phase"]})
	bridge.register_query("audio", func(_a: Variant) -> Dictionary:
		var buses := {}
		for bus: String in AudioService.BUSES:
			var i := AudioServer.get_bus_index(bus)
			buses[bus] = {"db": AudioServer.get_bus_volume_db(i), "mute": AudioServer.is_bus_mute(i)}
		var vp := get_viewport()
		var conv := func(c: Control) -> Array:
			var r := c.get_global_rect()
			var a: Vector2 = vp.get_final_transform() * r.position
			var b: Vector2 = vp.get_final_transform() * r.end
			return [a.x, a.y, b.x - a.x, b.y - a.y]
		var sl := {}
		for key: String in settings_view.sliders:
			sl[key] = {"value": (settings_view.sliders[key] as HSlider).value, "rect": conv.call(settings_view.sliders[key]) if settings_view.is_visible_in_tree() else []}
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		return {"played": audio.played, "level": audio.level, "target": audio.target, "buses": buses, "master_mute": AudioServer.is_bus_mute(0),
			"music": audio.music.playing, "sliders": sl, "mute": conv.call(settings_view.mute_toggle) if settings_view.is_visible_in_tree() else [],
			"settings": {"music_volume": settings.get_value("music_volume"), "ambience_volume": settings.get_value("ambience_volume"), "sfx_volume": settings.get_value("sfx_volume"), "muted": settings.get_value("muted")},
			"window": [win.x, win.y]})
	bridge.register_query("dev_level", func(lv: Variant) -> Dictionary:
		var prog: ProgressionSystem = sim.system(&"progression")
		while prog.level < int(lv):
			prog.add_exp(prog.next_level_exp() - prog.experience, "dev")
		return {"level": prog.level})
	bridge.register_query("watch", func(_a: Variant) -> Dictionary:
		var vp := get_viewport()
		var conv := func(c: Control) -> Array:
			var r := c.get_global_rect()
			var a: Vector2 = vp.get_final_transform() * r.position
			var b: Vector2 = vp.get_final_transform() * r.end
			return [a.x, a.y, b.x - a.x, b.y - a.y]
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		var cells := watch_overlay.tinted().map(func(c: Vector2i) -> Array: return [c.x, c.y])
		var m := watch_editor.momo
		return {"momo": m, "editing": watch_editor.active, "tinted": cells,
			"capacity": (sim.system(&"momo") as MomoSystem).watch_capacity(m) if m != 0 else 0,
			"pencil": conv.call(watch_editor.pencil) if watch_editor.visible else [],
			"count": watch_editor.count_label.text if watch_editor.count_label.visible else "",
			"result": watch_editor.last_result, "window": [win.x, win.y]})
	bridge.register_query("strip", func(_a: Variant) -> Dictionary:
		var vp := get_viewport()
		var conv := func(c: Control) -> Array:
			var r := c.get_global_rect()
			var a: Vector2 = vp.get_final_transform() * r.position
			var b: Vector2 = vp.get_final_transform() * r.end
			return [a.x, a.y, b.x - a.x, b.y - a.y]
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		var buttons := {}
		for t: String in build_strip.buttons:
			buttons[t] = {"rect": conv.call(build_strip.buttons[t]), "disabled": (build_strip.buttons[t] as Button).disabled,
				"price": ((build_strip.buttons[t] as Button).find_child("Price", true, false) as Label).text}
		var specials := {}
		for t: String in build_strip.special_buttons:
			var b: Button = build_strip.special_buttons[t]
			specials[t] = {"rect": conv.call(b), "disabled": b.disabled, "price": (b.find_child("Price", true, false) as Label).text}
		return {"open": build_strip.open, "cell": [build_strip.cell.x, build_strip.cell.y], "buttons": buttons, "mode": build_strip.mode,
			"special": conv.call(build_strip.special_button) if build_strip.special_button != null and build_strip.open else [],
			"back": conv.call(build_strip.back_button) if build_strip.back_button != null and build_strip.open else [], "specials": specials,
			"trash": conv.call(panel.trash_button) if panel.trash_button.visible else [],
			"confirm": conv.call(panel.confirm_button) if panel.confirm_button.visible else [],
			"result": build_strip.last_result, "window": [win.x, win.y]})
	bridge.register_query("dev_select_cell", func(cell: Variant) -> Dictionary:
		var id := (sim.system(&"buildings") as BuildingSystem).building_at(Vector2i(int(cell[0]), int(cell[1])))
		if id != 0:
			selection.select_building(id)
		return {"id": id})
	bridge.register_query("life", func(_a: Variant) -> Dictionary:
		var c: CommunitySystem = sim.system(&"community")
		life_view.refresh()
		return {"happiness": c.happiness(), "homes": (life_view.homes_row.get_node("Value") as Label).text, "homeless": life_view.homeless.visible,
			"work": (life_view.work_row.get_node("Value") as Label).text, "parts": c.breakdown()})
	bridge.register_query("power", func(_a: Variant) -> Dictionary:
		var power: PowerSystem = sim.system(&"power")
		var vp := get_viewport()
		var r := hud.power_pill.get_global_rect()
		var a: Vector2 = vp.get_final_transform() * r.position
		var b: Vector2 = vp.get_final_transform() * r.end
		var win := vp.get_visible_rect().size * vp.get_final_transform().get_scale()
		return {"supply": power.supply(), "demand": power.demand(), "ratio": power.ratio(), "capacity": power.capacity(),
			"pill": hud.power_pill.visible, "pill_text": hud.power_label.text, "pill_rect": [a.x, a.y, b.x - a.x, b.y - a.y],
			"open": power_frame.visible, "head": power_view.head.text, "window": [win.x, win.y]})
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
	bridge.register_query("dev_add_items", func(arg: Variant) -> Dictionary:
		var inv: InventorySystem = sim.system(&"inventory")
		for item: String in (arg as Dictionary):
			inv.add(item, int(arg[item]), "dev")
		return inv.save_state())
	bridge.register_query("dev_research_done", func(ids: Variant) -> Dictionary:
		var research: ResearchSystem = sim.system(&"research")
		for id: Variant in ids:
			research.completed[String(id)] = sim.now_ms()
		sim.bus.emit(&"research_completed", {"id": String(ids[-1]) if not ids.is_empty() else ""})
		return {"completed": research.completed.keys()})
	# Levels researched this run, as if paid for and waited out (browser tests).
	bridge.register_query("dev_research_levels", func(levels: Variant) -> Dictionary:
		var research: ResearchSystem = sim.system(&"research")
		for id: String in (levels as Dictionary):
			research.bought[id] = int(levels[id])
			research.unlocked[id] = true
			if not research.completed.has(id):
				research.completed[id] = sim.now_ms()
			sim.bus.emit(&"research_completed", {"id": id})
		return {"pending": research.rp_pending()})
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
		out["takes"] = (detail_view.takes_row.get_node("Value") as Label).text if detail_view.takes_row.visible else ""
		var refits := {}
		if detail_view.refit_box.visible:
			for c: Node in detail_view.refit_box.get_children():
				var r := (c as Control).get_global_rect()
				var a: Vector2 = vp.get_final_transform() * r.position
				var b: Vector2 = vp.get_final_transform() * r.end
				refits[String(c.name).trim_prefix("Refit_")] = {"rect": [a.x, a.y, b.x - a.x, b.y - a.y], "disabled": (c as Button).disabled,
					"price": ((c as Button).find_child("Price", true, false) as Label).text}
		out["refits"] = refits
		out["result"] = detail_view.last_result
		if detail_view.priority_box.visible:
			var pr := {}
			for p: String in ManagerSystem.PRIORITIES:
				var r := (detail_view.priority_box.get_node("P_" + p) as Control).get_global_rect()
				var a: Vector2 = vp.get_final_transform() * r.position
				var b: Vector2 = vp.get_final_transform() * r.end
				pr[p] = [a.x, a.y, b.x - a.x, b.y - a.y]
			out["priority"] = pr
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
	# A sold island hands over the new one (already saved when saving is on).
	if Engine.has_meta("momonium_handoff"):
		var next: Simulation = Engine.get_meta("momonium_handoff")
		Engine.remove_meta("momonium_handoff")
		load_status = "sold"
		return next
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


## Selling: the appraisal opens in its own frame.
func open_sale() -> void:
	_close_frames()
	sale_view.confirming = false
	sale_frame.set_title(tr("sale.title"))
	sale_frame.open()


## Sells the island: the new one is saved (when saving is on) and the scene
## starts again on it, opening on its research points.
func sell_settlement() -> void:
	var r := PrestigeSystem.sell(sim)
	last_sale = r
	if not r["ok"]:
		return
	var next: Simulation = r["sim"]
	if persist and not save_blocked:
		var text := SaveService.encode(next)
		SaveService.write_text(text, save_path)
		WebStorage.set_item(MIRROR_KEY, text)
	Engine.set_meta("momonium_handoff", next)
	# The game restarts on it; a test that holds Main itself takes it from there.
	if get_tree().current_scene == self:
		get_tree().reload_current_scene.call_deferred()


## A new island from a sale opens on the research points to place.
func open_rp() -> void:
	_close_frames()
	rp_view.reset_draft()
	research_frame.open(research_frame.tabs.size() - 1)


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
	build_strip.close()
	watch_editor.end_edit()
	match action_name:
		&"settings":
			shop_menu.visible = false
			var was := settings_frame.visible
			_close_frames()
			if not was:
				settings_view.refresh()
				settings_frame.open()
		&"shop":
			selection.deselect()
			_close_frames()
			shop_menu.toggle()
			_place_shop_menu()
		&"status":
			shop_menu.visible = false
			detail_frame.close()
			mail_frame.close()
			research_frame.close()
			status_frame.toggle(0)
		&"power":
			shop_menu.visible = false
			var was := power_frame.visible
			_close_frames()
			if not was:
				power_frame.set_title(tr("research.industry.power"))
				power_frame.open()
		&"research":
			shop_menu.visible = false
			status_frame.close()
			detail_frame.close()
			mail_frame.close()
			research_frame.toggle(0)
		&"mailbox":
			shop_menu.visible = false
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
		"actions": hud_actions, "window": [win.x, win.y], "locale": LocaleService.current(),
		"burst": {"visible": hud.burst_pill.visible, "active": hud.burst_active, "text": hud.burst_text}}


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


## E2E: the land preview (which tile, price, line under it) and the last purchase.
func _land_buy_info(_arg: Variant) -> Dictionary:
	var f := land_preview.focus
	return {"focus": [] if f == LandPreview.NONE else [f.x, f.y], "pending": [] if land_buyer.pending == LandPreview.NONE else [land_buyer.pending.x, land_buyer.pending.y],
		"price": land_preview.price_text(), "hint": land_preview.hint, "affordable": land_preview.affordable,
		"cost": (sim.system(&"land") as LandSystem).next_cost(), "result": land_buyer.last_result}


func _place_shop_menu() -> void:
	if shop_menu == null:
		return
	shop_menu.reset_size()
	var size := get_viewport_rect().size
	shop_menu.position = Vector2(16.0, size.y - shop_menu.size.y - 104)


## E2E: shop cards and the stage cards under a selected building (window pixels).
func _build_ui_info(_arg: Variant) -> Dictionary:
	var vp := get_viewport()
	var rect := func(c: Control) -> Array:
		var a: Vector2 = vp.get_final_transform() * c.get_global_rect().position
		var b: Vector2 = vp.get_final_transform() * c.get_global_rect().end
		return [a.x, a.y, b.x - a.x, b.y - a.y]
	var cards := {}
	for type: String in shop_menu.cards:
		cards[type] = rect.call(shop_menu.cards[type])
	var win := DisplayServer.window_get_size()
	return {"menu_open": shop_menu.visible, "cards": cards, "panel_cards": panel.card_rects().map(func(r: Rect2) -> Array:
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
	if power_frame != null:
		power_frame.close()
	if sale_frame != null:
		sale_frame.close()
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
	for f: PanelFrame in [status_frame, detail_frame, mail_frame, research_frame, away_frame, settings_frame, power_frame]:
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
	shop_menu.visible = false
	detail_frame.set_title(BuildingDetailView.full_name(sim, String(b["type"])))
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
