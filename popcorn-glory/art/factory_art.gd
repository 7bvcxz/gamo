class_name PopFactoryArt
extends RefCounted

## Step 16: the factory's shapes in direction B (design/ART_DIRECTION.md), all from
## PopTokens. Static drawing helpers: callers draw them once into a layer that
## redraws only when something changes (QUALITY_GATES R-01).

## A rounded rectangle with a vertical gradient (light from above), optionally outlined.
static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color, radius: float, edge: Color = Color.TRANSPARENT, line: float = 0.0) -> void:
	var pts := PopMachineArt.round_rect_points(r, radius)
	var cols := PackedColorArray()
	for p: Vector2 in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	if line > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, edge, line, true)


static func shadow(ci: CanvasItem, r: Rect2, radius: float) -> void:
	PopMachineArt._round_rect(ci, Rect2(r.position + PopTokens.SHADOW_OFFSET, r.size), radius, PopTokens.SHADOW_COLOR)


static func floor_panel(ci: CanvasItem, r: Rect2, cols: Array, selected: bool = false) -> void:
	vgrad(ci, r, cols[0], cols[1], PopTokens.R_FLOOR, PopTokens.FLOOR_EDGE, 4.0)
	if selected:
		var pts := PopMachineArt.round_rect_points(r.grow(-3), PopTokens.R_FLOOR - 3)
		pts.append(pts[0])
		ci.draw_polyline(pts, PopPalette.GOLD, 6.0, true)


static func machine(ci: CanvasItem, r: Rect2, dim: bool = false) -> void:
	shadow(ci, r, PopTokens.R_MACHINE)
	var top := PopTokens.MACHINE
	var bottom := PopTokens.MACHINE_DEEP
	if dim:
		top = top.lerp(PopPalette.DISABLED, 0.7)
		bottom = bottom.lerp(PopPalette.DISABLED, 0.7)
	vgrad(ci, r, top, bottom, PopTokens.R_MACHINE, PopTokens.MACHINE_LINE, PopTokens.LINE_MACHINE)
	PopMachineArt._round_rect(ci, Rect2(r.position + Vector2(r.size.x * 0.08, 6), Vector2(r.size.x * 0.84, 7)), 4, Color(1, 1, 1, 0.45))


static func glass(ci: CanvasItem, r: Rect2, radius: float) -> void:
	vgrad(ci, r, Color(1, 1, 1, 0.85), Color(0.87, 0.96, 1.0, 0.45), radius, PopTokens.STEEL_DEEP, PopTokens.LINE_PART)


static func steel(ci: CanvasItem, r: Rect2, radius: float) -> void:
	vgrad(ci, r, PopTokens.STEEL, PopTokens.STEEL_DEEP, radius, PopTokens.STEEL_DEEP, 2.0)


static func popcorn(ci: CanvasItem, c: Vector2, s: float) -> void:
	for o: Vector2 in [Vector2(-0.5, 0.2), Vector2(0.45, 0.15), Vector2(0, -0.35), Vector2(0.1, 0.45)]:
		ci.draw_circle(c + o * s, s * 0.55, Color(0.85, 0.64, 0.25))
	for o: Vector2 in [Vector2(-0.5, 0.2), Vector2(0.45, 0.15), Vector2(0, -0.35), Vector2(0.1, 0.45)]:
		ci.draw_circle(c + o * s, s * 0.45, PopPalette.CREAM)



# -- Step 34: the five flavors ------------------------------------------------------
## Each flavor's look: the popped kernel (fill, its rim), the coating's mark (dust, sheen,
## ribbon, swirl), the bag's stripes and band. Original shapes and colours (no brand art).
const FLAVOR_LOOK := {
	"plain": {"fill": Color(1.0, 0.965, 0.91), "rim": Color(0.85, 0.64, 0.25), "mark": Color(1.0, 0.86, 0.36), "stripe": Color(0.91, 0.27, 0.23), "band": Color(0.91, 0.27, 0.23)},
	"cheese": {"fill": Color(1.0, 0.72, 0.22), "rim": Color(0.86, 0.47, 0.08), "mark": Color(0.93, 0.5, 0.06), "stripe": Color(1.0, 0.6, 0.1), "band": Color(1.0, 0.82, 0.2)},
	"spicy": {"fill": Color(0.98, 0.45, 0.25), "rim": Color(0.72, 0.13, 0.1), "mark": Color(0.6, 0.06, 0.06), "stripe": Color(0.85, 0.13, 0.12), "band": Color(0.3, 0.12, 0.12)},
	"caramel": {"fill": Color(0.9, 0.6, 0.24), "rim": Color(0.6, 0.33, 0.08), "mark": Color(1.0, 0.9, 0.62), "stripe": Color(0.78, 0.45, 0.12), "band": Color(0.96, 0.74, 0.3)},
	"cocoa": {"fill": Color(0.52, 0.32, 0.2), "rim": Color(0.3, 0.17, 0.1), "mark": Color(0.98, 0.9, 0.78), "stripe": Color(0.4, 0.23, 0.14), "band": Color(0.98, 0.9, 0.78)},
}


static func flavor_look(recipe: String) -> Dictionary:
	return FLAVOR_LOOK.get(recipe, FLAVOR_LOOK["plain"])


## A popped kernel of a flavor at `c` (`s` its size): butter's sheen, cheese's dust, spicy's
## red flecks and a spark, caramel's glossy coat and drip, cocoa's cream swirl.
static func flavor_popcorn(ci: CanvasItem, c: Vector2, s: float, recipe: String) -> void:
	var k := flavor_look(recipe)
	var puffs := [Vector2(-0.5, 0.2), Vector2(0.45, 0.15), Vector2(0, -0.35), Vector2(0.1, 0.45)]
	for o: Vector2 in puffs:
		ci.draw_circle(c + o * s, s * 0.55, k["rim"])
	for o: Vector2 in puffs:
		ci.draw_circle(c + o * s, s * 0.45, k["fill"])
	if s < 9.0:
		# Small (the bin's portions, a cup's top): one mark -- specks under a pixel are not seen
		# and each is a draw call (Step 34: the goods layer went 80 -> 229 calls with them).
		ci.draw_circle(c + Vector2(0.1, -0.1) * s, maxf(1.0, s * 0.16), k["mark"])
		return
	match recipe:
		"cheese":   # orange dust
			for o: Vector2 in [Vector2(-0.55, 0.1), Vector2(0.3, 0.3), Vector2(0.1, -0.45), Vector2(-0.15, 0.55), Vector2(0.6, 0.0)]:
				ci.draw_circle(c + o * s, maxf(0.8, s * 0.09), k["mark"])
		"spicy":   # dark red flecks and one bright spark
			for o: Vector2 in [Vector2(-0.4, 0.25), Vector2(0.4, 0.05), Vector2(0.05, -0.3), Vector2(0.2, 0.55)]:
				ci.draw_circle(c + o * s, maxf(0.8, s * 0.08), k["mark"])
			var sp := c + Vector2(0.55, -0.55) * s
			ci.draw_line(sp + Vector2(-s * 0.22, 0), sp + Vector2(s * 0.22, 0), Color(1.0, 0.9, 0.35), maxf(1.0, s * 0.08))
			ci.draw_line(sp + Vector2(0, -s * 0.22), sp + Vector2(0, s * 0.22), Color(1.0, 0.9, 0.35), maxf(1.0, s * 0.08))
		"caramel":   # a glossy highlight and a drip
			ci.draw_circle(c + Vector2(-0.15, -0.45) * s, s * 0.14, Color(1, 1, 1, 0.75))
			ci.draw_circle(c + Vector2(0.45, 0.62) * s, s * 0.16, k["rim"])
		"cocoa":   # a cream swirl across the top
			ci.draw_arc(c + Vector2(0, -0.1) * s, s * 0.35, PI * 1.1, PI * 2.2, 8, k["mark"], maxf(1.0, s * 0.12))
		_:   # butter: a sheen
			ci.draw_circle(c + Vector2(-0.2, -0.45) * s, s * 0.13, Color(1, 1, 1, 0.8))
			ci.draw_circle(c + Vector2(0.35, 0.05) * s, s * 0.1, k["mark"])


## Step 35: the mixed bag -- its two parts, half and half.
const MIX_PARTS := {"duo": ["caramel", "cheese"]}


## A sealed bag of an SKU: plain, premium and bargain as before; a flavor has its own
## stripes, band and mark (a cheese wedge, a chili, a caramel drip, a cocoa swirl).
## Step 35: a sealed flavor bag shows its crimped seal; `hand` adds the hand's gold seal
## (a finish of quality 95+); a mix ("duo") is two-tone, a part each side.
static func sku_bag(ci: CanvasItem, foot: Vector2, w: float, recipe: String, open: bool = false, fill: int = 0, of: int = 2, hand: bool = false) -> void:
	if MIX_PARTS.has(recipe) and not open:
		_mix_bag(ci, foot, w, MIX_PARTS[recipe], hand)
		return
	if not FLAVOR_LOOK.has(recipe) or recipe == "plain" or open:
		bag(ci, foot, w, PopTokens.STEEL_DEEP if recipe == "bargain" else PopTokens.MACHINE, open, fill, of, recipe == "premium", recipe == "bargain")
		if open and FLAVOR_LOOK.has(recipe) and recipe != "plain" and fill > 0:
			flavor_popcorn(ci, foot - Vector2(0, w * 1.5 + w * 0.02), w * 0.2, recipe)
		return
	var k := flavor_look(recipe)
	var h := w * 1.5
	var p := foot - Vector2(w * 0.5, h)
	var pts := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w * 0.88, h), p + Vector2(w * 0.12, h)])
	ci.draw_colored_polygon(pts, Color.WHITE)
	ci.draw_line(p + Vector2(w * 0.3, 0), p + Vector2(w * 0.33, h), k["stripe"], maxf(2.0, w * 0.1))
	ci.draw_line(p + Vector2(w * 0.7, 0), p + Vector2(w * 0.67, h), k["stripe"], maxf(2.0, w * 0.1))
	ci.draw_rect(Rect2(p, Vector2(w, w * 0.26)), k["band"])
	var loop := pts.duplicate()
	loop.append(p)
	ci.draw_polyline(loop, k["rim"], PopTokens.LINE_PART)
	var m := p + Vector2(w * 0.5, h * 0.58)
	var r := w * 0.22
	match recipe:
		"cheese":   # a wedge with holes
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-r, r * 0.7), m + Vector2(r, r * 0.7), m + Vector2(r, -r * 0.5)]), Color(1.0, 0.85, 0.25))
			ci.draw_polyline(PackedVector2Array([m + Vector2(-r, r * 0.7), m + Vector2(r, r * 0.7), m + Vector2(r, -r * 0.5), m + Vector2(-r, r * 0.7)]), k["rim"], maxf(1.0, w * 0.04))
			ci.draw_circle(m + Vector2(r * 0.45, r * 0.25), r * 0.18, k["rim"])
			ci.draw_circle(m + Vector2(-r * 0.1, r * 0.45), r * 0.13, k["rim"])
		"spicy":   # a chili
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-r * 0.9, -r * 0.5), m + Vector2(r * 0.4, -r * 0.6), m + Vector2(r * 0.9, r * 0.8), m + Vector2(0, r * 0.1)]), Color(0.88, 0.12, 0.1))
			ci.draw_line(m + Vector2(-r * 0.9, -r * 0.5), m + Vector2(-r * 1.1, -r * 0.95), Color(0.25, 0.6, 0.2), maxf(1.5, w * 0.06))
		"caramel":   # drips under the band
			for q in 3:
				var x := p.x + w * (0.22 + 0.28 * q)
				ci.draw_line(Vector2(x, p.y + w * 0.26), Vector2(x, p.y + w * (0.4 + 0.1 * float(q % 2))), k["band"], maxf(2.0, w * 0.09))
				ci.draw_circle(Vector2(x, p.y + w * (0.4 + 0.1 * float(q % 2))), maxf(1.2, w * 0.05), k["band"])
			flavor_popcorn(ci, m, w * 0.16, recipe)
		"cocoa":   # a swirl
			ci.draw_arc(m, r * 0.8, 0, PI * 1.6, 12, k["stripe"], maxf(1.5, w * 0.07))
			ci.draw_arc(m, r * 0.4, PI, PI * 2.6, 10, k["stripe"], maxf(1.5, w * 0.07))
	_crimp(ci, p, w, k["rim"])
	if hand:
		hand_seal(ci, p + Vector2(w * 0.86, w * 0.3), maxf(3.0, w * 0.2))


