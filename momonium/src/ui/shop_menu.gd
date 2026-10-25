class_name ShopMenu
extends PanelContainer

## The shop (bottom-left): hire another Momo. Buildings are not bought here --
## tap an empty tile and the four choices appear beside it (BuildStrip).

signal hire_requested

var sim: Simulation
var lib: SpriteLibrary
var list: HBoxContainer
var cards: Dictionary = {}


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	lib = p_lib
	name = "ShopMenu"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := PanelViews.close_button(52.0)
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	col.add_child(head)
	list = HBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 10)
	col.add_child(list)
	add_child(col)
	visible = false
	sim.bus.emitted.connect(func(type: StringName, _p: Dictionary) -> void:
		if visible and type in [&"money_changed", &"momo_hired"]:
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
	PanelViews.clear(list)
	cards.clear()
	_add_hire_card(sim.system(&"economy"))
	reset_size()


## A new Momo appears somewhere on the island and starts to wander.
func _add_hire_card(economy: EconomySystem) -> void:
	var momos: MomoSystem = sim.system(&"momo")
	var cost := momos.hire_cost()
	var card := Button.new()
	card.name = "Card_momo"
	card.custom_minimum_size = Vector2(150, 168)
	card.focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var icon := PanelViews.icon(lib, "momo_front", 56.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var name_label := PanelViews.label(tr("momo.hire"), 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var price := PanelViews.label("$%d" % cost, 15)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not economy.can_afford(cost):
		price.modulate = Color("#ff9a8f")
		card.disabled = true
	box.add_child(price)
	card.pressed.connect(func() -> void:
		visible = false
		hire_requested.emit())
	list.add_child(card)
	cards["momo"] = card
