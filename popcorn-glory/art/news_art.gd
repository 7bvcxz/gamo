class_name PopNewsArt
extends RefCounted
## Step 37: the news's pictures -- an original folded paper, each event's subject (a flavor's
## bag, the big bag, a festival's clapperboard and its crowd, an ingredient on sale), the effect
## as a number beside what it multiplies, and the time left as a ring. Pictures first: the only
## words are numbers.

const PAPER := Color(0.99, 0.97, 0.92)
const PAPER_EDGE := Color(0.36, 0.3, 0.26)
const MAST := Color(0.86, 0.25, 0.22)


## The folded paper (the icon and the card's masthead): `live` in colour, otherwise grey.
static func paper(ci: CanvasItem, c: Vector2, s: float, live: bool) -> void:
	var ink := PAPER_EDGE if live else Color(PAPER_EDGE, 0.45)
	var back := Rect2(c + Vector2(-s * 0.42, -s * 0.36), Vector2(s * 0.84, s * 0.7))
	var front := Rect2(c + Vector2(-s * 0.5, -s * 0.3), Vector2(s * 0.84, s * 0.7))
	ci.draw_rect(back, Color(0.9, 0.87, 0.8) if live else Color(0.93, 0.93, 0.93))
	ci.draw_rect(back, ink, false, maxf(1.5, s * 0.04))
	ci.draw_rect(front, PAPER if live else Color(1, 1, 1))
	ci.draw_rect(Rect2(front.position, Vector2(front.size.x, front.size.y * 0.22)), MAST if live else Color(0.7, 0.7, 0.7))
	ci.draw_rect(front, ink, false, maxf(1.5, s * 0.04))
	# a picture box and the column's lines
	var pic := Rect2(front.position + Vector2(front.size.x * 0.1, front.size.y * 0.34), Vector2(front.size.x * 0.34, front.size.y * 0.5))
	ci.draw_rect(pic, Color(1.0, 0.82, 0.36) if live else Color(0.85, 0.85, 0.85))
	for i in 4:
		var y := front.position.y + front.size.y * (0.38 + i * 0.14)
		ci.draw_line(Vector2(front.position.x + front.size.x * 0.52, y), Vector2(front.end.x - front.size.x * 0.1, y), ink, maxf(1.2, s * 0.035))


## The subject of an event (its "SKU"): a flavor's bag, the big bag, the festival, a sale.
static func subject(ci: CanvasItem, c: Vector2, s: float, row: Dictionary, dim: bool = false) -> void:
	var f := String(row.get("flavor", ""))
	match String(row.get("channel", "")):
		"flavor":
			PopFactoryArt.sku_bag(ci, c + Vector2(0, s * 0.45), s * 0.62, f)
			if not dim:
				PopFactoryArt.glint(ci, c + Vector2(s * 0.36, -s * 0.36), s * 0.16, Color(1, 0.95, 0.6))
		"size":   # the big bag beside a small one
			PopFactoryArt.sku_bag(ci, c + Vector2(s * 0.12, s * 0.48), s * 0.62, "plain")
			PopFactoryArt.sku_bag(ci, c + Vector2(-s * 0.36, s * 0.48), s * 0.3, "plain")
		"arrivals":   # a clapperboard and a crowd
			var b := Rect2(c + Vector2(-s * 0.42, -s * 0.18), Vector2(s * 0.6, s * 0.42))
			ci.draw_rect(b, Color(0.2, 0.2, 0.24))
			var top := PackedVector2Array([b.position + Vector2(0, -s * 0.02), b.position + Vector2(b.size.x, -s * 0.14), b.position + Vector2(b.size.x, -s * 0.02 - s * 0.0), b.position + Vector2(0, s * 0.1)])
			ci.draw_colored_polygon(top, Color(0.95, 0.95, 0.95))
			for i in 3:
				var x := b.position.x + b.size.x * (0.15 + i * 0.3)
				ci.draw_line(Vector2(x, b.position.y - s * 0.03), Vector2(x + s * 0.08, b.position.y + s * 0.07), Color(0.2, 0.2, 0.24), maxf(1.5, s * 0.05))
			for i in 2:
				var hc := c + Vector2(s * (0.28 + i * 0.2), s * (0.08 - i * 0.12))
				ci.draw_circle(hc + Vector2(0, s * 0.2), s * 0.11, PopPalette.GOLD if i == 0 else Color(0.56, 0.88, 0.77))
				ci.draw_circle(hc, s * 0.09, Color(0.96, 0.82, 0.68))
		"cost":   # the flavor's popcorn on a price tag with a coin going down
			PopFactoryArt.flavor_popcorn(ci, c + Vector2(-s * 0.14, -s * 0.06), s * 0.42, f)
			var cc := c + Vector2(s * 0.28, s * 0.22)
			PopMachineArt.draw_coin(ci, cc, s * 0.17)
			ci.draw_line(cc + Vector2(s * 0.26, -s * 0.2), cc + Vector2(s * 0.26, s * 0.12), PopTokens.OK, maxf(2.0, s * 0.07))
			ci.draw_colored_polygon(PackedVector2Array([cc + Vector2(s * 0.17, s * 0.06), cc + Vector2(s * 0.35, s * 0.06), cc + Vector2(s * 0.26, s * 0.2)]), PopTokens.OK)


