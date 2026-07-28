extends Node2D
class_name FxLayer

## Floating numbers and impact rings. Pooled in plain arrays: no node churn,
## no allocations per event beyond a small dictionary.

const MAX_EFFECTS := 96

var _labels: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []

func _process(delta: float) -> void:
	_advance(_labels, delta)
	_advance(_rings, delta)
	_advance(_sparks, delta)
	if not _labels.is_empty() or not _rings.is_empty() or not _sparks.is_empty():
		queue_redraw()

func _advance(pool: Array[Dictionary], delta: float) -> void:
	var index := pool.size() - 1
	while index >= 0:
		var fx: Dictionary = pool[index]
		fx["life"] = float(fx["life"]) - delta
		if float(fx["life"]) <= 0.0:
			pool.remove_at(index)
		else:
			pool[index] = fx
		index -= 1

func popup(at: Vector2, text: String, color: Color, plated: bool = false) -> void:
	if _labels.size() >= MAX_EFFECTS:
		return
	# Repeating the same message spawned a second copy at a slight offset, which
	# overlapped into unreadable glyph soup. Refresh the existing one instead.
	for index in _labels.size():
		if String(_labels[index]["text"]) == text:
			var existing: Dictionary = _labels[index]
			existing["life"] = float(existing["max"])
			existing["pos"] = at
			_labels[index] = existing
			return
	_labels.append({"pos": at, "text": text, "color": color, "life": 0.9, "max": 0.9, "plate": plated})

func ring(at: Vector2, color: Color, radius: float = 26.0) -> void:
	if _rings.size() >= MAX_EFFECTS:
		return
	_rings.append({"pos": at, "color": color, "life": 0.45, "max": 0.45, "radius": radius})

func burst(at: Vector2, color: Color, count: int = 7) -> void:
	if _sparks.size() >= MAX_EFFECTS:
		return
	for index in count:
		var angle: float = TAU * float(index) / float(count) + randf() * 0.5
		_sparks.append({
			"pos": at, "vel": Vector2.from_angle(angle) * randf_range(40.0, 95.0),
			"color": color, "life": 0.4, "max": 0.4,
		})

func _draw() -> void:
	# The fallback font has no CJK glyphs, so Korean popups rendered as boxes.
	var font: Font = UIFont.FONT
	for fx: Dictionary in _rings:
		var k: float = 1.0 - float(fx["life"]) / float(fx["max"])
		var col: Color = fx["color"]
		draw_arc(fx["pos"], 6.0 + k * float(fx["radius"]), 0.0, TAU, 28,
			Color(col.r, col.g, col.b, (1.0 - k) * 0.75), 2.5 * (1.0 - k) + 0.5, true)
	for fx: Dictionary in _sparks:
		var k: float = 1.0 - float(fx["life"]) / float(fx["max"])
		var col: Color = fx["color"]
		var at: Vector2 = Vector2(fx["pos"]) + Vector2(fx["vel"]) * k * 0.4
		draw_circle(at, 2.6 * (1.0 - k), Color(col.r, col.g, col.b, 1.0 - k))
	for fx: Dictionary in _labels:
		var k: float = 1.0 - float(fx["life"]) / float(fx["max"])
		var at: Vector2 = Vector2(fx["pos"]) + Vector2(0, -26.0 * k)
		var col: Color = fx["color"]
		var alpha: float = clampf(1.0 - k * k, 0.0, 1.0)
		var body: String = String(fx["text"])
		var width: float = font.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		# Text over the amber pool measured 1.38:1; a plate is the only way to
		# hold contrast against a background that can be any colour.
		if bool(fx.get("plate", false)):
			draw_rect(Rect2(at.x - width * 0.5 - 8.0, at.y - 15.0, width + 16.0, 21.0),
				Color(0.06, 0.08, 0.12, alpha * 0.92))
		draw_string(font, at - Vector2(width * 0.5, 0), body, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(col.r, col.g, col.b, alpha))
