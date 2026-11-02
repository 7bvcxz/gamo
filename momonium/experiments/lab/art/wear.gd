class_name LabWear
extends RefCounted

## Little things a Momo wears (experiment B), drawn from shapes on the work
## frame's own measured marks -- `eyes`, `torso` and the head's top (hats sit
## on it), already in the Momo's local pixels -- so they move with the body
## through every frame. `u` is
## local pixels per texel of the work sheet (160 texels feet to curl).
## Each returns the point it is pinned to (tests check it follows the marks).

const INK := Color("#4b3324")


static func draw(ci: CanvasItem, name: String, eyes: Vector2, torso: Vector2, head: Vector2, u: float, flipped: bool) -> Vector2:
	var side := -1.0 if flipped else 1.0
	match name:
		"bag":
			var at := torso + Vector2(44.0 * side, 6.0) * u
			ci.draw_line(eyes + Vector2(-22.0 * side, 24.0) * u, at + Vector2(0, -12.0) * u, Color("#7a4b2f"), 4.0 * u, true)
			_box(ci, Rect2(at - Vector2(17, 12) * u, Vector2(34, 26) * u), 6.0 * u, Color("#b07a4a"))
			_box(ci, Rect2(at - Vector2(17, 12) * u, Vector2(34, 11) * u), 5.0 * u, Color("#8c5a34"))
			ci.draw_circle(at + Vector2(0, -2) * u, 2.6 * u, Color("#f2c230"))
			return at
		"hat":
			var at := head + Vector2(0, 6.0) * u
			_ellipse(ci, at, Vector2(40, 12) * u, 0.0, INK)
			_ellipse(ci, at, Vector2(38, 10) * u, 0.0, Color("#6cc650"))
			_ellipse(ci, at + Vector2(-8, -3) * u, Vector2(20, 4) * u, -0.1, Color("#9be07a"))
			ci.draw_line(at + Vector2(0, -8) * u, at + Vector2(6, -18) * u, Color("#4e9f38"), 3.0 * u, true)
			return at
		"apron":
			# Low on the body, under the paws that hold the tool.
			var at := torso + Vector2(0, 24.0) * u
			_box(ci, Rect2(at - Vector2(23, 14) * u, Vector2(46, 28) * u), 9.0 * u, Color("#f7b2c2"))
			_box(ci, Rect2(at + Vector2(-10, -2) * u, Vector2(20, 11) * u), 4.0 * u, Color("#f39ab0"))
			ci.draw_line(at + Vector2(-23, -10) * u, at + Vector2(-31, -16) * u, Color("#e88aa0"), 3.0 * u, true)
			ci.draw_line(at + Vector2(23, -10) * u, at + Vector2(31, -16) * u, Color("#e88aa0"), 3.0 * u, true)
			return at
		"scarf":
			var at := eyes + Vector2(0, 40.0) * u
			_box(ci, Rect2(at - Vector2(34, 6) * u, Vector2(68, 13) * u), 6.0 * u, Color("#e5534b"))
			_box(ci, Rect2(at + Vector2(14.0 * side - 6.0, 4) * u, Vector2(13, 28) * u), 5.0 * u, Color("#d24440"))
			for k in 3:
				ci.draw_line(at + Vector2(-30 + 20 * k, -6) * u, at + Vector2(-24 + 20 * k, 7) * u, Color("#f58a83"), 2.0 * u, true)
			return at
		"helmet":
			var at := head + Vector2(0, 22.0) * u
			var dome := PackedVector2Array()
			for k in 17:
				var a := PI + PI * k / 16.0
				dome.append(at + Vector2(cos(a) * 40.0, sin(a) * 30.0) * u)
			ci.draw_colored_polygon(dome, Color("#f2c230"))
			_box(ci, Rect2(at + Vector2(-46, -3) * u, Vector2(92, 9) * u), 4.0 * u, Color("#d9a520"))
			ci.draw_circle(at + Vector2(0, -16) * u, 9.0 * u, Color("#fff6c4"))
			ci.draw_circle(at + Vector2(0, -16) * u, 5.0 * u, Color("#ffffff"))
			return at
		"medal":
			# Hung from the scarf's knot side.
			var at := eyes + Vector2(-18.0 * side, 60.0) * u
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -22) * u, at + Vector2(0, -4) * u, at + Vector2(7, -22) * u]), Color("#5a8fd8"))
			ci.draw_circle(at, 9.5 * u, INK)
			ci.draw_circle(at, 8.0 * u, Color("#ffd34d"))
			ci.draw_circle(at + Vector2(-2.5, -2.5) * u, 2.5 * u, Color(1, 1, 1, 0.8))
			return at
		"crown":
			var at := head + Vector2(0, 2.0) * u
			var pts := PackedVector2Array([at + Vector2(-28, 10) * u, at + Vector2(-30, -14) * u, at + Vector2(-14, -2) * u, at + Vector2(0, -20) * u,
				at + Vector2(14, -2) * u, at + Vector2(30, -14) * u, at + Vector2(28, 10) * u])
			ci.draw_colored_polygon(pts, Color("#ffd34d"))
			var ring := pts.duplicate()
			ring.append(pts[0])
			ci.draw_polyline(ring, Color("#c9972a"), 2.5 * u, true)
			for x: float in [-16.0, 0.0, 16.0]:
				ci.draw_circle(at + Vector2(x, 4) * u, 3.5 * u, Color("#ff6b8a") if x != 0.0 else Color("#6bd0ff"))
			return at
	return eyes


static func _box(ci: CanvasItem, r: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, turn: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(turn))
	ci.draw_colored_polygon(pts, col)
