class_name BuildStrip
extends Control

## Tap an empty tile of your island and five choices appear right beside it:
## farm, mine, lumberyard, lab -- each with its price, or the level / research
## it waits for -- and Special. One tap builds it there. Special turns the strip
## into the landmarks not yet standing (a back arrow first): each with its
## price or what it waits for (a level, a free special slot, the wait after it
## was pulled down); built ones are not offered. Kept on screen near the edges;
## tap anywhere else and it goes.

signal built(id: int)
## The strip switched between the five choices and the landmarks.
signal mode_changed(mode: String)

const FAMILIES: PackedStringArray = ["farm", "mine", "lumberyard", "research"]
const BUTTON := Vector2(108, 124)

var sim: Simulation
var lib: SpriteLibrary
var cameras: CameraController
var projection: IsoProjection
var cell := Vector2i.ZERO
var open := false
## "core" (the four families and Special) or "special" (the landmarks).
var mode := "core"
var buttons: Dictionary = {}
var special_buttons: Dictionary = {}
var special_button: Button
var back_button: Button
var row: HBoxContainer
var last_result: Dictionary = {}


func setup(p_sim: Simulation, p_lib: SpriteLibrary, p_cameras: CameraController, p_projection: IsoProjection) -> void:
	sim = p_sim
	lib = p_lib
	cameras = p_cameras
	projection = p_projection
	# Prices follow the purse while the choices are open (Step 50: a player
	# watched the lumberyard stay red at $97 and $115 until they reopened it).
	sim.bus.emitted.connect(func(type: StringName, _payload: Dictionary) -> void:
		if open and type in [&"money_changed", &"inventory_changed", &"level_up", &"research_completed"]:
			refresh())
	name = "BuildStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	row = HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 6)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_child(row)
	add_child(panel)
	visible = false


func show_for(p_cell: Vector2i) -> void:
	cell = p_cell
	open = true
	visible = true
	_set_mode("core")
	place()


func close() -> void:
	open = false
	visible = false


func show_specials() -> void:
	_set_mode("special")
	place()


func show_core() -> void:
	_set_mode("core")
	place()


func _set_mode(m: String) -> void:
	mode = m
	for c: Node in row.get_children():
		row.remove_child(c)
		c.queue_free()
	buttons.clear()
	special_buttons.clear()
	special_button = null
	back_button = null
	if mode == "core":
		for type: String in FAMILIES:
			var b := _choice("Build_" + type, String(sim.data.building_type(type).get("sprite", "")))
			var t := type
			b.pressed.connect(func() -> void: build(t))
			row.add_child(b)
			buttons[type] = b
		special_button = _choice("Build_special", "icon_star")
		special_button.pressed.connect(func() -> void:
			if open:
				show_specials())
		row.add_child(special_button)
	else:
		back_button = Button.new()
		back_button.name = "Back"
		back_button.custom_minimum_size = Vector2(64, BUTTON.y)
		back_button.focus_mode = Control.FOCUS_NONE
		back_button.draw.connect(_draw_back)
		back_button.pressed.connect(func() -> void:
			if open:
				show_core())
		row.add_child(back_button)
		for e: Dictionary in (sim.system(&"buildings") as BuildingSystem).special_catalog():
			var type := String(e["type"])
			var b := _choice("Special_" + type, String(sim.data.building_type(type).get("sprite", "")))
			b.pressed.connect(func() -> void: build(type))
			row.add_child(b)
			special_buttons[type] = b
		if special_buttons.is_empty():
			var none := PanelViews.label(tr("build.special_none"), 15, true)
			none.name = "None"
			row.add_child(none)
	refresh()
	mode_changed.emit(mode)


