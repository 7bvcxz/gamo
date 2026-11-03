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
var kind := PackedByteArray()        # 0 popcorn, 1 coin
var target := Vector2.ZERO           # where coins fly (the money counter)
var alive := 0
var peak := 0
var dropped := 0


func _init() -> void:
	pos.resize(CAP); vel.resize(CAP); life.resize(CAP); size.resize(CAP); rot.resize(CAP); kind.resize(CAP)


func clear() -> void:
	life.fill(0.0)
	alive = 0


## `n` popcorn pieces bursting up out of `from`.
func burst(from: Vector2, n: int, scale: float, rng: RandomNumberGenerator) -> void:
	for i in n:
		var a := -PI / 2 + rng.randf_range(-0.9, 0.9)
		var speed := rng.randf_range(650.0, 1150.0) * scale
		_spawn(0, from + Vector2(rng.randf_range(-20, 20), 0) * scale, Vector2(cos(a), sin(a)) * speed,
			rng.randf_range(0.9, 1.3), rng.randf_range(15.0, 22.0) * scale, rng.randf() * TAU)


func coin(from: Vector2, scale: float) -> void:
	_spawn(1, from, Vector2.ZERO, 0.55, 20.0 * scale, 0.0)


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
		else:
			vel[i] += Vector2(0, GRAVITY) * delta
			pos[i] += vel[i] * delta
			rot[i] += delta * 3.0
		if life[i] > 0.0:
			alive += 1
	peak = maxi(peak, alive)


func draw(ci: CanvasItem) -> void:
	for i in CAP:
		if life[i] <= 0.0:
			continue
		if kind[i] == 1:
			PopMachineArt.draw_coin(ci, pos[i], size[i])
		else:
			var fade := clampf(life[i] / 0.25, 0.0, 1.0)
			PopMachineArt.draw_piece(ci, pos[i], size[i], rot[i], Color(PopPalette.CREAM, fade))


func _spawn(k: int, p: Vector2, v: Vector2, t: float, s: float, r: float) -> void:
	for i in CAP:
		if life[i] <= 0.0:
			pos[i] = p; vel[i] = v; life[i] = t; size[i] = s; rot[i] = r; kind[i] = k
			return
	dropped += 1
