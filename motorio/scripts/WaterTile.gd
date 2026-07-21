extends StaticBody2D
class_name WaterTile

const WATER_COLOR := Color("17647b")
const EDGE_COLOR := Color("0b4055")
const WAVE_COLOR := Color("71cfe0")

func _ready() -> void:
	add_to_group("water_tile")
	add_to_group("fixed")
	queue_redraw()

func set_bridged(value: bool) -> void:
	$CollisionShape2D.disabled = value
	set_meta("bridged", value)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-16, -16, 32, 32), WATER_COLOR)
	draw_rect(Rect2(-15, -15, 30, 30), EDGE_COLOR, false, 2.0)
	var wave := WAVE_COLOR if not get_meta("bridged", false) else Color("376a70")
	draw_line(Vector2(-12, -6), Vector2(3, -6), wave, 2.0)
	draw_line(Vector2(-3, 6), Vector2(12, 6), wave, 2.0)
	draw_line(Vector2(-14, 14), Vector2(-5, 5), Color(0.72, 0.94, 1.0, 0.55), 1.0)
	draw_line(Vector2(14, -14), Vector2(6, -6), Color(0.72, 0.94, 1.0, 0.55), 1.0)
