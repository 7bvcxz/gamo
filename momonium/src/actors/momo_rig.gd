class_name MomoRig
extends Node2D

## Momo, assembled from parts and moved by code.
##
## The parts (assets/src/svg/momo/*.svg) share one 200x220 frame; each carries
## its joint (hip, shoulder, neck, ear root ...) in that frame, so putting
## every part at its joint rebuilds the drawing exactly, and then any joint can
## turn. The node's origin is where Momo's feet touch the ground -- the same
## origin convention as every other world sprite, so depth sorting works.
##
## States are light loops computed from time, not frame-by-frame art:
##   idle   breathing, ears swaying, a blink every few seconds, a look around now and then
##   walk   legs and arms swinging, a bob in the step, ears bouncing
##   sit    legs out in front, body lowered, still breathing
##   sleep  curled low, eyes closed, slow breaths, little z's rising
##   work   leaning in, arms busy in turn (the job's own tool comes later)
## `facing` picks the front or the back view and mirrors for left/right.
## Special outfits for later jobs attach to the "hand_r" point.

const FRAME_ORIGIN := Vector2(100, 210)
## World pixels per frame unit: Momo stands about 70 px tall, a bit over half a tile.
const UNIT := 0.33
const STATES: PackedStringArray = ["idle", "walk", "sit", "sleep", "work"]

var state := "idle"
var facing := Vector2(1, 1)
var walk_speed := 1.0
var time := 0.0
var blinking := false
var looking := 0.0

var body_root: Node2D
var head_root: Node2D
var parts: Dictionary = {}
var _lib: SpriteLibrary
var _rng := RandomNumberGenerator.new()
var _next_blink := 2.0
var _blink_until := -1.0
var _next_look := 5.0
var _look_until := -1.0
var _look_dir := 1.0
var _back := false


func setup(lib: SpriteLibrary, seed_value: int = 0) -> void:
	_lib = lib
	_rng.seed = seed_value
	_next_blink = _rng.randf_range(1.5, 4.0)
	_next_look = _rng.randf_range(3.0, 7.0)
	body_root = Node2D.new()
	body_root.name = "Body"
	add_child(body_root)
	for part: String in ["leg_l", "leg_r", "body", "arm_l", "arm_r"]:
		parts[part] = _part(part, body_root, FRAME_ORIGIN)
	head_root = Node2D.new()
	head_root.name = "Head"
	head_root.position = (_joint("head") - FRAME_ORIGIN) * UNIT
	body_root.add_child(head_root)
	for part: String in ["head", "eyes", "tuft", "ear_l", "ear_r"]:
		parts[part] = _part(part, head_root, _joint("head"))
	_apply_view()
	tick(0.0)


func _sprite_name(part: String) -> String:
	match part:
		"eyes":
			return "momo_eyes_closed" if blinking else "momo_eyes_open"
		"head":
			return "momo_head_back" if _back else "momo_head"
		"body":
			return "momo_body_back" if _back else "momo_body"
	return "momo_" + part


func _joint(part: String) -> Vector2:
	var name := _sprite_name(part)
	var j: Array = _lib.meta(name).get("frame_joint", [100, 120])
	return Vector2(j[0], j[1])


