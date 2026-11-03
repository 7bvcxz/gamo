class_name PopIconButton
extends PopPressArea

## A round button with a drawn icon: "back" (an arrow) or "restart" (a circle
## arrow). Icons, not words.

var icon := "back"


func _draw() -> void:
	var c := size / 2
	var r := minf(size.x, size.y) / 2
	draw_circle(c + Vector2(0, 3), r, PopPalette.SHADOW)
	draw_circle(c, r, Color(1, 1, 1, 0.85) if not held else PopPalette.CREAM.darkened(0.08))
	var k := r * 0.42
	match icon:
		"back":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k, 0), c + Vector2(k * 0.2, -k * 0.85), c + Vector2(k * 0.2, k * 0.85)]), PopPalette.INK)
			draw_rect(Rect2(c + Vector2(0, -k * 0.3), Vector2(k * 0.95, k * 0.6)), PopPalette.INK)
		"restart":
			draw_arc(c, k, deg_to_rad(-60), deg_to_rad(230), 24, PopPalette.INK, k * 0.38)
			var tip := c + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * k
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-k * 0.55, -k * 0.2), tip + Vector2(k * 0.35, -k * 0.55), tip + Vector2(k * 0.2, k * 0.45)]), PopPalette.INK)
