class_name PopFx
extends RefCounted

## Flying popcorn and coins: a fixed pool, stepped with the frame and drawn by
## the view in one _draw(). Purely a picture -- the rules have already paid
## the money when a piece appears, so dropping pieces (the cap, reduced motion)
## never changes the game.

const CAP := 400
const GRAVITY := 1900.0

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat32Array()     # seconds left; <= 0 is a free slot
var size := PackedFloat32Array()
var rot := PackedFloat32Array()
var kind := PackedByteArray()        # 0 popcorn, 1 coin, 2 smoke, 3 kernel, 4 sparkle
var tint := PackedColorArray()
var target := Vector2.ZERO           # where coins fly (the money counter)
var alive := 0
var peak := 0
var dropped := 0


func _init() -> void:
	pos.resize(CAP); vel.resize(CAP); life.resize(CAP); size.resize(CAP); rot.resize(CAP); kind.resize(CAP)
	tint.resize(CAP)


func clear() -> void:
	life.fill(0.0)
	alive = 0


## `n` popcorn pieces bursting up out of `from`. `spread` widens the fan,
## `power` the speed, `big` the pieces (C draws fewer, bigger pieces past the cap).
func burst(from: Vector2, n: int, scale: float, rng: RandomNumberGenerator, col: Color = PopPalette.CREAM,
		spread: float = 0.9, power: float = 1.0, big: float = 1.0, life_s: float = 1.1) -> void:
	for i in n:
		var a := -PI / 2 + rng.randf_range(-spread, spread)
		var speed := rng.randf_range(650.0, 1150.0) * scale * power
		_spawn(0, from + Vector2(rng.randf_range(-20, 20), 0) * scale, Vector2(cos(a), sin(a)) * speed,
			rng.randf_range(life_s * 0.8, life_s * 1.2), rng.randf_range(15.0, 22.0) * scale * big, rng.randf() * TAU, col)


## Dark puffs rising (a burnt batch).
func smoke(from: Vector2, n: int, scale: float, rng: RandomNumberGenerator) -> void:
	for i in n:
		_spawn(2, from + Vector2(rng.randf_range(-60, 60), 0) * scale, Vector2(rng.randf_range(-40, 40), rng.randf_range(-260, -160)) * scale,
			rng.randf_range(0.9, 1.4), rng.randf_range(22.0, 34.0) * scale, 0.0, Color(0.25, 0.22, 0.22, 0.75))


## Unpopped kernels tumbling out (an early release).
func kernels(from: Vector2, n: int, scale: float, rng: RandomNumberGenerator) -> void:
	for i in n:
		var a := -PI / 2 + rng.randf_range(-1.2, 1.2)
		_spawn(3, from, Vector2(cos(a), sin(a)) * rng.randf_range(300.0, 600.0) * scale,
			rng.randf_range(0.6, 0.9), rng.randf_range(7.0, 10.0) * scale, rng.randf() * TAU, Color(0.78, 0.52, 0.2))


## A sparkle that grows and fades (a perfect pop, an upgrade).
func sparkle(at: Vector2, scale: float, rng: RandomNumberGenerator, n: int = 6, spread: float = 160.0) -> void:
	for i in n:
		_spawn(4, at + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.6, spread * 0.4)) * scale,
			Vector2.ZERO, rng.randf_range(0.35, 0.6), rng.randf_range(18.0, 30.0) * scale, rng.randf() * 0.6, Color.WHITE)


func coin(from: Vector2, scale: float) -> void:
	_spawn(1, from, Vector2.ZERO, 0.55, 20.0 * scale, 0.0, PopPalette.GOLD)


func step(delta: float) -> void:
	alive = 0
	for i in CAP:
		if life[i] <= 0.0:
			continue
		life[i] -= delta
		if kind[i] == 1:
			# Coins ease towards the counter and are gone when they reach it.
			pos[i] = pos[i].lerp(target, clampf(delta * 9.0, 0.0, 1.0))
			if pos[i].distance_to(target) < 12.0:
				life[i] = 0.0
		elif kind[i] == 2:
			pos[i] += vel[i] * delta
			size[i] += delta * 30.0
		elif kind[i] == 4:
			size[i] += delta * 20.0
		else:
			vel[i] += Vector2(0, GRAVITY) * delta
			pos[i] += vel[i] * delta
			rot[i] += delta * 3.0
		if life[i] > 0.0:
			alive += 1
	peak = maxi(peak, alive)


