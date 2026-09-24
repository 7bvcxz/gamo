extends RefCounted
class_name HudStyle

## One look for everything drawn in screen space.
##
## The HUD grew a box per purpose -- a framed ledger with corner ticks, a grey
## wash behind two bars, an amber-ruled card for the goal, square plates for the
## notifications -- and every one of them was a number typed where it was used.
## Side by side they read as five interfaces that happened to share a screen. So
## the numbers live here, once, and every panel is drawn by the one function
## below: a cold navy plate the snow shows through a little, a hairline edge, a
## soft corner. Warmth is the accent, because warmth is what this game is about:
## the fire, the hand-held torch, the slot in her hand.
##
## Units are the HUD's own. The HUD scales itself for the platform and the
## player's setting, so a token of 10 is ten of whatever that scale makes it --
## nothing here should ever be multiplied by a screen size.

# --- Spacing ----------------------------------------------------------------
## Distance from the screen edge to any panel.
const OUTER_MARGIN := 16.0
## Inside a panel, from its edge to its content.
const PANEL_PADDING := 10.0
## Between two things in one list.
const ITEM_GAP := 6.0
## Between two groups inside a panel, or two panels in one corner.
const SECTION_GAP := 10.0
const CORNER_RADIUS := 8.0
const BORDER_WIDTH := 1.0

# --- Sizes ------------------------------------------------------------------
const ICON_SMALL := 14.0
const ICON_NORMAL := 22.0
const ICON_LARGE := 32.0
const TEXT_SMALL := 11
const TEXT_NORMAL := 13
const TEXT_TITLE := 15
## One row of a list set in TEXT_NORMAL.
const ROW := 19.0
## A row that carries a large icon beside two lines of text -- a thing, its name,
## its price. The icon plus a gap above and below, so the text never sets it.
const ROW_LARGE := ICON_LARGE + ITEM_GAP * 2.0
## A small window: one list the player picks from, not a catalogue. Wide enough
## for a large row with a name, a price and a badge.
const WINDOW_W_SMALL := 340.0

# --- Colour -----------------------------------------------------------------
## The plate. Navy rather than black so it belongs to the cold, and translucent
## enough that the world under a corner panel is still the world.
const PANEL_FILL := Color(0.055, 0.075, 0.125, 0.78)
## Windows the player stops to read hold text over a busy world, and the snow
## coming through a lighter plate made long lines swim.
const PANEL_FILL_SOLID := Color(0.055, 0.075, 0.125, 0.95)
const PANEL_BORDER := Color(0.62, 0.74, 0.92, 0.20)
const PANEL_SHADOW := Color(0.0, 0.01, 0.04, 0.28)
const TEXT_MAIN := Defs.COL_TEXT
const TEXT_SUB := Defs.COL_TEXT_DIM
## The fire's amber. Selection, progress, the thing to look at.
const ACCENT := Defs.COL_CORE
## Night and ice -- the other half of every bar in this game.
const ACCENT_COLD := Color(0.60, 0.77, 0.93)
const DANGER := Defs.COL_DANGER
## Something finished.
const DONE := Defs.COL_BELT_RIM
## An empty bar: dark enough that a fill of any colour reads against it.
const TRACK := Color(0.10, 0.13, 0.21, 0.95)
const TEXT_SHADOW := Color(0.02, 0.03, 0.06, 0.70)
## A rule between two groups inside one panel.
const DIVIDER := Color(0.62, 0.74, 0.92, 0.14)

# --- Panels -----------------------------------------------------------------
enum { PANEL, SOLID, SLOT, SLOT_ON, CHIP, BUTTON, BUTTON_ON }

static var _boxes: Dictionary = {}

