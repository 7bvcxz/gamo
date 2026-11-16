extends PopPlayView

## Step 15's runnable preview (#artboard, not on the chooser): direction B's
## three floors, materials, machine silhouettes, colours and type scale, drawn
## in the engine from PopTokens -- the art direction as the game will draw it,
## not a picture of it. Nothing here plays.

func setup(p_rules: PopRules) -> void:
	super(p_rules)
	machine_node.visible = false


func _process(delta: float) -> void:
	super(delta)
	machine_node.visible = false


func _gui_input(_event: InputEvent) -> void:
	pass


## A rounded rectangle with a vertical gradient (light from above).
func _vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color, radius: float, edge: Color = Color.TRANSPARENT, line: float = 0.0) -> void:
	var pts := PopMachineArt.round_rect_points(r, radius)
	var cols := PackedColorArray()
	for p: Vector2 in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	if line > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, edge, line, true)


func _shadow(ci: CanvasItem, r: Rect2, radius: float) -> void:
	PopMachineArt._round_rect(ci, Rect2(r.position + PopTokens.SHADOW_OFFSET, r.size), radius, PopTokens.SHADOW_COLOR)


func _machine(ci: CanvasItem, r: Rect2) -> void:
	_shadow(ci, r, PopTokens.R_MACHINE)
	_vgrad(ci, r, PopTokens.MACHINE, PopTokens.MACHINE_DEEP, PopTokens.R_MACHINE, PopTokens.MACHINE_LINE, PopTokens.LINE_MACHINE)
	PopMachineArt._round_rect(ci, Rect2(r.position + Vector2(r.size.x * 0.08, 6), Vector2(r.size.x * 0.84, 7)), 4, Color(1, 1, 1, 0.45))


func _glass(ci: CanvasItem, r: Rect2, radius: float) -> void:
	_vgrad(ci, r, Color(1, 1, 1, 0.85), Color(0.87, 0.96, 1.0, 0.45), radius, PopTokens.STEEL_DEEP, PopTokens.LINE_PART)


func _popcorn(ci: CanvasItem, c: Vector2, s: float) -> void:
	for o: Vector2 in [Vector2(-0.5, 0.2), Vector2(0.45, 0.15), Vector2(0, -0.35), Vector2(0.1, 0.45)]:
		ci.draw_circle(c + o * s, s * 0.55, Color(0.85, 0.64, 0.25))
	for o: Vector2 in [Vector2(-0.5, 0.2), Vector2(0.45, 0.15), Vector2(0, -0.35), Vector2(0.1, 0.45)]:
		ci.draw_circle(c + o * s, s * 0.45, PopPalette.CREAM)


func _bag(ci: CanvasItem, p: Vector2, w: float) -> void:
	var pts := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w * 0.88, w * 1.5), p + Vector2(w * 0.12, w * 1.5)])
	ci.draw_colored_polygon(pts, Color.WHITE)
	var loop := pts.duplicate()
	loop.append(p)
	ci.draw_polyline(loop, PopTokens.MACHINE, PopTokens.LINE_PART)
	ci.draw_line(p + Vector2(w * 0.35, 0), p + Vector2(w * 0.38, w * 1.5), PopTokens.MACHINE, 3.0)
	ci.draw_line(p + Vector2(w * 0.65, 0), p + Vector2(w * 0.62, w * 1.5), PopTokens.MACHINE, 3.0)


