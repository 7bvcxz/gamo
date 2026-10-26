class_name ResearchView
extends HBoxContainer

## One industry's branch of the technology tree, as in the reference: node
## cards joined by dashed lines on the left (lock, check or progress on each,
## research notes needed under the name), the chosen node's details on the
## right -- the technique, what it changes, what it still needs, its cost and
## time, and the button. Every value comes from the ResearchSystem; effects
## are described from the same data the simulation applies.

const CARD := Vector2(118, 104)
const ROW := 134.0
const GAP := 8.0

## "Build a research lab" pressed: the island should offer the lab on a free
## tile (Step 50: four blind players tapped that line and nothing happened).
signal lab_wanted

var sim: Simulation
var lib: SpriteLibrary
var research: ResearchSystem
var industry := ""
var tree: Control
var cards: Dictionary = {}
var selected := ""
var detail: VBoxContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_desc: Label
var effects_box: VBoxContainer
var needs_box: VBoxContainer
var cost_label: Label
var time_label: Label
var start_button: Button
var last_result: Dictionary = {}
## Most nodes on one row: cards narrow to fit it.
var _widest := 1
## Step 57: topics that were news when the panel opened -- a red dot on their
## card until it closes (Main.open_research).
var fresh: Dictionary = {}


func setup(p_sim: Simulation, p_lib: SpriteLibrary, p_industry: String) -> void:
	sim = p_sim
	lib = p_lib
	industry = p_industry
	research = sim.system(&"research")
	name = "Research_" + industry
	add_theme_constant_override("separation", 12)
	tree = Control.new()
	tree.name = "Tree"
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.draw.connect(_draw_links)
	tree.resized.connect(_place_cards)
	add_child(tree)
	for n: Dictionary in research.nodes(industry):
		var id := String(n["id"])
		cards[id] = _card(n)
		tree.add_child(cards[id])
	var depth := 0
	for id: String in cards:
		depth = maxi(depth, _depth(id))
	tree.custom_minimum_size = Vector2(2 * CARD.x + 24, (depth + 1) * ROW)
	_widest = 1
	for d in depth + 1:
		_widest = maxi(_widest, cards.keys().filter(func(id: String) -> bool: return _depth(id) == d).size())
	_build_detail()
	for id: String in cards:
		if selected == "" or research.state_of(id) in ["active", "available"] and research.state_of(selected) == "locked":
			selected = id


## Shows `id`'s details (a letter's "See it in Research", the news).
func select(id: String) -> void:
	if cards.has(id):
		selected = id
		refresh()


func _depth(id: String) -> int:
	var d := 0
	for r: String in research.node(id).get("requires", []):
		d = maxi(d, _depth(r) + 1)
	return d


func _place_cards() -> void:
	var by_depth: Dictionary = {}
	for id: String in cards:
		var d := _depth(id)
		if not by_depth.has(d):
			by_depth[d] = []
		(by_depth[d] as Array).append(id)
	var w := minf(CARD.x, tree.size.x / _widest - GAP)
	for d: int in by_depth:
		var row: Array = by_depth[d]
		for i in row.size():
			var card: Button = cards[row[i]]
			card.custom_minimum_size = Vector2(w, CARD.y)
			card.size = Vector2(w, CARD.y)
			(card.find_child("Name", true, false) as Label).custom_minimum_size.x = w - 10.0
			card.position = Vector2(tree.size.x * (i + 0.5) / row.size() - w * 0.5, d * ROW + 6.0)
	tree.queue_redraw()


