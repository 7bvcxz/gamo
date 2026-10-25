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
## The last few HUD actions, newest last (for the browser bridge and tests).
var hud_actions: Array[String] = []
var entities: EntityLayer
var _version_label: Label


func _ready() -> void:
	sim = Simulation.new_game()
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

	LocaleService.apply(LocaleService.detect())
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var lib := SpriteLibrary.load_atlas()
	panel = ContextPanel.new()
	ui.add_child(panel)
	panel.setup(sim, lib)
	hud = Hud.new()
	ui.add_child(hud)
	hud.setup(sim, lib)
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
	status_panel = StatusPanel.new()
	ui.add_child(status_panel)
	status_panel.setup(sim, lib)
	status_panel.resized.connect(_place_status_panel)
	_version_label = Label.new()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0")
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_version_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(_version_label)
	get_viewport().size_changed.connect(_layout)
	_layout()
	cameras.frame_island()

	bridge.attach(sim, _version_label.text.trim_prefix("v"))
	bridge.register_query("save_roundtrip", _save_roundtrip)
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
	sim.advance_seconds(delta)


func _layout() -> void:
	var size := get_viewport_rect().size
	_version_label.position = size - Vector2(84, 28)
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
			land_mode.toggle()
		&"shop":
			land_mode.close()
			placement.close()
			status_panel.visible = false
			build_menu.toggle()
			_place_build_menu()
		&"status":
			build_menu.visible = false
			status_panel.toggle()
			_place_status_panel()


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
	build_menu.reset_size()
	var size := get_viewport_rect().size
	build_menu.position = Vector2((size.x - build_menu.size.x) * 0.5, size.y - build_menu.size.y - 104)


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


func _place_status_panel() -> void:
	if status_panel == null:
		return
	status_panel.reset_size()
	var size := get_viewport_rect().size
	# Centred in the space left of the side buttons, so they stay usable.
	var right := hud.side_buttons[0].position.x - 8.0 if not hud.side_buttons.is_empty() else size.x - 16.0
	var left := 16.0
	status_panel.position = Vector2(left + maxf((right - left - status_panel.size.x) * 0.5, 0.0), size.y * 0.16)


## E2E: the Status panel's numbers.
func _status_info(_arg: Variant) -> Dictionary:
	var out := {"open": status_panel.visible, "level": status_panel.level_label.text, "exp": status_panel.exp_label.text, "mastery": {}}
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
