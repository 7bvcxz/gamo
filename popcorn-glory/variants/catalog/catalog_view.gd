extends PopPlayView

## Step 27's preview (#machines, not on the chooser): the forty machines of
## data/machines.json at the size of a real machine place, in their five groups
## of eight, with their ids -- and below, the same forty collapsed onto the
## factory's floors (sixteen in the kitchen, eight packing, eight in the shop,
## eight support along the tube), which is how 40 instances are meant to fit.
## A design sheet: nothing plays. Machines that do not run yet are drawn faded.

var _cat: Array = []
var _font := ThemeDB.fallback_font


func setup(p_rules: PopRules) -> void:
	super(p_rules)
	machine_node.visible = false
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/machines.json"))
	_cat = (doc as Dictionary)["machines"] if typeof(doc) == TYPE_DICTIONARY else []


func _process(delta: float) -> void:
	super(delta)
	machine_node.visible = false


func _gui_input(_event: InputEvent) -> void:
	pass


func _needs_redraw() -> bool:
	return false


func _draw_under(ci: CanvasItem, _base: Vector2, _size_px: float) -> void:
	var r := Rect2(Vector2.ZERO, size)
	ci.draw_rect(r, PopTokens.FLOOR_TOP[0])
	var wide := size.x > size.y * 1.15
	var sheet := Rect2(Vector2(16, 16), Vector2(size.x * (0.55 if wide else 1.0) - 32, size.y * (1.0 if wide else 0.56) - 24))
	var plan := Rect2(Vector2(size.x * 0.55 + 8, 16), Vector2(size.x * 0.45 - 24, size.y - 32)) if wide else Rect2(Vector2(16, size.y * 0.56 + 8), Vector2(size.x - 32, size.y * 0.44 - 24))
	_draw_sheet(ci, sheet)
	_draw_plan(ci, plan)


## Five rows of eight: M01-M08, M09-M16, P01-P08, S01-S08, U01-U08.
func _draw_sheet(ci: CanvasItem, r: Rect2) -> void:
	var cell := minf(r.size.x / 8.0, r.size.y / 5.0)
	var fs := int(clampf(cell * 0.16, 9.0, 15.0))
	for i in _cat.size():
		var e: Dictionary = _cat[i]
		var p := r.position + Vector2((i % 8) * cell, (i / 8) * cell)
		var box := Rect2(p + Vector2(3, 3), Vector2(cell - 6, cell - 6))
		var runs := e.get("runtime") != null
		PopMachineArt._round_rect(ci, box, 8, Color(1, 1, 1, 0.9 if runs else 0.5))
		PopFactoryArt.catalog_icon(ci, Rect2(box.position + Vector2(cell * 0.12, cell * 0.04), Vector2(cell * 0.76, cell * 0.66)), e["parts"], String(e["group"]))
		if not runs:
			PopMachineArt._round_rect(ci, box, 8, Color(1, 0.97, 0.9, 0.45))
		ci.draw_string(_font, box.position + Vector2(5, box.size.y - 6), String(e["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
		if runs:
			ci.draw_circle(box.end - Vector2(9, box.size.y - 9), 5.0, PopTokens.OK)


## The factory collapsed: every machine at a small, same size in rows per floor.
func _draw_plan(ci: CanvasItem, r: Rect2) -> void:
	var rows := {"kitchen": [], "packing": [], "shop": [], "support": []}
	for e: Dictionary in _cat:
		(rows[String(e["floor"])] as Array).append(e)
	var bands := [["shop", PopTokens.FLOOR_TOP], ["packing", PopTokens.FLOOR_MID], ["kitchen", PopTokens.FLOOR_LOW], ["support", [Color(0.85, 0.95, 0.93), Color(0.7, 0.88, 0.86)]]]
	var h := r.size.y / 4.0
	for k in bands.size():
		var name := String(bands[k][0])
		var band := Rect2(r.position + Vector2(0, k * h), Vector2(r.size.x, h - 8))
		PopFactoryArt.floor_panel(ci, band, bands[k][1])
		var list: Array = rows[name]
		var per := 8
		var cw := minf((band.size.x - 24) / per, band.size.y / ceilf(list.size() / float(per)) - 6)
		for i in list.size():
			var e: Dictionary = list[i]
			var p := band.position + Vector2(12 + (i % per) * cw, 6 + (i / per) * cw)
			PopFactoryArt.catalog_icon(ci, Rect2(p, Vector2(cw - 4, cw - 4)), e["parts"], String(e["group"]), Color(0, 0, 0, 0) if e.get("runtime") != null else Color(0, 0, 0, 0))
		ci.draw_string(_font, band.position + Vector2(band.size.x - 70, band.size.y - 8), "%s %d" % [name, list.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(PopPalette.INK, 0.6))
