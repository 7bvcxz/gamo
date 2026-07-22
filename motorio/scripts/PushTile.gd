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
	draw_rect(Rect2(tile_rect.position + Vector2(2, 3), tile_rect.size), Color(0.12, 0.07, 0.03, 0.3))
	UIVisuals.draw_panel(self, tile_rect, Color("9b6736"), Color("5b361d"), 4, 2)
	draw_rect(Rect2(-13, -12, 26, 5), Color("b97c40"))
	draw_line(Vector2(-11, 10), Vector2(11, 10), Color("5f391f"), 2.0)
	draw_line(Vector2(-11, -10), Vector2(-11, 11), Color(1.0, 0.78, 0.43, 0.28), 1.0)
	for rivet in [Vector2(-11, -10), Vector2(11, -10), Vector2(-11, 10), Vector2(11, 10)]:
		draw_circle(rivet, 1.3, Color("e2b35c"))
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
