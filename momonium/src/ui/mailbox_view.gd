class_name MailboxView
extends VBoxContainer

## The mailbox: every letter Momo have written, newest first -- the sender's
## face, the title, the day, a red dot while unread -- and, opened, the letter
## itself on paper. Opening a letter marks it read through the simulation;
## nothing is stored here.
##
## Step 57: reading is for the story. A research letter's topic was already
## discovered when the letter came, so there is nothing to accept: under the
## letter a small footer says what that research needs -- the real rules,
## with progress -- or that it is ready, running or done, and a button goes
## to it in Research. A letter without research has no footer.

signal letter_opened(id: int)
## "See it in Research": the research the letter proposes.
signal research_wanted(id: String)

const INK := Color("#5a4632")
const INK_SOFT := Color("#8a7158")

var sim: Simulation
var lib: SpriteLibrary
var mail: MailSystem
var list_box: VBoxContainer
var letter_box: VBoxContainer
var back_button: Button
var card: LetterCard
var footer: VBoxContainer
var footer_title: Label
var footer_lines: VBoxContainer
var research_button: Button
var empty_label: Label
var open_id := 0
var last_result: Dictionary = {}
var _shown_rows := ""


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	lib = p_lib
	mail = sim.system(&"mail")
	name = "MailboxView"
	add_theme_constant_override("separation", 10)
	list_box = VBoxContainer.new()
	list_box.name = "List"
	list_box.add_theme_constant_override("separation", 8)
	add_child(list_box)
	empty_label = PanelViews.label("", 18, true)
	empty_label.name = "Empty"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(empty_label)

	letter_box = VBoxContainer.new()
	letter_box.name = "Letter"
	letter_box.add_theme_constant_override("separation", 10)
	letter_box.visible = false
	add_child(letter_box)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.custom_minimum_size = Vector2(52, 52)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.draw.connect(func() -> void:
		var c := back_button.size * 0.5 + Vector2(-2, 0)
		back_button.draw_polyline(PackedVector2Array([c + Vector2(6, -10), c + Vector2(-5, 0), c + Vector2(6, 10)]), back_button.get_theme_color("glyph", "Ink"), 3.5, true))
	back_button.pressed.connect(show_list)
	letter_box.add_child(back_button)
	card = LetterCard.new()
	card.setup(lib)
	letter_box.add_child(card)
	footer = VBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 4)
	letter_box.add_child(footer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(PanelViews.icon(lib, "ui_flask", 30.0))
	footer_title = PanelViews.label("", 17)
	footer_title.name = "FooterTitle"
	footer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(footer_title)
	footer.add_child(head)
	footer_lines = VBoxContainer.new()
	footer_lines.name = "Conditions"
	footer_lines.add_theme_constant_override("separation", 0)
	footer.add_child(footer_lines)
	research_button = Button.new()
	research_button.name = "ToResearch"
	research_button.custom_minimum_size = Vector2(0, 50)
	research_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	research_button.focus_mode = Control.FOCUS_NONE
	research_button.add_theme_font_size_override("font_size", 17)
	research_button.pressed.connect(func() -> void:
		var l := mail.get_letter(open_id)
		if not l.is_empty() and String(l.get("research", "")) != "":
			research_wanted.emit(String(l["research"])))
	footer.add_child(research_button)


func show_list() -> void:
	open_id = 0
	refresh()


func open_letter(id: int) -> void:
	if mail.get_letter(id).is_empty():
		return
	open_id = id
	last_result = sim.execute({"type": "mail.read", "id": id})
	letter_opened.emit(id)
	refresh()


func refresh() -> void:
	var reading := open_id != 0
	list_box.visible = not reading
	letter_box.visible = reading
	empty_label.visible = not reading and mail.letters.is_empty()
	empty_label.text = tr("mail.empty")
	if reading:
		_refresh_letter()
	else:
		_refresh_list()


func _refresh_list() -> void:
	var key := ""
	for l: Dictionary in mail.letters:
		key += "%d:%s;" % [int(l["id"]), int(l["read_ms"]) >= 0]
	key += TranslationServer.get_locale()
	if key == _shown_rows:
		return
	_shown_rows = key
	PanelViews.clear(list_box)
	var newest_first := mail.letters.duplicate()
	newest_first.reverse()
	for l: Dictionary in newest_first:
		list_box.add_child(_row(l))


func _row(l: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Row_%d" % int(l["id"])
	b.custom_minimum_size = Vector2(0, 76)
	b.focus_mode = Control.FOCUS_NONE
	var id := int(l["id"])
	b.pressed.connect(func() -> void: open_letter(id))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -34
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(PanelViews.icon(lib, "momo_front", 54.0))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := PanelViews.label(tr(String(l["title"])), 19)
	title.name = "Title"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(title)
	col.add_child(PanelViews.label("%s  ·  %s" % [tr("hud.day") % int(l["day"]), tr(String(l["sender_name"]))], 15, true))
	row.add_child(col)
	b.add_child(row)
	var unread := int(l["read_ms"]) < 0
	b.set_meta("unread", unread)
	# Unread: a red dot and the title in gold; read: the row steps back.
	if unread:
		title.theme_type_variation = &"GoldLabel"
	else:
		row.modulate = Color(1, 1, 1, 0.72)
	b.draw.connect(func() -> void:
		if unread:
			var c := Vector2(b.size.x - 20, b.size.y * 0.5)
			b.draw_circle(c, 8.0, Color("#ff5a4f"))
			b.draw_arc(c, 8.0, 0, TAU, 16, Color.WHITE, 1.6, true))
	return b


func _refresh_letter() -> void:
	var l := mail.get_letter(open_id)
	if l.is_empty():
		show_list()
		return
	card.show_letter(tr("mail.from") % tr(String(l["sender_name"])), tr(String(l["title"])), tr(String(l["body"])), tr(String(l["sender_name"])))
	var research_id := String(l.get("research", ""))
	footer.visible = research_id != ""
	if research_id == "":
		return
	var research: ResearchSystem = sim.system(&"research")
	footer_title.text = tr("mail.req.title").format({"name": tr(String(research.node(research_id).get("name", research_id)))})
	PanelViews.clear(footer_lines)
	for c: Dictionary in conditions(research_id):
		var line := PanelViews.label(("✓ " if c["met"] else "· ") + String(c["text"]), 15)
		line.name = "Condition"
		line.theme_type_variation = &"GoodLabel" if c["met"] else &""
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		footer_lines.add_child(line)
	research_button.text = tr("mail.to_research")


## What the letter's research needs, from the research rules themselves:
## [{text, met}], first the state (done, running, ready), then each condition
## with its progress. Nothing here is made up for the letter.
func conditions(research_id: String) -> Array[Dictionary]:
	var research: ResearchSystem = sim.system(&"research")
	var out: Array[Dictionary] = []
	var n := research.node(research_id)
	if n.is_empty():
		return out
	match research.state_of(research_id):
		"done", "levelup":
			out.append({"text": tr("mail.req.done"), "met": true})
			return out
		"active":
			out.append({"text": tr("mail.req.active"), "met": true})
			return out
	# The letter itself is what opened it.
	out.append({"text": tr("mail.req.discovered"), "met": true})
	for r: String in n.get("requires", []):
		out.append({"text": tr("research.req.requires").format({"name": tr(String(research.node(r).get("name", r)))}), "met": research.is_done(r)})
	if not research.unlocked.has(research_id):
		var unlock: Dictionary = n.get("unlock", {})
		var prog: ProgressionSystem = sim.system(&"progression")
		if unlock.has("level"):
			var need := int(unlock["level"])
			out.append({"text": tr("research.req.level").format({"n": need}) + _progress(prog.level, need), "met": prog.level >= need})
		for t: String in unlock.get("mastery", {}):
			var need := int(unlock["mastery"][t])
			var have := int(prog.mastery_of(t)["level"])
			out.append({"text": tr("research.req.mastery").format({"type": tr("mastery." + t), "n": need}) + _progress(have, need), "met": have >= need})
	out.append({"text": tr("mail.req.lab"), "met": research.has_lab()})
	var cost := research.cost_of(research_id)
	var inv: InventorySystem = sim.system(&"inventory")
	for item: String in cost["items"]:
		var need := int(cost["items"][item])
		var have := inv.count(item)
		out.append({"text": "%s %d / %d" % [tr("item." + item), mini(have, need), need], "met": have >= need})
	if int(cost["money"]) > 0:
		var money := (sim.system(&"economy") as EconomySystem).money
		out.append({"text": "%s $%d / $%d" % [tr("mail.req.money"), mini(money, int(cost["money"])), int(cost["money"])], "met": money >= int(cost["money"])})
	if research.state_of(research_id) == "available" and research.can_start(research_id)["ok"]:
		out.push_front({"text": tr("mail.req.ready"), "met": true})
	return out


static func _progress(have: int, need: int) -> String:
	return "" if have >= need else "  (%d / %d)" % [have, need]


## The letter on paper: cream sheet, airmail stripes round the edge, a stamp,
## the sender's face and line, the title, the words, and the signature with a
## sprout, as in the reference letter.
class LetterCard:
	extends PanelContainer

	var from_label: Label
	var title_label: Label
	var body_label: Label
	var sign_label: Label

	func setup(lib: SpriteLibrary) -> void:
		name = "LetterCard"
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("#fbf3e3")
		paper.set_corner_radius_all(12)
		paper.set_content_margin_all(26)
		paper.content_margin_top = 22
		paper.shadow_color = Color(0, 0.08, 0.2, 0.25)
		paper.shadow_size = 6
		paper.shadow_offset = Vector2(0, 3)
		add_theme_stylebox_override("panel", paper)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(PanelViews.icon(lib, "momo_front", 56.0))
		from_label = _ink(20, MailboxView.INK_SOFT)
		from_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(from_label)
		col.add_child(head)
		title_label = _ink(22, MailboxView.INK)
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(title_label)
		body_label = _ink(18, MailboxView.INK)
		body_label.name = "Body"
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.add_theme_constant_override("line_spacing", 4)
		col.add_child(body_label)
		var sign_row := HBoxContainer.new()
		sign_row.alignment = BoxContainer.ALIGNMENT_END
		sign_row.add_child(PanelViews.icon(lib, "ui_sprout", 28.0))
		sign_label = _ink(20, MailboxView.INK_SOFT)
		sign_row.add_child(sign_label)
		col.add_child(sign_row)

	func _ink(font_size: int, color: Color) -> Label:
		var l := PanelViews.label("", font_size)
		l.add_theme_color_override("font_color", color)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		return l

	func show_letter(from_text: String, title: String, body: String, signature: String) -> void:
		from_label.text = from_text
		title_label.text = title
		body_label.text = body
		sign_label.text = signature

	func _draw() -> void:
		# Airmail stripes: short slanted red and blue dashes round the edge.
		var band := 7.0
		var step := 16.0
		var colors: Array[Color] = [Color("#e9877a"), Color("#7fa6d9")]
		var i := 0
		var x := 14.0
		while x < size.x - 14.0:
			for y: float in [4.0, size.y - 4.0 - band]:
				draw_colored_polygon(PackedVector2Array([Vector2(x, y + band), Vector2(x + 6, y), Vector2(x + 12, y), Vector2(x + 6, y + band)]), colors[i % 2])
			x += step
			i += 1
		var y2 := 14.0
		i = 0
		while y2 < size.y - 14.0:
			for x2: float in [4.0, size.x - 4.0 - band]:
				draw_colored_polygon(PackedVector2Array([Vector2(x2, y2 + 6), Vector2(x2 + band, y2), Vector2(x2 + band, y2 + 6), Vector2(x2, y2 + 12)]), colors[i % 2])
			y2 += step
			i += 1
		# The stamp: a pink square with a scalloped white edge and a blossom.
		var s := Rect2(size.x - 70, 18, 46, 52)
		draw_rect(s.grow(3), Color.WHITE)
		draw_rect(s, Color("#f4a9b5"))
		var c := s.get_center()
		for k in 5:
			var a := TAU * k / 5.0 - PI / 2.0
			draw_circle(c + Vector2(cos(a), sin(a)) * 8.0, 6.0, Color("#fff4f6"))
		draw_circle(c, 4.0, Color("#f2c14e"))
