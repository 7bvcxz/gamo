extends RigidBody2D
class_name FacilityBlock

@export var facility_type := "power_generator"

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	add_to_group("facility")
	add_to_group(facility_type)
	freeze = true
	queue_redraw()

func _draw() -> void:
	if facility_type == "cheese_field":
		draw_rect(Rect2(-15, -15, 30, 30), Color("6f5430"))
		for y in [-8.0, 0.0, 8.0]:
			draw_line(Vector2(-12, y), Vector2(12, y), Color("b28c4c"), 2.0)
		draw_circle(Vector2(-6, -4), 3.0, Color("efd65b"))
		draw_circle(Vector2(6, 5), 3.0, Color("efd65b"))
	else:
		draw_rect(Rect2(-15, -15, 30, 30), Color("43515a"))
		draw_rect(Rect2(-11, -11, 22, 22), Color("667781"), false, 3.0)
		draw_polygon(PackedVector2Array([Vector2(2, -11), Vector2(-6, 2), Vector2(1, 2), Vector2(-2, 11), Vector2(8, -3), Vector2(1, -3)]), PackedColorArray([Color("f3d650")]))
