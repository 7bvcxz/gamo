class_name ResearchView
extends HBoxContainer

## One industry's branch of the technology tree, as in the reference: node
## cards joined by dashed lines on the left (lock, check or progress on each,
## research notes needed under the name), the chosen node's details on the
## right -- the technique, what it changes, what it still needs, its cost and
## time, and the button. Every value comes from the ResearchSystem; effects
## are described from the same data the simulation applies.
##
## Step 71: a tab is a discipline eight tiers deep, so the tree scrolls on its
## own (the details stay put) and shows only what ResearchSystem.is_shown
## allows -- the tree grows with the level. Cards sit in fixed slots: a tier
## is a row, at most PER_LINE cards a line; a line with nothing shown takes no
## room, and a card never moves sideways when a neighbour appears. A shown
## card whose next tier is still hidden trails a short dashed stub: more
## comes later.

const CARD := Vector2(118, 104)
const ROW := 134.0
const GAP := 8.0
const PER_LINE := 3
## Room under the last line for the "more later" stub.
const STUB := 26.0

## "Build a research lab" pressed: the island should offer the lab on a free
## tile (Step 50: four blind players tapped that line and nothing happened).
signal lab_wanted

var sim: Simulation
var lib: SpriteLibrary
var research: ResearchSystem
var industry := ""
var tree_scroll: ScrollContainer
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
## Most nodes on one line: cards narrow to fit it.
var _widest := 1
## The tree's lines, top to bottom: ids in their fixed slots (Step 71).
var _lines: Array = []
## id -> shown now; what the layout was last made for.
var _shown: Dictionary = {}
var _shown_sig := -1
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
	tree_scroll = ScrollContainer.new()
	tree_scroll.name = "TreeScroll"
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(tree_scroll)
	tree = Control.new()
	tree.name = "Tree"
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.draw.connect(_draw_links)
	tree.resized.connect(_place_cards)
	tree_scroll.add_child(tree)
	for n: Dictionary in research.nodes(industry):
		var id := String(n["id"])
		cards[id] = _card(n)
		tree.add_child(cards[id])
	_lines = _make_lines()
	_widest = 1
	for line: Array in _lines:
		_widest = maxi(_widest, line.size())
	tree.custom_minimum_size = Vector2(2 * CARD.x + 24, ROW)
	_build_detail()
	_update_shown()
	_select_default()


## The lines of the tree: a row per tier, each cut into lines of PER_LINE --
## ordinary nodes first, by the level they open at, specials last.
func _make_lines() -> Array:
	var order: Array = cards.keys()
	var by_tier: Dictionary = {}
	for id: String in cards:
		var t := research.tier_of(id)
		if not by_tier.has(t):
			by_tier[t] = []
		(by_tier[t] as Array).append(id)
	var tiers: Array = by_tier.keys()
	tiers.sort()
	var out: Array = []
	for t: int in tiers:
		var row: Array = by_tier[t]
		row.sort_custom(func(a: String, b: String) -> bool:
			var ka := [1 if research.node(a).has("special") else 0, int(research.node(a).get("unlock", {}).get("level", 99)), order.find(a)]
			var kb := [1 if research.node(b).has("special") else 0, int(research.node(b).get("unlock", {}).get("level", 99)), order.find(b)]
			return ka < kb)
		for i in range(0, row.size(), PER_LINE):
			out.append(row.slice(i, i + PER_LINE))
	return out


## Whether this tab shows anything (its tab button hides when not).
func has_shown() -> bool:
	_update_shown()
	return _shown.values().has(true)


## Reads what is shown now; lays the cards out again when that changed.
func _update_shown() -> void:
	var now := {}
	for id: String in cards:
		now[id] = research.is_shown(id)
	var sig := now.hash()
	if sig == _shown_sig:
		return
	_shown = now
	_shown_sig = sig
	if is_inside_tree():
		_place_cards()


func _select_default() -> void:
	selected = ""
	for id: String in cards:
		if not bool(_shown.get(id, false)):
			continue
		if selected == "" or research.state_of(id) in ["active", "available"] and research.state_of(selected) == "locked":
			selected = id


## Shows `id`'s details (a letter's "See it in Research", the news), and
## scrolls the tree to its card.
func select(id: String) -> void:
	if cards.has(id):
		selected = id
		refresh()
		reveal.call_deferred(id)


## Scrolls the tree so `id`'s card is in view -- a frame later, once the
## scroll knows how tall the tree has grown (a card just revealed is below
## the old bottom).
func reveal(id: String) -> void:
	if not cards.has(id) or not tree_scroll.is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(tree_scroll) and tree_scroll.is_inside_tree():
		tree_scroll.ensure_control_visible(cards[id])


