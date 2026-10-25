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
var selection: SelectionController
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
	selection = SelectionController.new()
	selection.name = "Selection"
	add_child(selection)
	selection.setup(sim, projection, building_views, marker, panel, router)
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
	bridge.register_query("hud", _hud_info)
	bridge.register_query("dev_place_building", func(arg: Variant) -> Dictionary:
		var id := (sim.system(&"buildings") as BuildingSystem).place_instant(String(arg[0]), Vector2i(int(arg[1]), int(arg[2])))
		return {"id": id})
	bridge.register_query("selection", _selection_info)
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
	return {"kind": selection.kind, "id": selection.selected_id, "cell": [selection.selected_cell.x, selection.selected_cell.y],
		"cards": cards, "result": selection.last_result, "window": [win.x, win.y]}
