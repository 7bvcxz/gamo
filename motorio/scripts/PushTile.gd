extends RigidBody2D

const TILE_SIZE := 32.0

func _ready() -> void:
	queue_redraw()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Remove tiny residual motion once the player is no longer pushing.
	if state.linear_velocity.length_squared() < 4.0:
		state.linear_velocity = Vector2.ZERO

func _draw() -> void:
	var tile_rect := Rect2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0, TILE_SIZE, TILE_SIZE)
	draw_rect(tile_rect, Color("7a4f2a"))
	draw_rect(tile_rect.grow(-3.0), Color("9a6938"), false, 2.0)
	draw_line(Vector2(-10, -10), Vector2(10, 10), Color(0.33, 0.19, 0.09, 0.7), 2.0)
	draw_line(Vector2(10, -10), Vector2(-10, 10), Color(0.33, 0.19, 0.09, 0.7), 2.0)
