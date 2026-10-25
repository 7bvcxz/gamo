class_name RpView
extends VBoxContainer

## Placing research points: every node ever researched is listed with its
## level now; - and + move points in a draft (levels researched this run are
## the floor and are not points); the header counts what is left of what was
## earned; Confirm applies the draft in one go (the simulation checks it
## again), Cancel throws it away. A draft that breaks a rule -- too few points,
## a node above its top, one whose prerequisite has no level -- cannot be
## confirmed and says why.

signal done

var sim: Simulation
var research: ResearchSystem
var head: Label
var why: Label
var list: VBoxContainer
var confirm_button: Button
var cancel_button: Button
## id -> allocated levels in the draft
var draft: Dictionary = {}
var rows: Dictionary = {}
var last_result: Dictionary = {}
var _ids_shown := ""


func setup(p_sim: Simulation, _lib: SpriteLibrary) -> void:
	sim = p_sim
	research = sim.system(&"research")
	name = "RpView"
	add_theme_constant_override("separation", 6)
	head = PanelViews.label("", 20)
	head.name = "Head"
	add_child(head)
	why = PanelViews.label("", 15)
	why.name = "Why"
	why.add_theme_color_override("font_color", Color("#ffb3a8"))
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(why)
	list = VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 4)
	add_child(list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	confirm_button = Button.new()
	confirm_button.name = "Confirm"
	confirm_button.custom_minimum_size = Vector2(0, 56)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.pressed.connect(func() -> void:
		last_result = sim.execute({"type": "research.allocate", "levels": draft.duplicate()})
		if last_result["ok"]:
			done.emit()
		refresh())
	row.add_child(confirm_button)
	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	cancel_button.custom_minimum_size = Vector2(110, 56)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(func() -> void:
		reset_draft()
		done.emit())
	row.add_child(cancel_button)
	add_child(row)


## The draft starts as what is placed now.
func reset_draft() -> void:
	draft = research.allocated.duplicate()
	last_result = {}
	refresh()


func _unlocked_ids() -> Array[String]:
	var out: Array[String] = []
	for n: Dictionary in research.nodes():
		if research.is_unlocked_node(String(n["id"])):
			out.append(String(n["id"]))
	return out


func _build_rows() -> void:
	PanelViews.clear(list)
	rows.clear()
	for id: String in _unlocked_ids():
		var r := HBoxContainer.new()
		r.name = "Row_" + id
		r.add_theme_constant_override("separation", 8)
		var label := PanelViews.label("", 16)
		label.name = "Name"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(label)
		var minus := _step_button("Minus", "-")
		minus.pressed.connect(func() -> void: _step(id, -1))
		r.add_child(minus)
		var lv := PanelViews.label("", 20)
		lv.name = "Level"
		lv.custom_minimum_size = Vector2(64, 0)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(lv)
		var plus := _step_button("Plus", "+")
		plus.pressed.connect(func() -> void: _step(id, 1))
		r.add_child(plus)
		list.add_child(r)
		rows[id] = r


func _step_button(node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	return b


func _step(id: String, by: int) -> void:
	var n := int(draft.get(id, 0)) + by
	if n <= 0:
		draft.erase(id)
	else:
		draft[id] = n
	last_result = {}
	refresh()


func _spent() -> int:
	var n := 0
	for id: String in draft:
		n += int(draft[id])
	return n


func refresh() -> void:
	var ids := ",".join(_unlocked_ids())
	if ids != _ids_shown:
		_ids_shown = ids
		_build_rows()
	var left := research.rp_earned - _spent()
	head.text = tr("rp.head").format({"left": left, "total": research.rp_earned})
	if research.rp_pending() > 0:
		head.text += "  " + tr("rp.pending") % research.rp_pending()
	var check := research.check_allocation(draft)
	why.text = "" if check["ok"] else _reason(check)
	why.visible = why.text != ""
	for id: String in rows:
		var r: HBoxContainer = rows[id]
		var base := int(research.bought.get(id, 0))
		var lv := base + int(draft.get(id, 0))
		(r.get_node("Name") as Label).text = tr(String(research.node(id).get("name", id)))
		(r.get_node("Level") as Label).text = "Lv %d/%d" % [lv, research.max_level(id)]
		(r.get_node("Minus") as Button).disabled = int(draft.get(id, 0)) <= 0
		(r.get_node("Plus") as Button).disabled = left <= 0 or lv >= research.max_level(id)
	confirm_button.text = tr("rp.confirm")
	confirm_button.disabled = not check["ok"]
	cancel_button.text = tr("sale.cancel")
	if list.get_child_count() == 0:
		why.text = tr("rp.none")
		why.visible = true


func _reason(check: Dictionary) -> String:
	var name_of := func(id: Variant) -> String: return tr(String(research.node(String(id)).get("name", id)))
	match String(check["reason"]):
		"err.research_needs":
			return tr("rp.needs").format({"a": name_of.call(check["id"]), "b": name_of.call(check["requires"])})
		"err.research_needed_by":
			return tr("rp.needed_by").format({"a": name_of.call(check["id"]), "b": name_of.call(check["by"])})
	return tr(String(check["reason"]))
