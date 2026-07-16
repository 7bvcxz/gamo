extends CharacterBody2D

const SPEED := 220.0
const RADIUS := 14.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	var input_vector := Vector2(
		(int(Input.is_key_pressed(KEY_D)) + int(Input.is_key_pressed(KEY_RIGHT)))
		- (int(Input.is_key_pressed(KEY_A)) + int(Input.is_key_pressed(KEY_LEFT))),
		(int(Input.is_key_pressed(KEY_S)) + int(Input.is_key_pressed(KEY_DOWN)))
		- (int(Input.is_key_pressed(KEY_W)) + int(Input.is_key_pressed(KEY_UP)))
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	velocity = input_vector * SPEED
	move_and_slide()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.25, 0.65, 0.95))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.1, 0.3, 0.5), false, 2.0)
