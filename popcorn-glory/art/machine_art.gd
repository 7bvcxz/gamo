class_name PopMachineArt
extends RefCounted

## The popcorn machine, drawn from shapes. One function draws every stage, so
## the upgrade button's silhouette of the next machine is the same drawing as
## the machine itself. Stage 0 is a small cart; each stage is visibly bigger,
## and every second stage adds something to the outline (awning, wheels,
## lights, a crown) so two stages are told apart even as a silhouette.
##
## `size` is the machine's height in canvas pixels at stage 4; smaller stages
## are drawn smaller. `squash` (0..1) presses it down for a moment after a pop.

const STAGES := 5


static func height_at(stage: int, size: float) -> float:
	return size * (0.62 + 0.095 * clampi(stage, 0, STAGES - 1))


## `fill` (0..1): how much popcorn is in the glass case.
## A silhouette colour draws the whole machine in that one colour.
## `breathe` (small, +-) stretches it: wider and lower when positive.
## Never uses draw_set_transform: a transform set here would replace the
## caller's (the first version reset it after the shadow and drew the machine
## in the corner of the screen).
static func draw(ci: CanvasItem, base: Vector2, size: float, stage: int, squash: float = 0.0,
		fill: float = 0.3, silhouette: Color = Color(0, 0, 0, 0), breathe: float = 0.0) -> void:
	var st := clampi(stage, 0, STAGES - 1)
	var h := height_at(st, size) * (1.0 - 0.08 * squash) * (1.0 - breathe)
	var w := h * (0.78 + 0.03 * st) * (1.0 + 0.06 * squash) * (1.0 + breathe) / (1.0 - breathe)
	var flat := silhouette.a > 0.0
	var c := func(col: Color) -> Color: return silhouette if flat else col

	# Shadow on the floor.
	if not flat:
		ci.draw_colored_polygon(ellipse(base, Vector2(w * 0.62, w * 0.62 * 0.22), 24), PopPalette.SHADOW)

	var wheel_r := h * 0.07
	var lift := wheel_r * 1.4 if st >= 2 else h * 0.02
	# Body: the red cabinet.
	var body_h := h * 0.36
	var body := Rect2(base.x - w / 2, base.y - lift - body_h, w, body_h)
	if st >= 2:
		for x: float in [body.position.x + w * 0.2, body.end.x - w * 0.2]:
			ci.draw_circle(Vector2(x, base.y - wheel_r), wheel_r, c.call(PopPalette.WHEEL))
			ci.draw_circle(Vector2(x, base.y - wheel_r), wheel_r * 0.45, c.call(PopPalette.CHROME))
	_round_rect(ci, body, h * 0.04, c.call(PopPalette.RED))
	if not flat:
		ci.draw_rect(Rect2(body.position + Vector2(0, body_h * 0.72), Vector2(w, body_h * 0.28)), PopPalette.RED_DARK)
		# The stripe of the cabinet door.
		ci.draw_rect(Rect2(body.position.x + w * 0.12, body.position.y + body_h * 0.18, w * 0.76, body_h * 0.1), PopPalette.CREAM)

	# Glass case with popcorn inside.
	var case_h := h * 0.42
	var case_w := w * 0.88
	var case_r := Rect2(base.x - case_w / 2, body.position.y - case_h, case_w, case_h)
	if flat:
		ci.draw_rect(case_r, silhouette)
	else:
		ci.draw_rect(case_r, PopPalette.GLASS)
		var pile_h := case_h * clampf(fill, 0.08, 0.95)
		var pile := Rect2(case_r.position.x, case_r.end.y - pile_h, case_w, pile_h)
		ci.draw_rect(pile, PopPalette.CREAM)
		var bumps := 7
		for i in bumps:
			var x := pile.position.x + case_w * (float(i) + 0.5) / bumps
			ci.draw_circle(Vector2(x, pile.position.y), case_w / bumps * 0.62, PopPalette.CREAM)
		# The kettle hanging in the case.
		var k := Vector2(base.x, case_r.position.y + case_h * 0.3)
		ci.draw_circle(k, case_w * 0.16, PopPalette.CHROME)
		ci.draw_rect(Rect2(k.x - case_w * 0.02, case_r.position.y, case_w * 0.04, case_h * 0.15), PopPalette.CHROME)
		ci.draw_rect(Rect2(case_r.position, Vector2(case_w * 0.05, case_h)), PopPalette.GLASS_EDGE)
		ci.draw_rect(case_r, PopPalette.RED_DARK, false, maxf(2.0, h * 0.012))

	# Roof.
	var roof_h := h * 0.1
	var roof := Rect2(base.x - w * 0.52, case_r.position.y - roof_h, w * 1.04, roof_h)
	_round_rect(ci, roof, roof_h * 0.3, c.call(PopPalette.RED))
	if st >= 1 and not flat:
		ci.draw_rect(Rect2(roof.position.x, roof.position.y + roof_h * 0.35, roof.size.x, roof_h * 0.3), PopPalette.CREAM)
	# Awning scallops (stage 1+): red and cream teeth under the roof.
	if st >= 1:
		var teeth := 6 + st
		var tw := roof.size.x / teeth
		for i in teeth:
			var x0 := roof.position.x + i * tw
			var pts := PackedVector2Array([Vector2(x0, roof.end.y), Vector2(x0 + tw, roof.end.y), Vector2(x0 + tw / 2, roof.end.y + tw * 0.5)])
			ci.draw_colored_polygon(pts, c.call(PopPalette.CREAM if i % 2 == 1 else PopPalette.RED))
	# Lights along the roof (stage 3+).
	if st >= 3 and not flat:
		var n := 5 + st
		for i in n:
			var x := roof.position.x + roof.size.x * (float(i) + 0.5) / n
			ci.draw_circle(Vector2(x, roof.position.y + roof_h * 0.5), roof_h * 0.16, PopPalette.GOLD)
	# Crown sign (stage 4): a gold star on top.
	if st >= 4:
		var top := Vector2(base.x, roof.position.y - h * 0.08)
		ci.draw_colored_polygon(_star(top, h * 0.085, h * 0.04), c.call(PopPalette.GOLD))
	# Chimney popcorn sign (stage 0..3: a small bucket on the roof).
	if st < 4:
		var b := Rect2(base.x - w * 0.08, roof.position.y - h * 0.09, w * 0.16, h * 0.09)
		ci.draw_rect(b, c.call(PopPalette.CREAM))
		if not flat:
			ci.draw_rect(Rect2(b.position.x + b.size.x * 0.35, b.position.y, b.size.x * 0.3, b.size.y), PopPalette.RED)


