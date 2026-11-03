class_name RockPlusView
extends RockView

## C+'s rock (Step 95): RockView's boulder or crystal, plus what the hits
## leave on it --
##   - a dent where each hit landed and a short crack running from it, so
##     every hit changes the rock you see (the oldest go when there are many);
##   - two chunks that break off the rim at a third and two thirds of the
##     damage (`stage`; RockPlusFeel.STAGES) -- the crystal loses a shard;
##   - a white flash on impact and a jolt of the rock alone, never the world
##     or the camera (the experiment sets `flash` and `jolt` and lets them
##     fade).
## The same taps on the same rock leave the same marks (its own seeded
## random), and all the hit cracks are drawn in one call (an antialiased
## line per crack would cost a render object each: Step 93's lesson).

const MAX_MARKS := 28
const MAX_HIT_CRACKS := 36

var marks: Array[Dictionary] = []
var hit_cracks: Array[PackedVector2Array] = []
var stage := 0:
	set(v):
		stage = clampi(v, 0, 2)
		queue_redraw()
var flash := 0.0:
	set(v):
		flash = clampf(v, 0.0, 1.0)
		queue_redraw()
var jolt := Vector2.ZERO:
	set(v):
		jolt = v
		queue_redraw()
## The two chunks that break off (this node's coordinates).
var notches: Array[PackedVector2Array] = []

var _outlines: Array[PackedVector2Array] = []
var _rng := RandomNumberGenerator.new()


func setup(r: Dictionary, seed_value: int) -> void:
	marks.clear()
	hit_cracks.clear()
	stage = 0
	flash = 0.0
	jolt = Vector2.ZERO
	_rng.seed = seed_value * 31 + 7
	super.setup(r, seed_value)
	_build_stages(seed_value)


func _build_stages(seed_value: int) -> void:
	notches.clear()
	_outlines.clear()
	_outlines.append(outline)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7 + 3
	if crystal:
		# The crystal loses its outermost shards, left then right.
		for i: int in [0, shards.size() - 1]:
			notches.append(_shard_polygon(shards[i]))
		return
	# Two bites out of the rim, upper left then upper right (the faces in view).
	var current := outline
	for deg: float in [-145.0, -35.0]:
		var a := deg_to_rad(deg + rng.randf_range(-12.0, 12.0))
		var rim := centre + Vector2(cos(a) * radius, sin(a) * radius * 0.8)
		var bite := PackedVector2Array()
		for k in 8:
			var t := TAU * k / 8.0
			var rr := radius * rng.randf_range(0.26, 0.36)
			bite.append(rim + Vector2(cos(t) * rr, sin(t) * rr * 0.85))
		var piece := _largest(Geometry2D.intersect_polygons(current, bite))
		var rest := _largest(Geometry2D.clip_polygons(current, bite))
		if piece.size() >= 3 and rest.size() >= 3:
			current = rest
		notches.append(piece if piece.size() >= 3 else bite)
		_outlines.append(current)


