class_name SelectionMarker
extends Node2D

## A soft gold outline on the selected tile, drawn on the ground (above the
## island, below everything standing on it).

var projection: IsoProjection
var cell := Vector2i.ZERO
var shown := false
var _t := 0.0


func show_cell(p_cell: Vector2i) -> void:
	cell = p_cell
	shown = true
	_t = 0.0
	queue_redraw()


func clear() -> void:
	shown = false
	queue_redraw()


func _process(delta: float) -> void:
	if shown:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if not shown or projection == null:
		return
	var c := projection.cell_corners(cell)
	var pulse := 0.75 + 0.25 * sin(_t * 4.0)
	draw_colored_polygon(c, Color(1, 0.96, 0.7, 0.16 * pulse))
	var loop := c.duplicate()
	loop.append(c[0])
	draw_polyline(loop, Color(1, 0.92, 0.45, 0.9 * pulse), 3.0, true)
