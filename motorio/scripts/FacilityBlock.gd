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
	if facility_type == "fishing_spot":
		draw_rect(Rect2(-15, -15, 30, 30), Color("236f86"))
		for y in [-8.0, 0.0, 8.0]:
			draw_line(Vector2(-12, y), Vector2(12, y), Color("75cadd"), 1.0)
		draw_polygon(PackedVector2Array([Vector2(-8, 2), Vector2(0, -4), Vector2(7, 2), Vector2(0, 7)]), PackedColorArray([Color("d7edf0")]))
	else:
		draw_rect(Rect2(-15, -15, 30, 30), Color("43515a"))
		draw_rect(Rect2(-11, -11, 22, 22), Color("667781"), false, 3.0)
		draw_polygon(PackedVector2Array([Vector2(2, -11), Vector2(-6, 2), Vector2(1, 2), Vector2(-2, 11), Vector2(8, -3), Vector2(1, -3)]), PackedColorArray([Color("f3d650")]))
