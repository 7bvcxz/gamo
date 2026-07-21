extends RigidBody2D
class_name WorldResource

@export var resource_type := "copper"

func _ready() -> void:
	add_to_group("world_resource")
	add_to_group("resource_%s" % resource_type)
	add_to_group("solid")
	queue_redraw()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length_squared() < 1.0:
		state.linear_velocity = Vector2.ZERO

func _draw() -> void:
	var color: Color = {
		"copper": Color("e58b4f"), "coal": Color("6a747b"), "crystal": Color("c4a2ff"),
		"oil": Color("405274"), "uranium": Color("9bef67"),
	}.get(resource_type, Color.WHITE)
	draw_circle(Vector2.ZERO, 7.0, color.darkened(0.25))
	draw_polygon(PackedVector2Array([Vector2(0, -6), Vector2(6, 1), Vector2(2, 7), Vector2(-6, 3), Vector2(-4, -4)]), PackedColorArray([color]))
