class_name LabLauncher
extends Control

## The Lab's front page: the sea, a Momo, the two chosen experiments and the
## six originals. Since Step 94 the owner's picks, C and E, come first: one
## card each with two buttons -- the frozen baseline and the improved track
## (C+, E+; LabRegistry.TRACKS). This chooser is the one place that says
## which is which. Below them the six tiles of Step 86 -- each with its
## letter, a picture from the game, a title and a PLAY or SOON badge -- three
## columns on a phone, six on a wide screen. A tile opens its experiment (a
## SOON tile opens the stub, which says so).

signal open_requested(id: String)

## The six original experiments' tiles, by id.
var tiles: Dictionary = {}
## The chooser's buttons, by the id they open: rock, rock-plus, tycoon, tycoon-plus.
var focus: Dictionary = {}
var _grid: GridContainer
var _focus_row: HBoxContainer
var _focus_cards: Array[Control] = []
var _focus_ways: Array[BoxContainer] = []
var _focus_titles: Array[Label] = []
var _six: Label
var _ocean: LabOcean
var _island: LabIsland
var _momo: LabMomo
var _title: Label
var _sub: Label
var _version: Label
var reduced_motion := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ocean = LabOcean.new()
	add_child(_ocean)
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	_island = LabIsland.new()
	_island.set_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	world.add_child(_island)
	_momo = LabMomo.new()
	_momo.reduced_motion = reduced_motion
	_momo.size = 1.0
	_momo.position = _island.iso.cell_center(Vector2i(1, 1)) + Vector2(-64, -49)
	_island.add_child(_momo)
	_ocean.follow(_island)

	_title = LabStyle.label("Momonium Fun Lab", 52, Color.WHITE, 12)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_sub = LabStyle.label("Two picks, two tracks · the six below", 26, Color.WHITE, 8)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_sub)

	_version = LabStyle.label("Lab %s" % String(ProjectSettings.get_setting("application/config/version", "")), 22, Color(1, 1, 1, 0.8), 6)
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_version)

	_focus_row = HBoxContainer.new()
	_focus_row.name = "Picks"
	_focus_row.add_theme_constant_override("separation", 20)
	add_child(_focus_row)
	for t: Dictionary in LabRegistry.TRACKS:
		var card := _pick(LabRegistry.find(String(t["base"])), t)
		_focus_cards.append(card)
		_focus_row.add_child(card)

	_six = LabStyle.label("All six · Step 93", 24, Color.WHITE, 6)
	_six.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_six)

	_grid = GridContainer.new()
	_grid.name = "Tiles"
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	add_child(_grid)
	for e: Dictionary in LabRegistry.EXPERIMENTS:
		var t := _tile(e)
		tiles[String(e["id"])] = t
		_grid.add_child(t)
	resized.connect(_layout)
	_layout()


## One of the owner's picks: its letter, picture and title, and the two ways
## in -- Baseline (the experiment as it was chosen) and the improved track.
func _pick(e: Dictionary, track: Dictionary) -> Control:
	var base: Color = e["color"]
	var card := PanelContainer.new()
	card.name = "Pick_" + String(e["id"])
	card.add_theme_stylebox_override("panel", LabStyle.box(LabStyle.CREAM, 32, base, 6, 8))
	card.custom_minimum_size = Vector2(330, 330)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter := PanelContainer.new()
	letter.add_theme_stylebox_override("panel", LabStyle.box(base, 24, Color(0, 0, 0, 0), 0, 0))
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ll := LabStyle.label(String(e["letter"]), 32, Color.WHITE)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.custom_minimum_size = Vector2(30, 0)
	letter.add_child(ll)
	top.add_child(letter)
	# One line, never wrapped: a wrapping label asks for its height at the
	# width it has before layout (none), and the card grows to fit that.
	var title := LabStyle.label(String(e["title"]), 28, LabStyle.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_focus_titles.append(title)
	top.add_child(title)
	col.add_child(top)
	var pic := TextureRect.new()
	pic.texture = LabAtlas.texture(String(e["icon"]))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	# Side by side on a wide screen, one above the other on a phone (_layout).
	var row := BoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_ways.append(row)
	row.add_child(_way(String(e["id"]), "Baseline", Color("#7d8794")))
	row.add_child(_way(String(track["id"]), "%s Improved" % track["letter"], LabStyle.LEAF))
	col.add_child(row)
	card.add_child(col)
	return card


func _way(id: String, text: String, color: Color) -> Button:
	var b := Button.new()
	b.name = "Open_" + id
	b.text = text
	LabStyle.button(b, color, 26)
	b.custom_minimum_size = Vector2(0, 68)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: open_requested.emit(id))
	focus[id] = b
	return b


