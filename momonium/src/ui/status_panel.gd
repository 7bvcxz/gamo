class_name StatusPanel
extends VBoxContainer

## Status (the reference's ステータス card): the level in a ring with the island
## name and its line, the exact EXP and a bar to the next level, then one small
## card per building mastery -- icon, name, level, bar, exact EXP. Every number
## is read from the simulation when shown and while open; nothing is stored here.
## It is the first tab of the status frame (PanelFrame), which owns closing.

const ICONS := {"farm": "ui_sprout", "mine": "ui_mine", "lumberyard": "ui_lumber", "research": "ui_flask"}
const FILLS := {"farm": "#9be15d", "mine": "#c8a27a", "lumberyard": "#d39b62", "research": "#5fb4ff"}

var sim: Simulation
var lib: SpriteLibrary
var ring: Donut
var level_label: Label
var exp_label: Label
var exp_bar: Bar
var cards: Dictionary = {}


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	lib = p_lib
	name = "StatusPanel"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	var ring_box := Control.new()
	ring_box.custom_minimum_size = Vector2(108, 108)
	ring = Donut.new()
	ring.thickness = 9.0
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring_box.add_child(ring)
	var lv := VBoxContainer.new()
	lv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", -8)
	var lv_small := _label("Lv.", 18)
	lv_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label = _label("1", 44)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(lv_small)
	lv.add_child(level_label)
	ring_box.add_child(lv)
	top.add_child(ring_box)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := _label(tr("status.title"), 30)
	title.name = "Title"
	text.add_child(title)
	var tagline := _label(tr("status.tagline"), 17)
	tagline.name = "Tagline"
	tagline.modulate = Color(1, 1, 1, 0.8)
	text.add_child(tagline)
	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 12)
	exp_bar = Bar.new(Color("#ffe27a"))
	exp_bar.custom_minimum_size = Vector2(220, 14)
	exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exp_row.add_child(exp_bar)
	exp_label = _label("", 18)
	exp_row.add_child(exp_label)
	text.add_child(exp_row)
	top.add_child(text)
	col.add_child(top)

	# One card per building mastery, three to a row as industries are added.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for type: String in (sim.system(&"progression") as ProgressionSystem).mastery_types():
		var card := PanelContainer.new()
		card.name = "Mastery_" + type
		card.custom_minimum_size = Vector2(160, 0)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var head := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = lib.atlas_texture(ICONS.get(type, "ui_sprout"))
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(icon)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -4)
		var n := _label(tr("mastery." + type), 17)
		var l := _label("", 15)
		l.name = "Level"
		names.add_child(n)
		names.add_child(l)
		head.add_child(names)
		box.add_child(head)
		var bar := Bar.new(Color(FILLS.get(type, "#9be15d")))
		bar.name = "Bar"
		box.add_child(bar)
		var e := _label("", 14)
		e.name = "Exp"
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(e)
		card.add_child(box)
		grid.add_child(card)
		cards[type] = card


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func refresh() -> void:
	var prog: ProgressionSystem = sim.system(&"progression")
	level_label.text = str(prog.level)
	var need := prog.next_level_exp()
	exp_label.text = tr("status.exp") % [prog.experience, need]
	exp_bar.value = float(prog.experience) / maxf(need, 1)
	ring.progress = exp_bar.value
	for type: String in cards:
		var m := prog.mastery_of(type)
		var card: PanelContainer = cards[type]
		(card.find_child("Level", true, false) as Label).text = tr("hud.level") % int(m["level"])
		(card.find_child("Bar", true, false) as Bar).value = float(m["exp"]) / maxf(float(m["next"]), 1.0)
		(card.find_child("Exp", true, false) as Label).text = tr("status.exp") % [int(m["exp"]), int(m["next"])]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and sim != null:
		(find_child("Title", true, false) as Label).text = tr("status.title")
		(find_child("Tagline", true, false) as Label).text = tr("status.tagline")
		if visible:
			refresh()
