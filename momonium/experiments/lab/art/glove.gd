class_name LabGlove
extends RefCounted

## The player's glove and tools from the game (momonium src/render/hand_works.gd,
## Step 83: the same shapes and colours; the tools are shared/hands, a copy of
## the game's painted tools). `draw` puts a fist at `at` with its cuff toward
## +x and the handle along y; `tool` returns a tool's texture region, grip and
## tip.

const TOOLS := preload("res://shared/hands/hand_tools.png")
const DATA_PATH := "res://shared/hands/hand_tools.json"
const INK := Color("#4b3324")
const CREAM := Color("#fff7e8")
const SHADE := Color("#efdcc2")
const CUFF := Color("#8fd6c9")
const CUFF_SHADE := Color("#6fbfb1")

static var _data: Dictionary = {}


## {region: Rect2, grip: Vector2, tip: Vector2} in the tools texture's pixels.
static func tool(name: String) -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
	var t: Dictionary = (_data["tools"] as Dictionary)[name]
	var r: Array = t["region"]
	return {"region": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
		"grip": Vector2(float(t["grip"][0]), float(t["grip"][1])), "tip": Vector2(float(t["tip"][0]), float(t["tip"][1]))}


## A tool's picture alone (for a button).
static func tool_texture(name: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = TOOLS
	a.region = tool(name)["region"]
	return a


static func draw(ci: CanvasItem, at: Vector2 = Vector2.ZERO, size: float = 1.0) -> void:
	var lw := 1.25 * size
	var palm := _rounded(Rect2(at + Vector2(-5.0, -6.0) * size, Vector2(10.5, 12.0) * size), 4.0 * size)
	var fingers: Array[Vector2] = []
	for y: float in [-4.4, -1.5, 1.5, 4.4]:
		fingers.append(at + Vector2(-5.6, y) * size)
	var thumb := at + Vector2(-1.6, -5.4) * size
	var cuff := _rounded(Rect2(at + Vector2(4.2, -6.2) * size, Vector2(6.4, 12.4) * size), 2.2 * size)
	var band := _rounded(Rect2(at + Vector2(8.0, -6.2) * size, Vector2(2.6, 12.4) * size), 1.2 * size)
	ci.draw_colored_polygon(_grown(cuff, at + Vector2(7.4, 0) * size, lw), INK)
	ci.draw_colored_polygon(_grown(palm, at + Vector2(0.2, 0) * size, lw), INK)
	for f: Vector2 in fingers:
		ci.draw_circle(f, 2.15 * size + lw, INK)
	_ellipse(ci, thumb, Vector2(3.3, 2.0) * size + Vector2(lw, lw), -0.35, INK)
	ci.draw_colored_polygon(cuff, CUFF)
	ci.draw_colored_polygon(band, CUFF_SHADE)
	ci.draw_colored_polygon(palm, CREAM)
	ci.draw_colored_polygon(_rounded(Rect2(at + Vector2(-1.0, -2.0) * size, Vector2(6.0, 7.6) * size), 3.0 * size), SHADE)
	for f: Vector2 in fingers:
		ci.draw_circle(f, 2.15 * size, CREAM)
	_ellipse(ci, thumb, Vector2(3.3, 2.0) * size, -0.35, CREAM)
	for y: float in [-2.95, 0.0, 2.95]:
		ci.draw_line(at + Vector2(-7.0, y) * size, at + Vector2(-4.4, y) * size, INK.lerp(SHADE, 0.35), 0.8 * size, true)
	ci.draw_circle(at + Vector2(-2.6, -2.2) * size, 1.0 * size, Color(1, 1, 1, 0.85))


static func _rounded(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners := [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5]]
	for c: Array in corners:
		for i in 5:
			var a := float(c[1]) + PI * 0.5 * i / 4.0
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts


static func _grown(pts: PackedVector2Array, centre: Vector2, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + (p - centre).normalized() * by)
	return out


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, turn: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(turn))
	ci.draw_colored_polygon(pts, col)