## The shapes, built once. Godot's StyleBoxFlat already knows how to draw a
## rounded, bordered, shadowed rectangle with antialiased corners, so a panel is
## one of these rather than a polygon assembled by hand in three files.
static func box(kind: int) -> StyleBoxFlat:
	if _boxes.has(kind):
		return _boxes[kind]
	var style := StyleBoxFlat.new()
	style.anti_aliasing = true
	style.set_corner_radius_all(int(CORNER_RADIUS))
	style.set_border_width_all(int(BORDER_WIDTH))
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.shadow_color = PANEL_SHADOW
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 2.0)
	match kind:
		SOLID:
			style.bg_color = PANEL_FILL_SOLID
			style.shadow_size = 10
		SLOT:
			style.bg_color = Color(PANEL_FILL.r, PANEL_FILL.g, PANEL_FILL.b, 0.72)
		SLOT_ON:
			# The slot in her hand: the fire's colour at the edge and a little of
			# it inside, the way a lamp lights the thing nearest it.
			style.bg_color = Color(0.16, 0.12, 0.10, 0.86)
			style.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.95)
			style.set_border_width_all(2)
			style.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.22)
			style.shadow_size = 8
			style.shadow_offset = Vector2.ZERO
		CHIP:
			style.set_corner_radius_all(int(CORNER_RADIUS) - 2)
			style.shadow_size = 4
		BUTTON:
			style.set_corner_radius_all(int(CORNER_RADIUS) - 2)
			style.bg_color = Color(PANEL_FILL.r, PANEL_FILL.g, PANEL_FILL.b, 0.86)
			style.shadow_size = 4
		BUTTON_ON:
			style.set_corner_radius_all(int(CORNER_RADIUS) - 2)
			style.bg_color = Color(0.16, 0.12, 0.10, 0.90)
			style.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.85)
			style.shadow_size = 4
	_boxes[kind] = style
	return style

## Every panel on the screen goes through here.
static func panel(on: CanvasItem, rect: Rect2, kind: int = PANEL) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	box(kind).draw(on.get_canvas_item(), rect)

## A panel that fades with whatever it carries. Built per call rather than kept,
## because the alpha is the caller's and the shared boxes must not remember it.
static func panel_faded(on: CanvasItem, rect: Rect2, alpha: float, kind: int = PANEL) -> void:
	if alpha >= 0.999:
		panel(on, rect, kind)
		return
	if alpha <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var style: StyleBoxFlat = box(kind).duplicate() as StyleBoxFlat
	style.bg_color.a *= alpha
	style.border_color.a *= alpha
	style.shadow_color.a *= alpha
	style.draw(on.get_canvas_item(), rect)

## A title inside a window, and the rule under it. Every window lays its content
## out below TITLE_RULE, so the two numbers are the contract, not a suggestion.
const TITLE_BASELINE := 16.0
const TITLE_RULE := 22.0

static func title(on: CanvasItem, rect: Rect2, body: String, tint: Color = ACCENT) -> void:
	text(on, rect.position + Vector2(PANEL_PADDING, TITLE_BASELINE), body, TEXT_SMALL,
		Color(tint.r, tint.g, tint.b, 0.95))
	on.draw_line(rect.position + Vector2(PANEL_PADDING, TITLE_RULE),
		rect.position + Vector2(rect.size.x - PANEL_PADDING, TITLE_RULE), DIVIDER, 1.0)

## A hairline between two groups in one panel.
static func divider(on: CanvasItem, from: Vector2, width: float) -> void:
	on.draw_line(from, from + Vector2(width, 0.0), DIVIDER, 1.0)

# --- Badges -----------------------------------------------------------------
## A small pill with one word in it: NEW, a state, a count. Drawn right-aligned
## to `right` so a column of them lines up, and returns its rect.
static func badge(on: CanvasItem, right: Vector2, body: String, tint: Color,
		filled: bool = false) -> Rect2:
	var width: float = width_of(body, TEXT_SMALL) + ITEM_GAP * 2.0
	var height: float = float(TEXT_SMALL) + 6.0
	var rect := Rect2(right.x - width, right.y - height * 0.5, width, height)
	var fill := Color(tint.r, tint.g, tint.b, 0.92 if filled else 0.14)
	on.draw_colored_polygon(rounded(rect, height * 0.5), fill)
	if not filled:
		on.draw_polyline(_closed(rounded(rect, height * 0.5)),
			Color(tint.r, tint.g, tint.b, 0.75), 1.0, true)
	var ink: Color = Color(0.08, 0.07, 0.06) if filled else tint
	text_in(on, Rect2(rect.position.x, baseline_for(rect.get_center().y, TEXT_SMALL),
		rect.size.x, 12.0), body, TEXT_SMALL, ink)
	return rect

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out