func _part(part: String, parent: Node2D, parent_joint: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = part
	parent.add_child(s)
	s.position = (_joint(part) - parent_joint) * UNIT
	_skin(s, part)
	return s


func _skin(s: Sprite2D, part: String) -> void:
	var name := _sprite_name(part)
	_lib.place(s, name, "joint")
	s.scale = Vector2.ONE * (UNIT / _lib.source_scale(name))


func set_state(p_state: String) -> void:
	if STATES.has(p_state):
		state = p_state


## Screen-space direction Momo looks or walks towards. Moving up the screen
## shows the back; left is the right side mirrored.
func face(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	facing = direction
	var back := direction.y < -0.15
	if back != _back:
		_back = back
		_apply_view()
	scale.x = -1.0 if direction.x < 0.0 else 1.0


func is_back_view() -> bool:
	return _back


func _apply_view() -> void:
	for part: String in ["head", "body", "eyes"]:
		if parts.has(part):
			_skin(parts[part], part)
	if parts.has("eyes"):
		(parts["eyes"] as Sprite2D).visible = not _back
	# From behind the arms are partly hidden by the body: draw them first.
	if parts.has("arm_l"):
		body_root.move_child(parts["arm_l"], 0 if _back else 3)
		body_root.move_child(parts["arm_r"], 0 if _back else 4)


func _process(delta: float) -> void:
	tick(delta)


## Advances the animation by `delta` seconds and poses every joint. Pure
## presentation: it never touches the simulation.
func tick(delta: float) -> void:
	time += delta
	_update_blink()
	var t := time
	var lb: Sprite2D = parts["leg_l"]
	var rb: Sprite2D = parts["leg_r"]
	var la: Sprite2D = parts["arm_l"]
	var ra: Sprite2D = parts["arm_r"]
	var el: Sprite2D = parts["ear_l"]
	var er: Sprite2D = parts["ear_r"]
	var eyes: Sprite2D = parts["eyes"]
	var base_head := (_joint("head") - FRAME_ORIGIN) * UNIT
	var leg_scale := 1.0
	var body_y := 0.0
	var breathe := sin(t * TAU * 0.45)
	var head_rot := 0.0
	var ear_l := 0.04 * sin(t * 1.3)
	var ear_r := -0.04 * sin(t * 1.3 + 0.6)
	var leg_l := 0.0
	var leg_r := 0.0
	var arm_l := 0.05 * breathe
	var arm_r := -0.05 * breathe
	match state:
		"walk":
			var phase := t * TAU * 2.2 * walk_speed
			leg_l = 0.38 * sin(phase)
			leg_r = -0.38 * sin(phase)
			arm_l = -0.32 * sin(phase)
			arm_r = 0.32 * sin(phase)
			body_y = -absf(sin(phase)) * 2.4
			ear_l += 0.1 * sin(phase * 2.0)
			ear_r -= 0.1 * sin(phase * 2.0)
			breathe = 0.0
		"sit":
			leg_scale = 0.55
			leg_l = 0.5
			leg_r = -0.5
			body_y = 10.0
			arm_l = 0.25
			arm_r = -0.25
		"work":
			var w := t * TAU * 1.6
			arm_l = -0.55 + 0.35 * sin(w)
			arm_r = 0.55 - 0.35 * sin(w + PI)
			body_y = 1.5 + absf(sin(w)) * 1.5
			head_rot = 0.06
			ear_l += 0.06 * sin(w)
			ear_r -= 0.06 * sin(w)
			breathe = 0.0
		"sleep":
			leg_scale = 0.45
			leg_l = 0.9
			leg_r = -0.9
			body_y = 17.0
			head_rot = 0.12
			breathe = sin(t * TAU * 0.22)
			ear_l = 0.35
			ear_r = -0.35
			arm_l = 0.5
			arm_r = -0.5
		_:
			if t < _look_until:
				head_rot = 0.07 * _look_dir
	lb.rotation = leg_l
	rb.rotation = leg_r
	lb.scale.y = absf(lb.scale.x) * leg_scale
	rb.scale.y = absf(rb.scale.x) * leg_scale
	la.rotation = arm_l
	ra.rotation = arm_r
	el.rotation = ear_l
	er.rotation = ear_r
	body_root.position = Vector2(0, body_y)
	body_root.scale = Vector2(1.0 - 0.01 * breathe, 1.0 + 0.02 * breathe)
	head_root.position = base_head + Vector2(0, -1.2 * breathe)
	head_root.rotation = head_rot
	var closed := blinking or state == "sleep"
	var want := "momo_eyes_closed" if closed else "momo_eyes_open"
	if eyes.region_rect != _lib.region(want):
		_lib.place(eyes, want, "joint")
		eyes.scale = Vector2.ONE * (UNIT / _lib.source_scale(want))
	looking = 0.0
	if state == "idle" and t < _look_until and not closed:
		looking = _look_dir
		eyes.position = (_joint("eyes") - _joint("head")) * UNIT + Vector2(2.2 * _look_dir, 0)
	else:
		eyes.position = (_joint("eyes") - _joint("head")) * UNIT
	queue_redraw()


func _update_blink() -> void:
	if time >= _blink_until and blinking:
		blinking = false
	if time >= _next_blink:
		blinking = true
		_blink_until = time + 0.13
		_next_blink = time + _rng.randf_range(2.2, 5.0)
	if state == "idle" and time >= _next_look:
		_look_dir = -1.0 if _rng.randf() < 0.5 else 1.0
		_look_until = time + 1.3
		_next_look = time + _rng.randf_range(4.0, 8.0)


## Where a held tool goes (front view, in this node's space).
func hand_point() -> Vector2:
	return (Vector2(146, 156) - FRAME_ORIGIN) * UNIT + body_root.position


func _draw() -> void:
	# A soft shadow on the ground under the feet.
	var w := 22.0 if state != "sleep" else 28.0
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, w, Color(0.05, 0.15, 0.1, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == "sleep":
		for i in 3:
			var k := fposmod(time * 0.35 + i / 3.0, 1.0)
			var p := Vector2(14.0 + k * 14.0, -38.0 - k * 26.0)
			var s := 3.0 + i
			var c := Color(0.55, 0.75, 1.0, 1.0 - k)
			draw_line(p, p + Vector2(s, 0), c, 1.6, true)
			draw_line(p + Vector2(s, 0), p + Vector2(0, s), c, 1.6, true)
			draw_line(p + Vector2(0, s), p + Vector2(s, s), c, 1.6, true)
