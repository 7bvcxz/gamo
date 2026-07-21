extends CharacterBody2D

const SPEED := 220.0
const SPRINT_MULTIPLIER := 1.8
const RADIUS := 11.0
const PUSH_FORCE := 2200.0
const SPRITE_SCALE := 0.115
const FRAME_CENTER := Vector2(181.0, 181.0)
const TARGET_FOOT := Vector2(0.0, 13.0)
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

@onready var character: Sprite2D = $Character

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	queue_redraw()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not touch_direction.is_zero_approx():
		direction = touch_direction
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
	var row := 0
	var frames_per_second := 4.0
	if not direction.is_zero_approx():
		row = 2 if sprinting else 1
		frames_per_second = 14.0 if sprinting else 9.0
	animation_time += delta
	_set_character_frame(row * 4 + int(animation_time * frames_per_second) % 4)
	if abs(facing.x) > 0.15:
		character.flip_h = facing.x < 0.0

func _set_character_frame(frame_index: int) -> void:
	character.frame = frame_index
	var foot_anchor: Vector2 = FRAME_FOOT_ANCHORS[frame_index]
	character.position = TARGET_FOOT - (foot_anchor - FRAME_CENTER) * SPRITE_SCALE

func _push_rigid_bodies() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as RigidBody2D
		if body:
			body.apply_central_force(-collision.get_normal() * PUSH_FORCE)

func _draw() -> void:
	# Isometric-style ground shadow beneath the animated character.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 15), 10.0, Color(0.02, 0.03, 0.025, 0.45))
	draw_set_transform(Vector2.ZERO)
