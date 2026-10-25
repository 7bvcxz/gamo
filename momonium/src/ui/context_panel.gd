class_name ContextPanel
extends Control

## The small panel along the bottom for whatever is selected.
##
## A building shows one card per stage of its work cycle -- icon, name and how
## long it takes -- with the stage that comes next lit up. While that stage
## runs its card fills; during a cooldown it counts down. Tapping the lit card
## does the same as tapping the building. A tile shows just its name. Nothing
## shows when nothing is selected: the island stays the picture.

signal start_pressed(id: int)
signal cancel_pressed(id: int)

const CARD_SIZE := Vector2(150, 118)
const GAP := 10.0

var sim: Simulation
var buildings: BuildingSystem
var lib: SpriteLibrary
var building_id := 0
var cards: Array[Button] = []
var title: Label
var _shown_state := ""
var _tile_pill: PanelContainer
var _tile_label: Label
## Bottom margin, and the width taken by the bottom-left buttons: cards sit on
## the same line as those buttons, to their right, so they cover none of the
## island above.
var _bottom_reserved := 16.0
var _left_reserved := 168.0


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	buildings = sim.system(&"buildings")
	lib = p_lib
	name = "ContextPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile_pill = PanelContainer.new()
	_tile_label = Label.new()
	_tile_label.add_theme_font_size_override("font_size", 20)
	_tile_pill.add_child(_tile_label)
	_tile_pill.visible = false
	add_child(_tile_pill)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.visible = false
	add_child(title)
	resized.connect(_layout)


func show_building(id: int) -> void:
	_clear_cards()
	_tile_pill.visible = false
	building_id = id
	var b := buildings.get_building(id)
	title.text = _title(b)
	title.visible = true
	_shown_state = String(b["state"])
	if b["state"] == BuildingSystem.CONSTRUCTING:
		var build_card := _make_card({"id": "construct", "label": "build.constructing", "icon": "ui_build", "seconds": float(buildings.type_def(b).get("build_seconds", 0))}, 0)
		build_card.disabled = true
		cards.append(build_card)
		var cancel := _make_card({"id": "cancel", "label": "build.cancel", "icon": "ui_build", "seconds": 0}, 1)
		cancel.pressed.connect(func() -> void: cancel_pressed.emit(building_id))
		cancel.set_meta("cancel", true)
		cards.append(cancel)
	else:
		var groups := buildings.action_groups(b)
		for i in groups.size():
			var card := _make_card(groups[i], i)
			card.set_meta("first", int(groups[i]["first"]))
			card.set_meta("count", int(groups[i]["count"]))
			cards.append(card)
	_layout()
	_refresh()


## Name, and the worker spots when the building has any: "Farm · 1/1".
func _title(b: Dictionary) -> String:
	var text := tr(buildings.type_def(b).get("name", ""))
	var momos: MomoSystem = sim.system(&"momo")
	var slots := momos.slots_of(int(b["id"]))
	if slots > 0:
		text += "  ·  %d/%d" % [momos.workers_at(int(b["id"])).size(), slots]
	return text


func show_tile(text_key: String) -> void:
	_clear_cards()
	building_id = 0
	title.visible = false
	_tile_label.text = tr(text_key)
	_tile_pill.visible = true
	_layout()


func hide_panel() -> void:
	_clear_cards()
	building_id = 0
	title.visible = false
	_tile_pill.visible = false


func is_open() -> bool:
	return building_id != 0 or _tile_pill.visible


func _clear_cards() -> void:
	for c: Button in cards:
		c.queue_free()
	cards.clear()


