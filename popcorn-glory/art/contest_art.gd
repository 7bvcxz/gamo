class_name PopContestArt
extends RefCounted
## Step 38: the contests' pictures -- an original trophy cup, bronze/silver/gold medals with
## their marks, each format's subject (a run of perfect pops, a batch leaving the drum,
## customers served, a bag with nothing spilling out, a balanced scale of coins), a
## stopwatch for the length and a lock. Pictures first: the only words are numbers (and the
## short description, shown only when asked).

const TIER_COL := [Color(0.72, 0.72, 0.74), Color(0.80, 0.50, 0.25), Color(0.78, 0.80, 0.84), Color(1.0, 0.78, 0.18)]
const TIER_EDGE := [Color(0.55, 0.55, 0.58), Color(0.55, 0.32, 0.14), Color(0.48, 0.5, 0.56), Color(0.70, 0.48, 0.05)]


## The cup: tier 0 is a grey outline (not won yet), 1-3 bronze, silver, gold.
static func trophy(ci: CanvasItem, c: Vector2, s: float, tier: int, shine: bool = false) -> void:
	tier = clampi(tier, 0, 3)
	var col: Color = TIER_COL[tier] if tier > 0 else Color(1, 1, 1, 0.65)
	var edge: Color = TIER_EDGE[tier]
	var lw := maxf(1.5, s * 0.06)
	# the bowl: a half-ellipse, the handles, the stem and the base
	var bowl := PackedVector2Array()
	for i in 13:
		var a := PI * float(i) / 12.0
		bowl.append(c + Vector2(cos(a) * s * 0.34, -s * 0.28 + sin(a) * s * 0.34))
	ci.draw_arc(c + Vector2(-s * 0.36, -s * 0.12), s * 0.13, PI * 0.5, PI * 1.5, 10, edge, lw)
	ci.draw_arc(c + Vector2(s * 0.36, -s * 0.12), s * 0.13, -PI * 0.5, PI * 0.5, 10, edge, lw)
	ci.draw_colored_polygon(bowl, col)
	var rim := bowl.duplicate()
	rim.append(bowl[0])
	ci.draw_polyline(rim, edge, lw, true)
	var stem := Rect2(c + Vector2(-s * 0.06, s * 0.06), Vector2(s * 0.12, s * 0.16))
	ci.draw_rect(stem, col)
	ci.draw_rect(stem, edge, false, lw * 0.8)
	var base := Rect2(c + Vector2(-s * 0.24, s * 0.22), Vector2(s * 0.48, s * 0.14))
	PopMachineArt._round_rect(ci, base, s * 0.04, col)
	ci.draw_rect(base, edge, false, lw * 0.8)
	if tier > 0:   # a star on the bowl
		PopFactoryArt.star(ci, c + Vector2(0, -s * 0.12), s * 0.11, Color(1, 1, 1, 0.85), edge)
	if shine:
		PopFactoryArt.glint(ci, c + Vector2(s * 0.28, -s * 0.36), s * 0.14, Color(1, 0.97, 0.7))


## A medal of a tier with its mark written on it (e.g. 5, 90, 116).
static func medal(ci: CanvasItem, font: Font, c: Vector2, r: float, tier: int, mark: String, lit: bool = true) -> void:
	var col: Color = TIER_COL[clampi(tier, 0, 3)]
	if not lit:
		col = Color(col, 0.45)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.6), c + Vector2(-r * 0.2, -r * 1.35), c + Vector2(r * 0.05, -r * 0.8)]), Color(PopNewsArt.MAST, 0.85 if lit else 0.35))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.7, -r * 0.6), c + Vector2(r * 0.2, -r * 1.35), c + Vector2(-r * 0.05, -r * 0.8)]), Color(PopTokens.SKY, 0.85 if lit else 0.35))
	ci.draw_circle(c, r, col)
	ci.draw_arc(c, r, 0, TAU, 24, Color(TIER_EDGE[clampi(tier, 0, 3)], 1.0 if lit else 0.5), maxf(1.5, r * 0.14))
	var fs := int(r * (1.05 if mark.length() <= 2 else 0.8))
	var w := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PopPalette.INK, 1.0 if lit else 0.5))