func _tile(e: Dictionary) -> Button:
	var id := String(e["id"])
	var playable := LabRegistry.playable(id)
	var b := Button.new()
	b.name = "Tile_" + id
	b.custom_minimum_size = Vector2(220, 220)
	b.focus_mode = Control.FOCUS_NONE
	var base: Color = e["color"]
	var card := LabStyle.box(LabStyle.CREAM, 32, base, 6, 8)
	b.add_theme_stylebox_override("normal", card)
	b.add_theme_stylebox_override("hover", LabStyle.box(Color.WHITE, 32, base, 6, 10))
	b.add_theme_stylebox_override("pressed", LabStyle.box(LabStyle.CREAM.darkened(0.06), 32, base, 6, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: open_requested.emit(id))
	if not playable:
		b.modulate = Color(1, 1, 1, 0.82)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 14
	col.offset_bottom = -14
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter := PanelContainer.new()
	letter.add_theme_stylebox_override("panel", LabStyle.box(base, 24, Color(0, 0, 0, 0), 0, 0))
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ll := LabStyle.label(String(e["letter"]), 30, Color.WHITE)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.custom_minimum_size = Vector2(34, 0)
	letter.add_child(ll)
	top.add_child(letter)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.add_theme_stylebox_override("panel", LabStyle.box(LabStyle.LEAF if playable else LabStyle.MUTED, 20, Color(0, 0, 0, 0), 0, 0))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := LabStyle.label("PLAY" if playable else "SOON", 20, Color.WHITE)
	bl.name = "BadgeText"
	badge.add_child(bl)
	top.add_child(badge)
	col.add_child(top)

	var pic := TextureRect.new()
	pic.texture = LabAtlas.texture(String(e["icon"]))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not playable:
		pic.modulate = Color(0.85, 0.85, 0.85, 0.9)
	col.add_child(pic)
	var title := LabStyle.label(String(e["title"]), 22, LabStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	b.add_child(col)
	return b


func _layout() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0:
		return
	var wide := w > h * 1.05
	_grid.columns = 6 if wide else 3
	var tile := Vector2(220, 220) if not wide else Vector2(230, 220)
	for t: Button in tiles.values():
		t.custom_minimum_size = tile
	var pick := Vector2(324, 380) if not wide else Vector2(440, 320)
	for c: Control in _focus_cards:
		c.custom_minimum_size = pick
	for row: BoxContainer in _focus_ways:
		row.vertical = not wide
	for t: Label in _focus_titles:
		t.add_theme_font_size_override("font_size", 28 if wide else 22)
	_title.size = Vector2(w, 70)
	_title.position = Vector2(0, 40)
	_sub.size = Vector2(w, 40)
	_sub.position = Vector2(0, 108)
	_version.size = Vector2(240, 30)
	_version.position = Vector2(w - 256, h - 40)
	# The islet with its Momo: under the title on a phone, beside it on a
	# wide screen (no room between).
	var picks_top := 300.0 if not wide else 160.0
	if wide:
		var k := 0.42
		_island.scale = Vector2(k, k)
		var title_w := _title.get_theme_font("font").get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		_island.position = Vector2(w * 0.5 - title_w * 0.5 - 90.0, 54.0)
	else:
		var k := 0.5
		_island.scale = Vector2(k, k)
		_island.position = Vector2(w * 0.5, 230.0 - 49.0 * k)
	_focus_row.reset_size()
	var fw := _focus_row.get_combined_minimum_size()
	_focus_row.size = fw
	_focus_row.position = Vector2((w - fw.x) * 0.5, picks_top)
	var six_top := picks_top + fw.y + 24.0
	_six.size = Vector2(w, 34)
	_six.position = Vector2(0, six_top)
	_grid.reset_size()
	var gw := _grid.get_combined_minimum_size()
	_grid.size = gw
	_grid.position = Vector2((w - gw.x) * 0.5, six_top + 44.0)


## Where each tile is, in canvas pixels.
func rects() -> Dictionary:
	return _rects(tiles)


## Where the chooser's buttons are (rock, rock-plus, tycoon, tycoon-plus).
func focus_rects() -> Dictionary:
	return _rects(focus)


static func _rects(of: Dictionary) -> Dictionary:
	var out := {}
	for id: String in of:
		var r := (of[id] as Control).get_global_rect()
		out[id] = [r.position.x, r.position.y, r.size.x, r.size.y]
	return out
