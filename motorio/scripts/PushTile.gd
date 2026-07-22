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
	# Ginger-and-cream worker cat sticker matching the illustrated cat family.
	draw_circle(Vector2(0, -3), 8.0, Color("fff0cf"))
	draw_polygon(PackedVector2Array([Vector2(-7, -7), Vector2(-5, -14), Vector2(-1, -9)]), PackedColorArray([Color("f3a34d")]))
	draw_polygon(PackedVector2Array([Vector2(1, -9), Vector2(5, -14), Vector2(7, -7)]), PackedColorArray([Color("f3a34d")]))
	draw_polygon(PackedVector2Array([Vector2(-5, -8), Vector2(-4.5, -11.5), Vector2(-2.5, -8.5)]), PackedColorArray([Color("efaaa1")]))
	draw_polygon(PackedVector2Array([Vector2(2.5, -8.5), Vector2(4.5, -11.5), Vector2(5, -8)]), PackedColorArray([Color("efaaa1")]))
	draw_arc(Vector2.ZERO, 7.3, PI, TAU, 12, Color("e88735"), 3.0)
	draw_polygon(PackedVector2Array([Vector2(-2, -10), Vector2(0, -6), Vector2(2, -10)]), PackedColorArray([Color("e88735")]))
	draw_circle(Vector2(-2.7, -3.5), 1.45, Color("5a341e"))
	draw_circle(Vector2(2.7, -3.5), 1.45, Color("5a341e"))
	draw_circle(Vector2(-2.3, -3.9), 0.45, Color.WHITE)
	draw_circle(Vector2(3.1, -3.9), 0.45, Color.WHITE)
	draw_circle(Vector2(0, -0.8), 1.0, Color("dc7f73"))
	draw_line(Vector2(0, 0), Vector2(-2, 1.5), Color("8a5747"), 0.9)
	draw_line(Vector2(0, 0), Vector2(2, 1.5), Color("8a5747"), 0.9)
