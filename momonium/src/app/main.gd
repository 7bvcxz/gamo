extends Node2D

## Composition root. Builds the Simulation, then the views that show it, and
## hands each view the simulation it reads -- nothing is reached through a
## global. Owns the frame loop: real time in, simulated time out.

## Where the island's centre sits on screen, as a fraction of the height: the
## sky takes the top two fifths, the island the middle of the rest.
const ISLAND_SCREEN_Y := 0.68

var sim: Simulation
var projection: IsoProjection
var bridge := WebBridge.new()
var camera: Camera2D
var island: IslandRenderer
var _version_label: Label


func _ready() -> void:
	sim = Simulation.new_game()
	projection = IsoProjection.from_data(sim.data)

	var back := CanvasLayer.new()
	back.name = "Background"
	back.layer = -10
	back.add_child(Backdrop.new())
	add_child(back)

	var world_root := Node2D.new()
	world_root.name = "World"
	add_child(world_root)
	island = IslandRenderer.new()
	island.name = "Island"
	world_root.add_child(island)
	island.setup(sim, projection)
	camera = Camera2D.new()
	camera.name = "Camera"
	world_root.add_child(camera)
	camera.make_current()

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	_version_label = Label.new()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0")
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_version_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(_version_label)
	get_viewport().size_changed.connect(_layout)
	_layout()

	bridge.attach(sim, _version_label.text.trim_prefix("v"))
	bridge.register_query("save_roundtrip", _save_roundtrip)
	bridge.register_query("art_info", _art_info)
	bridge.register_query("cell_screen", _cell_screen)


func _process(delta: float) -> void:
	sim.advance_seconds(delta)


func _layout() -> void:
	var size := get_viewport_rect().size
	_version_label.position = size - Vector2(84, 28)
	_frame_island(size)


## Fits the island into the lower part of the screen. Replaced by the camera
## controller in Step 07.
func _frame_island(size: Vector2) -> void:
	var world: WorldSystem = sim.system(&"world")
	var b := world.bounds()
	var pts := PackedVector2Array()
	for cell: Vector2i in [b.position, b.end - Vector2i.ONE, Vector2i(b.position.x, b.end.y - 1), Vector2i(b.end.x - 1, b.position.y)]:
		pts.append_array(projection.cell_corners(cell))
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p: Vector2 in pts:
		rect = rect.expand(p)
	var zoom := clampf(size.x * 0.62 / maxf(rect.size.x, 1.0), 0.2, 4.0)
	camera.zoom = Vector2(zoom, zoom)
	camera.position = rect.get_center() - Vector2(0, (ISLAND_SCREEN_Y - 0.5) * size.y / zoom)


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
	var cell := Vector2i(int(arg[0]), int(arg[1]))
	var world_pos := projection.cell_center(cell)
	var vp := get_viewport()
	var window_pos: Vector2 = vp.get_final_transform() * (vp.get_canvas_transform() * world_pos)
	var win := DisplayServer.window_get_size()
	return {"x": window_pos.x, "y": window_pos.y, "window": [win.x, win.y]}
