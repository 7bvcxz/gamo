class_name LandPreview
extends Node2D

## One sea tile that can be bought, shown before it is: a translucent block
## rising out of the water where the land would be, gold (red when it cannot
## be bought now), with its price on a tag above it and, when there is one, a
## short line under the price ("tap again", "not enough money"). Purely
## visual; LandBuyer decides which tile.

const NONE := Vector2i(-99999, -99999)

var projection: IsoProjection
var land: LandSystem
var world: WorldSystem
var font: Font
var focus := NONE
var affordable := true
var hint := ""
var _t := 0.0


func setup(sim: Simulation, p_projection: IsoProjection) -> void:
	projection = p_projection
	land = sim.system(&"land")
	world = sim.system(&"world")


func show_cell(cell: Vector2i, p_affordable: bool, p_hint: String) -> void:
	focus = cell
	affordable = p_affordable
	hint = p_hint
	queue_redraw()


func clear() -> void:
	if focus == NONE:
		return
	focus = NONE
	hint = ""
	queue_redraw()


func _process(delta: float) -> void:
	if focus != NONE:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if focus == NONE or projection == null:
		return
	_draw_block(focus)
	_draw_price(focus)


func _draw_block(cell: Vector2i) -> void:
	var shine := 0.5 + 0.5 * sin(_t * 3.0)
	var fill := Color(1.0, 0.86, 0.3, 0.30 + 0.12 * shine) if affordable else Color(1.0, 0.45, 0.4, 0.22)
	var line := Color(1.0, 0.9, 0.4, 1.0) if affordable else Color(1, 0.5, 0.45, 1)
	var depth := projection.cliff_height * projection.height_scale
	var top := projection.cell_corners(cell)
	for d: Array in [[Vector2i(1, 0), 1, 2], [Vector2i(0, 1), 3, 2]]:
		if world.is_owned(cell + d[0]):
			continue
		var a: Vector2 = top[d[1]]
		var b: Vector2 = top[d[2]]
		draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, depth), a + Vector2(0, depth)]), Color(fill, fill.a * 0.8))
	draw_colored_polygon(top, fill)
	var loop := top.duplicate()
	loop.append(top[0])
	_dashed(loop, line, 3.0)


func _dashed(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var steps := maxi(1, int(length / 9.0))
		for s in steps:
			if s % 2 == 0:
				draw_line(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), color, width, true)


## The price tag: it lives in the world (it points at its cell) but reads the
## same size at any zoom, so its measurements are divided by the camera's scale.
func _draw_price(cell: Vector2i) -> void:
	if font == null:
		return
	var k := 1.0 / maxf(get_global_transform_with_canvas().get_scale().x, 0.01)
	var font_size := maxi(int(round(24.0 * k)), 4)
	var small := maxi(int(round(16.0 * k)), 4)
	var p := projection.cell_center(cell) + Vector2(0, -projection.tile_height * 0.45 - 30.0 * k)
	var text := price_text()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var hint_size := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, small) if hint != "" else Vector2.ZERO
	var pad := Vector2(12, 4) * k
	var w := maxf(size.x, hint_size.x)
	var h := size.y + (hint_size.y if hint != "" else 0.0)
	var rect := Rect2(Vector2(p.x - w * 0.5, p.y - h + size.y * 0.5) - pad, Vector2(w, h) + pad * 2.0)
	var bg := Color(0.06, 0.18, 0.36, 0.88)
	draw_rect(rect, bg, true)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - 6 * k, rect.end.y), Vector2(p.x + 6 * k, rect.end.y), Vector2(p.x, rect.end.y + 7 * k)]), bg)
	var y := rect.position.y + pad.y + size.y * 0.78
	draw_string(font, Vector2(p.x - size.x * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE if affordable else Color("#ff9a8f"))
	if hint != "":
		draw_string(font, Vector2(p.x - hint_size.x * 0.5, y + hint_size.y), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1, 1, 1, 0.85))


func price_text() -> String:
	return "$%d" % land.next_cost()
