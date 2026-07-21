extends CharacterBody2D

const SPEED := 220.0
const SPRINT_MULTIPLIER := 1.8
const RADIUS := 11.0
const PUSH_FORCE := 2200.0
const SPRITE_SCALE := 0.115
const FRAME_CENTER := Vector2(181.0, 181.0)
const TARGET_FOOT := Vector2(0.0, 13.0)
const MODE_LIGHT_DISTANCE := 22.0
const MODE_IN_LIGHT := Color(0.2, 0.72, 1.0, 0.34)
const MODE_OUT_LIGHT := Color(1.0, 0.22, 0.18, 0.34)
const FRAME_FOOT_ANCHORS := [
	Vector2(249.0, 339.0), Vector2(193.5, 339.0), Vector2(199.0, 339.0), Vector2(91.5, 339.0),
	Vector2(249.0, 321.0), Vector2(195.5, 321.0), Vector2(202.0, 320.0), Vector2(91.5, 321.0),
	Vector2(250.0, 301.0), Vector2(200.0, 289.0), Vector2(202.5, 304.0), Vector2(105.0, 306.0),
]

var world_bounds := Rect2()
var facing := Vector2.DOWN
var walk_phase := 0.0
var animation_time := 0.0
var touch_direction := Vector2.ZERO
var touch_sprint := false
var controls_locked := false
var mode_light_color := MODE_IN_LIGHT

@onready var character: Sprite2D = $Character

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	queue_redraw()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if controls_locked:
		direction = Vector2.ZERO
	if not touch_direction.is_zero_approx():
		direction = Vector2.ZERO if controls_locked else touch_direction
	if not direction.is_zero_approx():
		facing = direction.normalized()
		walk_phase += delta * 12.0
	else:
		walk_phase = 0.0
	var sprinting := Input.is_action_pressed("sprint") or touch_sprint
	var speed_multiplier := SPRINT_MULTIPLIER if sprinting else 1.0
	velocity = direction * SPEED * speed_multiplier
	_update_character_animation(delta, direction, sprinting)
	move_and_slide()
	_push_rigid_bodies()
	queue_redraw()

	# Keep the complete character inside the 100 × 100 tile world.
	position.x = clamp(position.x, world_bounds.position.x + RADIUS, world_bounds.end.x - RADIUS)
	position.y = clamp(position.y, world_bounds.position.y + RADIUS, world_bounds.end.y - RADIUS)

func _update_character_animation(delta: float, direction: Vector2, sprinting: bool) -> void:
	animation_time += delta
	if abs(facing.x) > 0.15:
		character.flip_h = facing.x < 0.0
	if direction.is_zero_approx():
		_set_idle_animation()
	else:
		_set_motion_animation(sprinting)

func _set_idle_animation() -> void:
	# Keep one registered drawing for idle. A tiny vertical scale pulse creates
	# breathing without swapping differently composed generated frames.
	var breath := 1.0 + sin(animation_time * 3.2) * 0.012
	character.rotation = 0.0
	character.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * breath)
	_set_character_frame(0)

func _set_motion_animation(sprinting: bool) -> void:
	# Generated action frames do not share a continuous silhouette. Animate one
	# registered pose per state so movement stays readable without lateral jumps.
	var rate: float = 13.0 if sprinting else 8.5
	var phase: float = animation_time * rate
	var stretch: float = sin(phase) * (0.045 if sprinting else 0.035)
	var squash: float = -stretch * 0.45
	var bounce: float = abs(sin(phase)) * (3.0 if sprinting else 2.0)
	character.rotation = sin(phase) * (0.075 if sprinting else 0.055)
	character.scale = Vector2(SPRITE_SCALE * (1.0 + squash), SPRITE_SCALE * (1.0 + stretch))
	_set_character_frame(8 if sprinting else 4, TARGET_FOOT - Vector2(0.0, bounce))

func _set_character_frame(frame_index: int, target_foot: Vector2 = TARGET_FOOT) -> void:
	character.frame = frame_index
	var foot_anchor: Vector2 = FRAME_FOOT_ANCHORS[frame_index]
	var foot_delta := foot_anchor - FRAME_CENTER
	if character.flip_h:
		foot_delta.x = -foot_delta.x
	foot_delta = (foot_delta * character.scale).rotated(character.rotation)
	character.position = target_foot - foot_delta

func _push_rigid_bodies() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as RigidBody2D
		if body:
			body.apply_central_force(-collision.get_normal() * PUSH_FORCE)

func set_out_mode_light(out_mode: bool) -> void:
	mode_light_color = MODE_OUT_LIGHT if out_mode else MODE_IN_LIGHT
	queue_redraw()

func get_mode_light_position() -> Vector2:
	var direction := facing.normalized()
	if abs(direction.x) > abs(direction.y):
		direction = Vector2(sign(direction.x), 0.0)
	else:
		direction = Vector2(0.0, sign(direction.y))
	return direction * MODE_LIGHT_DISTANCE

func _draw() -> void:
	# A soft light marks the interaction cell directly in front of the player.
	var light_position := get_mode_light_position()
	draw_set_transform(light_position, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 15.0, Color(mode_light_color, mode_light_color.a * 0.22))
	draw_circle(Vector2.ZERO, 10.0, Color(mode_light_color, mode_light_color.a * 0.48))
	draw_circle(Vector2.ZERO, 5.0, mode_light_color)
	draw_set_transform(Vector2.ZERO)
	# Isometric-style ground shadow beneath the animated character.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 15), 10.0, Color(0.02, 0.03, 0.025, 0.45))
	draw_set_transform(Vector2.ZERO)
