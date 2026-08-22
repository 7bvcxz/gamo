extends Node2D
class_name FxLayer

## Floating numbers and impact rings. Pooled in plain arrays: no node churn,
## no allocations per event beyond a small dictionary.

const MAX_EFFECTS := 96

var _labels: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
## Things travelling from one place to another. The only effect here that has a
## destination: everything else happens where it happens, and this one exists to
## say that what was in her hands is now in the fire.
var _streams: Array[Dictionary] = []

## The signpost's line, drawn here rather than with the board itself.
##
## The board is painted by the machine layer, which sits *under* the fog -- so
## the one piece of directions in this game was legible everywhere except the
## white where it is needed. This layer is above the fog, and above the world in
## general, which is what "a label" means.
##
## Pushed by Main every frame: where the board is, and how brightly it is saying
## its line.
var sign_at := Vector2.ZERO
var sign_label: float = 0.0
const SIGN_TEXT := 11

func _process(delta: float) -> void:
	_advance(_labels, delta)
	_advance(_rings, delta)
	_advance(_sparks, delta)
	_advance(_streams, delta)
	if not _labels.is_empty() or not _rings.is_empty() or not _sparks.is_empty() \
			or not _streams.is_empty() or sign_label > 0.0:
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

## Half of what it was. These are the "+1 열석" labels that go up over whatever
## she just picked up, and at fifteen they were the size of the interface -- a
## number the size of a headline for a thing that happens twenty times a minute.
## The plate around a plated label is measured from this rather than written
## down, so the two cannot come apart.
const LABEL_SIZE := 8

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
	_labels.append({"pos": at, "text": text, "color": color, "life": 0.9, "max": 0.9, "iron": plated})

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

## How long one piece takes to travel, whatever the distance. Long enough to be
## watched: the core is usually one tile away when this fires, and at half this
## the whole thing was over before a screenshot could catch it.
const FLIGHT := 0.75

## A handful of pieces flying from `from` into `to`, staggered so they arrive as
## a stream rather than as one clump. They curve: a straight line between two
## points reads as a laser, and these are meant to read as being pulled in.
func stream(from: Vector2, to: Vector2, color: Color, count: int = 6) -> void:
	if _streams.size() >= MAX_EFFECTS:
		return
	var span: Vector2 = to - from
	# One side or the other, alternating, so the arc is a spray and not a rope.
	var side: Vector2 = Vector2(-span.y, span.x).normalized()
	for index in count:
		var delay: float = float(index) * 0.09
		_streams.append({
			"pos": from, "to": to, "color": color,
			"bend": side * (20.0 + randf() * 16.0) * (1.0 if index % 2 == 0 else -1.0),
			"life": FLIGHT + delay, "max": FLIGHT + delay, "delay": delay,
		})

func _draw() -> void:
	# The fallback font has no CJK glyphs, so Korean popups rendered as boxes.
	var font: Font = UIFont.FONT
	_draw_sign_label(font)
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
	for fx: Dictionary in _streams:
		var elapsed: float = float(fx["max"]) - float(fx["life"])
		if elapsed < float(fx["delay"]):
			continue
		var k: float = clampf((elapsed - float(fx["delay"])) / FLIGHT, 0.0, 1.0)
		var col: Color = fx["color"]
		# A quadratic bend, so the piece leaves her sideways and arrives head on.
		var straight: Vector2 = Vector2(fx["pos"]).lerp(Vector2(fx["to"]), k)
		var at: Vector2 = straight + Vector2(fx["bend"]) * sin(k * PI)
		# Shrinking as it goes in, which is what being swallowed looks like.
		draw_circle(at, 5.2 * (1.0 - k * 0.7), Color(col.r, col.g, col.b, 1.0 - k * 0.3))
		draw_circle(at, 2.4 * (1.0 - k * 0.7), Color(1, 1, 1, (1.0 - k) * 0.7))
	for fx: Dictionary in _labels:
		var k: float = 1.0 - float(fx["life"]) / float(fx["max"])
		var at: Vector2 = Vector2(fx["pos"]) + Vector2(0, -26.0 * k)
		var col: Color = fx["color"]
		var alpha: float = clampf(1.0 - k * k, 0.0, 1.0)
		var body: String = String(fx["text"])
		var width: float = font.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		# Text over the amber pool measured 1.38:1; a plate is the only way to
		# hold contrast against a background that can be any colour.
		if bool(fx.get("iron", false)):
			draw_rect(Rect2(at.x - width * 0.5 - 5.0, at.y - float(LABEL_SIZE),
				width + 10.0, float(LABEL_SIZE) + 6.0),
				Color(0.06, 0.08, 0.12, alpha * 0.92))
		draw_string(font, at - Vector2(width * 0.5, 0), body, HORIZONTAL_ALIGNMENT_LEFT, -1,
			LABEL_SIZE, Color(col.r, col.g, col.b, alpha))

## What the board says, on a plate above it. The plate is the same idea as the
## key caps over her head: this sits over snow, over fog and over the amber pool,
## and has to be legible on all three.
func _draw_sign_label(font: Font) -> void:
	if sign_label <= 0.01:
		return
	var fade: float = clampf(sign_label, 0.0, 1.0)
	var width: float = font.get_string_size(Defs.SIGN_LINE,
		HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_TEXT).x
	var box := Rect2(sign_at.x - width * 0.5 - 7.0, sign_at.y - 40.0,
		width + 14.0, float(SIGN_TEXT) + 9.0)
	# Nearly opaque, for the same reason the key caps are: this is read standing
	# in white fog, and a translucent plate on white is a grey plate.
	draw_rect(box, Color(0.04, 0.05, 0.09, 0.95 * fade))
	draw_rect(box, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b,
		0.55 * fade), false, 1.0)
	draw_string(font, Vector2(box.position.x + 7.0, box.end.y - 6.0),
		Defs.SIGN_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_TEXT,
		Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, fade))
