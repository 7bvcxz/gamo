class_name BuildMenu
extends PanelContainer

## The shop's building list: one card per building on offer -- icon, name,
## price, build time -- with locked ones dimmed and their level shown. Picking
## a card starts placement. Opened from the Shop button.

signal picked(type: String)

var sim: Simulation
var buildings: BuildingSystem
var lib: SpriteLibrary
var list: HBoxContainer
var cards: Dictionary = {}


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	buildings = sim.system(&"buildings")
	lib = p_lib
	name = "BuildMenu"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.name = "Close"
	close.text = "✕"
	close.custom_minimum_size = Vector2(52, 52)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	col.add_child(head)
	list = HBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	col.add_child(list)
	add_child(col)
	visible = false
	sim.bus.emitted.connect(func(type: StringName, _p: Dictionary) -> void:
		if visible and type in [&"money_changed", &"inventory_changed", &"level_up"]:
			rebuild())


func open() -> void:
	rebuild()
	visible = true


func toggle() -> void:
	if visible:
		visible = false
	else:
		open()


func rebuild() -> void:
	(find_child("Title", true, false) as Label).text = tr("hud.shop")
	for c: Node in list.get_children():
		c.queue_free()
	cards.clear()
	var economy: EconomySystem = sim.system(&"economy")
	for entry: Dictionary in buildings.catalog():
		var type: String = entry["type"]
		var def := sim.data.building_type(type)
		var card := Button.new()
		card.name = "Card_" + type
		card.custom_minimum_size = Vector2(150, 150)
		card.focus_mode = Control.FOCUS_NONE
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var icon := TextureRect.new()
		var sprite_name: String = def.get("sprite", "")
		icon.texture = lib.atlas_texture(sprite_name if lib.has(sprite_name) else "ui_build")
		icon.custom_minimum_size = Vector2(64, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		box.add_child(_label(tr(def.get("name", type)), 19))
		var money := int((entry["cost"] as Dictionary).get("money", 0))
		var price := _label("$%d · %s" % [money, tr("panel.seconds") % int(entry["build_seconds"])], 15)
		box.add_child(price)
		if not entry["unlocked"]:
			box.add_child(_label(tr("err.locked") % int(entry["level"]), 15))
			card.disabled = true
			card.modulate = Color(1, 1, 1, 0.55)
		elif not economy.can_afford(money):
			price.modulate = Color("#ff9a8f")
		card.pressed.connect(func() -> void:
			visible = false
			picked.emit(type))
		list.add_child(card)
		cards[type] = card


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
