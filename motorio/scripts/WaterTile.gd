extends StaticBody2D
class_name WaterTile

func _ready() -> void:
	add_to_group("water_tile")
	add_to_group("fixed")
	queue_redraw()

func set_bridged(value: bool) -> void:
	$CollisionShape2D.disabled = value
	set_meta("bridged", value)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-16, -16, 32, 32), Color("245d70"))
	var wave := Color("4a96a6") if not get_meta("bridged", false) else Color("376a70")
	draw_line(Vector2(-12, -6), Vector2(3, -6), wave, 2.0)
	draw_line(Vector2(-3, 6), Vector2(12, 6), wave, 2.0)
