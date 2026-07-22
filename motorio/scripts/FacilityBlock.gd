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
	draw_circle(Vector2(2, 5), 15.0, Color(0.03, 0.09, 0.10, 0.25))
	if facility_type == "fishing_spot":
		UIVisuals.draw_panel(self, Rect2(-15, -15, 30, 30), Color("24778a"), Color("78cad6"), 6, 2)
		for y in [-8.0, 0.0, 8.0]:
			draw_line(Vector2(-10, y), Vector2(10, y), Color(0.60, 0.91, 0.94, 0.58), 1.0)
		draw_polygon(PackedVector2Array([Vector2(-8, 2), Vector2(0, -4), Vector2(7, 2), Vector2(0, 7)]), PackedColorArray([Color("d7edf0")]))
		draw_circle(Vector2(2, -1), 1.3, Color("29444a"))
	else:
		UIVisuals.draw_panel(self, Rect2(-15, -15, 30, 30), Color("405d65"), Color("8aa3a5"), 6, 2)
		UIVisuals.draw_panel(self, Rect2(-10, -10, 20, 20), Color("203f45"), Color(0.59, 0.75, 0.75, 0.5), 4, 1)
		draw_polygon(PackedVector2Array([Vector2(2, -11), Vector2(-6, 2), Vector2(1, 2), Vector2(-2, 11), Vector2(8, -3), Vector2(1, -3)]), PackedColorArray([Color("f3d650")]))
