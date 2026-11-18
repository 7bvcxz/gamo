class_name PopIcons
extends RefCounted

## Step 41: one small set of icons for what the factory's numbers are about. Every icon is
## drawn in the same box (`s` across, centred on `c`), with the same ink outline weight, from
## one colour family each -- and each has its own outline, so two icons are told apart by their
## shape alone (a grey screen, colour-blind eyes) and by their colour at a glance. Words stay
## off; a number beside an icon is the only text it needs.
##
##   heat       a flame (red to yellow)            -- the kitchen's heat
##   perfect    a gold star with rays              -- the B Perfect Pop window
##   pop_rate   a popcorn puff with speed lines    -- lots a minute
##   pack_rate  a bag with speed lines             -- packs a minute
##   sales      a coin with speed lines            -- sales a minute
##   stock      three bags on a shelf              -- goods waiting
##   queue      three heads in a row (sky blue)    -- customers waiting
##   upkeep     a coin and a wrench                -- what the machines cost to keep
##   sign_up    the sign board and an up arrow     -- the sign's next tier
##   news       the folded paper (art/news_art.gd) -- the news
##   trophy     the contest cup (art/contest_art.gd) -- contests
##
## The news paper and the trophy are the ones already on their buttons (one drawing for one
## idea); the others are drawn here. `plate` puts the icon on the white disc the floor badges
## and buttons use.

const NAMES := ["heat", "perfect", "pop_rate", "pack_rate", "sales", "stock", "queue", "upkeep", "sign_up", "news", "trophy"]
const INK := PopPalette.INK


static func line_w(s: float) -> float:
	return maxf(1.5, s * 0.08)


static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, plate: bool = false) -> void:
	if plate:
		ci.draw_circle(c, s * 0.62, Color.WHITE)
		ci.draw_arc(c, s * 0.62, 0, TAU, 24, INK, line_w(s) * 0.8)
	var h := s * 0.5
	var lw := line_w(s)
	match name:
		"heat":
			var outer := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.45, -h * 0.35), c + Vector2(h * 0.7, h * 0.25), c + Vector2(h * 0.5, h * 0.8),
				c + Vector2(0, h), c + Vector2(-h * 0.5, h * 0.8), c + Vector2(-h * 0.7, h * 0.25), c + Vector2(-h * 0.35, -h * 0.15), c + Vector2(-h * 0.15, h * 0.05)])
			ci.draw_colored_polygon(outer, PopTokens.WARN)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.15), c + Vector2(h * 0.35, h * 0.45), c + Vector2(0, h * 0.85), c + Vector2(-h * 0.35, h * 0.45)]), PopPalette.GOLD)
			_outline(ci, outer, lw)
		"perfect":
			for q in 8:
				var a := TAU * q / 8.0 + PI / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * h * 0.72, c + Vector2(cos(a), sin(a)) * h, PopTokens.BRASS, lw)
			PopFactoryArt.star(ci, c, h * 0.72, PopPalette.GOLD, INK)
		"pop_rate":
			_speed(ci, c + Vector2(-h * 0.55, 0), h, lw)
			PopFactoryArt.popcorn(ci, c + Vector2(h * 0.25, 0), h * 0.5)
		"pack_rate":
			_speed(ci, c + Vector2(-h * 0.55, 0), h, lw)
			PopFactoryArt.bag(ci, c + Vector2(h * 0.3, h * 0.8), h * 1.05)
		"sales":
			_speed(ci, c + Vector2(-h * 0.55, 0), h, lw)
			PopMachineArt.draw_coin(ci, c + Vector2(h * 0.3, 0), h * 0.55)
		"stock":
			ci.draw_line(c + Vector2(-h, h * 0.85), c + Vector2(h, h * 0.85), INK, lw)
			for q in 3:
				var x := (q - 1) * h * 0.62
				var bh := h * (1.15 if q == 1 else 0.95)
				var r := Rect2(c + Vector2(x - h * 0.27, h * 0.85 - bh), Vector2(h * 0.54, bh))
				ci.draw_rect(r, Color.WHITE)
				ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.25)), PopTokens.MACHINE)
				ci.draw_rect(r, INK, false, maxf(1.0, lw * 0.6))
		"queue":
			for q in 3:
				var p := c + Vector2((q - 1) * h * 0.68, h * 0.2 - (h * 0.12 if q == 1 else 0.0))
				PopMachineArt._round_rect(ci, Rect2(p + Vector2(-h * 0.3, h * 0.1), Vector2(h * 0.6, h * 0.7)), h * 0.25, PopTokens.SKY)
				ci.draw_circle(p - Vector2(0, h * 0.18), h * 0.26, Color(0.96, 0.82, 0.68))
				ci.draw_arc(p - Vector2(0, h * 0.18), h * 0.26, 0, TAU, 12, INK, maxf(1.0, lw * 0.6))
		"upkeep":
			PopMachineArt.draw_coin(ci, c + Vector2(-h * 0.22, h * 0.2), h * 0.62)
			var a := c + Vector2(h * 0.75, -h * 0.75)
			var b := c + Vector2(-h * 0.05, h * 0.05)
			ci.draw_line(a, b, PopTokens.STEEL_DEEP, lw * 1.8)
			ci.draw_circle(a, h * 0.3, PopTokens.STEEL_DEEP)
			ci.draw_circle(a + Vector2(h * 0.1, -h * 0.1), h * 0.14, Color.WHITE)
			ci.draw_line(a, b, INK, maxf(1.0, lw * 0.5))
		"sign_up":
			var board := Rect2(c + Vector2(-h, -h * 0.55), Vector2(h * 1.3, h * 0.95))
			ci.draw_rect(board, PopTokens.MACHINE)
			ci.draw_rect(Rect2(board.position + Vector2(h * 0.15, h * 0.18), Vector2(board.size.x - h * 0.3, h * 0.22)), PopPalette.CREAM)
			ci.draw_rect(board, INK, false, maxf(1.0, lw * 0.7))
			ci.draw_line(Vector2(board.get_center().x, board.end.y), Vector2(board.get_center().x, c.y + h), INK, lw)
			var ar := c + Vector2(h * 0.72, h * 0.1)
			ci.draw_colored_polygon(PackedVector2Array([ar + Vector2(0, -h * 0.6), ar + Vector2(h * 0.32, -h * 0.15), ar + Vector2(h * 0.12, -h * 0.15),
				ar + Vector2(h * 0.12, h * 0.4), ar + Vector2(-h * 0.12, h * 0.4), ar + Vector2(-h * 0.12, -h * 0.15), ar + Vector2(-h * 0.32, -h * 0.15)]), PopTokens.OK)
		"news":
			PopNewsArt.paper(ci, c, s * 0.9, true)
		"trophy":
			PopContestArt.trophy(ci, c, s * 0.95, 3)


static func _speed(ci: CanvasItem, right: Vector2, h: float, lw: float) -> void:
	for q in 3:
		var y := (q - 1) * h * 0.35
		ci.draw_line(right + Vector2(-h * (0.45 + 0.12 * float(q % 2)), y), right + Vector2(0, y), Color(INK, 0.55), maxf(1.0, lw * 0.7))


static func _outline(ci: CanvasItem, pts: PackedVector2Array, lw: float) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, INK, maxf(1.0, lw * 0.7))
