class_name TreeView
extends Node2D

## One tree drawn from a TreeLevels shape: a tapered trunk (or twin trunks),
## branches forking `depth` times, and a crown of its kind -- leaves, round
## clusters, an umbrella, pagoda tiers, a heart, crystal shards, clouds --
## with blossoms, fruit, lanterns, fireflies, a treehouse or a rainbow when
## the shape has them. The same shape and seed always draw the same tree; its
## foot is the node's origin. As a `silhouette` it is one flat pale shape (the
## next stage's preview). `grow` 0..1 brings it in; it sways a little unless
## reduced motion.

const BARK := Color("#7a5536")
const BARK_DARK := Color("#5a3d27")

var shape: Dictionary = {}
var geo: Dictionary = {}
var grow := 1.0:
	set(v):
		grow = v
		queue_redraw()
var silhouette := false
var sil_color := Color(1, 1, 1, 0.2)
var reduced_motion := false
var time := 0.0


func set_shape(s: Dictionary, seed_value: int) -> void:
	shape = s
	geo = TreeView.build(s, seed_value)
	queue_redraw()


func _process(delta: float) -> void:
	time += delta
	if not reduced_motion and not silhouette:
		queue_redraw()
	elif silhouette:
		queue_redraw()


## The tree's height above its foot and half its width (px, unscaled).
func extent() -> Vector2:
	return Vector2(float(geo.get("half_w", 40.0)), -float(geo.get("top", -40.0)))


