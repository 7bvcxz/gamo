extends Node2D
class_name PlayerActor

## The engineer. Movement is intentionally snappy: high acceleration, short
## stop, and a visible facing cell so building never feels ambiguous.

const SPEED := 168.0
const SPRINT := 1.7
const ACCEL := 1500.0
const FRICTION := 1900.0

var velocity := Vector2.ZERO
var facing := Vector2i.RIGHT
var warmth := 100.0
var locked := false
var _step_phase := 0.0
var _bob := 0.0
var _flip := 1.0

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not locked:
		input = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
		if input.length() > 1.0:
			input = input.normalized()
	var sprinting: bool = Input.is_action_pressed("sprint") and not locked
	var target: Vector2 = input * SPEED * (SPRINT if sprinting else 1.0)
	if input == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	else:
		velocity = velocity.move_toward(target, ACCEL * delta)
		if absf(input.x) > 0.25:
			facing = Vector2i(signi(int(signf(input.x))), 0)
			_flip = signf(input.x)
		elif absf(input.y) > 0.25:
			facing = Vector2i(0, signi(int(signf(input.y))))
	position += velocity * delta

	var moving: float = velocity.length() / SPEED
	_step_phase += delta * (7.0 + moving * 6.0)
	_bob = sin(_step_phase) * minf(moving, 1.4) * 1.9
	queue_redraw()

func facing_cell() -> Vector2i:
	return Vector2i((position / float(Defs.TILE)).floor()) + facing

func cell() -> Vector2i:
	return Vector2i((position / float(Defs.TILE)).floor())

func _draw() -> void:
	var chill: float = clampf(1.0 - warmth / 100.0, 0.0, 1.0)
	var coat := Color("2f6d72").lerp(Color("4a6d9c"), chill * 0.6)
	var skin := Color("f7ddc4").lerp(Color("bcd0ea"), chill * 0.7)
	var scarf := Color("e8574c").lerp(Color("a8544f"), chill * 0.5)
	var y := _bob

	# Soft ground shadow keeps the character anchored to the grid.
	draw_circle(Vector2(0, 11), 7.0, Color(0.02, 0.04, 0.08, 0.35))

	# Legs alternate with the walk phase.
	var stride: float = sin(_step_phase) * 3.0 * clampf(velocity.length() / SPEED, 0.0, 1.2)
	draw_line(Vector2(-2.5, 4 + y), Vector2(-2.5 + stride, 11 + y), coat.darkened(0.35), 3.0)
	draw_line(Vector2(2.5, 4 + y), Vector2(2.5 - stride, 11 + y), coat.darkened(0.35), 3.0)

	# Body.
	draw_rect(Rect2(-6, -5 + y, 12, 11), coat)
	draw_rect(Rect2(-6, -5 + y, 12, 3), scarf)
	# Head.
	draw_circle(Vector2(0, -10 + y), 6.0, skin)
	draw_arc(Vector2(0, -10 + y), 6.0, PI, TAU, 10, Color("3a2a34"), 3.0)
	# A single warm highlight so she stays readable against the snow.
	draw_circle(Vector2(2.0 * _flip, -11 + y), 1.4, Color("3a2a34"))

	# Facing pip: tiny, but it is the whole build-targeting contract.
	var pip := Vector2(facing.x, facing.y) * 13.0
	draw_circle(pip + Vector2(0, y), 2.2, Defs.COL_CORE)