## The effect: what it multiplies (a customer's head, a door's crowd, a coin) and the number,
## e.g. a head and "x2". Returns the width drawn.
static func effect(ci: CanvasItem, font: Font, left: Vector2, fs: float, row: Dictionary, dim: bool = false) -> float:
	var mult := float(row.get("mult", 1.0))
	var ch := String(row.get("channel", ""))
	var x := left.x
	match ch:
		"flavor", "size", "arrivals":   # people: a head (two for arrivals)
			for i in (2 if ch == "arrivals" else 1):
				var hc := Vector2(x + fs * 0.3 + i * fs * 0.32, left.y - fs * 0.15)
				ci.draw_circle(hc + Vector2(0, fs * 0.42), fs * 0.24, Color(PopTokens.SKY, 0.5 if dim else 1.0))
				ci.draw_circle(hc, fs * 0.2, Color(0.96, 0.82, 0.68, 0.5 if dim else 1.0))
			x += fs * (0.95 if ch == "arrivals" else 0.65)
		"cost":
			PopMachineArt.draw_coin(ci, Vector2(x + fs * 0.32, left.y), fs * 0.3)
			x += fs * 0.75
	var txt := "x%s" % _num(mult)
	var tc: Color = PopTokens.OK if ch == "cost" else MAST   # cheaper in green, more people in the paper's red
	ci.draw_string(font, Vector2(x, left.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), Color(tc, 0.5) if dim else tc)
	return x + font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x - left.x


static func _num(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return "%d" % int(roundf(v))
	return ("%.2f" % v).rstrip("0").rstrip(".")


## The time left: a ring that empties, and m:ss under it.
static func timer(ci: CanvasItem, font: Font, c: Vector2, r: float, left_ms: int, ms: int, fs: float) -> void:
	var k := clampf(float(left_ms) / float(maxi(1, ms)), 0.0, 1.0)
	ci.draw_circle(c, r, Color(1, 1, 1))
	ci.draw_arc(c, r, 0, TAU, 32, Color(PopPalette.INK, 0.2), maxf(2.0, r * 0.22))
	if k > 0.0:
		ci.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * k, 32, PopPalette.GOLD, maxf(2.0, r * 0.22))
	ci.draw_line(c, c + Vector2(0, -r * 0.55), PopPalette.INK, maxf(1.5, r * 0.12))
	var a := -PI * 0.5 + TAU * (1.0 - k)
	ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.42, PopPalette.INK, maxf(1.5, r * 0.12))
	var s := int(ceil(left_ms / 1000.0))
	var txt := "%d:%02d" % [s / 60, s % 60]
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
	ci.draw_string(font, Vector2(c.x - w * 0.5, c.y + r + fs * 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), PopPalette.INK)


## A tick: an event that is over.
static func tick(ci: CanvasItem, c: Vector2, s: float, col: Color = PopTokens.OK) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, 0), c + Vector2(-s * 0.1, s * 0.3), c + Vector2(s * 0.45, -s * 0.35)]), col, maxf(2.0, s * 0.18))


## The line icon: a small paper corner with the event's colour, over a machine the news is
## about (a coater of its flavor, the counter for a festival, the fillers for big bags).
static func line_mark(ci: CanvasItem, c: Vector2, s: float, row: Dictionary) -> void:
	var col := MAST
	if String(row.get("flavor", "")) != "":
		col = PopFactoryArt.flavor_look(String(row["flavor"]))["rim"]
	ci.draw_circle(c, s * 0.5, Color(1, 1, 1, 0.95))
	ci.draw_arc(c, s * 0.5, 0, TAU, 20, col, maxf(2.0, s * 0.12))
	var p := Rect2(c + Vector2(-s * 0.26, -s * 0.2), Vector2(s * 0.52, s * 0.4))
	ci.draw_rect(p, PAPER)
	ci.draw_rect(Rect2(p.position, Vector2(p.size.x, p.size.y * 0.3)), col)
	ci.draw_rect(p, PAPER_EDGE, false, maxf(1.0, s * 0.06))
