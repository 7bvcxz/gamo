class_name LandPreview
extends Node2D

## Land mode's picture: every cell that can be bought shows as a translucent
## glass block rising out of the sea (white dashed outline), cells that would
## square the island up shine a little more, and the chosen one turns gold with
## its price above it. Purely visual; LandMode decides what is chosen.

var projection: IsoProjection
var land: LandSystem
var world: WorldSystem
var font: Font
var active := false
var chosen := Vector2i(-99999, -99999)
var affordable := true
var _t := 0.0
var _candidates: Array[Vector2i] = []
var _suggested: Dictionary = {}


func setup(sim: Simulation, p_projection: IsoProjection) -> void:
	projection = p_projection
	land = sim.system(&"land")
	world = sim.system(&"world")
	sim.bus.emitted.connect(func(type: StringName, _p: Dictionary) -> void:
		if type in [&"land_added", &"game_loaded"]:
			refresh())


func refresh() -> void:
	_candidates = land.candidates()
	_suggested.clear()
	for c: Vector2i in land.suggested():
		_suggested[c] = true
	queue_redraw()


func _process(delta: float) -> void:
	if active:
		_t += delta
		queue_redraw()


func is_candidate(cell: Vector2i) -> bool:
	return _candidates.has(cell)


func _draw() -> void:
	if not active:
		return
	var order := _candidates.duplicate()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return IsoProjection.depth(a) < IsoProjection.depth(b) or (IsoProjection.depth(a) == IsoProjection.depth(b) and a.x < b.x))
	for cell: Vector2i in order:
		_draw_block(cell)
	if _candidates.has(chosen):
		_draw_price(chosen)


func _draw_block(cell: Vector2i) -> void:
	var is_chosen := cell == chosen
	var shine := 0.5 + 0.5 * sin(_t * 3.0 + cell.x * 0.7 + cell.y * 1.3)
	var fill := Color(1, 1, 1, 0.16 + (0.06 * shine if _suggested.has(cell) else 0.0))
	var line := Color(1, 1, 1, 0.75 if _suggested.has(cell) else 0.5)
	if is_chosen:
		fill = Color(1.0, 0.86, 0.3, 0.42 if affordable else 0.25)
		line = Color(1.0, 0.9, 0.4, 1.0) if affordable else Color(1, 0.5, 0.45, 1)
	var depth := projection.cliff_height * projection.height_scale
	var top := projection.cell_corners(cell)
	# Faces only where nothing (land or another block) is in front.
	for d: Array in [[Vector2i(1, 0), 1, 2], [Vector2i(0, 1), 3, 2]]:
		var n: Vector2i = cell + d[0]
		if world.is_owned(n) or _candidates.has(n):
			continue
		var a: Vector2 = top[d[1]]
		var b: Vector2 = top[d[2]]
		draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, depth), a + Vector2(0, depth)]), Color(fill, fill.a * 0.8))
	draw_colored_polygon(top, fill)
	var loop := top.duplicate()
	loop.append(top[0])
	_dashed(loop, line, 2.0 if not is_chosen else 3.0)


func _dashed(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var steps := maxi(1, int(length / 9.0))
		for s in steps:
			if s % 2 == 0:
				draw_line(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), color, width, true)


func _draw_price(cell: Vector2i) -> void:
	if font == null:
		return
	# The tag lives in the world (it points at its cell) but should read the same
	# size at any zoom, so its measurements are divided by the camera's scale.
	var k := 1.0 / maxf(get_global_transform_with_canvas().get_scale().x, 0.01)
	var font_size := maxi(int(round(24.0 * k)), 4)
	var p := projection.cell_center(cell) + Vector2(0, -projection.tile_height * 0.45 - 26.0 * k)
	var text := "$%d" % land.next_cost()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pad := Vector2(12, 4) * k
	var rect := Rect2(p - size * 0.5 - pad, size + pad * 2.0)
	var bg := Color(0.06, 0.18, 0.36, 0.85)
	draw_rect(rect, bg, true)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - 6 * k, rect.end.y), Vector2(p.x + 6 * k, rect.end.y), Vector2(p.x, rect.end.y + 7 * k)]), bg)
	draw_string(font, Vector2(rect.position.x + pad.x, p.y + size.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE if affordable else Color("#ff9a8f"))