static func _largest(polys: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var area := -1.0
	for p: PackedVector2Array in polys:
		var a := absf(_area(p))
		if a > area:
			area = a
			best = p
	return best


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


func _shard_polygon(s: Dictionary) -> PackedVector2Array:
	var x := float(s["x"])
	var h := float(s["h"])
	var w := float(s["w"])
	var lean := float(s["lean"])
	return PackedVector2Array([Vector2(x - w * 0.5, 0), Vector2(x - w * 0.5 + lean * h * 0.7, -h * 0.78), Vector2(x + lean * h, -h),
		Vector2(x + w * 0.5 + lean * h * 0.7, -h * 0.78), Vector2(x + w * 0.5, 0)])


## The boulder's outline after the chunks broken off so far.
func stage_outline() -> PackedVector2Array:
	return _outlines[mini(stage, _outlines.size() - 1)] if not crystal else outline


## A hit at `p` (this node's coordinates) with impact 0..1: a dent there and
## a crack running from it. A point just off the rock (the hit area is
## generous) is pulled in to the rock's face.
func add_mark(p: Vector2, p_impact: float) -> void:
	var q := p
	if not crystal:
		var poly := stage_outline()
		var tries := 0
		while not Geometry2D.is_point_in_polygon(q, poly) and tries < 16:
			q = q.lerp(centre, 0.2)
			tries += 1
	marks.append({"p": q, "r": radius * (0.05 + 0.05 * p_impact), "turn": _rng.randf() * TAU})
	while marks.size() > MAX_MARKS:
		marks.pop_front()
	var away := q - (centre if not crystal else Vector2(0, top() * 0.5))
	var dir := away.normalized() if away.length() > 4.0 else Vector2.RIGHT.rotated(_rng.randf() * TAU)
	dir = dir.rotated(_rng.randf_range(-0.9, 0.9))
	var line := PackedVector2Array([q])
	var at := q
	for s in 2 + int(round(p_impact * 2.0)):
		dir = dir.rotated(_rng.randf_range(-0.7, 0.7))
		at += dir * radius * _rng.randf_range(0.07, 0.12) * (0.6 + p_impact)
		line.append(at)
	hit_cracks.append(line)
	while hit_cracks.size() > MAX_HIT_CRACKS:
		hit_cracks.pop_front()
	queue_redraw()


## The rock cut into `n` wedges from its centre, what is left of it after
## the chunks (for the break).
func pieces(n: int = 7) -> Array[PackedVector2Array]:
	if crystal:
		return super.pieces(n)
	var ring := stage_outline()
	var out: Array[PackedVector2Array] = []
	var per := maxi(1, ring.size() / n)
	var i := 0
	while i < ring.size():
		var poly := PackedVector2Array([centre])
		for k in per + 1:
			poly.append(ring[(i + k) % ring.size()])
		# A wedge across a bitten-out rim can fold over itself; its hull is
		# a fine piece of rock and always draws.
		poly = _drawable(poly)
		if poly.size() >= 3:
			out.append(poly)
		i += per
	return out


func _draw() -> void:
	var sq := Vector2(1.0 + 0.05 * squash, 1.0 - 0.07 * squash)
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(sq.x, 0.3))
	draw_circle(Vector2.ZERO, radius * 1.15, Color(0.05, 0.15, 0.1, 0.25))
	draw_set_transform(jolt, 0.0, sq)
	if crystal:
		_draw_crystal_plus()
	else:
		_draw_boulder_plus()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_boulder_plus() -> void:
	var poly := stage_outline()
	var cols := PackedColorArray()
	for p: Vector2 in poly:
		var k := clampf((p.y - centre.y) / radius, -1.0, 1.0)
		cols.append(body.lightened(0.18 * maxf(-k, 0.0)).darkened(0.32 * maxf(k, 0.0)))
	draw_polygon(poly, cols)
	var lit := PackedVector2Array()
	for p: Vector2 in poly:
		lit.append(centre + (p - centre) * 0.62 + Vector2(-radius * 0.16, -radius * 0.14))
	draw_colored_polygon(lit, Color(1, 1, 1, 0.12))
	# The veins, their glints and the dents: one draw command (a shape per
	# draw call costs a render object each).
	var tri := _Tris.new()
	for v: Dictionary in veins:
		if not Geometry2D.is_point_in_polygon(v["at"], poly):
			continue
		var pts := PackedVector2Array()
		var r := float(v["r"])
		for k in 6:
			var a := float(v["turn"]) + TAU * k / 6.0
			pts.append((v["at"] as Vector2) + Vector2(cos(a) * r * (1.3 if k % 3 == 0 else 0.8), sin(a) * r * 0.7))
		tri.fan(pts, vein)
		tri.disc((v["at"] as Vector2) + Vector2(-r * 0.3, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.7))
	_draw_marks(tri)
	_draw_all_cracks(poly)
	# The broken faces where the chunks came off: a darker rim inside the bite.
	for i in mini(stage, notches.size()):
		var edge := Geometry2D.intersect_polyline_with_polygon(_closed(notches[i]), outline)
		for e: PackedVector2Array in edge:
			draw_polyline(e, body.darkened(0.45), 7.0)
	if flash > 0.0:
		draw_colored_polygon(poly, Color(1, 1, 1, 0.6 * flash))
	draw_polyline(_closed(poly), INK, 5.0, true)


func _draw_crystal_plus() -> void:
	for i in shards.size():
		if (stage >= 1 and i == 0) or (stage >= 2 and i == shards.size() - 1):
			continue
		var pts := _shard_polygon(shards[i])
		var tip := pts[2]
		var x := float(shards[i]["x"])
		var lean := float(shards[i]["lean"])
		var h := float(shards[i]["h"])
		draw_colored_polygon(_drawable(pts), vein.darkened(0.25).lerp(Color.WHITE, 0.6 * flash))
		# The lit face can fold over itself on a leaning shard (RockView draws
		# it anyway and the renderer refuses it); its hull is the same light.
		draw_colored_polygon(_drawable(PackedVector2Array([pts[0], pts[1], tip, Vector2(x + lean * h * 0.5, 0)])), vein.lightened(0.15).lerp(Color.WHITE, 0.6 * flash))
		draw_polyline(_closed(pts), INK, 4.0, true)
	_draw_marks(_Tris.new())
	_draw_all_cracks(PackedVector2Array())