## What a format measures, as a picture (row: a contest card's dictionary).
static func subject(ci: CanvasItem, c: Vector2, s: float, row: Dictionary, dim: bool = false) -> void:
	var a := 0.5 if dim else 1.0
	match String(row.get("kind", "")):
		"streak":   # three popped kernels in a row, each in a gold ring
			for i in 3:
				var p := c + Vector2((i - 1) * s * 0.34, (s * 0.06 if i == 1 else s * 0.14))
				ci.draw_arc(p, s * 0.16, 0, TAU, 20, Color(PopPalette.GOLD, a), maxf(2.0, s * 0.06))
				PopFactoryArt.popcorn(ci, p, s * 0.2)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.24), c + Vector2(s * 0.4, -s * 0.24), Color(PopPalette.GOLD, a), maxf(2.0, s * 0.05))
			for i in 3:
				ci.draw_circle(c + Vector2((i - 1) * s * 0.34, -s * 0.24), s * 0.05, Color(PopPalette.GOLD, a))
		"best_batch":   # the flavor's batch with a star: the best one
			PopFactoryArt.flavor_popcorn(ci, c + Vector2(-s * 0.06, s * 0.06), s * 0.5, String(row.get("flavor", "caramel")))
			PopFactoryArt.star(ci, c + Vector2(s * 0.3, -s * 0.26), s * 0.14, Color(PopPalette.GOLD, a), PopPalette.INK)
		"served":   # customers, each with a bag: served
			for i in 3:
				var hc := c + Vector2((i - 1) * s * 0.3, -s * 0.12 + (i % 2) * s * 0.06)
				ci.draw_circle(hc + Vector2(0, s * 0.2), s * 0.13, Color(PopTokens.SKY if i != 1 else PopPalette.GOLD, a))
				ci.draw_circle(hc, s * 0.1, Color(0.96, 0.82, 0.68, a))
			PopFactoryArt.sku_bag(ci, c + Vector2(s * 0.36, s * 0.44), s * 0.24, "plain")
		"waste":   # a sealed bag, and the one portion that did not fall out (crossed)
			PopFactoryArt.sku_bag(ci, c + Vector2(-s * 0.08, s * 0.42), s * 0.5, "plain")
			var pc := c + Vector2(s * 0.32, s * 0.24)
			PopFactoryArt.popcorn(ci, pc, s * 0.14)
			ci.draw_line(pc + Vector2(-s * 0.13, -s * 0.13), pc + Vector2(s * 0.13, s * 0.13), Color(PopTokens.WARN, a), maxf(2.0, s * 0.06))
			ci.draw_line(pc + Vector2(-s * 0.13, s * 0.13), pc + Vector2(s * 0.13, -s * 0.13), Color(PopTokens.WARN, a), maxf(2.0, s * 0.06))
		"net":   # a level scale: coins in one pan, the machines' keep in the other
			var col := Color(PopPalette.INK, a)
			ci.draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), col, maxf(2.0, s * 0.05))
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.22), c + Vector2(s * 0.4, -s * 0.22), col, maxf(2.0, s * 0.05))
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.32), c + Vector2(s * 0.2, s * 0.32), col, maxf(2.0, s * 0.06))
			for k in [-1, 1]:
				var pan := c + Vector2(k * s * 0.4, s * 0.02)
				ci.draw_line(c + Vector2(k * s * 0.4, -s * 0.22), pan + Vector2(-s * 0.12, 0), col, 1.5)
				ci.draw_line(c + Vector2(k * s * 0.4, -s * 0.22), pan + Vector2(s * 0.12, 0), col, 1.5)
				ci.draw_line(pan + Vector2(-s * 0.15, 0), pan + Vector2(s * 0.15, 0), col, maxf(2.0, s * 0.05))
			PopMachineArt.draw_coin(ci, c + Vector2(-s * 0.4, -s * 0.06), s * 0.1)
			PopMachineArt.draw_coin(ci, c + Vector2(-s * 0.36, -s * 0.15), s * 0.08)
			var gear := c + Vector2(s * 0.4, -s * 0.08)
			ci.draw_circle(gear, s * 0.09, Color(0.55, 0.58, 0.62, a))
			ci.draw_arc(gear, s * 0.12, 0, TAU, 8, Color(0.4, 0.42, 0.46, a), maxf(2.0, s * 0.05))