## Step 35: the sealed top -- a zigzag crimp along the band (a bag being filled has none).
static func _crimp(ci: CanvasItem, p: Vector2, w: float, col: Color) -> void:
	if w < 14.0:
		return   # too small to read; the band says sealed
	var zz := PackedVector2Array()
	var n := 6
	for i in n + 1:
		zz.append(p + Vector2(w * float(i) / float(n), (w * 0.05) if i % 2 == 0 else (-w * 0.03)))
	ci.draw_polyline(zz, col, maxf(1.0, w * 0.05))


## Step 35: the hand's seal -- a gold rosette with a white star: this bag was finished by hand.
static func hand_seal(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r * 1.15, PopTokens.BRASS)
	ci.draw_circle(c, r, PopPalette.GOLD)
	star(ci, c, r * 0.62, Color.WHITE, PopTokens.BRASS)


## Step 35: a two-tone mixed bag: the left half is the first part's, the right the second's.
static func _mix_bag(ci: CanvasItem, foot: Vector2, w: float, parts: Array, hand: bool) -> void:
	var a := flavor_look(String(parts[0]))
	var b := flavor_look(String(parts[1]))
	var h := w * 1.5
	var p := foot - Vector2(w * 0.5, h)
	var pts := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w * 0.88, h), p + Vector2(w * 0.12, h)])
	ci.draw_colored_polygon(pts, Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(w * 0.5, 0), p + Vector2(w * 0.5, h), p + Vector2(w * 0.12, h)]), Color(a["fill"], 0.35))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(w * 0.5, 0), p + Vector2(w, 0), p + Vector2(w * 0.88, h), p + Vector2(w * 0.5, h)]), Color(b["fill"], 0.35))
	ci.draw_rect(Rect2(p, Vector2(w * 0.5, w * 0.26)), a["band"])
	ci.draw_rect(Rect2(p + Vector2(w * 0.5, 0), Vector2(w * 0.5, w * 0.26)), b["band"])
	ci.draw_line(p + Vector2(w * 0.5, 0), p + Vector2(w * 0.5, h), PopPalette.INK, maxf(1.0, w * 0.04))
	var loop := pts.duplicate()
	loop.append(p)
	ci.draw_polyline(loop, a["rim"], PopTokens.LINE_PART)
	flavor_popcorn(ci, p + Vector2(w * 0.27, h * 0.6), w * 0.15, String(parts[0]))
	flavor_popcorn(ci, p + Vector2(w * 0.73, h * 0.6), w * 0.15, String(parts[1]))
	_crimp(ci, p, w, a["rim"])
	if hand:
		hand_seal(ci, p + Vector2(w * 0.86, w * 0.3), maxf(3.0, w * 0.2))


## Step 35: the hand's spoon (a ladle with a drop of the flavor), `c` its centre, `s` its size.
static func spoon(ci: CanvasItem, c: Vector2, s: float, recipe: String) -> void:
	var k := flavor_look(recipe)
	ci.draw_line(c + Vector2(s * 0.45, -s * 0.5), c + Vector2(-s * 0.05, s * 0.05), PopPalette.INK, maxf(2.5, s * 0.16))
	ci.draw_circle(c + Vector2(-s * 0.18, s * 0.2), s * 0.32, PopPalette.INK)
	ci.draw_circle(c + Vector2(-s * 0.18, s * 0.2), s * 0.25, Color.WHITE)
	ci.draw_circle(c + Vector2(-s * 0.18, s * 0.2), s * 0.19, k["fill"])
	ci.draw_circle(c + Vector2(-s * 0.18, s * 0.6), s * 0.1, k["fill"])


## Step 35: a gloss glint (a four-point sparkle): what a hand's finish leaves on the goods.
static func glint(ci: CanvasItem, c: Vector2, s: float, col: Color = Color.WHITE) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.22, -s * 0.22), c + Vector2(s, 0), c + Vector2(s * 0.22, s * 0.22),
		c + Vector2(0, s), c + Vector2(-s * 0.22, s * 0.22), c + Vector2(-s, 0), c + Vector2(-s * 0.22, -s * 0.22)]), col)

## A striped paper bag, bottom-centre anchored at `foot`, `w` wide. Sealed by
## default (a folded top and a gold label: Step 20); `open` while it is being
## filled, with `fill` puffs of popcorn showing at the mouth.
static func bag(ci: CanvasItem, foot: Vector2, w: float, col: Color = PopTokens.MACHINE, open: bool = false, fill: int = 0, of: int = 2, premium: bool = false, bargain: bool = false) -> void:
	var h := w * 1.5
	var p := foot - Vector2(w * 0.5, h)
	var pts := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w * 0.88, h), p + Vector2(w * 0.12, h)])
	ci.draw_colored_polygon(pts, Color.WHITE)
	var loop := pts.duplicate()
	loop.append(p)
	ci.draw_polyline(loop, col, PopTokens.LINE_PART)
	ci.draw_line(p + Vector2(w * 0.35, 0), p + Vector2(w * 0.38, h), col, 3.0)
	ci.draw_line(p + Vector2(w * 0.65, 0), p + Vector2(w * 0.62, h), col, 3.0)
	if open:
		ci.draw_rect(Rect2(p + Vector2(2, 1), Vector2(w - 4, w * 0.16)), Color(0.55, 0.42, 0.3, 0.55))
		for k in mini(fill, maxi(1, of)):
			var fx := (float(k) + 0.5) / float(maxi(1, of))
			popcorn(ci, p + Vector2(w * (0.2 + 0.6 * fx), w * 0.02 - w * 0.08 * float(k % 2)), w * 0.2)
	elif bargain:
		# Step 32: the bargain SKU -- grey stripes, a price tag with a slash (cheaper).
		ci.draw_rect(Rect2(p, Vector2(w, w * 0.22)), col)
		var tag := p + Vector2(w * 0.5, h * 0.56)
		ci.draw_colored_polygon(PackedVector2Array([tag + Vector2(-w * 0.2, -w * 0.12), tag + Vector2(w * 0.14, -w * 0.12), tag + Vector2(w * 0.24, 0), tag + Vector2(w * 0.14, w * 0.12), tag + Vector2(-w * 0.2, w * 0.12)]), Color(0.95, 0.95, 0.9))
		ci.draw_line(tag + Vector2(-w * 0.1, w * 0.08), tag + Vector2(w * 0.06, -w * 0.08), PopTokens.WARN, maxf(1.5, w * 0.06))
	elif premium:
		# Step 29: the premium SKU -- a gold top band and a gold star (never mistaken for plain).
		ci.draw_rect(Rect2(p, Vector2(w, w * 0.26)), PopPalette.GOLD)
		ci.draw_line(p + Vector2(0, w * 0.26), p + Vector2(w, w * 0.26), PopTokens.BRASS, 2.0)
		star(ci, p + Vector2(w * 0.5, h * 0.56), w * 0.24, PopPalette.GOLD, PopTokens.BRASS)
	else:
		ci.draw_rect(Rect2(p, Vector2(w, w * 0.22)), col)
		ci.draw_circle(p + Vector2(w * 0.5, h * 0.55), w * 0.17, PopPalette.GOLD)
		ci.draw_arc(p + Vector2(w * 0.5, h * 0.55), w * 0.17, 0, TAU, 16, PopTokens.BRASS, 2.0)


## Step 30: a cup of popcorn (one portion), standing on `foot`.
static func cup(ci: CanvasItem, foot: Vector2, w: float, full: bool = true) -> void:
	var h := w * 1.1
	var pts := PackedVector2Array([foot + Vector2(-w * 0.5, -h), foot + Vector2(w * 0.5, -h), foot + Vector2(w * 0.36, 0), foot + Vector2(-w * 0.36, 0)])
	ci.draw_colored_polygon(pts, Color.WHITE)
	for q in 3:
		var x0 := -w * 0.5 + w * (0.17 + 0.33 * q)
		ci.draw_line(foot + Vector2(x0, -h), foot + Vector2(x0 * 0.72, 0), PopTokens.MACHINE, maxf(1.5, w * 0.1))
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, PopTokens.MACHINE, maxf(1.0, w * 0.06))
	if full:
		for q in 3:
			ci.draw_circle(foot + Vector2((q - 1) * w * 0.25, -h - w * 0.08 - (w * 0.06 if q == 1 else 0.0)), w * 0.17, PopPalette.CREAM)