func _place_cards() -> void:
	var w := minf(CARD.x, tree.size.x / _widest - GAP)
	var y := 0.0
	for line: Array in _lines:
		var any := false
		for i in line.size():
			var card: Button = cards[line[i]]
			card.custom_minimum_size = Vector2(w, CARD.y)
			card.size = Vector2(w, CARD.y)
			(card.find_child("Name", true, false) as Label).custom_minimum_size.x = w - 10.0
			card.position = Vector2(tree.size.x * (i + 0.5) / line.size() - w * 0.5, y + 6.0)
			card.visible = bool(_shown.get(line[i], false))
			any = any or card.visible
		if any:
			y += ROW
	tree.custom_minimum_size.y = maxf(y + STUB, ROW)
	tree_scroll.custom_minimum_size.y = minf(tree.custom_minimum_size.y, _tree_room())
	tree.queue_redraw()


## How tall the tree may be before it scrolls on its own: the room the
## panel gives its body (PanelFrame: two thirds of the window), so the
## details beside it never scroll away.
func _tree_room() -> float:
	var n: Node = get_parent()
	while n != null and not n is PanelFrame:
		n = n.get_parent()
	if n == null:
		return 520.0
	return maxf((n as PanelFrame).size.y * 0.66 - 8.0, 260.0)


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
	col.name = "Body"
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
	# Step 70: a node held back by the player level says which, where the
	# padlock is: "Lv 5" on a dark pill -- the forward track, readable at a
	# glance. It is not faded with the locked card (see refresh) and grows to
	# the left from the corner, so "Lv 10" stays on the card.
	var gate := PanelViews.label("", 14)
	gate.name = "Gate"
	gate.add_theme_color_override("font_color", Color("#ffd166"))
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.1, 0.18, 0.3, 0.92)
	pill.set_corner_radius_all(11)
	pill.content_margin_left = 8.0
	pill.content_margin_right = 8.0
	gate.add_theme_stylebox_override("normal", pill)
	gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gate.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	gate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gate.visible = false
	b.add_child(gate)
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
		"locked" when gate_level(id) > 0:
			pass # the "Lv N" pill stands where the padlock would
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


## Step 71: shown cards with a next tier still hidden -- the ones that trail
## the "more later" stub.
func more_later() -> Array[String]:
	var out: Array[String] = []
	for id: String in cards:
		if bool(_shown.get(id, false)):
			continue
		for r: String in research.node(id).get("requires", []):
			if cards.has(r) and bool(_shown.get(r, false)) and not out.has(r):
				out.append(r)
	return out


func _draw_links() -> void:
	var line := tree.get_theme_color("line", "Ink")
	for id: String in cards:
		var child: Button = cards[id]
		if not child.visible:
			continue
		for r: String in research.node(id).get("requires", []):
			if not cards.has(r) or not (cards[r] as Button).visible:
				continue
			var parent: Button = cards[r]
			var a := parent.position + Vector2(parent.size.x * 0.5, parent.size.y)
			var b := child.position + Vector2(child.size.x * 0.5, 0)
			var mid := (a.y + b.y) * 0.5
			var color := line if research.is_done(r) else Color(line, line.a * 0.45)
			for seg: Array in [[a, Vector2(a.x, mid)], [Vector2(a.x, mid), Vector2(b.x, mid)], [Vector2(b.x, mid), b]]:
				tree.draw_dashed_line(seg[0], seg[1], color, 2.0, 6.0)
	# More comes later: a short fading stub under a card whose next tier is
	# still hidden -- no card, no words.
	for r: String in more_later():
		var parent: Button = cards[r]
		var a := parent.position + Vector2(parent.size.x * 0.5, parent.size.y)
		tree.draw_dashed_line(a, a + Vector2(0, 12), Color(line, line.a * 0.4), 2.0, 4.0)
		tree.draw_circle(a + Vector2(0, 18), 2.0, Color(line, line.a * 0.3))


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


## Step 70: the player level a locked node waits for (0 when it waits for
## nothing of the kind -- open, or held back by a parent or a special gate).
func gate_level(id: String) -> int:
	for m: Dictionary in research.missing(id):
		if String(m["kind"]) == "level":
			return int(m["need"])
	return 0


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
	_update_shown()
	if selected == "" or not bool(_shown.get(selected, false)):
		_select_default()
	for id: String in cards:
		var b: Button = cards[id]
		var n := research.node(id)
		(b.find_child("Name", true, false) as Label).text = tr(String(n.get("name", id)))
		var need := int(research.cost_of(id)["items"].get("notes", 0))
		(b.find_child("Notes", true, false) as Label).text = "%d / %d" % [mini(inv.count("notes"), need), need]
		var gate := gate_level(id)
		(b.find_child("Notes", true, false) as Label).get_parent().visible = not research.is_done(id)
		var gate_label := b.find_child("Gate", true, false) as Label
		gate_label.visible = gate > 0
		gate_label.text = "Lv %d" % gate
		# A locked card fades -- its face and its own drawing, not the Lv pill.
		var fade := Color(1, 1, 1, 0.55) if research.state_of(id) == "locked" else Color.WHITE
		b.self_modulate = fade
		(b.get_node("Body") as Control).modulate = fade
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
