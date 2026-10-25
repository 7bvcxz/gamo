class_name MomoPanel
extends PanelContainer

## The small card for a selected Momo: face, name, what it is doing, and the
## buttons that do without dragging what a drag does -- Assign (then tap a
## building) and Release. Accessible for anyone who cannot or would rather not
## drag.

signal assign_requested(momo: int)
signal release_requested(momo: int)

var sim: Simulation
var momos: MomoSystem
var momo_id := 0
var name_label: Label
var status_label: Label
var assign_button: Button
var release_button: Button
var assigning := false


func setup(p_sim: Simulation, lib: SpriteLibrary) -> void:
	sim = p_sim
	momos = sim.system(&"momo")
	name = "MomoPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var face := TextureRect.new()
	face.texture = lib.atlas_texture("momo_front")
	face.custom_minimum_size = Vector2(64, 64)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.modulate = Color(1, 1, 1, 0.85)
	col.add_child(name_label)
	col.add_child(status_label)
	row.add_child(col)
	assign_button = _button("Assign")
	assign_button.pressed.connect(func() -> void:
		assigning = not assigning
		assign_requested.emit(momo_id)
		refresh())
	row.add_child(assign_button)
	release_button = _button("Release")
	release_button.pressed.connect(func() -> void: release_requested.emit(momo_id))
	row.add_child(release_button)
	add_child(row)
	visible = false


func _button(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(110, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	return b


func show_momo(id: int) -> void:
	momo_id = id
	assigning = false
	visible = true
	refresh()


func hide_panel() -> void:
	visible = false
	assigning = false
	momo_id = 0


func _process(_delta: float) -> void:
	if visible:
		refresh()


func refresh() -> void:
	var m := momos.get_momo(momo_id)
	if m.is_empty():
		hide_panel()
		return
	name_label.text = tr(m["name"])
	var b := int(m["assigned"])
	if b != 0:
		var buildings: BuildingSystem = sim.system(&"buildings")
		status_label.text = tr("momo.working_at") % tr(buildings.type_def(buildings.get_building(b)).get("name", ""))
	else:
		status_label.text = tr("momo.roaming")
	assign_button.text = tr("momo.assign")
	assign_button.modulate = Color(1.3, 1.25, 0.8) if assigning else Color.WHITE
	release_button.text = tr("momo.unassign")
	release_button.visible = b != 0