## A five-pointed star (Step 29: premium).
static func star(ci: CanvasItem, c: Vector2, r: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, edge, maxf(1.0, r * 0.12))


## Step 20: the packing station at a tier's look, in `r` (its body and belt;
## the moving nozzles are drawn by the view's actors at packer_heads()).
## 0 scoop table, 1 bag feeder, 2 twin heads, 3 rotary head, 4 mini conveyor,
## 5 multihead packer. `mono` (alpha > 0) draws it as one-colour silhouette.
static func packer(ci: CanvasItem, r: Rect2, look: int, heads: int, mono: Color = Color(0, 0, 0, 0)) -> void:
	var m := mono.a > 0.0
	var belt := Rect2(Vector2(r.position.x, r.end.y - r.size.y * 0.12), Vector2(r.size.x, r.size.y * 0.12))
	if look == 0:
		# A wooden table and a post with a scoop arm.
		var top := Rect2(Vector2(r.position.x, r.end.y - r.size.y * 0.14), Vector2(r.size.x, r.size.y * 0.14))
		PopMachineArt._round_rect(ci, top, 6, mono if m else Color(0.74, 0.52, 0.34))
		var post := Rect2(Vector2(r.position.x + r.size.x * 0.06, r.position.y + r.size.y * 0.1), Vector2(r.size.x * 0.08, r.size.y * 0.78))
		PopMachineArt._round_rect(ci, post, 4, mono if m else PopTokens.STEEL_DEEP)
		var arm := Rect2(Vector2(post.position.x, r.position.y + r.size.y * 0.1), Vector2(r.size.x * 0.8, r.size.y * 0.07))
		PopMachineArt._round_rect(ci, arm, 4, mono if m else PopTokens.STEEL)
		return
	# A machine body across the top, a belt along the bottom.
	var body := Rect2(Vector2(r.position.x, r.position.y + r.size.y * 0.04), Vector2(r.size.x, r.size.y * 0.4))
	if m:
		PopMachineArt._round_rect(ci, body, PopTokens.R_MACHINE, mono)
		PopMachineArt._round_rect(ci, belt, belt.size.y * 0.5, mono)
	else:
		machine(ci, body)
		steel(ci, belt, belt.size.y * 0.5)
		# Rollers show the belt is a conveyor from tier 4.
		if look >= 4:
			var nr := 7
			for k in nr:
				ci.draw_circle(Vector2(belt.position.x + belt.size.x * (k + 0.5) / nr, belt.get_center().y), belt.size.y * 0.32, PopTokens.STEEL_DEEP)
	match look:
		1:   # a stack of flat bags on the body's left
			for k in 4:
				var b := Rect2(Vector2(r.position.x - r.size.x * 0.12, body.position.y + body.size.y * (0.15 + 0.17 * k)), Vector2(r.size.x * 0.13, body.size.y * 0.13))
				PopMachineArt._round_rect(ci, b, 3, mono if m else Color.WHITE)
		2:   # a pressure gauge
			ci.draw_circle(body.position + Vector2(body.size.x * 0.88, body.size.y * 0.45), body.size.y * 0.2, mono if m else Color.WHITE)
		3:   # the rotary head: a disk on top
			var c := Vector2(body.get_center().x, body.position.y)
			ci.draw_circle(c, body.size.y * 0.42, mono if m else PopTokens.STEEL)
			if not m:
				for k in 6:
					var a := TAU * k / 6.0
					ci.draw_circle(c + Vector2(cos(a), sin(a) * 0.4) * body.size.y * 0.3, body.size.y * 0.07, PopTokens.MACHINE_DEEP)
		5:   # the weigher: a cone of gold buckets on top
			var c := Vector2(body.get_center().x, body.position.y)
			var cone := PackedVector2Array([c + Vector2(-body.size.x * 0.36, 0), c + Vector2(body.size.x * 0.36, 0), c + Vector2(body.size.x * 0.12, -body.size.y * 0.6), c + Vector2(-body.size.x * 0.12, -body.size.y * 0.6)])
			ci.draw_colored_polygon(cone, mono if m else PopTokens.STEEL)
			if not m:
				for k in 6:
					ci.draw_circle(c + Vector2(body.size.x * (-0.3 + 0.12 * k), -body.size.y * 0.1), body.size.y * 0.08, PopPalette.GOLD)
	# One window per head (where its nozzle hangs).
	if not m:
		for i in heads:
			var x := packer_head_x(r, i, heads)
			ci.draw_circle(Vector2(x, body.get_center().y), body.size.y * 0.22, Color(1, 1, 1, 0.75))


static func packer_head_x(r: Rect2, i: int, heads: int) -> float:
	var span := r.size.x * (0.84 if heads > 1 else 0.0)
	return r.get_center().x - span * 0.5 + (span * float(i) / float(heads - 1) if heads > 1 else 0.0) + (r.size.x * 0.06 if heads == 1 else 0.0)


## A nozzle (tier >= 1) or the scoop (tier 0), its tip at the origin.
static func nozzle(ci: CanvasItem, w: float, scoop: bool, at: Vector2 = Vector2.ZERO) -> void:
	if scoop:
		ci.draw_line(at + Vector2(0, -w * 1.6), at + Vector2(0, -w * 0.5), PopTokens.STEEL_DEEP, w * 0.18)
		ci.draw_arc(at + Vector2(0, -w * 0.3), w * 0.42, 0.0, PI, 12, PopTokens.STEEL_DEEP, w * 0.2)
		return
	var cone := PackedVector2Array([at + Vector2(-w * 0.32, -w * 1.1), at + Vector2(w * 0.32, -w * 1.1), at + Vector2(w * 0.12, -w * 0.15), at + Vector2(-w * 0.12, -w * 0.15)])
	ci.draw_colored_polygon(cone, PopTokens.STEEL)
	ci.draw_polyline(PackedVector2Array([cone[0], cone[1], cone[2], cone[3], cone[0]]), PopTokens.STEEL_DEEP, 2.0)
	ci.draw_rect(Rect2(at + Vector2(-w * 0.42, -w * 0.18), Vector2(w * 0.84, w * 0.18)), PopTokens.MACHINE_DEEP)


## A striped awning across `r` (top edge).
static func awning(ci: CanvasItem, r: Rect2, stripes: int = 10) -> void:
	var w := r.size.x / float(stripes)
	for i in stripes:
		ci.draw_rect(Rect2(r.position + Vector2(w * i, 0), Vector2(w, r.size.y)), PopTokens.MACHINE if i % 2 == 0 else Color.WHITE)
		ci.draw_circle(r.position + Vector2(w * (i + 0.5), r.size.y), minf(w * 0.5, r.size.y * 0.55), PopTokens.MACHINE if i % 2 == 0 else Color.WHITE)


## A customer, bottom-centre anchored at `foot`, height ~ 2.6 x head radius.
## Step 21: a face by `mood` -- "wait" (calm), "impatient" (flat mouth, a sweat
## drop), "happy" (a smile, rosy cheeks), "sad" (a frown) -- read without words.
static func customer(ci: CanvasItem, foot: Vector2, head: float, body: Color, skin: Color, mood: String = "wait") -> void:
	PopMachineArt._round_rect(ci, Rect2(foot - Vector2(head * 1.05, head * 1.8), Vector2(head * 2.1, head * 1.8)), head * 0.8, body)
	var c := foot - Vector2(0, head * 2.6)
	ci.draw_circle(c, head, skin)
	ci.draw_arc(c, head, 0, TAU, 24, PopPalette.INK, 3.0)
	var ink := PopPalette.INK
	var e := head * 0.13
	ci.draw_circle(c + Vector2(-head * 0.36, -head * 0.12), e, ink)
	ci.draw_circle(c + Vector2(head * 0.36, -head * 0.12), e, ink)
	var m := c + Vector2(0, head * 0.38)
	match mood:
		"happy":
			ci.draw_arc(m + Vector2(0, -head * 0.18), head * 0.38, 0.25, PI - 0.25, 10, ink, 2.5)
			ci.draw_circle(c + Vector2(-head * 0.6, head * 0.22), head * 0.16, Color(1.0, 0.55, 0.55, 0.6))
			ci.draw_circle(c + Vector2(head * 0.6, head * 0.22), head * 0.16, Color(1.0, 0.55, 0.55, 0.6))
		"sad":
			ci.draw_arc(m + Vector2(0, head * 0.22), head * 0.3, PI + 0.4, TAU - 0.4, 10, ink, 2.5)
		"impatient":
			ci.draw_line(m + Vector2(-head * 0.26, 0), m + Vector2(head * 0.26, 0), ink, 2.5)
			var d := c + Vector2(head * 0.95, -head * 0.55)
			ci.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -head * 0.3), d + Vector2(head * 0.16, 0), d + Vector2(0, head * 0.12), d + Vector2(-head * 0.16, 0)]), PopTokens.SKY)
		_:
			ci.draw_arc(m + Vector2(0, -head * 0.1), head * 0.22, 0.4, PI - 0.4, 8, ink, 2.5)


## Step 21: the shop's bell (it swings when the next customer is about to come in).
static func bell(ci: CanvasItem, s: float) -> void:
	ci.draw_line(Vector2.ZERO, Vector2(0, s * 0.4), PopTokens.STEEL_DEEP, 2.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.45, s * 1.25), Vector2(s * 0.45, s * 1.25), Vector2(s * 0.3, s * 0.55), Vector2(0, s * 0.4), Vector2(-s * 0.3, s * 0.55)]), PopTokens.BRASS)
	ci.draw_circle(Vector2(0, s * 1.3), s * 0.13, PopTokens.STEEL_DEEP)


## A dashed rounded outline (an empty machine slot, blue = automation).
static func dashed_slot(ci: CanvasItem, r: Rect2, col: Color = PopTokens.AUTO) -> void:
	PopMachineArt._round_rect(ci, r, PopTokens.R_MACHINE, Color(1, 1, 1, 0.3))
	var pts := PopMachineArt.round_rect_points(r, PopTokens.R_MACHINE)
	for q in range(0, pts.size(), 2):
		ci.draw_line(pts[q], pts[(q + 1) % pts.size()], col, 4.0)