## The dents (added to `tri`, then all of it drawn at once) and their lit
## upper rims (one multiline).
func _draw_marks(tri: _Tris) -> void:
	var rims := PackedVector2Array()
	for m: Dictionary in marks:
		var c: Vector2 = m["p"]
		var r := float(m["r"])
		var turn := float(m["turn"])
		var dent := PackedVector2Array()
		for k in 7:
			var a := turn + TAU * k / 7.0
			var rr := r * (1.0 if k % 2 == 0 else 0.75)
			dent.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.7))
		tri.fan(dent, body.darkened(0.42))
		var last := Vector2.ZERO
		for k in 4:
			var a := PI * 0.95 + PI * 0.6 * k / 3.0
			var p := c + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.85)
			if k > 0:
				rims.append_array([last, p])
			last = p
	tri.draw(self)
	if not rims.is_empty():
		draw_multiline(rims, Color(1, 1, 1, 0.45), 2.0)


## Triangles gathered from many small shapes, drawn in one command.
class _Tris extends RefCounted:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	## A star-shaped polygon, as a fan from its middle.
	func fan(poly: PackedVector2Array, col: Color) -> void:
		var mid := Vector2.ZERO
		for p: Vector2 in poly:
			mid += p
		mid /= maxf(1.0, poly.size())
		var base := pts.size()
		pts.append(mid)
		cols.append(col)
		for p: Vector2 in poly:
			pts.append(p)
			cols.append(col)
		for k in poly.size():
			idx.append_array([base, base + 1 + k, base + 1 + (k + 1) % poly.size()])

	func disc(c: Vector2, r: float, col: Color, n: int = 8) -> void:
		var poly := PackedVector2Array()
		for k in n:
			var a := TAU * k / n
			poly.append(c + Vector2(cos(a), sin(a)) * r)
		fan(poly, col)

	func draw(ci: CanvasItem) -> void:
		if not idx.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## The structural cracks (RockView's, opening with the damage) and the hit
## cracks, each set in one multiline, clipped to what is left of the rock.
## Not antialiased: an antialiased multiline is one render object per
## segment, and a cracked rock drew 1,500 more objects than a whole one
## (Step 95; Step 93 found the same of antialiased draw_line).
func _draw_all_cracks(poly: PackedVector2Array) -> void:
	var dark := PackedVector2Array()
	var widths: Array[float] = []
	for c: Dictionary in cracks:
		var at := float(c["at"])
		if damage_frac < at:
			continue
		var line: PackedVector2Array = c["line"]
		var grown := clampf((damage_frac - at) / 0.12, 0.0, 1.0)
		var n := maxi(2, int(ceil(line.size() * grown)))
		_segments(line.slice(0, n), poly, dark)
		widths.append(float(c["width"]))
	var thin := PackedVector2Array()
	for line: PackedVector2Array in hit_cracks:
		_segments(line, poly, thin)
	if not dark.is_empty():
		draw_multiline(dark, INK, 4.5)
		draw_multiline(_offset(dark, Vector2(1.5, 1.5)), Color(1, 1, 1, 0.3), 1.5)
	if not thin.is_empty():
		draw_multiline(thin, INK.lerp(body, 0.25), 2.5)
		draw_multiline(_offset(thin, Vector2(1.2, 1.2)), Color(1, 1, 1, 0.28), 1.2)


## Appends `line`'s segments, clipped to `poly` (none: unclipped), as pairs.
static func _segments(line: PackedVector2Array, poly: PackedVector2Array, out: PackedVector2Array) -> void:
	var parts: Array[PackedVector2Array] = []
	if poly.is_empty():
		parts.append(line)
	else:
		parts = Geometry2D.intersect_polyline_with_polygon(line, poly)
	for part: PackedVector2Array in parts:
		for i in part.size() - 1:
			out.append(part[i])
			out.append(part[i + 1])


## `poly` as given if it triangulates, else its convex hull.
static func _drawable(poly: PackedVector2Array) -> PackedVector2Array:
	if not Geometry2D.triangulate_polygon(poly).is_empty():
		return poly
	var hull := Geometry2D.convex_hull(poly)
	hull.remove_at(hull.size() - 1)
	return hull


static func _offset(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + by)
	return out


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	if not out.is_empty():
		out.append(p[0])
	return out