static func build(s: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var h := float(s["h"])
	var w := float(s["w"])
	var depth := int(s.get("depth", 0))
	var segs: Array = []
	var tips: Array = []
	var tops: Array[Vector2] = []
	if bool(s.get("twin", false)):
		var fork := Vector2(0, -h * 0.32)
		segs.append({"a": Vector2.ZERO, "b": fork, "w0": w * 1.3, "w1": w, "d": 0})
		for side: float in [-1.0, 1.0]:
			var top := fork + Vector2(side * h * 0.32, -h * 0.62)
			segs.append({"a": fork, "b": top, "w0": w * 0.8, "w1": w * 0.55, "d": 0})
			tops.append(top)
	else:
		# The trunk runs to the first fork; the branches make the rest of
		# the height (a sprout is all trunk).
		var trunk := h if depth == 0 else (h * 0.7 if depth == 1 else h * 0.42)
		var mid := Vector2(rng.randf_range(-6, 6), -trunk * 0.5)
		var top := Vector2(0, -trunk)
		segs.append({"a": Vector2.ZERO, "b": mid, "w0": w, "w1": w * 0.85, "d": 0})
		segs.append({"a": mid, "b": top, "w0": w * 0.85, "w1": w * 0.7, "d": 0})
		tops.append(top)
	var spread := deg_to_rad(float(s.get("spread", 40.0)))
	var ratio := float(s.get("ratio", 0.6))
	var kids := int(s.get("kids", 2))
	var twist := deg_to_rad(float(s.get("twist", 0.0)))
	var r := float(s.get("r", 20.0))
	for top: Vector2 in tops:
		if depth == 0:
			tips.append({"p": top, "r": r, "d": 0})
		else:
			var first := h * (0.3 if depth == 1 else 0.3)
			if bool(s.get("twin", false)):
				first = h * 0.22
			_branch(segs, tips, rng, top, -PI / 2.0, first, w * 0.62, 1, depth, kids, spread, ratio, twist, r * (0.6 if String(s.get("crown", "")) == "layers" else 1.0), String(s.get("crown", "blob")))
	var top_y := 0.0
	var half_w := w
	for t: Dictionary in tips:
		var p: Vector2 = t["p"]
		var tr := float(t["r"]) * (1.6 if String(s.get("crown", "")) == "umbrella" else 1.0)
		top_y = minf(top_y, p.y - float(t["r"]))
		half_w = maxf(half_w, absf(p.x) + tr)
	for sg: Dictionary in segs:
		top_y = minf(top_y, (sg["b"] as Vector2).y)
	# The crowns drawn round the trunk rather than at the tips.
	match String(s.get("crown", "")):
		"heart":
			top_y = minf(top_y, TreeView.heart_centre(h, r).y - r * 0.16 * 12.5)
			half_w = maxf(half_w, r * 0.16 * 16.0)
		"layers":
			half_w = maxf(half_w, r * 3.0)
	var blossoms: Array = []
	for i in int(s.get("blossom", 0)):
		var t: Dictionary = tips[rng.randi_range(0, tips.size() - 1)]
		var a := rng.randf() * TAU
		blossoms.append((t["p"] as Vector2) + Vector2(cos(a), sin(a)) * float(t["r"]) * sqrt(rng.randf()) * 0.95)
	var fruits: Array = []
	for i in int(s.get("fruit", 0)):
		var t: Dictionary = tips[rng.randi_range(0, tips.size() - 1)]
		var a := rng.randf_range(0.2, PI - 0.2)
		fruits.append((t["p"] as Vector2) + Vector2(cos(a), sin(a)) * float(t["r"]) * rng.randf_range(0.4, 0.9))
	var lanterns: Array = []
	var deep := segs.filter(func(sg: Dictionary) -> bool: return int(sg["d"]) >= 1)
	for i in int(s.get("lanterns", 0)):
		if deep.is_empty():
			break
		var sg: Dictionary = deep[rng.randi_range(0, deep.size() - 1)]
		lanterns.append((sg["a"] as Vector2).lerp(sg["b"], rng.randf_range(0.3, 0.8)))
	var flies: Array = []
	if bool(s.get("glow", false)):
		for i in 16:
			flies.append({"c": Vector2(rng.randf_range(-half_w, half_w) * 0.8, rng.randf_range(top_y * 0.95, top_y * 0.35)), "ph": rng.randf() * TAU, "rad": rng.randf_range(6, 16)})
	var clouds: Array = []
	if bool(s.get("clouds", false)):
		for i in 5:
			clouds.append({"c": Vector2(rng.randf_range(-half_w * 1.1, half_w * 1.1), top_y + rng.randf_range(0, h * 0.35)), "s": rng.randf_range(0.8, 1.4)})
	return {"segs": segs, "tips": tips, "blossoms": blossoms, "fruits": fruits, "lanterns": lanterns, "flies": flies,
		"clouds": clouds, "top": top_y, "half_w": half_w, "h": h}


static func _branch(segs: Array, tips: Array, rng: RandomNumberGenerator, start: Vector2, ang: float, length: float, width: float,
		d: int, depth: int, kids: int, spread: float, ratio: float, twist: float, r: float, crown: String) -> void:
	var end := start + Vector2(cos(ang), sin(ang)) * length
	segs.append({"a": start, "b": end, "w0": width, "w1": width * 0.7, "d": d})
	if d >= depth:
		tips.append({"p": end, "r": r * rng.randf_range(0.85, 1.15), "d": d})
		return
	if d >= depth - 1 and crown in ["blob", "umbrella", "cloud", "heart"]:
		tips.append({"p": end, "r": r * 0.8, "d": d})
	for k in kids:
		var f := (float(k) / float(kids - 1) - 0.5) if kids > 1 else 0.0
		var a2 := ang + spread * f * 1.4 + twist + rng.randf_range(-0.12, 0.12)
		_branch(segs, tips, rng, end, a2, length * ratio * rng.randf_range(0.9, 1.1), width * 0.68, d + 1, depth, kids, spread, ratio, twist, r, crown)


# --- drawing -------------------------------------------------------------------------

func _sway(p: Vector2) -> Vector2:
	if reduced_motion or silhouette:
		return p
	var h := maxf(1.0, float(geo.get("h", 100.0)))
	return p + Vector2(sin(time * 1.1) * (-p.y / h) * 4.0, 0)


func _draw() -> void:
	if geo.is_empty():
		return
	var g := clampf(grow, 0.0, 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.55 + 0.45 * g, 0.4 + 0.6 * g))
	var a := clampf(g * 1.4, 0.0, 1.0)
	if silhouette:
		_draw_silhouette()
	else:
		_draw_tree(a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_silhouette() -> void:
	var c := sil_color
	for sg: Dictionary in geo["segs"]:
		draw_colored_polygon(_quad(sg), c)
	var kind := String(shape.get("crown", "blob"))
	for t: Dictionary in geo["tips"]:
		var p: Vector2 = t["p"]
		var r := float(t["r"])
		if kind == "umbrella":
			_ellipse(p, Vector2(r * 1.6, r * 0.8), c)
		elif kind == "crystal":
			draw_colored_polygon(_shard(p, r), c)
		else:
			draw_circle(p, r, c)
	if kind == "layers":
		for tier: Array in _tiers():
			_ellipse(tier[0], tier[1], c)
	if kind == "heart":
		draw_colored_polygon(_heart(), c)


func _draw_tree(a: float) -> void:
	var kind := String(shape.get("crown", "blob"))
	if kind == "layers":
		for tier: Array in _tiers():
			_ellipse(_sway(tier[0]) + Vector2(0, 8), tier[1], Color(shape["leaf2"], a))
	for sg: Dictionary in geo["segs"]:
		var q := _quad(sg)
		draw_colored_polygon(q, Color(BARK, a))
		var inner := PackedVector2Array([q[0].lerp(q[3], 0.55), q[1].lerp(q[2], 0.55), q[2], q[3]])
		draw_colored_polygon(inner, Color(BARK_DARK, a))
	if bool(shape.get("house", false)):
		_draw_house(a)
	match kind:
		"leaves":
			for t: Dictionary in geo["tips"]:
				var p := _sway(t["p"])
				var r := float(t["r"])
				for side: float in [-1.0, 1.0]:
					_leaf(p, r, side * 0.7 - PI / 2.0, a)
		"crystal":
			for t: Dictionary in geo["tips"]:
				var p := _sway(t["p"])
				var r := float(t["r"])
				var shard := _shard(p, r)
				draw_colored_polygon(shard, Color(shape["leaf"], a))
				draw_colored_polygon(PackedVector2Array([shard[0], shard[1], shard[2], p]), Color(Color(shape["leaf2"]).lightened(0.2), a * 0.9))
				var ring := shard.duplicate()
				ring.append(shard[0])
				draw_polyline(ring, Color(0.2, 0.25, 0.45, a * 0.8), 2.5, true)
		"heart":
			var heart := _heart()
			var moved := PackedVector2Array()
			for p: Vector2 in heart:
				moved.append(_sway(p))
			draw_colored_polygon(moved, Color(shape["leaf2"], a))
			var lit := PackedVector2Array()
			var c := _heart_centre()
			for p: Vector2 in moved:
				lit.append(c + (p - c) * 0.86 + Vector2(-6, -8))
			draw_colored_polygon(lit, Color(shape["leaf"], a))
		_:
			_draw_clusters(kind, a)
	if kind == "layers":
		for tier: Array in _tiers():
			_ellipse(_sway(tier[0]), (tier[1] as Vector2) * 0.94, Color(shape["leaf"], a))
			_ellipse(_sway(tier[0]) + Vector2(-(tier[1] as Vector2).x * 0.25, -(tier[1] as Vector2).y * 0.3), (tier[1] as Vector2) * Vector2(0.45, 0.35), Color(Color(shape["leaf"]).lightened(0.2), a * 0.8))
	for b: Vector2 in geo["blossoms"]:
		var p := _sway(b)
		var pc: Color = shape.get("petal", Color.WHITE)
		for k in 5:
			var ang := TAU * k / 5.0
			draw_circle(p + Vector2(cos(ang), sin(ang)) * 3.2, 3.0, Color(pc, a))
		draw_circle(p, 2.0, Color(1, 0.85, 0.4, a))
	for f: Vector2 in geo["fruits"]:
		var p := _sway(f)
		var fc: Color = shape.get("fruit_col", Color("#ffcf3f"))
		draw_line(p + Vector2(0, -9), p + Vector2(0, -4), Color(BARK, a), 2.0)
		draw_circle(p, 7.0, Color(fc.darkened(0.2), a))
		draw_circle(p + Vector2(-1, -1), 6.0, Color(fc, a))
		draw_circle(p + Vector2(-2.5, -2.5), 2.0, Color(1, 1, 1, a * 0.8))
	for l: Vector2 in geo["lanterns"]:
		var p := _sway(l)
		draw_line(p, p + Vector2(0, 14), Color(BARK_DARK, a), 1.5)
		draw_circle(p + Vector2(0, 20), 13.0, Color(1, 0.8, 0.4, a * 0.25))
		draw_circle(p + Vector2(0, 20), 7.0, Color("#ffb347", a))
		draw_circle(p + Vector2(-1.5, 18.5), 3.0, Color("#fff3c4", a))
	for fl: Dictionary in geo["flies"]:
		var ph := float(fl["ph"]) + time * 1.3
		var p := (fl["c"] as Vector2) + Vector2(cos(ph), sin(ph * 1.3)) * float(fl["rad"])
		var tw := 0.5 + 0.5 * sin(time * 3.0 + float(fl["ph"]) * 3.0)
		draw_circle(p, 6.0, Color(1, 1, 0.6, a * 0.18 * tw))
		draw_circle(p, 2.4, Color(1, 1, 0.75, a * (0.4 + 0.6 * tw)))
	for cl: Dictionary in geo["clouds"]:
		var c := _sway(cl["c"])
		var s := float(cl["s"])
		for off: Vector2 in [Vector2(-28, 6), Vector2(0, -6), Vector2(28, 4), Vector2(12, 12), Vector2(-12, 12)]:
			draw_circle(c + off * s, 22.0 * s, Color(1, 1, 1, a * 0.92))


func _draw_clusters(kind: String, a: float) -> void:
	var tips: Array = geo["tips"].duplicate()
	tips.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return (x["p"] as Vector2).y < (y["p"] as Vector2).y)
	var rainbow := bool(shape.get("rainbow", false))
	var half_w := maxf(1.0, float(geo["half_w"]))
	for pass_i in 3:
		for t: Dictionary in tips:
			var p := _sway(t["p"])
			var r := float(t["r"])
			var main: Color = shape["leaf"]
			var dark: Color = shape["leaf2"]
			if rainbow:
				var hue := fposmod((p.x / half_w) * 0.35 + time * 0.05 + 0.5, 1.0)
				main = Color.from_hsv(hue, 0.55, 0.95)
				dark = Color.from_hsv(hue, 0.65, 0.7)
			var stretch := Vector2(1.6, 0.8) if kind == "umbrella" else Vector2.ONE
			match pass_i:
				0:
					_ellipse(p + Vector2(r * 0.12, r * 0.16), Vector2(r, r) * stretch, Color(dark, a))
				1:
					_ellipse(p, Vector2(r, r) * stretch * 0.92, Color(main, a))
				2:
					_ellipse(p + Vector2(-r * 0.28, -r * 0.3) * stretch, Vector2(r, r) * stretch * 0.42, Color(main.lightened(0.22), a * 0.85))