## A glow drawn round a rect and fading as `k` goes from 1 to 0 -- a slot that
## just received something, a row that just changed.
static func pulse(on: CanvasItem, rect: Rect2, k: float, tint: Color = ACCENT) -> void:
	if k <= 0.0:
		return
	var spread: float = (1.0 - k) * 7.0 + 1.0
	on.draw_polyline(_closed(rounded(rect.grow(spread), CORNER_RADIUS + spread)),
		Color(tint.r, tint.g, tint.b, 0.9 * k), 2.0, true)

# --- Text -------------------------------------------------------------------
## Everything is set with a soft one-pixel shadow: panels are translucent, and a
## line that is legible over the navy has to stay legible where snow shows through.
static func text(on: CanvasItem, at: Vector2, body: String, size: int, color: Color) -> void:
	var shadow := Color(TEXT_SHADOW.r, TEXT_SHADOW.g, TEXT_SHADOW.b, TEXT_SHADOW.a * color.a)
	on.draw_string(UIFont.FONT, at + Vector2(1, 1), body, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	on.draw_string(UIFont.FONT, at, body, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## In a box, aligned. Godot ignores alignment without a width, so centred text
## always spans an explicit box.
static func text_in(on: CanvasItem, box_rect: Rect2, body: String, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var shadow := Color(TEXT_SHADOW.r, TEXT_SHADOW.g, TEXT_SHADOW.b, TEXT_SHADOW.a * color.a)
	on.draw_string(UIFont.FONT, box_rect.position + Vector2(1, 1), body, align,
		box_rect.size.x, size, shadow)
	on.draw_string(UIFont.FONT, box_rect.position, body, align, box_rect.size.x, size, color)

## Where to put the baseline so a line of this size sits centred on `middle`.
##
## The corner used to place labels by eye -- a baseline "a little above" the bar
## -- and at the next font size the day number sat on top of its own bar. The
## font knows how tall it is; ask it.
static func baseline_for(middle: float, size: int) -> float:
	var ascent: float = UIFont.FONT.get_ascent(size)
	var descent: float = UIFont.FONT.get_descent(size)
	return middle + (ascent - descent) * 0.5

static func width_of(body: String, size: int) -> float:
	return UIFont.FONT.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Lines, broken at spaces rather than between syllables.
##
## Godot's own wrap follows the Unicode line-break rules, which treat every
## Hangul syllable as a place a line may end -- so "불이 무언가" came out as
## "불이 무 / 언가", a word cut in half in the middle of the world card. Korean
## is set keep-all: a line ends at a space, and a word longer than the whole
## line is the only thing ever broken inside itself. Double spaces (this game's
## pause between two sentences) survive, except at the start of a line.
static func wrap_lines(body: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	for paragraph: String in body.split("\n"):
		var line := ""
		for word: String in paragraph.split(" ", true):
			var candidate: String = word if line.is_empty() else line + " " + word
			if line.is_empty() or width_of(candidate.strip_edges(), size) <= width:
				line = candidate
				continue
			out.append(line.strip_edges())
			line = word
			# A single word wider than the line: cut it where it overflows.
			while width_of(line, size) > width and line.length() > 1:
				var cut: int = line.length() - 1
				while cut > 1 and width_of(line.substr(0, cut), size) > width:
					cut -= 1
				out.append(line.substr(0, cut))
				line = line.substr(cut)
		out.append(line.strip_edges())
	return out

static func line_height(size: int) -> float:
	return UIFont.FONT.get_height(size)

## A wrapped block. `at` is the first line's baseline, as with draw_string.
static func block(on: CanvasItem, at: Vector2, body: String, width: float, size: int,
		color: Color) -> void:
	if body == "":
		return
	var step: float = line_height(size)
	var lines: PackedStringArray = wrap_lines(body, width, size)
	for index in lines.size():
		text(on, at + Vector2(0.0, step * float(index)), lines[index], size, color)

static func block_height(body: String, width: float, size: int) -> float:
	if body == "":
		return 0.0
	return float(wrap_lines(body, width, size).size()) * line_height(size)

# --- Bars -------------------------------------------------------------------
## A rounded bar. The track first, then the fill clipped to the same pill, so a
## sliver of fill at the start is a rounded sliver rather than a square one.
static func bar(on: CanvasItem, rect: Rect2, fraction: float, fill: Color,
		track: Color = TRACK) -> void:
	var radius: float = rect.size.y * 0.5
	on.draw_colored_polygon(rounded(rect, radius), track)
	var k: float = clampf(fraction, 0.0, 1.0)
	if k <= 0.0:
		return
	var length: float = maxf(rect.size.x * k, rect.size.y)
	on.draw_colored_polygon(rounded(Rect2(rect.position, Vector2(length, rect.size.y)), radius),
		fill)

## A rounded rectangle, as a polygon. Godot's draw_rect has square corners, and a
## square key cap is a tile.
static func rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var out := PackedVector2Array()
	var corners: Array[Vector2] = [
		rect.position + Vector2(r, r),
		Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r),
		Vector2(rect.position.x + r, rect.end.y - r),
	]
	for index in 4:
		var start: float = PI + float(index) * PI * 0.5
		for step in 5:
			var angle: float = start + PI * 0.5 * float(step) / 4.0
			out.append(corners[index] + Vector2.from_angle(angle) * r)
	return out

# --- Key caps ---------------------------------------------------------------
## One key: a dark side, a light face sitting on it, and the glyph. The guide in
## settings and the prompt in the corner draw the same key, so a player who
## learned a cap in one place recognises it in the other.
const CAP_H := 17.0
const CAP_MIN := 17.0
const CAP_PAD := 8.0
const CAP_RADIUS := 3.5
const CAP_LIP := 2.5
const CAP_GLYPH := 10

static func cap_width(label: String, height: float = CAP_H) -> float:
	var glyph_size: int = int(round(float(CAP_GLYPH) * height / CAP_H))
	var glyph: float = width_of(label, glyph_size)
	return maxf(CAP_MIN * height / CAP_H, glyph + CAP_PAD * height / CAP_H)

## Draws the cap with its top-left at `at` and returns how wide it was.
static func keycap(on: CanvasItem, at: Vector2, label: String, fade: float = 1.0,
		height: float = CAP_H) -> float:
	var width: float = cap_width(label, height)
	var k: float = height / CAP_H
	var body := Rect2(at, Vector2(width, height))
	on.draw_colored_polygon(rounded(body, CAP_RADIUS * k), Color(0.42, 0.46, 0.55, 0.95 * fade))
	var face := Rect2(body.position, Vector2(width, height - CAP_LIP * k))
	on.draw_colored_polygon(rounded(face, CAP_RADIUS * k), Color(0.93, 0.95, 0.98, 0.98 * fade))
	on.draw_line(face.position + Vector2(CAP_RADIUS * k, 1.0),
		Vector2(face.end.x - CAP_RADIUS * k, face.position.y + 1.0),
		Color(1, 1, 1, 0.85 * fade), 1.0)
	var glyph_size: int = int(round(float(CAP_GLYPH) * k))
	var glyph_w: float = width_of(label, glyph_size)
	on.draw_string(UIFont.FONT, Vector2(face.get_center().x - glyph_w * 0.5,
		baseline_for(face.get_center().y, glyph_size)), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
		glyph_size, Color(0.13, 0.16, 0.24, fade))
	return width