## Step 22: the shop's sign at a tier, in `r` -- 0 a chalkboard, 1 with a lamp,
## 2 a lit marquee, 3 a bigger marquee, 4 a neon popcorn, 5 neon with a frame
## of bulbs, 6 a landmark with a star. `mono` (alpha > 0) is a silhouette.
static func shop_sign(ci: CanvasItem, r: Rect2, look: int, mono: Color = Color(0, 0, 0, 0)) -> void:
	var m := mono.a > 0.0
	var board := Color(0.24, 0.27, 0.25) if look < 2 else (Color(0.35, 0.1, 0.16) if look < 4 else Color(0.14, 0.12, 0.22))
	PopMachineArt._round_rect(ci, r, PopTokens.R_PART, mono if m else board)
	if m:
		return
	if look == 1:   # a lamp over the board
		ci.draw_line(r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x * 0.5, -r.size.y * 0.16), PopTokens.STEEL_DEEP, 3.0)
		ci.draw_circle(r.position + Vector2(r.size.x * 0.5, -r.size.y * 0.18), r.size.y * 0.08, PopPalette.GOLD)
	if look >= 2:   # bulbs along the top (and all round from 5)
		var n := 6 if look < 3 else 9
		for q in n:
			ci.draw_circle(Vector2(r.position.x + r.size.x * (q + 0.5) / n, r.position.y + 5), maxf(3.0, r.size.y * 0.05), PopTokens.BRASS)
		if look >= 5:
			for q in n:
				ci.draw_circle(Vector2(r.position.x + r.size.x * (q + 0.5) / n, r.end.y - 5), maxf(3.0, r.size.y * 0.05), PopTokens.BRASS)
	if look >= 4:   # a neon outline
		var pts := PopMachineArt.round_rect_points(r.grow(-6), PopTokens.R_PART)
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(1.0, 0.45, 0.7), 3.0, true)
	if look >= 6:   # the landmark's star on top
		ci.draw_colored_polygon(PopMachineArt._star(r.position + Vector2(r.size.x * 0.5, -r.size.y * 0.12), r.size.y * 0.22, r.size.y * 0.1), PopPalette.GOLD)


## Step 23: what a customer wants, in a bubble over their head -- a small bag,
## or a bigger bag with a fuller top for the large one (no words, no numbers).
static func order_bubble(ci: CanvasItem, tail: Vector2, head: float, size: int, premium: bool = false, bargain: bool = false, recipe: String = "") -> void:
	var w := head * 1.5
	var h := head * 1.35
	var r := Rect2(tail - Vector2(w * 0.5, h + head * 0.25), Vector2(w, h))
	PopMachineArt._round_rect(ci, r, head * 0.35, Color(1, 1, 1, 0.95))
	ci.draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(-head * 0.2, -head * 0.3), tail + Vector2(head * 0.2, -head * 0.3)]), Color(1, 1, 1, 0.95))
	var big := size > 2
	var bw := head * (0.62 if big else 0.42)
	var fl := recipe != "" and (FLAVOR_LOOK.has(recipe) or MIX_PARTS.has(recipe)) and recipe != "plain"
	if size == 1:   # Step 30: a cup
		cup(ci, Vector2(r.get_center().x, r.end.y - head * 0.16), head * 0.5)
		if fl:   # Step 34: a flavored cup shows its kernels on top
			flavor_popcorn(ci, Vector2(r.get_center().x, r.end.y - head * 0.16 - head * 0.6), head * 0.16, recipe)
		return
	if fl:
		sku_bag(ci, Vector2(r.get_center().x, r.end.y - head * 0.14), bw, recipe)
	else:
		bag(ci, Vector2(r.get_center().x, r.end.y - head * 0.14), bw, PopTokens.STEEL_DEEP if bargain else PopTokens.MACHINE, false, 0, 2, premium, bargain)
	if big:
		if MIX_PARTS.has(recipe):   # Step 35: a mix shows both kernels
			flavor_popcorn(ci, Vector2(r.get_center().x - bw * 0.25, r.end.y - head * 0.14 - bw * 1.55), bw * 0.22, String(MIX_PARTS[recipe][0]))
			flavor_popcorn(ci, Vector2(r.get_center().x + bw * 0.25, r.end.y - head * 0.14 - bw * 1.55), bw * 0.22, String(MIX_PARTS[recipe][1]))
		elif fl:
			flavor_popcorn(ci, Vector2(r.get_center().x, r.end.y - head * 0.14 - bw * 1.55), bw * 0.28, recipe)
		else:
			popcorn(ci, Vector2(r.get_center().x, r.end.y - head * 0.14 - bw * 1.55), bw * 0.28)


## Step 26: the three machines, in a slot `r` (bottom-centre on the slot's floor).
## `mono` (alpha > 0) draws the silhouette (a ghost in an empty slot, the card).
static func machine_icon(ci: CanvasItem, r: Rect2, type: String, tier: int, mono: Color = Color(0, 0, 0, 0)) -> void:
	var m := mono.a > 0.0
	var c := r.get_center()
	match type:
		"cooker":   # a small kettle on legs
			var body := Rect2(Vector2(c.x - r.size.x * 0.32, r.position.y + r.size.y * 0.22), Vector2(r.size.x * 0.64, r.size.y * 0.5))
			PopMachineArt._round_rect(ci, Rect2(body.position - Vector2(4, r.size.y * 0.1), Vector2(body.size.x + 8, r.size.y * 0.12)), 4, mono if m else PopTokens.MACHINE)
			PopMachineArt._round_rect(ci, body, 6, mono if m else Color(0.9, 0.96, 1.0, 0.95))
			if not m:
				popcorn(ci, body.get_center() + Vector2(0, body.size.y * 0.15), body.size.x * 0.14)
			PopMachineArt._round_rect(ci, Rect2(Vector2(body.position.x, body.end.y), Vector2(body.size.x, r.size.y * 0.14)), 4, mono if m else PopTokens.MACHINE_DEEP)
		"bagger":   # a box with a nozzle over a bag
			var body := Rect2(Vector2(c.x - r.size.x * 0.34, r.position.y + r.size.y * 0.12), Vector2(r.size.x * 0.68, r.size.y * 0.38))
			PopMachineArt._round_rect(ci, body, 6, mono if m else PopTokens.MACHINE)
			if not m:
				nozzle(ci, r.size.x * 0.22, false, Vector2(c.x, body.end.y + r.size.y * 0.12))
				bag(ci, Vector2(c.x, r.end.y - 2), r.size.x * 0.24)
			else:
				ci.draw_rect(Rect2(Vector2(c.x - r.size.x * 0.12, body.end.y), Vector2(r.size.x * 0.24, r.size.y * 0.42)), mono)
		"kiosk":   # a tall box with a screen and a bag slot
			var body := Rect2(Vector2(c.x - r.size.x * 0.3, r.position.y + r.size.y * 0.06), Vector2(r.size.x * 0.6, r.size.y * 0.92))
			PopMachineArt._round_rect(ci, body, 8, mono if m else PopTokens.MACHINE)
			if not m:
				PopMachineArt._round_rect(ci, Rect2(body.position + Vector2(body.size.x * 0.14, body.size.y * 0.1), Vector2(body.size.x * 0.72, body.size.y * 0.3)), 4, Color(0.75, 0.92, 1.0))
				ci.draw_rect(Rect2(body.position + Vector2(body.size.x * 0.25, body.size.y * 0.62), Vector2(body.size.x * 0.5, body.size.y * 0.1)), PopTokens.MACHINE_DEEP)
	if not m:
		for k in tier:   # a gold dot per tier
			ci.draw_circle(Vector2(r.position.x + 8 + k * 11, r.position.y + 8), 4.0, PopPalette.GOLD)


## A machine's state, as a small badge (no words): paused (two bars), unpaid
## (a coin with a slash), blocked (no-entry), starved (a dashed ring), working (green).
static func state_badge(ci: CanvasItem, at: Vector2, s: float, state: String) -> void:
	match state:
		"paused":
			ci.draw_circle(at, s, Color.WHITE)
			ci.draw_rect(Rect2(at + Vector2(-s * 0.45, -s * 0.5), Vector2(s * 0.3, s)), PopPalette.INK)
			ci.draw_rect(Rect2(at + Vector2(s * 0.15, -s * 0.5), Vector2(s * 0.3, s)), PopPalette.INK)
		"unpaid":
			ci.draw_circle(at, s, PopPalette.GOLD)
			ci.draw_line(at + Vector2(-s * 0.7, s * 0.7), at + Vector2(s * 0.7, -s * 0.7), PopTokens.WARN, s * 0.3)
		"blocked":
			ci.draw_circle(at, s, PopTokens.WARN)
			ci.draw_rect(Rect2(at + Vector2(-s * 0.6, -s * 0.15), Vector2(s * 1.2, s * 0.3)), Color.WHITE)
		"starved":
			ci.draw_circle(at, s, Color(1, 1, 1, 0.9))
			for q in 8:
				var a0 := TAU * q / 8.0
				ci.draw_arc(at, s, a0, a0 + TAU / 16.0, 4, PopTokens.SKY, 2.5)
		"run":
			ci.draw_circle(at, s * 0.6, PopTokens.OK)
		"overheat":   # Step 29: too hot -- red with three heat waves
			ci.draw_circle(at, s, PopTokens.WARN)
			for q in 3:
				var x := at.x + (q - 1) * s * 0.45
				ci.draw_polyline(PackedVector2Array([Vector2(x, at.y + s * 0.5), Vector2(x - s * 0.15, at.y + s * 0.15), Vector2(x + s * 0.15, at.y - s * 0.15), Vector2(x, at.y - s * 0.5)]), Color.WHITE, maxf(1.5, s * 0.16))
		"saving":   # Step 32: the maintenance robot stopped it to keep coins for the line
			ci.draw_circle(at, s, PopPalette.GOLD)
			ci.draw_rect(Rect2(at + Vector2(-s * 0.4, -s * 0.45), Vector2(s * 0.25, s * 0.9)), PopPalette.INK)
			ci.draw_rect(Rect2(at + Vector2(s * 0.15, -s * 0.45), Vector2(s * 0.25, s * 0.9)), PopPalette.INK)
		"waiting":   # Step 29: the dispatcher holds it -- white with an hourglass
			ci.draw_circle(at, s, Color(1, 1, 1, 0.92))
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.4, -s * 0.5), at + Vector2(s * 0.4, -s * 0.5), at, ]), PopTokens.SKY)
			ci.draw_colored_polygon(PackedVector2Array([at, at + Vector2(s * 0.4, s * 0.5), at + Vector2(-s * 0.4, s * 0.5)]), PopTokens.SKY)