func _draw_under(ci: CanvasItem, _base: Vector2, _size_px: float) -> void:
	var s := size
	ci.draw_rect(Rect2(Vector2.ZERO, s), PopPalette.BG)
	var bands := [[PopTokens.TOP_FLOOR, PopTokens.FLOOR_TOP], [PopTokens.MID_FLOOR, PopTokens.FLOOR_MID], [PopTokens.LOW_FLOOR, PopTokens.FLOOR_LOW]]
	var rects: Array[Rect2] = []
	for b: Array in bands:
		var r := PopTokens.floor_rect(b[0], s)
		rects.append(r)
		var cols: Array = b[1]
		_vgrad(ci, r, cols[0], cols[1], PopTokens.R_FLOOR, PopTokens.FLOOR_EDGE, 4.0)
	# The glass tube carrying goods up, on the right of every floor.
	var tx := s.x * PopTokens.LIFT_X
	var tube := Rect2(Vector2(tx - 20, rects[0].end.y - rects[0].size.y * 0.3), Vector2(40, rects[2].get_center().y - rects[0].end.y + rects[0].size.y * 0.3))
	_glass(ci, tube, 20)
	for k in 5:
		_popcorn(ci, Vector2(tx, tube.end.y - 40 - k * tube.size.y * 0.2), 11)
	# TOP: awning, counter, customers, a bag handed over.
	var top := rects[0]
	var aw := Rect2(top.position + Vector2(40, 10), Vector2(top.size.x - 80, 36))
	for i in 10:
		var w := aw.size.x / 10.0
		ci.draw_rect(Rect2(aw.position + Vector2(w * i, 0), Vector2(w, aw.size.y)), PopTokens.MACHINE if i % 2 == 0 else Color.WHITE)
	var counter := Rect2(Vector2(top.position.x + 40, top.end.y - top.size.y * 0.3), Vector2(top.size.x - 120, top.size.y * 0.14))
	_machine(ci, counter)
	var cols := [Color(0.435, 0.714, 0.91), PopTokens.MINT, Color(1.0, 0.7, 0.42), Color(0.78, 0.6, 0.88)]
	for i in 4:
		var x := top.position.x + 270 + i * 82
		var y := counter.position.y
		PopMachineArt._round_rect(ci, Rect2(Vector2(x - 24, y - 42), Vector2(48, 42)), 18, cols[i])
		ci.draw_circle(Vector2(x, y - 62), 23, Color(0.96, 0.82, 0.68))
		ci.draw_arc(Vector2(x, y - 62), 23, 0, TAU, 24, PopPalette.INK, 3.0)
	_bag(ci, Vector2(top.position.x + 190, counter.position.y - 44), 28)
	# MIDDLE: hopper, packer, conveyor, shelf of bags.
	var mid := rects[1]
	var belt := Rect2(Vector2(mid.position.x + 40, mid.end.y - mid.size.y * 0.22), Vector2(mid.size.x - 140, mid.size.y * 0.08))
	_vgrad(ci, belt, PopTokens.STEEL, PopTokens.STEEL_DEEP, 10, PopTokens.STEEL_DEEP, 2.0)
	var hs := mid.size.y * 0.5
	var hop := Rect2(Vector2(mid.position.x + 40, mid.position.y + mid.size.y * 0.14), Vector2(hs, hs))
	_glass(ci, hop, PopTokens.R_PART)
	for k in 5:
		_popcorn(ci, hop.get_center() + Vector2(-30 + k * 15, 25 - (k % 2) * 18), 12)
	var pk := Rect2(Vector2(mid.position.x + 220, mid.position.y + mid.size.y * 0.12), Vector2(mid.size.y * 0.85, mid.size.y * 0.62))
	_machine(ci, pk)
	ci.draw_circle(pk.get_center(), pk.size.y * 0.3, Color(1, 1, 1, 0.7))
	for i in 3:
		_bag(ci, Vector2(mid.position.x + 450 + i * 40, belt.position.y - 46), 28)
	# BOTTOM: the hand's kettle, the ring, two dashed automation slots (blue = automation).
	var low := rects[2]
	var rr := minf(low.size.x * 0.3, low.size.y * 0.38)
	var c := Vector2(low.position.x + low.size.x * 0.42, low.position.y + rr + 26)
	ci.draw_arc(c, rr, -PI / 2, -PI / 2 + TAU * 0.47, 48, PopTokens.SKY, 24)
	ci.draw_arc(c, rr, -PI / 2 + TAU * 0.47, -PI / 2 + TAU * 0.62, 24, PopPalette.GOLD, 38)
	ci.draw_arc(c, rr, -PI / 2 + TAU * 0.62, -PI / 2 + TAU, 32, PopTokens.WARN, 24)
	var kettle := Rect2(c - Vector2(rr * 0.6, rr * 0.62), Vector2(rr * 1.2, rr * 1.22))
	_machine(ci, Rect2(kettle.position, Vector2(kettle.size.x, kettle.size.y * 0.2)))
	_glass(ci, Rect2(kettle.position + Vector2(kettle.size.x * 0.05, kettle.size.y * 0.2), Vector2(kettle.size.x * 0.9, kettle.size.y * 0.45)), PopTokens.R_PART)
	for k in 6:
		_popcorn(ci, kettle.position + Vector2(kettle.size.x * (0.2 + 0.12 * k), kettle.size.y * (0.52 - (k % 2) * 0.1)), 13)
	_machine(ci, Rect2(kettle.position + Vector2(-kettle.size.x * 0.04, kettle.size.y * 0.65), Vector2(kettle.size.x * 1.08, kettle.size.y * 0.32)))
	for j in 2:
		var sh := low.size.y * 0.3
		var slot := Rect2(Vector2(low.end.x - 170, low.position.y + low.size.y * 0.06 + j * sh * 1.12), Vector2(sh * 0.82, sh))
		PopMachineArt._round_rect(ci, slot, PopTokens.R_MACHINE, Color(1, 1, 1, 0.3))
		var pts := PopMachineArt.round_rect_points(slot, PopTokens.R_MACHINE)
		for q in range(0, pts.size(), 2):
			ci.draw_line(pts[q], pts[(q + 1) % pts.size()], PopTokens.AUTO, 4.0)
	# The card band: the palette as swatches, and the type scale as plain numbers.
	var sw := [PopPalette.BG, PopTokens.MACHINE, PopTokens.MACHINE_DEEP, PopPalette.GOLD, PopTokens.MINT, PopTokens.STEEL, PopTokens.AUTO, PopTokens.BRASS, PopTokens.WARN, PopPalette.INK]
	# Inside the bottom floor, under the ring (the band below is the game's card).
	var y0 := low.end.y - 54
	for i in sw.size():
		var sr := Rect2(Vector2(low.position.x + 16 + i * 40, y0), Vector2(34, 34))
		PopMachineArt._round_rect(ci, sr, PopTokens.R_PART, sw[i])
		ci.draw_polyline(PackedVector2Array([sr.position, sr.position + Vector2(sr.size.x, 0), sr.end, sr.position + Vector2(0, sr.size.y), sr.position]), PopPalette.INK, 2.0)
	var font := ThemeDB.fallback_font
	var x := low.position.x + 424.0
	for fs: int in [PopTokens.TEXT_MONEY, PopTokens.TEXT_PRICE, PopTokens.TEXT_DELTA]:
		ci.draw_string(font, Vector2(x, y0 + 30), "1,240", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
		x += fs * 2.55