func _draw_house(a: float) -> void:
	var h := float(geo["h"])
	var base := _sway(Vector2(10, -h * 0.62))
	draw_rect(Rect2(base + Vector2(-58, 0), Vector2(116, 10)), Color("#8a5d3b", a))
	var body := Rect2(base + Vector2(-38, -54), Vector2(76, 54))
	draw_rect(body, Color("#e9c48f", a))
	draw_rect(Rect2(body.position, Vector2(body.size.x * 0.5, body.size.y)), Color("#f3d6a6", a))
	draw_colored_polygon(PackedVector2Array([body.position + Vector2(-10, 0), body.position + Vector2(body.size.x * 0.5, -36), body.position + Vector2(body.size.x + 10, 0)]), Color("#d0533f", a))
	draw_rect(Rect2(body.position + Vector2(12, 16), Vector2(22, 20)), Color("#ffe08a", a))
	draw_rect(Rect2(body.position + Vector2(46, 22), Vector2(16, 32)), Color("#7a4b2f", a))


func _quad(sg: Dictionary) -> PackedVector2Array:
	var pa := _sway(sg["a"])
	var pb := _sway(sg["b"])
	var n := (pb - pa).orthogonal().normalized()
	var w0 := float(sg["w0"]) * 0.5
	var w1 := float(sg["w1"]) * 0.5
	return PackedVector2Array([pa + n * w0, pb + n * w1, pb - n * w1, pa - n * w0])


