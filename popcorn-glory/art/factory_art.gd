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


## A striped paper bag, bottom-centre anchored at `foot`, `w` wide.
static func bag(ci: CanvasItem, foot: Vector2, w: float, col: Color = PopTokens.MACHINE) -> void:
	var h := w * 1.5
	var p := foot - Vector2(w * 0.5, h)
	var pts := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w * 0.88, h), p + Vector2(w * 0.12, h)])
	ci.draw_colored_polygon(pts, Color.WHITE)
	var loop := pts.duplicate()
	loop.append(p)
	ci.draw_polyline(loop, col, PopTokens.LINE_PART)
	ci.draw_line(p + Vector2(w * 0.35, 0), p + Vector2(w * 0.38, h), col, 3.0)
	ci.draw_line(p + Vector2(w * 0.65, 0), p + Vector2(w * 0.62, h), col, 3.0)


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
