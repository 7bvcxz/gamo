class_name RpView
extends VBoxContainer

## Placing research points: every node ever researched is listed with its
## level now; - and + move points in a draft (levels researched this run are
## the floor and are not points); the header counts what is left of what was
## earned; Confirm applies the draft in one go (the simulation checks it
## again), Cancel throws it away. A draft that breaks a rule -- too few points,
## a node above its top, one whose prerequisite has no level -- cannot be
## confirmed and says why. Under each node, what it does now and what the draft
## would make it do. Three saved plans: tap one to load it into the draft,
## Save to keep the draft there -- they survive every sale, like the points.

signal done

var sim: Simulation
var research: ResearchSystem
var head: Label
var why: Label
var list: VBoxContainer
var profile_buttons: Array[Button] = []
var save_buttons: Array[Button] = []
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
	var ph := PanelViews.label(tr("rp.profiles"), 15, true)
	ph.name = "ProfilesHead"
	ph.set_meta("key", "rp.profiles")
	add_child(ph)
	var prow := HBoxContainer.new()
	prow.name = "Profiles"
	prow.add_theme_constant_override("separation", 6)
	for i in ResearchSystem.PROFILES:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		var load_button := Button.new()
		load_button.name = "Load%d" % i
		load_button.custom_minimum_size = Vector2(0, 48)
		load_button.focus_mode = Control.FOCUS_NONE
		load_button.add_theme_font_size_override("font_size", 15)
		var slot := i
		load_button.pressed.connect(func() -> void: load_profile(slot))
		col.add_child(load_button)
		var save_button := Button.new()
		save_button.name = "Save%d" % i
		save_button.custom_minimum_size = Vector2(0, 40)
		save_button.focus_mode = Control.FOCUS_NONE
		save_button.flat = true
		save_button.add_theme_font_size_override("font_size", 14)
		save_button.pressed.connect(func() -> void:
			last_result = sim.execute({"type": "research.profile_save", "slot": slot, "levels": draft.duplicate()})
			refresh())
		col.add_child(save_button)
		prow.add_child(col)
		profile_buttons.append(load_button)
		save_buttons.append(save_button)
	add_child(prow)
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


## A saved plan into the draft: only nodes unlocked now, each at most what it
## can still take on top of what was researched this run.
func load_profile(slot: int) -> void:
	var p: Dictionary = research.profiles[slot]
	draft = {}
	for id: String in p:
		if research.is_unlocked_node(id):
			var room := research.max_level(id) - int(research.bought.get(id, 0))
			if mini(int(p[id]), room) > 0:
				draft[id] = mini(int(p[id]), room)
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
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 0)
		var label := PanelViews.label("", 16)
		label.name = "Name"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(label)
		var preview := PanelViews.label("", 13)
		preview.name = "Preview"
		preview.add_theme_color_override("font_color", Color("#b7f08a"))
		preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(preview)
		r.add_child(words)
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
		(r.find_child("Name", true, false) as Label).text = tr(String(research.node(id).get("name", id)))
		(r.get_node("Level") as Label).text = "Lv %d/%d" % [lv, research.max_level(id)]
		(r.find_child("Preview", true, false) as Label).text = preview_text(id, research.level(id), lv)
		(r.get_node("Minus") as Button).disabled = int(draft.get(id, 0)) <= 0
		(r.get_node("Plus") as Button).disabled = left <= 0 or lv >= research.max_level(id)
	for i in ResearchSystem.PROFILES:
		var p: Dictionary = research.profiles[i]
		var n := 0
		for k: String in p:
			n += int(p[k])
		var slot := String.chr(65 + i)
		profile_buttons[i].text = tr("rp.profile").format({"slot": slot, "n": n}) if not p.is_empty() else tr("rp.profile_empty").format({"slot": slot})
		profile_buttons[i].disabled = p.is_empty()
		save_buttons[i].text = tr("rp.save")
	for child: Node in get_children():
		if child.has_meta("key"):
			(child as Label).text = tr(String(child.get_meta("key")))
	confirm_button.text = tr("rp.confirm")
	confirm_button.disabled = not check["ok"]
	cancel_button.text = tr("sale.cancel")
	if list.get_child_count() == 0:
		why.text = tr("rp.none")
		why.visible = true


## "now -> with the draft", in the effect's own numbers.
func preview_text(id: String, now: int, then: int) -> String:
	if now == 0 and then == 0:
		return tr("rp.at_one") % ResearchText.at_level(sim, id, 1)
	var a := ResearchText.at_level(sim, id, now) if now > 0 else tr("rp.off")
	if now == then:
		return a
	var b := ResearchText.at_level(sim, id, then) if then > 0 else tr("rp.off")
	return "%s → %s" % [a, b]


func _reason(check: Dictionary) -> String:
	var name_of := func(id: Variant) -> String: return tr(String(research.node(String(id)).get("name", id)))
	match String(check["reason"]):
		"err.research_needs":
			return tr("rp.needs").format({"a": name_of.call(check["id"]), "b": name_of.call(check["requires"])})
		"err.research_needed_by":
			return tr("rp.needed_by").format({"a": name_of.call(check["id"]), "b": name_of.call(check["by"])})
	return tr(String(check["reason"]))