## The recipes a format counts: a row of small popcorn of each (from the left).
static func recipes(ci: CanvasItem, left: Vector2, s: float, list: Array) -> float:
	var x := left.x
	for r: String in list:
		PopFactoryArt.flavor_popcorn(ci, Vector2(x + s * 0.5, left.y), s * 0.42, r)
		x += s * 0.9
	return x - left.x


## A stopwatch with the length under (m:ss).
static func stopwatch(ci: CanvasItem, font: Font, c: Vector2, r: float, ms: int, fs: float, dim: bool = false) -> float:
	var ink := Color(PopPalette.INK, 0.5 if dim else 1.0)
	ci.draw_circle(c, r, Color(1, 1, 1))
	ci.draw_arc(c, r, 0, TAU, 24, ink, maxf(1.5, r * 0.16))
	ci.draw_rect(Rect2(c + Vector2(-r * 0.22, -r * 1.45), Vector2(r * 0.44, r * 0.3)), ink)
	ci.draw_line(c, c + Vector2(r * 0.42, -r * 0.42), ink, maxf(1.5, r * 0.14))
	var s := int(ceil(ms / 1000.0))
	var txt := "%d:%02d" % [s / 60, s % 60]
	ci.draw_string(font, Vector2(c.x + r * 1.3, c.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), ink)
	return r * 1.3 + font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x


static func lock(ci: CanvasItem, c: Vector2, s: float) -> void:
	var body := Rect2(c + Vector2(-s * 0.3, -s * 0.05), Vector2(s * 0.6, s * 0.45))
	ci.draw_arc(c + Vector2(0, -s * 0.05), s * 0.2, PI, TAU, 12, Color(PopPalette.INK, 0.6), maxf(2.0, s * 0.08))
	PopMachineArt._round_rect(ci, body, s * 0.06, Color(0.6, 0.6, 0.62))
	ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.06, Color(0.25, 0.25, 0.27))


## The score's bar: 0 .. past gold, the three marks as small medals, the score's marker.
## `lower`: fewer is better (lean packing) -- the bar runs from the bronze mark down to 0.
static func bar(ci: CanvasItem, font: Font, r: Rect2, tiers: Array, score: float, tier: int, lower: bool) -> void:
	var top := float(tiers[2]) * (1.0 if lower else 1.15)
	var lo := 0.0 if not lower else float(tiers[0]) * 1.5
	var pos := func(v: float) -> float:
		var k := clampf(v / maxf(0.001, top), 0.0, 1.0) if not lower else clampf((lo - v) / maxf(0.001, lo), 0.0, 1.0)
		return r.position.x + r.size.x * k
	PopMachineArt._round_rect(ci, r, r.size.y * 0.5, Color(PopPalette.INK, 0.12))
	var fx: float = pos.call(score)
	if fx > r.position.x + 2.0:
		PopMachineArt._round_rect(ci, Rect2(r.position, Vector2(fx - r.position.x, r.size.y)), r.size.y * 0.5, TIER_COL[tier] if tier > 0 else PopTokens.SKY)
	for i in 3:
		var x: float = pos.call(float(tiers[i]))
		ci.draw_line(Vector2(x, r.position.y - r.size.y * 0.3), Vector2(x, r.end.y + r.size.y * 0.3), Color(TIER_EDGE[i + 1], 0.9), 2.0)
		ci.draw_circle(Vector2(x, r.position.y - r.size.y * 0.55), r.size.y * 0.42, TIER_COL[i + 1])
		ci.draw_arc(Vector2(x, r.position.y - r.size.y * 0.55), r.size.y * 0.42, 0, TAU, 12, TIER_EDGE[i + 1], 1.5)
	ci.draw_circle(Vector2(fx, r.get_center().y), r.size.y * 0.7, Color.WHITE)
	ci.draw_arc(Vector2(fx, r.get_center().y), r.size.y * 0.7, 0, TAU, 16, PopPalette.INK, 2.5)