func _leaf(p: Vector2, r: float, turn: float, a: float) -> void:
	var pts := PackedVector2Array()
	for k in 12:
		var t := TAU * k / 12.0
		pts.append(p + Vector2(cos(t) * r, sin(t) * r * 0.45).rotated(turn) + Vector2(cos(turn), sin(turn)) * r * 0.8)
	draw_colored_polygon(pts, Color(shape["leaf"], a))
	draw_line(p, p + Vector2(cos(turn), sin(turn)) * r * 1.5, Color(shape["leaf2"], a), 1.5, true)


func _shard(p: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(0, -r * 1.5), p + Vector2(r * 0.55, -r * 0.3), p + Vector2(r * 0.35, r * 0.6),
		p + Vector2(-r * 0.35, r * 0.6), p + Vector2(-r * 0.55, -r * 0.3)])


func _ellipse(c: Vector2, rr: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		pts.append(c + Vector2(cos(t) * rr.x, sin(t) * rr.y))
	draw_colored_polygon(pts, col)


func _tiers() -> Array:
	var h := float(geo["h"])
	var r := float(shape.get("r", 50.0))
	var out: Array = []
	for i in 4:
		out.append([Vector2(0, -h * (0.4 + 0.15 * i)), Vector2(r * (2.6 - 0.45 * i), r * 0.5)])
	return out


## The heart crown's middle: its point a little above the fork, so it sits
## on the twin trunks rather than hanging over them.
static func heart_centre(h: float, r: float) -> Vector2:
	return Vector2(0, -h * 0.5 - 17.0 * r * 0.16)


func _heart_centre() -> Vector2:
	return TreeView.heart_centre(float(geo["h"]), float(shape.get("r", 60.0)))


func _heart() -> PackedVector2Array:
	var c := _heart_centre()
	var s := float(shape.get("r", 60.0)) * 0.16
	var pts := PackedVector2Array()
	for k in 40:
		var t := TAU * k / 40.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * s)
	return pts