## One polygon, not rectangles and circles: overlapping translucent pieces
## showed their seams as brighter circles in the corners.
##
## A sliver (a fill a few pixels high) is a plain rectangle: its rounded
## outline collapses onto itself and the renderer refuses to triangulate it
## ("Invalid polygon data" in the browser console, Step 03).
static func _round_rect(ci: CanvasItem, r: Rect2, radius: float, col: Color) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	if minf(r.size.x, r.size.y) < 6.0 or radius < 1.0:
		ci.draw_rect(r, col)
		return
	ci.draw_colored_polygon(round_rect_points(r, radius), col)


## The outline, without repeated points (where a corner's radius is half the
## side, two arcs meet in the same point).
static func round_rect_points(r: Rect2, radius: float) -> PackedVector2Array:
	var rad := minf(radius, minf(r.size.x, r.size.y) / 2 - 0.5)
	var corners: Array[Vector2] = [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
		r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]
	var pts := PackedVector2Array()
	for i in 4:
		var a0 := PI + i * PI / 2
		for j in 7:
			var a := a0 + j * (PI / 2) / 6
			var p := corners[i] + Vector2(cos(a), sin(a)) * rad
			if pts.is_empty() or pts[pts.size() - 1].distance_squared_to(p) > 0.01:
				pts.append(p)
	if pts.size() > 1 and pts[0].distance_squared_to(pts[pts.size() - 1]) <= 0.01:
		pts.remove_at(pts.size() - 1)
	return pts


static func ellipse(c: Vector2, radii: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


static func _star(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := -PI / 2 + i * PI / 5
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## One popcorn piece: four overlapping puffs.
static func draw_piece(ci: CanvasItem, p: Vector2, r: float, rot: float, col: Color = PopPalette.CREAM) -> void:
	var o := Vector2(r * 0.55, 0).rotated(rot)
	ci.draw_circle(p + o, r * 0.7, col)
	ci.draw_circle(p - o, r * 0.7, col)
	ci.draw_circle(p + o.orthogonal(), r * 0.62, col)
	ci.draw_circle(p, r * 0.35, PopPalette.BUTTER)


static func draw_coin(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_circle(p, r, PopPalette.GOLD)
	ci.draw_circle(p, r * 0.68, Color(1.0, 0.86, 0.38))
	ci.draw_rect(Rect2(p.x - r * 0.12, p.y - r * 0.4, r * 0.24, r * 0.8), PopPalette.GOLD)