func _choice(node_name: String, sprite: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = BUTTON
	b.focus_mode = Control.FOCUS_NONE
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PanelViews.icon(lib, sprite if lib.has(sprite) else "ui_build", 62.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var n := PanelViews.label("", 16)
	n.name = "Name"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	var price := PanelViews.label("", 14)
	price.name = "Price"
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(price)
	b.add_child(col)
	return b


func build(type: String) -> void:
	# One tap, one building: a second press arriving while it closes (touch
	# and its emulated mouse) finds it shut.
	if not open:
		return
	last_result = sim.execute({"type": "building.place", "building": type, "anchor": [cell.x, cell.y]})
	if last_result["ok"]:
		var id := int(last_result["id"])
		close()
		built.emit(id)
	else:
		refresh()


## Price, or what it waits for, on each choice; dimmed when it cannot be built now.
func refresh() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	for type: String in buttons:
		_label_choice(buttons[type], type, bs.can_place(type, cell))
	if special_button != null:
		(special_button.find_child("Name", true, false) as Label).text = tr("build.special")
		(special_button.find_child("Price", true, false) as Label).text = "%d/%d" % [bs.specials_count(), bs.special_slots()]
	for type: String in special_buttons:
		var check := bs.can_place(type, cell)
		_label_choice(special_buttons[type], type, check)
		var price: Label = special_buttons[type].find_child("Price", true, false)
		match String(check.get("reason", "")):
			"err.special_slots":
				price.text = tr("build.special_slots") % [bs.specials_count(), bs.special_slots()]
			"err.special_cooldown":
				price.text = tr("build.special_cooldown") % BuildingDetailView.duration(ceilf(int(check["remaining_ms"]) / 1000.0))
	(get_node("Panel") as PanelContainer).reset_size()


func _label_choice(b: Button, type: String, check: Dictionary) -> void:
	var def := sim.data.building_type(type)
	(b.find_child("Name", true, false) as Label).text = tr(String(def.get("name", type)))
	var price: Label = b.find_child("Price", true, false)
	var cost: Dictionary = def.get("cost", {})
	var text := "$%d" % int(cost.get("money", 0))
	for item: String in cost.get("items", {}):
		text += " · %s %d" % [tr(String(sim.data.item(item).get("name", item))), int(cost["items"][item])]
	var reason := String(check.get("reason", ""))
	var locked := reason in ["err.locked", "err.needs_research", "err.special_slots", "err.special_cooldown"]
	if reason == "err.locked":
		text = tr("build.unlock_at") % int(def.get("unlock", {}).get("level", 1))
	price.text = text
	b.tooltip_text = "%s · %s" % [tr(String(def.get("name", type))), text]
	price.add_theme_color_override("font_color", Color("#ffe27a") if locked else (Color.WHITE if check["ok"] else Color("#ff9a8f")))
	b.disabled = not check["ok"]
	b.modulate = Color(1, 1, 1, 0.7) if locked else Color.WHITE


func _draw_back() -> void:
	var c := back_button.size * 0.5
	var col := Color(1, 1, 1, 0.95)
	back_button.draw_polyline(PackedVector2Array([c + Vector2(6, -14), c + Vector2(-8, 0), c + Vector2(6, 14)]), col, 4.0, true)


## Below the tile, or above it near the bottom; kept inside the screen.
func place() -> void:
	var panel: PanelContainer = get_node("Panel")
	panel.reset_size()
	var s := panel.size
	var screen := get_viewport_rect().size
	var c := cameras.world_to_screen(projection.cell_center(cell))
	var half := projection.tile_width * cameras.camera.zoom.x * 0.32
	var x := clampf(c.x - s.x * 0.5, 8.0, maxf(screen.x - s.x - 8.0, 8.0))
	var y := c.y + half + 8.0
	if y + s.y > screen.y - 96.0:
		y = c.y - half - s.y - 8.0
	panel.position = Vector2(x, clampf(y, 80.0, maxf(screen.y - s.y - 8.0, 80.0)))


func _process(_delta: float) -> void:
	if open:
		place()


func strip_rect() -> Rect2:
	return (get_node("Panel") as Control).get_global_rect()
