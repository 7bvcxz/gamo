extends RigidBody2D

func _ready() -> void:
	add_to_group("mined_resource")
	add_to_group("solid")
	queue_redraw()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length_squared() < 1.0:
		state.linear_velocity = Vector2.ZERO

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color("78d5dc"))
	draw_polygon(PackedVector2Array([Vector2(0, -6), Vector2(6, 2), Vector2(1, 7), Vector2(-6, 3), Vector2(-4, -4)]), PackedColorArray([Color("a9f0ea")]))
