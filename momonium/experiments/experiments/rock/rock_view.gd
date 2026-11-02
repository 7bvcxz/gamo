class_name RockView
extends Node2D

## One big rock, drawn from shapes (crisp at any size, no new art): a lumpy
## boulder lit from the upper left, coloured veins and glints of its ore, and
## cracks that open as it takes damage (`damage_frac` 0..1, each crack from
## its own threshold, so the same damage always shows the same cracks). The
## Giant Crystal is a cluster of shards instead. Its foot is the node's origin.
## `pieces()` cuts it into the chunks that fly when it breaks.

const INK := Color("#3a3430")

var radius := 120.0
var body := Color("#9aa3ad")
var vein := Color("#c9d1d8")
var crystal := false
var damage_frac := 0.0:
	set(v):
		damage_frac = clampf(v, 0.0, 1.0)
		queue_redraw()
var squash := 0.0:
	set(v):
		squash = v
		queue_redraw()

var outline := PackedVector2Array()
var cracks: Array = []
var veins: Array = []
var shards: Array = []
var centre := Vector2.ZERO


func setup(r: Dictionary, seed_value: int) -> void:
	radius = float(r["radius"])
	body = r["body"]
	vein = r["vein"]
	crystal = bool(r["goal"])
	_build(seed_value)
	queue_redraw()


func _build(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	centre = Vector2(0, -radius * 0.78)
	outline = PackedVector2Array()
	var n := 18
	for i in n:
		var a := TAU * i / n
		var rr := radius * (0.84 + 0.16 * rng.randf())
		var p := centre + Vector2(cos(a) * rr * 1.08, sin(a) * rr * 0.86)
		if p.y > 0.0:
			p.y = lerpf(p.y, 0.0, 0.75)
		outline.append(p)
	cracks.clear()
	var count := 9
	for i in count:
		var a := rng.randf() * TAU
		var start := centre + Vector2(cos(a), sin(a) * 0.8) * radius * rng.randf_range(0.0, 0.35)
		var line := PackedVector2Array([start])
		var dir := Vector2(cos(a), sin(a)).normalized()
		var p := start
		for s in 5:
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			p += dir * radius * rng.randf_range(0.12, 0.2)
			if not Geometry2D.is_point_in_polygon(p, outline):
				break
			line.append(p)
		if line.size() >= 2:
			cracks.append({"line": line, "at": float(i + 1) / float(count + 1), "width": rng.randf_range(3.0, 5.0)})
	veins.clear()
	for i in 7:
		var a := rng.randf() * TAU
		var p := centre + Vector2(cos(a) * 0.62, sin(a) * 0.5) * radius * rng.randf_range(0.2, 1.0)
		veins.append({"at": p, "r": radius * rng.randf_range(0.05, 0.1), "turn": rng.randf() * TAU})
	shards.clear()
	if crystal:
		for i in 6:
			var x := (float(i) - 2.5) * radius * 0.32 + rng.randf_range(-8, 8)
			var h := radius * rng.randf_range(1.0, 1.9) * (1.0 - absf(float(i) - 2.5) * 0.12)
			shards.append({"x": x, "h": h, "w": radius * rng.randf_range(0.2, 0.28), "lean": rng.randf_range(-0.25, 0.25)})


## How high the rock stands (for the bar above it).
func top() -> float:
	if crystal:
		var h := 0.0
		for s: Dictionary in shards:
			h = maxf(h, float(s["h"]))
		return -h
	var t := 0.0
	for p: Vector2 in outline:
		t = minf(t, p.y)
	return t


## Whether `local` is on the rock, generously (a finger is not a mouse).
func hit_test(local: Vector2, slack: float = 1.25) -> bool:
	var c := centre if not crystal else Vector2(0, top() * 0.5)
	var r := Vector2(radius * 1.1, (radius * 0.9 if not crystal else -top() * 0.55)) * slack
	var d := (local - c) / r
	return d.length() <= 1.0


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + 0.05 * squash, 1.0 - 0.07 * squash))
	# The shadow on the ground.
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0 + 0.05 * squash, 0.3))
	draw_circle(Vector2.ZERO, radius * 1.15, Color(0.05, 0.15, 0.1, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + 0.05 * squash, 1.0 - 0.07 * squash))
	if crystal:
		_draw_crystal()
	else:
		_draw_boulder()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_boulder() -> void:
	var cols := PackedColorArray()
	for p: Vector2 in outline:
		var k := clampf((p.y - centre.y) / radius, -1.0, 1.0)
		cols.append(body.lightened(0.18 * maxf(-k, 0.0)).darkened(0.32 * maxf(k, 0.0)))
	draw_polygon(outline, cols)
	# The lit upper left.
	var lit := PackedVector2Array()
	for p: Vector2 in outline:
		lit.append(centre + (p - centre) * 0.62 + Vector2(-radius * 0.16, -radius * 0.14))
	draw_colored_polygon(lit, Color(1, 1, 1, 0.12))
	for v: Dictionary in veins:
		var pts := PackedVector2Array()
		var r := float(v["r"])
		for k in 6:
			var a := float(v["turn"]) + TAU * k / 6.0
			pts.append((v["at"] as Vector2) + Vector2(cos(a) * r * (1.3 if k % 3 == 0 else 0.8), sin(a) * r * 0.7))
		draw_colored_polygon(pts, vein)
		draw_circle((v["at"] as Vector2) + Vector2(-r * 0.3, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.7))
	_draw_cracks()
	var ring := outline.duplicate()
	ring.append(outline[0])
	draw_polyline(ring, INK, 5.0, true)


func _draw_crystal() -> void:
	for s: Dictionary in shards:
		var x := float(s["x"])
		var h := float(s["h"])
		var w := float(s["w"])
		var lean := float(s["lean"])
		var tip := Vector2(x + lean * h, -h)
		var pts := PackedVector2Array([Vector2(x - w * 0.5, 0), Vector2(x - w * 0.5 + lean * h * 0.7, -h * 0.78), tip,
			Vector2(x + w * 0.5 + lean * h * 0.7, -h * 0.78), Vector2(x + w * 0.5, 0)])
		draw_colored_polygon(pts, vein.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], tip, Vector2(x + lean * h * 0.5, 0)]), vein.lightened(0.15))
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, INK, 4.0, true)
	_draw_cracks()


func _draw_cracks() -> void:
	for c: Dictionary in cracks:
		var at := float(c["at"])
		if damage_frac < at:
			continue
		var line: PackedVector2Array = c["line"]
		var grown := clampf((damage_frac - at) / 0.12, 0.0, 1.0)
		var n := maxi(2, int(ceil(line.size() * grown)))
		var shown := line.slice(0, n)
		draw_polyline(shown, INK, float(c["width"]), true)
		var light := PackedVector2Array()
		for p: Vector2 in shown:
			light.append(p + Vector2(1.5, 1.5))
		draw_polyline(light, Color(1, 1, 1, 0.35), 1.5, true)


## The rock cut into `n` wedges from its centre (for the break).
func pieces(n: int = 7) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var ring := outline if not crystal else _crystal_ring()
	var per := maxi(1, ring.size() / n)
	var c := centre if not crystal else Vector2(0, top() * 0.5)
	var i := 0
	while i < ring.size():
		var poly := PackedVector2Array([c])
		for k in per + 1:
			poly.append(ring[(i + k) % ring.size()])
		out.append(poly)
		i += per
	return out


func _crystal_ring() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var h := -top()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(Vector2(cos(a) * radius, -h * 0.5 + sin(a) * h * 0.5))
	return pts
