extends Node2D
class_name PlayerActor

## The engineer. The artwork and the animation approach are carried over from
## Motorio: one registered pose per state, animated with squash, bounce and a
## foot anchor, because the generated sheet's frames do not share a continuous
## silhouette and cross-fading them made the character jitter sideways.

const SPEED := 168.0
const SPRINT := 1.7
const ACCEL := 1500.0
const FRICTION := 1900.0

const SPRITE_SCALE := 0.105
const FRAME_CENTER := Vector2(181.0, 181.0)
const TARGET_FOOT := Vector2(0.0, 12.0)
## Where the feet sit inside each generated frame. Aligning to these instead of
## the frame centre is what stops the character sliding when the pose changes.
const FRAME_FOOT_ANCHORS := [
	Vector2(249.0, 339.0), Vector2(193.5, 339.0), Vector2(199.0, 339.0), Vector2(91.5, 339.0),
	Vector2(249.0, 321.0), Vector2(195.5, 321.0), Vector2(202.0, 320.0), Vector2(91.5, 321.0),
	Vector2(250.0, 301.0), Vector2(200.0, 289.0), Vector2(202.5, 304.0), Vector2(105.0, 306.0),
]

var velocity := Vector2.ZERO
var facing := Vector2i.RIGHT
var warmth := 100.0
var locked := false
var animation_time := 0.0

@onready var character: Sprite2D = $Character

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
		elif absf(input.y) > 0.25:
			facing = Vector2i(0, signi(int(signf(input.y))))
	position += velocity * delta

	_animate(delta, input, sprinting)
	queue_redraw()

func _animate(delta: float, input: Vector2, sprinting: bool) -> void:
	animation_time += delta
	if absf(input.x) > 0.15:
		character.flip_h = input.x < 0.0
	# Cold drains the colour out of her the same way it does the world.
	var chill: float = clampf(1.0 - warmth / 100.0, 0.0, 1.0)
	character.modulate = Color.WHITE.lerp(Color(0.70, 0.80, 1.0), chill * 0.65)
	if input.is_zero_approx():
		_idle()
	else:
		_moving(sprinting)

func _idle() -> void:
	var breath: float = 1.0 + sin(animation_time * 3.2) * 0.012
	character.rotation = 0.0
	character.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * breath)
	_set_frame(0)

func _moving(sprinting: bool) -> void:
	var rate: float = 13.0 if sprinting else 8.5
	var phase: float = animation_time * rate
	var stretch: float = sin(phase) * (0.045 if sprinting else 0.035)
	var squash: float = -stretch * 0.45
	var bounce: float = absf(sin(phase)) * (3.0 if sprinting else 2.0)
	character.rotation = sin(phase) * (0.075 if sprinting else 0.055)
	character.scale = Vector2(SPRITE_SCALE * (1.0 + squash), SPRITE_SCALE * (1.0 + stretch))
	_set_frame(8 if sprinting else 4, TARGET_FOOT - Vector2(0.0, bounce))

func _set_frame(frame_index: int, target_foot: Vector2 = TARGET_FOOT) -> void:
	character.frame = frame_index
	var foot_delta: Vector2 = FRAME_FOOT_ANCHORS[frame_index] - FRAME_CENTER
	if character.flip_h:
		foot_delta.x = -foot_delta.x
	foot_delta = (foot_delta * character.scale).rotated(character.rotation)
	character.position = target_foot - foot_delta

func facing_cell() -> Vector2i:
	return Vector2i((position / float(Defs.TILE)).floor()) + facing

func cell() -> Vector2i:
	return Vector2i((position / float(Defs.TILE)).floor())

func _draw() -> void:
	# Flattened ground shadow, drawn under the sprite so she is anchored to the
	# grid rather than floating over it.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 26), 9.0, Color(0.02, 0.04, 0.08, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The facing pip is the whole build-targeting contract, so it stays.
	draw_circle(Vector2(facing.x, facing.y) * 15.0, 2.4, Defs.COL_CORE)
