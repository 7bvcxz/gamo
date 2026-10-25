class_name BuildStrip
extends Control

## Tap an empty tile of your island and four choices appear right beside it:
## farm, mine, lumberyard, lab -- each with its price, or the level / research
## it waits for. One tap builds it there. Kept on screen near the edges; tap
## anywhere else and it goes.

signal built(id: int)

const FAMILIES: PackedStringArray = ["farm", "mine", "lumberyard", "research"]
const BUTTON := Vector2(112, 112)

var sim: Simulation
var lib: SpriteLibrary
var cameras: CameraController
var projection: IsoProjection
var cell := Vector2i.ZERO
var open := false
var buttons: Dictionary = {}
var row: HBoxContainer
var last_result: Dictionary = {}


func setup(p_sim: Simulation, p_lib: SpriteLibrary, p_cameras: CameraController, p_projection: IsoProjection) -> void:
	sim = p_sim
	lib = p_lib
	cameras = p_cameras
	projection = p_projection
	name = "BuildStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	row = HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 6)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_child(row)
	add_child(panel)
	for type: String in FAMILIES:
		var b := Button.new()
		b.name = "Build_" + type
		b.custom_minimum_size = BUTTON
		b.focus_mode = Control.FOCUS_NONE
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sprite := String(sim.data.building_type(type).get("sprite", ""))
		var icon := PanelViews.icon(lib, sprite if lib.has(sprite) else "ui_build", 48.0)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(icon)
		var n := PanelViews.label("", 15)
		n.name = "Name"
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var price := PanelViews.label("", 14)
		price.name = "Price"
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(price)
		b.add_child(col)
		var t := type
		b.pressed.connect(func() -> void: build(t))
		row.add_child(b)
		buttons[type] = b
	visible = false


func show_for(p_cell: Vector2i) -> void:
	cell = p_cell
	open = true
	visible = true
	refresh()
	place()


func close() -> void:
	open = false
	visible = false


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
	var inv: InventorySystem = sim.system(&"inventory")
	var economy: EconomySystem = sim.system(&"economy")
	for type: String in FAMILIES:
		var b: Button = buttons[type]
		var def := sim.data.building_type(type)
		(b.find_child("Name", true, false) as Label).text = tr(String(def.get("name", type)))
		var price: Label = b.find_child("Price", true, false)
		var cost: Dictionary = def.get("cost", {})
		var text := "$%d" % int(cost.get("money", 0))
		for item: String in cost.get("items", {}):
			text += " · %s %d" % [tr(String(sim.data.item(item).get("name", item))), int(cost["items"][item])]
		var check := bs.can_place(type, cell)
		var locked := String(check.get("reason", "")) in ["err.locked", "err.needs_research"]
		if String(check.get("reason", "")) == "err.locked":
			text = tr("build.unlock_at") % int(def.get("unlock", {}).get("level", 1))
		price.text = text
		price.add_theme_color_override("font_color", Color("#ffe27a") if locked else (Color.WHITE if check["ok"] else Color("#ff9a8f")))
		b.disabled = not check["ok"]
		b.modulate = Color(1, 1, 1, 0.7) if locked else Color.WHITE
	(get_node("Panel") as PanelContainer).reset_size()


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
