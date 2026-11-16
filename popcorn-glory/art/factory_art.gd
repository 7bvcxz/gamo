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


## A striped paper bag, bottom-centre anchored at `foot`, `w` wide. Sealed by
## default (a folded top and a gold label: Step 20); `open` while it is being
## filled, with `fill` puffs of popcorn showing at the mouth.
static func bag(ci: CanvasItem, foot: Vector2, w: float, col: Color = PopTokens.MACHINE, open: bool = false, fill: int = 0, of: int = 2) -> void:
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
	else:
		ci.draw_rect(Rect2(p, Vector2(w, w * 0.22)), col)
		ci.draw_circle(p + Vector2(w * 0.5, h * 0.55), w * 0.17, PopPalette.GOLD)
		ci.draw_arc(p + Vector2(w * 0.5, h * 0.55), w * 0.17, 0, TAU, 16, PopTokens.BRASS, 2.0)


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
static func customer(ci: CanvasItem, foot: Vector2, head: float, body: Color, skin: Color) -> void:
	PopMachineArt._round_rect(ci, Rect2(foot - Vector2(head * 1.05, head * 1.8), Vector2(head * 2.1, head * 1.8)), head * 0.8, body)
	ci.draw_circle(foot - Vector2(0, head * 2.6), head, skin)
	ci.draw_arc(foot - Vector2(0, head * 2.6), head, 0, TAU, 24, PopPalette.INK, 3.0)


## A dashed rounded outline (an empty machine slot, blue = automation).
static func dashed_slot(ci: CanvasItem, r: Rect2, col: Color = PopTokens.AUTO) -> void:
	PopMachineArt._round_rect(ci, r, PopTokens.R_MACHINE, Color(1, 1, 1, 0.3))
	var pts := PopMachineArt.round_rect_points(r, PopTokens.R_MACHINE)
	for q in range(0, pts.size(), 2):
		ci.draw_line(pts[q], pts[(q + 1) % pts.size()], col, 4.0)
