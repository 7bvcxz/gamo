extends Node2D

const SPEED := 140.0

func _process(delta: float) -> void:
	var input_vector := Vector2(
		(int(Input.is_key_pressed(KEY_D)) + int(Input.is_key_pressed(KEY_RIGHT)))
		- (int(Input.is_key_pressed(KEY_A)) + int(Input.is_key_pressed(KEY_LEFT))),
		(int(Input.is_key_pressed(KEY_S)) + int(Input.is_key_pressed(KEY_DOWN)))
		- (int(Input.is_key_pressed(KEY_W)) + int(Input.is_key_pressed(KEY_UP)))
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	position += input_vector * SPEED * delta

func _draw() -> void:
	var hair_color := Color(0.32, 0.18, 0.42)
	var skin_color := Color(0.98, 0.85, 0.76)
	var dress_color := Color(0.92, 0.42, 0.58)
	var eye_color := Color(0.15, 0.1, 0.15)

	# hair back + twin buns
	draw_circle(Vector2(0, -16), 15.0, hair_color)
	draw_circle(Vector2(-14, -24), 6.0, hair_color)
	draw_circle(Vector2(14, -24), 6.0, hair_color)

	# face
	draw_circle(Vector2(0, -14), 12.0, skin_color)

	# eyes
	draw_circle(Vector2(-4, -14), 1.6, eye_color)
	draw_circle(Vector2(4, -14), 1.6, eye_color)

	# dress
	var dress_points := PackedVector2Array([
		Vector2(-9, -2), Vector2(9, -2), Vector2(15, 26), Vector2(-15, 26)
	])
	draw_colored_polygon(dress_points, dress_color)
