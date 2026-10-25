class_name LandRiseEffect
extends Node2D

## A new cell coming up out of the sea: a grass block rising from below the
## waterline into place while a ring of foam spreads around it. 0.9 s, then
## it removes itself. The island already owns the cell; this is only the show.

const DURATION := 0.9

var projection: IsoProjection
var cell := Vector2i.ZERO
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var rise := 1.0 - pow(1.0 - k, 3.0)
	var centre := projection.cell_center(cell, -projection.cliff_height)
	var corners := projection.cell_corners(cell, -projection.cliff_height)
	# Foam ring spreading on the water.
	var ring := PackedVector2Array()
	for c: Vector2 in corners:
		ring.append(centre + (c - centre) * (1.0 + k * 0.9))
	ring.append(ring[0])
	draw_polyline(ring, Color(1, 1, 1, (1.0 - k) * 0.9), 4.0 * (1.0 - k) + 1.0, true)
	# Sparkles rising.
	for i in 6:
		var a := TAU * i / 6.0 + k * 2.0
		var p := projection.cell_center(cell) + Vector2(cos(a) * 38.0, sin(a) * 22.0 - rise * 30.0)
		draw_circle(p, 3.0 * (1.0 - k), Color(1, 0.95, 0.6, 1.0 - k))
	# A light flash over the new top as it settles.
	var top := projection.cell_corners(cell)
	draw_colored_polygon(top, Color(1, 1, 0.85, 0.5 * (1.0 - rise)))