func _make_card(stage: Dictionary, index: int) -> Button:
	var card := Button.new()
	card.name = "Card_%s" % stage.get("id", index)
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var icon := TextureRect.new()
	var icon_name: String = stage.get("icon", "ui_sprout")
	icon.texture = lib.atlas_texture(icon_name if lib.has(icon_name) else "ui_sprout")
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	box.add_child(icon)
	var name_label := Label.new()
	name_label.text = tr(stage.get("label", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var time_label := Label.new()
	time_label.name = "Time"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.modulate = Color(1, 1, 1, 0.85)
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.set_meta("seconds", float(stage.get("seconds", 0)))
	box.add_child(time_label)
	card.set_meta("index", index)
	card.pressed.connect(func() -> void:
		if building_id != 0 and not card.has_meta("cancel"):
			start_pressed.emit(building_id))
	card.draw.connect(_draw_card_progress.bind(card))
	add_child(card)
	return card


func _process(_delta: float) -> void:
	if building_id != 0:
		_refresh()


func _refresh() -> void:
	var b := buildings.get_building(building_id)
	if b.is_empty():
		hide_panel()
		return
	if String(b["state"]) != _shown_state and (_shown_state == BuildingSystem.CONSTRUCTING or b["state"] == BuildingSystem.CONSTRUCTING):
		show_building(building_id)
		return
	_shown_state = String(b["state"])
	title.text = _title(b)
	if b["state"] == BuildingSystem.CONSTRUCTING:
		var left := ceili(buildings.remaining_ms(b) / 1000.0)
		var t: Label = cards[0].find_child("Time", true, false)
		t.text = tr("panel.seconds") % left
		var c: Label = cards[1].find_child("Time", true, false)
		c.text = "+$%d" % int((b.get("paid", {}) as Dictionary).get("money", 0))
		cards[0].queue_redraw()
		return
	var stage := int(b["stage"])
	for card: Button in cards:
		var first: int = card.get_meta("first")
		var count: int = card.get_meta("count")
		var is_current := stage >= first and stage < first + count
		var time_label: Label = card.find_child("Time", true, false)
		var secs: float = time_label.get_meta("seconds")
		card.disabled = not is_current or not buildings.is_ready(b)
		card.self_modulate = Color(1.25, 1.2, 0.9) if is_current else Color(1, 1, 1, 0.75)
		card.modulate = Color.WHITE if is_current else Color(1, 1, 1, 0.6)
		if is_current and b["state"] == BuildingSystem.COOLDOWN:
			time_label.text = tr("err.cooldown") % ceili(buildings.remaining_ms(b) / 1000.0)
		else:
			time_label.text = tr("panel.seconds") % int(secs)
		card.queue_redraw()


## Which group the building is in, for a card: -1 done, 0 current, 1 to come.
func _card_phase(card: Button, b: Dictionary) -> int:
	if not card.has_meta("first"):
		return 0
	var stage := int(b["stage"])
	var first: int = card.get_meta("first")
	var count: int = card.get_meta("count")
	if stage >= first + count:
		return -1
	return 0 if stage >= first else 1


func _draw_card_progress(card: Button) -> void:
	var b := buildings.get_building(building_id)
	if b.is_empty():
		return
	# Repeated stages (water x3) show one dot each, filled as they are done.
	if card.has_meta("count") and int(card.get_meta("count")) > 1:
		var count: int = card.get_meta("count")
		var first: int = card.get_meta("first")
		var done := clampi(int(b["stage"]) - first, 0, count)
		for i in count:
			var c := Vector2(card.size.x * 0.5 + (i - (count - 1) * 0.5) * 14.0, 12.0)
			card.draw_circle(c, 4.5, Color("#6fc3ff") if i < done else Color(1, 1, 1, 0.3))
	if _card_phase(card, b) != 0:
		return
	if b["state"] == BuildingSystem.WORKING or (b["state"] == BuildingSystem.CONSTRUCTING and not card.has_meta("cancel")):
		var p := buildings.progress(b)
		var bar := Rect2(10, card.size.y - 12, (card.size.x - 20) * p, 6)
		card.draw_rect(Rect2(10, card.size.y - 12, card.size.x - 20, 6), Color(1, 1, 1, 0.2))
		card.draw_rect(bar, Color("#9be15d"))


func set_reserved(left: float, bottom: float) -> void:
	_left_reserved = left
	_bottom_reserved = bottom
	_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var total := cards.size() * CARD_SIZE.x + maxf(cards.size() - 1, 0) * GAP
	var area_left := _left_reserved
	var area_right := w - 16.0
	var x := area_left + maxf((area_right - area_left - total) * 0.5, 0.0)
	var y := h - _bottom_reserved - CARD_SIZE.y
	for card: Button in cards:
		card.position = Vector2(x, y)
		x += CARD_SIZE.x + GAP
	title.reset_size()
	title.position = Vector2((w - title.size.x) * 0.5, y - title.size.y - 6)
	_tile_pill.reset_size()
	_tile_pill.position = Vector2(area_left + maxf((area_right - area_left - _tile_pill.size.x) * 0.5, 0.0), h - _bottom_reserved - _tile_pill.size.y)


func card_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c: Button in cards:
		out.append(c.get_global_rect())
	return out
