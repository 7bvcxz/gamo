class_name PlacementMode
extends Control

## Placing a building chosen in the shop. While active, a tap on the island
## moves the ghost there; the bar shows the building, its price and whether it
## can go there (green Build) or not (the reason, Build disabled). Build pays
## and starts construction, then the mode closes and the new building is
## selected so its construction shows. ✕ cancels without spending anything.

signal placed(id: int)

var sim: Simulation
var buildings: BuildingSystem
var preview: PlacementPreview
var projection: IsoProjection
var lib: SpriteLibrary
var active := false
var type := ""
var anchor := Vector2i(-99999, -99999)
var check: Dictionary = {}
var last_result: Dictionary = {}

var bar: PanelContainer
var name_label: Label
var status_label: Label
var build_button: Button
var close_button: Button


func setup(p_sim: Simulation, p_preview: PlacementPreview, p_projection: IsoProjection, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	buildings = sim.system(&"buildings")
	preview = p_preview
	projection = p_projection
	lib = p_lib
	name = "PlacementMode"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar = PanelContainer.new()
	bar.name = "PlacementBar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 20)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	col.add_child(name_label)
	col.add_child(status_label)
	row.add_child(col)
	build_button = Button.new()
	build_button.name = "Build"
	build_button.custom_minimum_size = Vector2(140, 64)
	build_button.focus_mode = Control.FOCUS_NONE
	build_button.icon = lib.atlas_texture("ui_build")
	build_button.add_theme_constant_override("icon_max_width", 28)
	build_button.add_theme_font_size_override("font_size", 22)
	build_button.pressed.connect(confirm)
	row.add_child(build_button)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(64, 64)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(close)
	row.add_child(close_button)
	bar.add_child(row)
	bar.visible = false
	add_child(bar)
	resized.connect(_layout)


func open(p_type: String) -> void:
	type = p_type
	active = true
	# Start on the first free cell so the ghost is visible at once.
	var world: WorldSystem = sim.system(&"world")
	var free := world.buildable_cells()
	anchor = free[0] if not free.is_empty() else world.owned_cells()[0]
	bar.visible = true
	_update()


func close() -> void:
	if not active:
		return
	active = false
	preview.clear()
	bar.visible = false


func on_world_tap(world_pos: Vector2) -> void:
	anchor = projection.cell_at(world_pos)
	_update()


func confirm() -> void:
	if not active:
		return
	last_result = sim.execute({"type": "building.place", "building": type, "anchor": [anchor.x, anchor.y]})
	if last_result["ok"]:
		close()
		placed.emit(int(last_result["id"]))
	else:
		_update()


func _update() -> void:
	check = buildings.can_place(type, anchor)
	preview.show_at(type, anchor, check["ok"])
	var def := sim.data.building_type(type)
	var money := int((def.get("cost", {}) as Dictionary).get("money", 0))
	name_label.text = "%s  $%d" % [tr(def.get("name", type)), money]
	build_button.text = tr("build.build")
	build_button.disabled = not check["ok"]
	status_label.text = "" if check["ok"] else _reason(check)
	status_label.modulate = Color("#ffb3a8")
	_layout()


func _reason(r: Dictionary) -> String:
	var key := String(r.get("reason", ""))
	if key == "err.locked":
		return tr(key) % int(r.get("level", 1))
	return tr(key)


func _layout() -> void:
	if bar == null:
		return
	bar.reset_size()
	bar.position = Vector2((size.x - bar.size.x) * 0.5, size.y - bar.size.y - 104)