func _card(n: Dictionary) -> Button:
	var id := String(n["id"])
	var b := Button.new()
	b.name = "Node_" + id
	b.custom_minimum_size = CARD
	b.size = CARD
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		selected = id
		refresh())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PanelViews.icon(lib, String(n.get("icon", "ui_research")), 42.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var label := PanelViews.label("", 14)
	label.name = "Name"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(CARD.x - 12, 0)
	col.add_child(label)
	var chip := HBoxContainer.new()
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(PanelViews.icon(lib, "ui_flask", 18.0))
	var notes := PanelViews.label("", 14)
	notes.name = "Notes"
	chip.add_child(notes)
	col.add_child(chip)
	b.add_child(col)
	b.draw.connect(_draw_card.bind(b, id))
	return b


func _draw_card(b: Button, id: String) -> void:
	var state := research.state_of(id)
	if id == selected:
		b.draw_rect(Rect2(Vector2.ONE * 2, b.size - Vector2.ONE * 4), b.get_theme_color("font_color", "GoldLabel"), false, 3.0)
	if fresh.has(id):
		b.draw_circle(Vector2(14, 14), 7.0, Color("#ff5a4f"))
		b.draw_arc(Vector2(14, 14), 7.0, 0, TAU, 16, Color.WHITE, 1.6, true)
	var corner := Vector2(b.size.x - 16, 16)
	match state:
		"locked":
			# A padlock: shackle and body.
			b.draw_circle(corner, 13.0, Color(0.1, 0.18, 0.3, 0.85))
			b.draw_arc(corner + Vector2(0, -2), 4.5, PI, TAU, 10, Color.WHITE, 2.0, true)
			b.draw_rect(Rect2(corner + Vector2(-6, -2), Vector2(12, 9)), Color.WHITE)
		"done":
			b.draw_circle(corner, 13.0, Color("#5fbf5a"))
			b.draw_polyline(PackedVector2Array([corner + Vector2(-6, 0), corner + Vector2(-2, 5), corner + Vector2(7, -5)]), Color.WHITE, 3.0, true)
		"levelup":
			# Researched, and can go higher: its level in a green disc.
			b.draw_circle(corner, 13.0, Color("#5fbf5a"))
			var f := b.get_theme_default_font()
			var t := str(research.level(id))
			var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			b.draw_string(f, corner + Vector2(-ts.x * 0.5, 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		"active":
			var r := Rect2(10, b.size.y - 9, b.size.x - 20, 5)
			b.draw_rect(r, b.get_theme_color("track", "Ink"))
			b.draw_rect(Rect2(r.position, Vector2(r.size.x * research.progress(), r.size.y)), Color("#9be15d"))
		"available":
			b.draw_circle(corner, 6.0, b.get_theme_color("font_color", "GoldLabel"))


func _draw_links() -> void:
	for id: String in cards:
		var child: Button = cards[id]
		for r: String in research.node(id).get("requires", []):
			if not cards.has(r):
				continue
			var parent: Button = cards[r]
			var a := parent.position + Vector2(parent.size.x * 0.5, parent.size.y)
			var b := child.position + Vector2(child.size.x * 0.5, 0)
			var mid := (a.y + b.y) * 0.5
			var line := tree.get_theme_color("line", "Ink")
			var color := line if research.is_done(r) else Color(line, line.a * 0.45)
			for seg: Array in [[a, Vector2(a.x, mid)], [Vector2(a.x, mid), Vector2(b.x, mid)], [Vector2(b.x, mid), b]]:
				tree.draw_dashed_line(seg[0], seg[1], color, 2.0, 6.0)


func _build_detail() -> void:
	detail = VBoxContainer.new()
	detail.name = "Detail"
	detail.custom_minimum_size = Vector2(214, 0)
	detail.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	detail_icon = PanelViews.icon(lib, "ui_research", 44.0)
	head.add_child(detail_icon)
	detail_name = PanelViews.label("", 20)
	detail_name.name = "Name"
	detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(detail_name)
	detail.add_child(head)
	detail_desc = PanelViews.label("", 15, true)
	detail_desc.name = "Desc"
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(detail_desc)
	effects_box = VBoxContainer.new()
	effects_box.name = "Effects"
	detail.add_child(effects_box)
	needs_box = VBoxContainer.new()
	needs_box.name = "Needs"
	detail.add_child(needs_box)
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 6)
	cost_row.add_child(PanelViews.icon(lib, "ui_flask", 24.0))
	cost_label = PanelViews.label("", 18)
	cost_label.name = "Cost"
	cost_row.add_child(cost_label)
	detail.add_child(cost_row)
	time_label = PanelViews.label("", 15, true)
	time_label.name = "Time"
	detail.add_child(time_label)
	start_button = Button.new()
	start_button.name = "Start"
	start_button.custom_minimum_size = Vector2(0, 56)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.add_theme_font_size_override("font_size", 18)
	start_button.pressed.connect(func() -> void:
		if String(research.can_start(selected).get("reason", "")) == "err.no_lab":
			lab_wanted.emit()
			return
		last_result = sim.execute({"type": "research.start", "id": selected})
		refresh())
	detail.add_child(start_button)
	add_child(detail)


## Effect lines for a node, from its data.
func effect_lines(id: String) -> Array[String]:
	return ResearchText.effect_lines(sim, research.node(id))


## What a locked node still needs, as lines.
func need_lines(id: String) -> Array[String]:
	var out: Array[String] = []
	for m: Dictionary in research.missing(id):
		match String(m["kind"]):
			"requires":
				out.append(tr("research.req.requires").format({"name": tr(String(research.node(String(m["id"])).get("name", "")))}))
			"level":
				out.append(tr("research.req.level").format({"n": m["need"]}))
			"mastery":
				out.append(tr("research.req.mastery").format({"type": tr("mastery." + String(m["type"])), "n": m["need"]}))
			"proposal":
				out.append(tr("research.req.proposal"))
	return out


func refresh() -> void:
	var inv: InventorySystem = sim.system(&"inventory")
	for id: String in cards:
		var b: Button = cards[id]
		var n := research.node(id)
		(b.find_child("Name", true, false) as Label).text = tr(String(n.get("name", id)))
		var need := int(research.cost_of(id)["items"].get("notes", 0))
		(b.find_child("Notes", true, false) as Label).text = "%d / %d" % [mini(inv.count("notes"), need), need]
		(b.find_child("Notes", true, false) as Label).get_parent().visible = not research.is_done(id)
		b.modulate = Color(1, 1, 1, 0.55) if research.state_of(id) == "locked" else Color.WHITE
		b.queue_redraw()
	tree.queue_redraw()
	if selected == "":
		return
	var n := research.node(selected)
	detail_icon.texture = lib.atlas_texture(String(n.get("icon", "ui_research")))
	detail_name.text = tr(String(n.get("name", "")))
	if research.max_level(selected) > 1 and research.level(selected) > 0:
		detail_name.text += "  " + tr("research.level_of") % [research.level(selected), research.max_level(selected)]
	detail_desc.text = tr(String(n.get("desc", "")))
	PanelViews.clear(effects_box)
	for line: String in effect_lines(selected):
		var l := PanelViews.label(line, 16)
		l.theme_type_variation = &"GoodLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effects_box.add_child(l)
	PanelViews.clear(needs_box)
	for line: String in (need_lines(selected) if research.state_of(selected) == "locked" else [] as Array[String]):
		var l := PanelViews.label(line, 15)
		l.theme_type_variation = &"BadLabel"
		needs_box.add_child(l)
	var cost := research.cost_of(selected)
	var notes := int(cost["items"].get("notes", 0))
	cost_label.text = "%d / %d" % [inv.count("notes"), notes] + ("   $%d" % cost["money"] if cost["money"] > 0 else "")
	time_label.text = tr("research.time").format({"t": BuildingDetailView.duration(research.duration_ms(selected) / 1000.0)})
	var state := research.state_of(selected)
	var check := research.can_start(selected)
	match state:
		"done":
			start_button.text = tr("research.done")
			start_button.disabled = true
		"active":
			start_button.text = tr("research.running").format({"t": BuildingDetailView.duration(ceilf(research.remaining_ms() / 1000.0))})
			start_button.disabled = true
		"levelup":
			start_button.disabled = not check["ok"]
			start_button.text = tr("research.level_up") % (research.level(selected) + 1)
			if not check["ok"]:
				start_button.text += " · " + tr(String(check["reason"]))
		_:
			# Without a lab the button is the way to one, not a dead label.
			start_button.disabled = not check["ok"] and String(check["reason"]) != "err.no_lab"
			start_button.text = tr("research.start") if check["ok"] or state == "locked" else tr(String(check["reason"]))