# -- Step 27: the forty machines' icons, composed from parts -----------------------
## Every machine is a body in its group's colour (manufacturing red, advanced deep
## red, packaging steel, storefront cream and gold, support teal) plus the parts
## that show what it does (data/machines.json `parts`). Same language as the floors.

static func group_colour(group: String) -> Color:
	match group:
		"manufacturing":
			return PopTokens.MACHINE
		"advanced":
			return PopTokens.MACHINE_DEEP
		"packaging":
			return PopTokens.STEEL_DEEP
		"storefront":
			return PopPalette.GOLD.darkened(0.15)
		"support":
			return Color(0.25, 0.62, 0.6)
	return PopTokens.STEEL


static func catalog_icon(ci: CanvasItem, r: Rect2, parts: Array, group: String, mono: Color = Color(0, 0, 0, 0)) -> void:
	var m := mono.a > 0.0
	var body := group_colour(group)
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	var ink := mono if m else PopPalette.INK
	var c := func(col: Color) -> Color: return mono if m else col
	for part: String in parts:
		match part:
			"box":
				vgrad(ci, Rect2(o + Vector2(w * 0.15, h * 0.35), Vector2(w * 0.7, h * 0.55)), c.call(body.lightened(0.15)), c.call(body), 6, c.call(body.darkened(0.3)), 2.0)
			# Step 28: the kitchen devices' own silhouettes (not a box each): one look per job.
			"bin":   # M01: a steel-rimmed hopper bin, a window of kernels, a spout and two legs
				ci.draw_line(o + Vector2(w * 0.3, h * 0.6), o + Vector2(w * 0.24, h * 0.92), c.call(PopTokens.STEEL_DEEP), 3.0)
				ci.draw_line(o + Vector2(w * 0.7, h * 0.6), o + Vector2(w * 0.76, h * 0.92), c.call(PopTokens.STEEL_DEEP), 3.0)
				var bin := PackedVector2Array([o + Vector2(w * 0.14, h * 0.1), o + Vector2(w * 0.86, h * 0.1), o + Vector2(w * 0.64, h * 0.62), o + Vector2(w * 0.36, h * 0.62)])
				ci.draw_colored_polygon(bin, c.call(body))
				ci.draw_polyline(bin + PackedVector2Array([bin[0]]), c.call(body.darkened(0.3)), 2.0)
				ci.draw_rect(Rect2(o + Vector2(w * 0.1, h * 0.06), Vector2(w * 0.8, h * 0.07)), c.call(PopTokens.STEEL))
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.3, h * 0.2), o + Vector2(w * 0.7, h * 0.2), o + Vector2(w * 0.6, h * 0.46), o + Vector2(w * 0.4, h * 0.46)]), c.call(Color(1.0, 0.95, 0.85)))
				for q in 6:
					ci.draw_circle(o + Vector2(w * (0.4 + 0.04 * (q % 3) + (0.02 if q >= 3 else 0.0)), h * (0.38 - 0.06 * (q / 3))), w * 0.04, c.call(Color(0.85, 0.62, 0.25)))
				ci.draw_rect(Rect2(o + Vector2(w * 0.44, h * 0.62), Vector2(w * 0.12, h * 0.12)), c.call(PopTokens.STEEL_DEEP))
			"bottle":   # M02: an upside-down oil bottle over a dosing head, a cup below it
				PopMachineArt._round_rect(ci, Rect2(o + Vector2(w * 0.3, h * 0.04), Vector2(w * 0.4, h * 0.34)), 6, c.call(Color(0.93, 0.7, 0.2)))
				ci.draw_rect(Rect2(o + Vector2(w * 0.36, h * 0.1), Vector2(w * 0.08, h * 0.2)), c.call(Color(1, 1, 1, 0.45)))
				ci.draw_rect(Rect2(o + Vector2(w * 0.44, h * 0.38), Vector2(w * 0.12, h * 0.06)), c.call(PopTokens.STEEL_DEEP))
				vgrad(ci, Rect2(o + Vector2(w * 0.24, h * 0.44), Vector2(w * 0.52, h * 0.16)), c.call(body.lightened(0.15)), c.call(body), 4, c.call(body.darkened(0.3)), 2.0)
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.46, h * 0.6), o + Vector2(w * 0.54, h * 0.6), o + Vector2(w * 0.5, h * 0.66)]), c.call(PopTokens.STEEL_DEEP))
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.32, h * 0.78), o + Vector2(w * 0.68, h * 0.78), o + Vector2(w * 0.62, h * 0.92), o + Vector2(w * 0.38, h * 0.92)]), c.call(PopTokens.STEEL))
			"cabinet":   # M03: a steel control cabinet with a red band
				vgrad(ci, Rect2(o + Vector2(w * 0.2, h * 0.3), Vector2(w * 0.6, h * 0.62)), c.call(PopTokens.STEEL), c.call(PopTokens.STEEL_DEEP), 5, c.call(PopTokens.STEEL_DEEP.darkened(0.3)), 2.0)
				ci.draw_rect(Rect2(o + Vector2(w * 0.2, h * 0.82), Vector2(w * 0.6, h * 0.06)), c.call(body))
				for q in 2:
					ci.draw_circle(o + Vector2(w * (0.34 + 0.32 * q), h * 0.36), w * 0.03, c.call(PopTokens.WARN if q == 0 else Color(0.4, 0.75, 0.45)))
			"motor":   # M04: a finned motor drum lying on its side, a shaft rising into the kettle
				vgrad(ci, Rect2(o + Vector2(w * 0.12, h * 0.42), Vector2(w * 0.76, h * 0.42)), c.call(body.lightened(0.15)), c.call(body.darkened(0.08)), 14, c.call(body.darkened(0.3)), 2.0)
				for q in 5:
					var fx := w * (0.24 + 0.13 * q)
					ci.draw_line(o + Vector2(fx, h * 0.46), o + Vector2(fx, h * 0.8), c.call(body.darkened(0.25)), 2.0)
				ci.draw_rect(Rect2(o + Vector2(w * 0.06, h * 0.52), Vector2(w * 0.08, h * 0.22)), c.call(PopTokens.STEEL_DEEP))
				ci.draw_rect(Rect2(o + Vector2(w * 0.86, h * 0.52), Vector2(w * 0.08, h * 0.22)), c.call(PopTokens.STEEL_DEEP))
			"sensor":   # M05: a round lens housing on a post
				ci.draw_rect(Rect2(o + Vector2(w * 0.46, h * 0.74), Vector2(w * 0.08, h * 0.14)), c.call(PopTokens.STEEL_DEEP))
				ci.draw_rect(Rect2(o + Vector2(w * 0.3, h * 0.88), Vector2(w * 0.4, h * 0.05)), c.call(PopTokens.STEEL_DEEP))
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.6), w * 0.26, c.call(body))
				ci.draw_arc(o + Vector2(w * 0.5, h * 0.6), w * 0.26, 0, TAU, 24, c.call(body.darkened(0.3)), 2.0)
				ci.draw_arc(o + Vector2(w * 0.5, h * 0.6), w * 0.19, 0, TAU, 24, c.call(PopTokens.STEEL), 3.0)
			"tipper":   # M06: a tipping chute on a stand (the arm tips it into the tube)
				ci.draw_rect(Rect2(o + Vector2(w * 0.28, h * 0.62), Vector2(w * 0.08, h * 0.28)), c.call(PopTokens.STEEL_DEEP))
				ci.draw_rect(Rect2(o + Vector2(w * 0.18, h * 0.88), Vector2(w * 0.3, h * 0.05)), c.call(PopTokens.STEEL_DEEP))
				var ch := PackedVector2Array([o + Vector2(w * 0.12, h * 0.5), o + Vector2(w * 0.9, h * 0.68), o + Vector2(w * 0.86, h * 0.8), o + Vector2(w * 0.12, h * 0.66)])
				ci.draw_colored_polygon(ch, c.call(body))
				ci.draw_polyline(ch + PackedVector2Array([ch[0]]), c.call(body.darkened(0.3)), 2.0)
				ci.draw_line(o + Vector2(w * 0.16, h * 0.56), o + Vector2(w * 0.84, h * 0.72), c.call(Color(1, 1, 1, 0.6)), 2.0)
			"cage":   # M08: a round fan cage on a foot
				ci.draw_rect(Rect2(o + Vector2(w * 0.44, h * 0.86), Vector2(w * 0.12, h * 0.06)), c.call(PopTokens.STEEL_DEEP))
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.6), w * 0.3, c.call(body))
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.6), w * 0.24, c.call(body.darkened(0.35)))
				ci.draw_arc(o + Vector2(w * 0.5, h * 0.6), w * 0.3, 0, TAU, 28, c.call(PopTokens.STEEL), 3.0)
				for q in 4:
					var a := TAU * q / 4.0 + 0.4
					ci.draw_line(o + Vector2(w * 0.5, h * 0.6) + Vector2(cos(a), sin(a)) * w * 0.1, o + Vector2(w * 0.5, h * 0.6) + Vector2(cos(a), sin(a)) * w * 0.29, c.call(Color(1, 1, 1, 0.35)), 1.5)
			# Step 29: the advanced kitchen's silhouettes (deep red: the advanced group).
			"sorter":   # M09: a shaker tray on legs over a drawer of re-popped kernels
				for q in 2:
					ci.draw_line(o + Vector2(w * (0.24 + 0.52 * q), h * 0.6), o + Vector2(w * (0.2 + 0.6 * q), h * 0.92), c.call(PopTokens.STEEL_DEEP), 3.0)
				var tray := PackedVector2Array([o + Vector2(w * 0.1, h * 0.36), o + Vector2(w * 0.9, h * 0.46), o + Vector2(w * 0.86, h * 0.62), o + Vector2(w * 0.14, h * 0.54)])
				ci.draw_colored_polygon(tray, c.call(body))
				ci.draw_polyline(tray + PackedVector2Array([tray[0]]), c.call(body.darkened(0.3)), 2.0)
				for q in 5:
					ci.draw_line(o + Vector2(w * (0.2 + 0.13 * q), h * (0.42 + 0.012 * q)), o + Vector2(w * (0.22 + 0.13 * q), h * (0.55 + 0.012 * q)), c.call(Color(1, 1, 1, 0.45)), 1.5)
				vgrad(ci, Rect2(o + Vector2(w * 0.32, h * 0.7), Vector2(w * 0.36, h * 0.14)), c.call(PopTokens.STEEL), c.call(PopTokens.STEEL_DEEP), 3)
			"manifold":   # M10: an upright tank whose pipes branch to two small pots
				vgrad(ci, Rect2(o + Vector2(w * 0.38, h * 0.28), Vector2(w * 0.24, h * 0.5)), c.call(body.lightened(0.15)), c.call(body), 8, c.call(body.darkened(0.3)), 2.0)
				for q in 2:
					var px := w * (0.1 + 0.62 * q)
					PopMachineArt._round_rect(ci, Rect2(o + Vector2(px, h * 0.62), Vector2(w * 0.18, h * 0.22)), 3, c.call(PopTokens.MACHINE))
					ci.draw_rect(Rect2(o + Vector2(px + w * 0.02, h * 0.64), Vector2(w * 0.14, h * 0.06)), c.call(Color(0.9, 0.96, 1.0)))
				ci.draw_rect(Rect2(o + Vector2(w * 0.3, h * 0.86), Vector2(w * 0.4, h * 0.05)), c.call(PopTokens.STEEL_DEEP))
			"scanner":   # M11: a gate over a belt, lots pass under its eye
				ci.draw_rect(Rect2(o + Vector2(w * 0.06, h * 0.82), Vector2(w * 0.88, h * 0.07)), c.call(PopTokens.STEEL))
				for q in 2:
					ci.draw_rect(Rect2(o + Vector2(w * (0.16 + 0.58 * q), h * 0.38), Vector2(w * 0.1, h * 0.46)), c.call(body))
				vgrad(ci, Rect2(o + Vector2(w * 0.14, h * 0.34), Vector2(w * 0.72, h * 0.14)), c.call(body.lightened(0.15)), c.call(body), 4, c.call(body.darkened(0.3)), 2.0)
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.44, h * 0.48), o + Vector2(w * 0.56, h * 0.48), o + Vector2(w * 0.66, h * 0.82), o + Vector2(w * 0.34, h * 0.82)]), c.call(Color(1.0, 0.93, 0.6, 0.45)))
			"mixer":   # M12: a stand mixer: base, column, head over the bowl
				ci.draw_rect(Rect2(o + Vector2(w * 0.14, h * 0.84), Vector2(w * 0.72, h * 0.08)), c.call(body.darkened(0.15)))
				ci.draw_rect(Rect2(o + Vector2(w * 0.7, h * 0.3), Vector2(w * 0.12, h * 0.56)), c.call(body))
				PopMachineArt._round_rect(ci, Rect2(o + Vector2(w * 0.36, h * 0.22), Vector2(w * 0.48, h * 0.16)), 6, c.call(body.lightened(0.1)))
			"tower":   # M13: a tall vent tower with louvres and a cap
				vgrad(ci, Rect2(o + Vector2(w * 0.28, h * 0.2), Vector2(w * 0.44, h * 0.72)), c.call(body.lightened(0.15)), c.call(body), 5, c.call(body.darkened(0.3)), 2.0)
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.22, h * 0.2), o + Vector2(w * 0.5, h * 0.06), o + Vector2(w * 0.78, h * 0.2)]), c.call(PopTokens.STEEL_DEEP))
			"exchanger":   # M14: a squat tank with two pipes to the kettles
				for q in 2:
					ci.draw_rect(Rect2(o + Vector2(w * (0.26 + 0.4 * q), h * 0.2), Vector2(w * 0.08, h * 0.24)), c.call(PopTokens.STEEL_DEEP))
				vgrad(ci, Rect2(o + Vector2(w * 0.12, h * 0.4), Vector2(w * 0.76, h * 0.48)), c.call(body.lightened(0.15)), c.call(body), 12, c.call(body.darkened(0.3)), 2.0)
			"console":   # M15: a sloped control desk with a screen
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.1, h * 0.9), o + Vector2(w * 0.9, h * 0.9), o + Vector2(w * 0.86, h * 0.4), o + Vector2(w * 0.14, h * 0.36)]), c.call(body))
				ci.draw_polyline(PackedVector2Array([o + Vector2(w * 0.1, h * 0.9), o + Vector2(w * 0.14, h * 0.36), o + Vector2(w * 0.86, h * 0.4), o + Vector2(w * 0.9, h * 0.9)]), c.call(body.darkened(0.3)), 2.0)
				for q in 3:
					ci.draw_circle(o + Vector2(w * (0.3 + 0.2 * q), h * 0.8), w * 0.035, c.call([PopTokens.OK, PopPalette.GOLD, PopTokens.WARN][q]))
			"rotary":   # M16: a frame holding the drum, a hopper on top
				for q in 2:
					ci.draw_line(o + Vector2(w * (0.16 + 0.68 * q), h * 0.3), o + Vector2(w * (0.12 + 0.76 * q), h * 0.94), c.call(PopTokens.STEEL_DEEP), 4.0)
				ci.draw_line(o + Vector2(w * 0.16, h * 0.3), o + Vector2(w * 0.84, h * 0.3), c.call(PopTokens.STEEL_DEEP), 4.0)
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.36, h * 0.04), o + Vector2(w * 0.64, h * 0.04), o + Vector2(w * 0.56, h * 0.24), o + Vector2(w * 0.44, h * 0.24)]), c.call(PopTokens.STEEL))
			# Step 30: the packing floor's silhouettes (steel: the packaging group).
			"cupstack":   # P01: a tube of cups over a little fill table, a filled cup on it
				vgrad(ci, Rect2(o + Vector2(w * 0.36, h * 0.04), Vector2(w * 0.28, h * 0.5)), c.call(Color(0.92, 0.95, 0.98)), c.call(Color(0.8, 0.85, 0.9)), 6, c.call(body), 2.0)
				ci.draw_rect(Rect2(o + Vector2(w * 0.16, h * 0.62), Vector2(w * 0.68, h * 0.08)), c.call(body))
				for q in 2:
					ci.draw_rect(Rect2(o + Vector2(w * (0.2 + 0.54 * q), h * 0.7), Vector2(w * 0.06, h * 0.22)), c.call(body.darkened(0.2)))
				cup(ci, o + Vector2(w * 0.5, h * 0.62), w * 0.22, not m)
			"dispenser":   # P02: a magazine of flat bags dropping open bags onto a chute
				vgrad(ci, Rect2(o + Vector2(w * 0.2, h * 0.3), Vector2(w * 0.6, h * 0.42)), c.call(body.lightened(0.2)), c.call(body), 5, c.call(body.darkened(0.3)), 2.0)
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.3, h * 0.72), o + Vector2(w * 0.7, h * 0.72), o + Vector2(w * 0.86, h * 0.92), o + Vector2(w * 0.46, h * 0.92)]), c.call(PopTokens.STEEL))
				if not m:
					bag(ci, o + Vector2(w * 0.5, h * 0.66), w * 0.2, PopTokens.MACHINE, true)
			"weigher":   # P04: a scale -- a pan on a column over a dial
				ci.draw_rect(Rect2(o + Vector2(w * 0.46, h * 0.36), Vector2(w * 0.08, h * 0.34)), c.call(body))
				vgrad(ci, Rect2(o + Vector2(w * 0.18, h * 0.68), Vector2(w * 0.64, h * 0.22)), c.call(body.lightened(0.2)), c.call(body), 5, c.call(body.darkened(0.3)), 2.0)
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.79), w * 0.08, c.call(Color.WHITE))
				ci.draw_line(o + Vector2(w * 0.5, h * 0.79), o + Vector2(w * 0.56, h * 0.74), c.call(PopTokens.WARN), 2.0)
			"sprayer":   # P05: a tank with a nozzle over a turning tray
				vgrad(ci, Rect2(o + Vector2(w * 0.3, h * 0.08), Vector2(w * 0.4, h * 0.34)), c.call(Color(0.95, 0.75, 0.3)), c.call(Color(0.85, 0.6, 0.2)), 8, c.call(body), 2.0)
				ci.draw_rect(Rect2(o + Vector2(w * 0.46, h * 0.42), Vector2(w * 0.08, h * 0.12)), c.call(body))
			"coater":   # P06: a drum with caramel running over it
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.62), w * 0.28, c.call(body))
				ci.draw_arc(o + Vector2(w * 0.5, h * 0.62), w * 0.28, PI * 1.1, PI * 1.9, 12, c.call(Color(0.78, 0.48, 0.18)), 5.0)
			"sealer":   # P07: two jaws on a frame over a belt
				ci.draw_rect(Rect2(o + Vector2(w * 0.14, h * 0.12), Vector2(w * 0.08, h * 0.76)), c.call(body))
				ci.draw_rect(Rect2(o + Vector2(w * 0.78, h * 0.12), Vector2(w * 0.08, h * 0.76)), c.call(body))
				ci.draw_rect(Rect2(o + Vector2(w * 0.14, h * 0.1), Vector2(w * 0.72, h * 0.08)), c.call(body.darkened(0.15)))
				ci.draw_rect(Rect2(o + Vector2(w * 0.06, h * 0.84), Vector2(w * 0.88, h * 0.06)), c.call(PopTokens.STEEL))
			"diverter":   # P08: a belt that forks in two, a gate at the fork
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.4, h * 0.2), o + Vector2(w * 0.6, h * 0.2), o + Vector2(w * 0.6, h * 0.5), o + Vector2(w * 0.4, h * 0.5)]), c.call(PopTokens.STEEL))
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.4, h * 0.5), o + Vector2(w * 0.6, h * 0.5), o + Vector2(w * 0.32, h * 0.9), o + Vector2(w * 0.1, h * 0.9)]), c.call(PopTokens.STEEL))
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.4, h * 0.5), o + Vector2(w * 0.6, h * 0.5), o + Vector2(w * 0.9, h * 0.9), o + Vector2(w * 0.68, h * 0.9)]), c.call(PopPalette.GOLD))
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.5), w * 0.08, c.call(body))
			# Step 31: the storefront's silhouettes (cream and gold: the storefront group).
			"pickup":   # S01: a short inclined belt on legs, a bag riding it
				for q in 2:
					ci.draw_line(o + Vector2(w * (0.2 + 0.56 * q), h * (0.7 - 0.2 * q)), o + Vector2(w * (0.2 + 0.56 * q), h * 0.92), c.call(PopTokens.STEEL_DEEP), 3.0)
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.08, h * 0.66), o + Vector2(w * 0.9, h * 0.42), o + Vector2(w * 0.92, h * 0.52), o + Vector2(w * 0.1, h * 0.76)]), c.call(PopTokens.STEEL))
				for q in 5:
					ci.draw_circle(o + Vector2(w * (0.16 + 0.17 * q), h * (0.71 - 0.049 * q)), w * 0.025, c.call(PopTokens.STEEL_DEEP))
			"printer":   # S02: a ticket printer on a post
				ci.draw_rect(Rect2(o + Vector2(w * 0.46, h * 0.6), Vector2(w * 0.08, h * 0.3)), c.call(PopTokens.STEEL_DEEP))
				vgrad(ci, Rect2(o + Vector2(w * 0.24, h * 0.36), Vector2(w * 0.52, h * 0.26)), c.call(body.lightened(0.2)), c.call(body), 6, c.call(body.darkened(0.3)), 2.0)
				ci.draw_rect(Rect2(o + Vector2(w * 0.3, h * 0.44), Vector2(w * 0.4, h * 0.04)), c.call(PopPalette.INK))
			"cashier":   # S03: a till with a drawer and a coin slot
				vgrad(ci, Rect2(o + Vector2(w * 0.14, h * 0.5), Vector2(w * 0.72, h * 0.4)), c.call(body.lightened(0.2)), c.call(body), 6, c.call(body.darkened(0.3)), 2.0)
				ci.draw_rect(Rect2(o + Vector2(w * 0.2, h * 0.76), Vector2(w * 0.6, h * 0.08)), c.call(body.darkened(0.25)))
				if not m:
					PopMachineArt.draw_coin(ci, o + Vector2(w * 0.7, h * 0.62), w * 0.08)
			"router":   # S04: a pole with a pointing lamp
				ci.draw_rect(Rect2(o + Vector2(w * 0.47, h * 0.3), Vector2(w * 0.06, h * 0.6)), c.call(PopTokens.STEEL_DEEP))
				ci.draw_rect(Rect2(o + Vector2(w * 0.3, h * 0.88), Vector2(w * 0.4, h * 0.05)), c.call(PopTokens.STEEL_DEEP))
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.3), w * 0.16, c.call(body))
			"express":   # S05: a small window booth with its own awning and bell
				vgrad(ci, Rect2(o + Vector2(w * 0.14, h * 0.3), Vector2(w * 0.72, h * 0.6)), c.call(body.lightened(0.25)), c.call(body), 5, c.call(body.darkened(0.3)), 2.0)
				ci.draw_rect(Rect2(o + Vector2(w * 0.26, h * 0.42), Vector2(w * 0.48, h * 0.24)), c.call(Color(0.75, 0.92, 1.0)))
				for q in 4:
					ci.draw_rect(Rect2(o + Vector2(w * (0.1 + 0.2 * q), h * 0.22), Vector2(w * 0.1, h * 0.1)), c.call(PopTokens.WARN if q % 2 == 0 else Color.WHITE))
			"menuboard":   # S06: a dark menu board on two legs, lit lines
				for q in 2:
					ci.draw_line(o + Vector2(w * (0.26 + 0.48 * q), h * 0.6), o + Vector2(w * (0.22 + 0.56 * q), h * 0.92), c.call(PopTokens.STEEL_DEEP), 3.0)
				PopMachineArt._round_rect(ci, Rect2(o + Vector2(w * 0.12, h * 0.16), Vector2(w * 0.76, h * 0.48)), 5, c.call(Color(0.22, 0.24, 0.27)))
				ci.draw_rect(Rect2(o + Vector2(w * 0.12, h * 0.16), Vector2(w * 0.76, h * 0.06)), c.call(body))
				for q in 3:
					ci.draw_line(o + Vector2(w * 0.22, h * (0.32 + 0.1 * q)), o + Vector2(w * (0.6 - 0.08 * q), h * (0.32 + 0.1 * q)), c.call(PopPalette.CREAM), 2.0)
			"servebot":   # S08: a robot on a rail with two arms
				ci.draw_rect(Rect2(o + Vector2(w * 0.04, h * 0.88), Vector2(w * 0.92, h * 0.05)), c.call(PopTokens.STEEL_DEEP))
				PopMachineArt._round_rect(ci, Rect2(o + Vector2(w * 0.32, h * 0.42), Vector2(w * 0.36, h * 0.44)), 6, c.call(body))
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.3), w * 0.13, c.call(Color.WHITE))
				ci.draw_circle(o + Vector2(w * 0.45, h * 0.29), w * 0.025, ink)
				ci.draw_circle(o + Vector2(w * 0.55, h * 0.29), w * 0.025, ink)
				ci.draw_line(o + Vector2(w * 0.32, h * 0.52), o + Vector2(w * 0.12, h * 0.4), c.call(PopTokens.STEEL_DEEP), 3.0)
				ci.draw_line(o + Vector2(w * 0.68, h * 0.52), o + Vector2(w * 0.88, h * 0.4), c.call(PopTokens.STEEL_DEEP), 3.0)
			# Step 32: the support machines' silhouettes (teal: the support group).
			"oiler":   # U02: an oil tank on legs with a long spout
				for q in 2:
					ci.draw_line(o + Vector2(w * (0.3 + 0.36 * q), h * 0.66), o + Vector2(w * (0.26 + 0.44 * q), h * 0.92), c.call(PopTokens.STEEL_DEEP), 3.0)
				vgrad(ci, Rect2(o + Vector2(w * 0.24, h * 0.36), Vector2(w * 0.5, h * 0.32)), c.call(body.lightened(0.2)), c.call(body), 10, c.call(body.darkened(0.3)), 2.0)
				ci.draw_line(o + Vector2(w * 0.74, h * 0.46), o + Vector2(w * 0.9, h * 0.6), c.call(PopTokens.STEEL_DEEP), 3.0)
			"saver":   # U03: a tall cabinet with a charge bar
				vgrad(ci, Rect2(o + Vector2(w * 0.28, h * 0.22), Vector2(w * 0.44, h * 0.7)), c.call(body.lightened(0.2)), c.call(body), 6, c.call(body.darkened(0.3)), 2.0)
				for q in 3:
					ci.draw_rect(Rect2(o + Vector2(w * 0.38, h * (0.72 - 0.12 * q)), Vector2(w * 0.24, h * 0.07)), c.call(PopTokens.OK.lightened(0.2 * q)))
			"desk":   # U05: an inspection desk with a lamp arm
				ci.draw_rect(Rect2(o + Vector2(w * 0.12, h * 0.62), Vector2(w * 0.76, h * 0.08)), c.call(body))
				for q in 2:
					ci.draw_rect(Rect2(o + Vector2(w * (0.16 + 0.62 * q), h * 0.7), Vector2(w * 0.06, h * 0.22)), c.call(body.darkened(0.2)))
				ci.draw_line(o + Vector2(w * 0.24, h * 0.62), o + Vector2(w * 0.3, h * 0.3), c.call(PopTokens.STEEL_DEEP), 3.0)
				ci.draw_circle(o + Vector2(w * 0.36, h * 0.3), w * 0.07, c.call(PopPalette.GOLD))
			"drum":
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.55), w * 0.32, c.call(body))
				ci.draw_arc(o + Vector2(w * 0.5, h * 0.55), w * 0.22, 0, TAU, 20, c.call(Color.WHITE), 3.0)
			"kettle", "kettle_small":
				var k := 1.0 if part == "kettle" else 0.6
				var at := o + Vector2(w * (0.38 if part == "kettle" else 0.75), h * 0.9)
				PopMachineArt._round_rect(ci, Rect2(at - Vector2(w * 0.22 * k, h * 0.62 * k), Vector2(w * 0.44 * k, h * 0.1 * k)), 3, c.call(PopTokens.MACHINE))
				PopMachineArt._round_rect(ci, Rect2(at - Vector2(w * 0.2 * k, h * 0.52 * k), Vector2(w * 0.4 * k, h * 0.3 * k)), 3, c.call(Color(0.9, 0.96, 1.0)))
				PopMachineArt._round_rect(ci, Rect2(at - Vector2(w * 0.22 * k, h * 0.22 * k), Vector2(w * 0.44 * k, h * 0.22 * k)), 3, c.call(PopTokens.MACHINE_DEEP))
			"funnel":
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.25, h * 0.05), o + Vector2(w * 0.75, h * 0.05), o + Vector2(w * 0.56, h * 0.33), o + Vector2(w * 0.44, h * 0.33)]), c.call(PopTokens.STEEL))
			"kernels":
				for q in 4:
					ci.draw_circle(o + Vector2(w * (0.4 + 0.07 * q), h * 0.12), w * 0.04, c.call(Color(0.85, 0.62, 0.25)))
			"drop":
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.24), w * 0.07, c.call(PopPalette.GOLD))
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.45, h * 0.22), o + Vector2(w * 0.55, h * 0.22), o + Vector2(w * 0.5, h * 0.1)]), c.call(PopPalette.GOLD))
			"dial", "thermometer":
				var dc := o + Vector2(w * 0.5, h * 0.6)
				ci.draw_circle(dc, w * 0.15, c.call(Color.WHITE))
				ci.draw_arc(dc, w * 0.15, 0, TAU, 20, ink, 2.0)
				ci.draw_line(dc, dc + Vector2(w * 0.1, -w * 0.06), c.call(PopTokens.WARN), 2.5)
				if part == "thermometer":
					ci.draw_rect(Rect2(o + Vector2(w * 0.47, h * 0.08), Vector2(w * 0.06, h * 0.3)), c.call(PopTokens.WARN))
			"gear":
				var gc := o + Vector2(w * 0.5, h * 0.62)
				for q in 8:
					var a := TAU * q / 8.0
					ci.draw_circle(gc + Vector2(cos(a), sin(a)) * w * 0.16, w * 0.05, c.call(PopTokens.STEEL))
				ci.draw_circle(gc, w * 0.14, c.call(PopTokens.STEEL))
				ci.draw_circle(gc, w * 0.05, c.call(body))
			"shaft":
				ci.draw_rect(Rect2(o + Vector2(w * 0.47, h * 0.05), Vector2(w * 0.06, h * 0.32)), c.call(PopTokens.STEEL_DEEP))
			"eye", "magnifier":
				var ec := o + Vector2(w * 0.5, h * 0.6)
				ci.draw_circle(ec, w * 0.14, c.call(Color.WHITE))
				ci.draw_circle(ec, w * 0.06, ink)
				if part == "magnifier":
					ci.draw_line(ec + Vector2(w * 0.1, h * 0.08), ec + Vector2(w * 0.24, h * 0.2), ink, 3.0)
			"arm":
				ci.draw_line(o + Vector2(w * 0.3, h * 0.4), o + Vector2(w * 0.7, h * 0.12), c.call(PopTokens.STEEL_DEEP), 4.0)
				ci.draw_circle(o + Vector2(w * 0.7, h * 0.12), w * 0.06, c.call(PopTokens.STEEL))
			"fan":
				var fc := o + Vector2(w * 0.5, h * 0.62)
				for q in 3:
					var a := TAU * q / 3.0
					ci.draw_colored_polygon(PackedVector2Array([fc, fc + Vector2(cos(a), sin(a)) * w * 0.2, fc + Vector2(cos(a + 0.6), sin(a + 0.6)) * w * 0.2]), c.call(Color.WHITE))
			"sieve":
				for q in 4:
					ci.draw_line(o + Vector2(w * 0.25, h * (0.12 + 0.06 * q)), o + Vector2(w * 0.75, h * (0.12 + 0.06 * q)), c.call(PopTokens.STEEL_DEEP), 2.0)
			"pipes":
				ci.draw_line(o + Vector2(w * 0.5, h * 0.05), o + Vector2(w * 0.5, h * 0.3), c.call(PopTokens.STEEL), 4.0)
				ci.draw_line(o + Vector2(w * 0.5, h * 0.3), o + Vector2(w * 0.2, h * 0.45), c.call(PopTokens.STEEL), 4.0)
				ci.draw_line(o + Vector2(w * 0.5, h * 0.3), o + Vector2(w * 0.8, h * 0.45), c.call(PopTokens.STEEL), 4.0)
			"split", "arrows_cross":
				ci.draw_line(o + Vector2(w * 0.3, h * 0.12), o + Vector2(w * 0.7, h * 0.32), ink, 3.0)
				ci.draw_line(o + Vector2(w * 0.7, h * 0.12), o + Vector2(w * 0.3, h * 0.32), ink if part == "arrows_cross" else c.call(PopPalette.GOLD), 3.0)
			"whisk", "bowl":
				if part == "bowl":
					ci.draw_arc(o + Vector2(w * 0.5, h * 0.62), w * 0.2, 0, PI, 12, c.call(Color.WHITE), 5.0)
				else:
					ci.draw_line(o + Vector2(w * 0.5, h * 0.05), o + Vector2(w * 0.5, h * 0.5), c.call(PopTokens.STEEL_DEEP), 3.0)
			"vent":
				for q in 3:
					ci.draw_rect(Rect2(o + Vector2(w * 0.3, h * (0.48 + 0.12 * q)), Vector2(w * 0.4, h * 0.05)), c.call(Color(1, 1, 1, 0.85)))
			"coil":
				for q in 4:
					ci.draw_arc(o + Vector2(w * (0.3 + 0.13 * q), h * 0.62), w * 0.07, PI, TAU, 8, c.call(PopTokens.WARN), 3.0)
			"screen", "ticket", "calendar", "board":
				var sr := Rect2(o + Vector2(w * 0.28, h * 0.45), Vector2(w * 0.44, h * 0.25))
				ci.draw_rect(sr, c.call(Color(0.75, 0.92, 1.0) if part != "board" else Color(0.24, 0.27, 0.25)))
				if part == "ticket":
					ci.draw_rect(Rect2(o + Vector2(w * 0.4, h * 0.15), Vector2(w * 0.2, h * 0.28)), c.call(Color.WHITE))
				if part == "calendar":
					ci.draw_rect(Rect2(sr.position, Vector2(sr.size.x, sr.size.y * 0.3)), c.call(PopTokens.WARN))
			"arrows", "gate":
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.35, h * 0.12), o + Vector2(w * 0.65, h * 0.22), o + Vector2(w * 0.35, h * 0.32)]), c.call(PopTokens.OK))
			"chute":
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.75, h * 0.6), o + Vector2(w * 0.95, h * 0.85), o + Vector2(w * 0.85, h * 0.9), o + Vector2(w * 0.68, h * 0.68)]), c.call(PopTokens.STEEL))
			"cups":
				for q in 3:
					ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.38, h * (0.06 + 0.08 * q)), o + Vector2(w * 0.62, h * (0.06 + 0.08 * q)), o + Vector2(w * 0.58, h * (0.16 + 0.08 * q)), o + Vector2(w * 0.42, h * (0.16 + 0.08 * q))]), c.call(Color.WHITE))
			"bags_flat":
				for q in 3:
					ci.draw_rect(Rect2(o + Vector2(w * (0.3 + 0.05 * q), h * (0.08 + 0.06 * q)), Vector2(w * 0.35, h * 0.08)), c.call(Color.WHITE))
			"nozzle":
				if m:
					ci.draw_rect(Rect2(o + Vector2(w * 0.44, h * 0.1), Vector2(w * 0.12, h * 0.25)), mono)
				else:
					nozzle(ci, w * 0.3, false, o + Vector2(w * 0.5, h * 0.36))
			"bag":
				if m:
					ci.draw_rect(Rect2(o + Vector2(w * 0.72, h * 0.62), Vector2(w * 0.2, h * 0.28)), mono)
				else:
					bag(ci, o + Vector2(w * 0.82, h * 0.92), w * 0.2)
			"scale":
				ci.draw_line(o + Vector2(w * 0.25, h * 0.3), o + Vector2(w * 0.75, h * 0.3), ink, 3.0)
				ci.draw_arc(o + Vector2(w * 0.3, h * 0.3), w * 0.1, 0, PI, 8, ink, 2.0)
				ci.draw_arc(o + Vector2(w * 0.7, h * 0.3), w * 0.1, 0, PI, 8, ink, 2.0)
			"spray":
				for q in 5:
					ci.draw_circle(o + Vector2(w * (0.35 + 0.07 * q), h * (0.2 + 0.03 * (q % 2))), w * 0.025, c.call(PopTokens.WARN))
			"drip":
				ci.draw_line(o + Vector2(w * 0.5, h * 0.05), o + Vector2(w * 0.5, h * 0.25), c.call(Color(0.7, 0.42, 0.16)), 5.0)
			"jaws":
				ci.draw_rect(Rect2(o + Vector2(w * 0.25, h * 0.12), Vector2(w * 0.5, h * 0.07)), c.call(PopTokens.WARN))
				ci.draw_rect(Rect2(o + Vector2(w * 0.25, h * 0.25), Vector2(w * 0.5, h * 0.07)), c.call(PopTokens.WARN))
			"belt", "rail":
				vgrad(ci, Rect2(o + Vector2(w * 0.05, h * 0.75), Vector2(w * 0.9, h * 0.12)), c.call(PopTokens.STEEL), c.call(PopTokens.STEEL_DEEP), 4)
			"coin":
				PopMachineArt.draw_coin(ci, o + Vector2(w * 0.5, h * 0.2), w * 0.1)
			"post", "rope":
				if part == "post":
					ci.draw_rect(Rect2(o + Vector2(w * 0.2, h * 0.35), Vector2(w * 0.08, h * 0.55)), c.call(PopPalette.GOLD))
					ci.draw_rect(Rect2(o + Vector2(w * 0.72, h * 0.35), Vector2(w * 0.08, h * 0.55)), c.call(PopPalette.GOLD))
				else:
					ci.draw_arc(o + Vector2(w * 0.5, h * 0.35), w * 0.27, 0.2, PI - 0.2, 10, c.call(PopTokens.WARN), 4.0)
			"window":
				PopMachineArt._round_rect(ci, Rect2(o + Vector2(w * 0.15, h * 0.2), Vector2(w * 0.7, h * 0.7)), 6, c.call(body))
				ci.draw_rect(Rect2(o + Vector2(w * 0.28, h * 0.32), Vector2(w * 0.44, h * 0.3)), c.call(Color(0.75, 0.92, 1.0)))
			"lights":
				for q in 4:
					ci.draw_circle(o + Vector2(w * (0.3 + 0.13 * q), h * 0.4), w * 0.04, c.call(PopTokens.BRASS))
			"kiosk":
				machine_icon(ci, r, "kiosk", 0, mono)
			"robot":
				PopMachineArt._round_rect(ci, Rect2(o + Vector2(w * 0.3, h * 0.35), Vector2(w * 0.4, h * 0.35)), 6, c.call(body))
				ci.draw_circle(o + Vector2(w * 0.5, h * 0.25), w * 0.12, c.call(Color.WHITE))
				ci.draw_circle(o + Vector2(w * 0.46, h * 0.24), w * 0.025, ink)
				ci.draw_circle(o + Vector2(w * 0.54, h * 0.24), w * 0.025, ink)
				ci.draw_circle(o + Vector2(w * 0.38, h * 0.76), w * 0.06, ink)
				ci.draw_circle(o + Vector2(w * 0.62, h * 0.76), w * 0.06, ink)
			"wrench", "oilcan":
				ci.draw_line(o + Vector2(w * 0.65, h * 0.12), o + Vector2(w * 0.85, h * 0.4), c.call(PopTokens.STEEL_DEEP), 4.0)
				if part == "oilcan":
					ci.draw_circle(o + Vector2(w * 0.62, h * 0.12), w * 0.05, c.call(PopPalette.GOLD))
			"leaf":
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.5, h * 0.08), o + Vector2(w * 0.68, h * 0.2), o + Vector2(w * 0.5, h * 0.32), o + Vector2(w * 0.32, h * 0.2)]), c.call(PopTokens.OK))
			"lift", "crate":
				if part == "lift":
					ci.draw_rect(Rect2(o + Vector2(w * 0.15, h * 0.05), Vector2(w * 0.06, h * 0.85)), c.call(PopTokens.STEEL_DEEP))
					ci.draw_rect(Rect2(o + Vector2(w * 0.79, h * 0.05), Vector2(w * 0.06, h * 0.85)), c.call(PopTokens.STEEL_DEEP))
				else:
					PopMachineArt._round_rect(ci, Rect2(o + Vector2(w * 0.28, h * 0.35), Vector2(w * 0.44, h * 0.35)), 3, c.call(Color(0.74, 0.52, 0.34)))
			"bubbles":
				for q in 3:
					ci.draw_arc(o + Vector2(w * (0.65 + 0.08 * q), h * (0.2 - 0.04 * q)), w * 0.05, 0, TAU, 10, c.call(PopTokens.SKY), 2.0)
