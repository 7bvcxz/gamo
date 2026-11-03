class_name PopChooser
extends Control

## The first screen when no experiment is in the address: one tile per listed
## experiment -- its letter and a small machine in its colour. Tap to play.

signal chosen(id: String)

var tiles: Array[Dictionary] = []   # {id, rect}
var _buttons: Array[PopPressArea] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(entries: Array[Dictionary]) -> void:
	for b: PopPressArea in _buttons:
		b.queue_free()
	_buttons.clear()
	tiles.clear()
	for e: Dictionary in entries:
		var b := PopPressArea.new()
		b.name = "Tile_" + String(e["id"])
		var id := String(e["id"])
		b.pressed.connect(func() -> void: chosen.emit(id))
		b.draw.connect(_draw_tile.bind(b, e))
		add_child(b)
		_buttons.append(b)
		tiles.append({"id": id, "button": b})
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var n := _buttons.size()
	if n == 0:
		return
	var col := minf(size.x, 720.0)
	var tile_h := clampf((size.y - 200.0) / n - 32.0, 180.0, 300.0)
	var total := n * tile_h + (n - 1) * 32.0
	var y := (size.y - total) / 2
	for b: PopPressArea in _buttons:
		b.size = Vector2(col - 120, tile_h)
		b.position = Vector2((size.x - b.size.x) / 2, y)
		y += tile_h + 32.0


## What you do, as a picture behind the machine: a ring with its gold arc (B).
func _draw_mechanic(b: CanvasItem, id: String, base: Vector2, size: float, _color: Color) -> void:
	if id == "perfect":
		var c := base - Vector2(0, size * 0.45)
		b.draw_arc(c, size * 0.62, -PI / 2, PI * 0.6, 32, Color(0.3, 0.55, 0.95, 0.6), size * 0.06)
		b.draw_arc(c, size * 0.62, PI * 0.6, PI * 1.05, 16, PopPalette.GOLD, size * 0.11)
		b.draw_arc(c, size * 0.62, PI * 1.05, PI * 1.5, 16, Color(0.9, 0.25, 0.2, 0.5), size * 0.06)


## ...and in front of it: a tapping finger with pops (A), a row of kernels and
## a burst (C).
func _draw_mechanic_over(b: CanvasItem, id: String, base: Vector2, size: float, _color: Color) -> void:
	var top := base - Vector2(0, size * 0.85)
	match id:
		"click":
			for i in 5:
				var a := -PI / 2 + (float(i) - 2.0) * 0.45
				PopMachineArt.draw_piece(b, top + Vector2(cos(a), sin(a)) * size * 0.32, size * 0.07, a)
			var p := base + Vector2(size * 0.42, -size * 0.25)
			b.draw_circle(p, size * 0.07, PopPalette.CREAM)
			b.draw_rect(Rect2(p.x - size * 0.07, p.y, size * 0.14, size * 0.22), PopPalette.CREAM)
			b.draw_arc(p, size * 0.07, PI, TAU, 12, PopPalette.INK, 3.0)
		"explosion":
			for i in 8:
				var q := top + Vector2((float(i) - 3.5) * size * 0.11, -size * 0.12)
				b.draw_circle(q, size * 0.045, Color(0.85, 0.55, 0.2) if i < 6 else Color(1, 1, 1, 0.9))
			b.draw_colored_polygon(PopMachineArt._star(base + Vector2(-size * 0.5, -size * 0.6), size * 0.2, size * 0.09), Color(1, 0.95, 0.6))


func _draw_tile(b: PopPressArea, e: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	if b.held:
		r.position.y += 4
	var color: Color = e["color"]
	PopMachineArt._round_rect(b, Rect2(r.position + Vector2(0, 8), r.size), 36, PopPalette.SHADOW)
	PopMachineArt._round_rect(b, r, 36, Color(1, 1, 1, 0.92))
	PopMachineArt._round_rect(b, Rect2(r.position, Vector2(r.size.y, r.size.y)), 36, color)
	var font := ThemeDB.fallback_font
	var fs := int(r.size.y * 0.55)
	b.draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + fs * 0.36), String(e["letter"]),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.y, fs, Color.WHITE)
	var mbase := Vector2(r.position.x + r.size.y + (r.size.x - r.size.y) / 2 - 20, r.end.y - r.size.y * 0.12)
	var msize := r.size.y * 0.72
	_draw_mechanic(b, String(e["id"]), mbase, msize, color)
	PopMachineArt.draw(b, mbase, msize, 2, 0.0, 0.4)
	_draw_mechanic_over(b, String(e["id"]), mbase, msize, color)
	# A play triangle.
	var p := Vector2(r.end.x - 56, r.get_center().y)
	b.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -24), p + Vector2(22, 0), p + Vector2(-16, 24)]), color)
