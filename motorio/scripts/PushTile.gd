extends RigidBody2D

const TILE_SIZE := 32.0

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	add_to_group("box_block")
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
	# Cream cat inspection sticker on the crate lid.
	draw_circle(Vector2(0, -3), 7.0, Color("f5dfaa"))
	draw_polygon(PackedVector2Array([Vector2(-6, -7), Vector2(-4, -13), Vector2(-1, -8)]), PackedColorArray([Color("f5dfaa")]))
	draw_polygon(PackedVector2Array([Vector2(1, -8), Vector2(4, -13), Vector2(6, -7)]), PackedColorArray([Color("f5dfaa")]))
	draw_circle(Vector2(-2.5, -4), 1.0, Color("473426"))
	draw_circle(Vector2(2.5, -4), 1.0, Color("473426"))
	draw_line(Vector2(-2, 0), Vector2(0, 1), Color("9a5f54"), 1.0)
	draw_line(Vector2(0, 1), Vector2(2, 0), Color("9a5f54"), 1.0)
