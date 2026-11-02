class_name LabLauncher
extends Control

## The Lab's front page: the sea, a Momo, and six tiles -- one per experiment,
## each with its letter, a picture from the game, a title and a PLAY or SOON
## badge. Two columns on a phone, three on a wide screen. A tile opens its
## experiment (a SOON tile opens the stub, which says so).

signal open_requested(id: String)

var tiles: Dictionary = {}
var _grid: GridContainer
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
	_sub = LabStyle.label("6 tiny experiments · 3 minutes each", 26, Color.WHITE, 8)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_sub)

	_version = LabStyle.label("Lab %s" % String(ProjectSettings.get_setting("application/config/version", "")), 22, Color(1, 1, 1, 0.8), 6)
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_version)

	_grid = GridContainer.new()
	_grid.name = "Tiles"
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 24)
	add_child(_grid)
	for e: Dictionary in LabRegistry.EXPERIMENTS:
		var t := _tile(e)
		tiles[String(e["id"])] = t
		_grid.add_child(t)
	resized.connect(_layout)
	_layout()


func _tile(e: Dictionary) -> Button:
	var id := String(e["id"])
	var playable := LabRegistry.playable(id)
	var b := Button.new()
	b.name = "Tile_" + id
	b.custom_minimum_size = Vector2(316, 300)
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
	var ll := LabStyle.label(String(e["letter"]), 36, Color.WHITE)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.custom_minimum_size = Vector2(40, 0)
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
	var bl := LabStyle.label("PLAY" if playable else "SOON", 24, Color.WHITE)
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
	var title := LabStyle.label(String(e["title"]), 30, LabStyle.INK)
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
	_grid.columns = 3 if wide else 2
	var tile := Vector2(316, 300) if not wide else Vector2(300, 250)
	for t: Button in tiles.values():
		t.custom_minimum_size = tile
	_grid.reset_size()
	var gw := _grid.get_combined_minimum_size()
	_grid.size = gw
	var top := 300.0 if not wide else 230.0
	_grid.position = Vector2((w - gw.x) * 0.5, maxf(top, h - gw.y - 60.0) if not wide else top)
	_title.size = Vector2(w, 70)
	_title.position = Vector2(0, 40)
	_sub.size = Vector2(w, 40)
	_sub.position = Vector2(0, 108)
	_version.size = Vector2(240, 30)
	_version.position = Vector2(w - 256, h - 40)
	# The islet with its Momo: between the title and the tiles on a phone,
	# beside the title on a wide screen (no room between).
	if wide:
		var k := 0.42
		_island.scale = Vector2(k, k)
		var title_w := _title.get_theme_font("font").get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		_island.position = Vector2(w * 0.5 - title_w * 0.5 - 90.0, 54.0)
	else:
		var islet_y := (160.0 + _grid.position.y) * 0.5 - 20.0
		var k := clampf((_grid.position.y - 170.0) / 260.0, 0.45, 1.0)
		_island.scale = Vector2(k, k)
		_island.position = Vector2(w * 0.5, islet_y - 49.0 * k)


## Where each tile is, in canvas pixels.
func rects() -> Dictionary:
	var out := {}
	for id: String in tiles:
		var r := (tiles[id] as Control).get_global_rect()
		out[id] = [r.position.x, r.position.y, r.size.x, r.size.y]
	return out