## Pieces are atlas sprites (art_src/*.svg) rotated by a transform set on this
## canvas item only and reset to identity at the end: draw() is called last on
## its own layer, so no caller's transform is in play (AGENTS.md 2026-11-03).
## Without the atlas it falls back to the shapes.
func draw(ci: CanvasItem) -> void:
	if PopAtlas.ready():
		_draw_sprites(ci)
		return
	for i in CAP:
		if life[i] <= 0.0:
			continue
		var fade := clampf(life[i] / 0.25, 0.0, 1.0)
		match kind[i]:
			1:
				PopMachineArt.draw_coin(ci, pos[i], size[i])
			2:
				ci.draw_circle(pos[i], size[i], Color(tint[i], tint[i].a * fade))
			3:
				ci.draw_circle(pos[i], size[i], Color(tint[i], fade))
			_:
				PopMachineArt.draw_piece(ci, pos[i], size[i], rot[i], Color(tint[i], fade))


## Any live popcorn piece's position (for a chain to start from), or `fallback`.
func random_piece(rng: RandomNumberGenerator, fallback: Vector2) -> Vector2:
	for attempt in 6:
		var i := rng.randi_range(0, CAP - 1)
		if life[i] > 0.3 and kind[i] == 0:
			return pos[i]
	return fallback


const PIECES := ["piece_a", "piece_b", "piece_c"]


func _draw_sprites(ci: CanvasItem) -> void:
	var tex := PopAtlas.texture()
	var regs := {}
	for n: String in ["piece_a", "piece_b", "piece_c", "coin", "smoke", "kernel", "sparkle"]:
		regs[n] = PopAtlas.region(n)
	for i in CAP:
		if life[i] <= 0.0:
			continue
		var fade := clampf(life[i] / 0.25, 0.0, 1.0)
		var name: String
		var d := size[i] * 2.0
		var col := Color(tint[i], fade)
		match kind[i]:
			1:
				name = "coin"
				col = Color.WHITE
			2:
				name = "smoke"
				col = Color(1, 1, 1, fade)
			3:
				name = "kernel"
				d = size[i] * 2.4
				col = Color(1, 1, 1, fade)
			4:
				name = "sparkle"
				col = Color(1, 1, 1, clampf(life[i] / 0.3, 0.0, 1.0))
			_:
				name = PIECES[i % 3]
				d = size[i] * 2.3
				# The source is cream: white keeps it, a tint (gold, brown) multiplies it.
				col = Color(tint[i].r / PopPalette.CREAM.r, tint[i].g / PopPalette.CREAM.g, tint[i].b / PopPalette.CREAM.b, fade)
		var r: Rect2 = regs[name]
		var k := d / maxf(r.size.x, r.size.y)
		var s := r.size * k
		ci.draw_set_transform(pos[i], rot[i] if kind[i] != 1 else 0.0, Vector2.ONE)
		ci.draw_texture_rect_region(tex, Rect2(-s / 2, s), r, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A full pool never swallows a new piece: the piece closest to its end gives
## its slot up (fast taps must always show, Step 04 addendum). `dropped`
## counts those replacements.
func _spawn(k: int, p: Vector2, v: Vector2, t: float, s: float, r: float, col: Color = PopPalette.CREAM) -> void:
	var slot := -1
	var oldest := INF
	for i in CAP:
		if life[i] <= 0.0:
			slot = i
			break
		if life[i] < oldest:
			oldest = life[i]
			slot = i
	if life[slot] > 0.0:
		dropped += 1
	pos[slot] = p; vel[slot] = v; life[slot] = t; size[slot] = s; rot[slot] = r; kind[slot] = k; tint[slot] = col
