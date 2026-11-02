class_name LabIconButton
extends Button

## A round button with a drawn icon: back, restart, sound, mute, report,
## play. Shapes rather than glyphs, so nothing depends on the font.

var icon_name := "back"
var ink := LabStyle.INK


static func make(p_icon: String, diameter: float = 88.0) -> LabIconButton:
	var b := LabIconButton.new()
	b.icon_name = p_icon
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.add_theme_stylebox_override("normal", LabStyle.box(Color(1, 1, 1, 0.92), int(diameter / 2.0)))
	b.add_theme_stylebox_override("hover", LabStyle.box(Color.WHITE, int(diameter / 2.0)))
	b.add_theme_stylebox_override("pressed", LabStyle.box(Color(0.9, 0.93, 0.95), int(diameter / 2.0), Color(0, 0, 0, 0), 0, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	return b


func set_icon(p_icon: String) -> void:
	icon_name = p_icon
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.22
	var w := maxf(4.0, r * 0.32)
	match icon_name:
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(r * 0.45, -r), c + Vector2(-r * 0.55, 0), c + Vector2(r * 0.45, r)]), ink, w, true)
		"restart":
			draw_arc(c, r, deg_to_rad(-60), deg_to_rad(230), 24, ink, w, true)
			var tip := c + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * r
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.55, -r * 0.2), tip + Vector2(r * 0.25, -r * 0.55), tip + Vector2(r * 0.2, r * 0.35)]), ink)
		"sound", "mute":
			var body := PackedVector2Array([c + Vector2(-r, -r * 0.4), c + Vector2(-r * 0.45, -r * 0.4), c + Vector2(r * 0.15, -r), c + Vector2(r * 0.15, r), c + Vector2(-r * 0.45, r * 0.4), c + Vector2(-r, r * 0.4)])
			draw_colored_polygon(body, ink)
			if icon_name == "sound":
				draw_arc(c + Vector2(r * 0.2, 0), r * 0.55, -0.9, 0.9, 10, ink, w * 0.7, true)
				draw_arc(c + Vector2(r * 0.2, 0), r * 0.95, -0.9, 0.9, 12, ink, w * 0.7, true)
			else:
				draw_line(c + Vector2(r * 0.45, -r * 0.45), c + Vector2(r * 1.15, r * 0.45), ink, w * 0.8, true)
				draw_line(c + Vector2(r * 1.15, -r * 0.45), c + Vector2(r * 0.45, r * 0.45), ink, w * 0.8, true)
		"report":
			for i in 3:
				var y := c.y + (float(i) - 1.0) * r * 0.7
				draw_line(Vector2(c.x - r * 0.8, y), Vector2(c.x + r * (0.8 - 0.3 * i), y), ink, w * 0.8, true)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r, 0), c + Vector2(-r * 0.6, r)]), ink)
