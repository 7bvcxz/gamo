class_name Donut
extends Control

## A thin ring that fills as the day passes (0..1), light blue into yellow
## like the reference: the day's progress read at a glance, no numbers needed.

var progress := 0.0:
	set(value):
		if not is_equal_approx(value, progress):
			progress = clampf(value, 0.0, 1.0)
			queue_redraw()
var thickness := 7.0
var track := Color(1, 1, 1, 0.22)
var start_color := Color("#8fe0ff")
var end_color := Color("#ffe27a")


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - thickness * 0.5
	var c := size * 0.5
	draw_arc(c, r, 0.0, TAU, 48, get_theme_color("track", "Ink") if has_theme_color("track", "Ink") else track, thickness, true)
	if progress <= 0.0:
		return
	# Drawn as short segments so the colour can travel along the ring.
	var steps := maxi(2, int(48 * progress))
	var a0 := -PI * 0.5
	for i in steps:
		var t0 := float(i) / steps * progress
		var t1 := float(i + 1) / steps * progress
		draw_arc(c, r, a0 + TAU * t0, a0 + TAU * t1, 3, start_color.lerp(end_color, t1), thickness, true)
