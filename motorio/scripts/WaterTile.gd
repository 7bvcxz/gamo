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
	draw_rect(Rect2(-16, -16, 32, 32), Color("1d6c80"))
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.46, 0.85, 0.91, 0.22), false, 1.0)
	var wave := WAVE_COLOR if not get_meta("bridged", false) else Color("376a70")
	draw_arc(Vector2(-5, -5), 8.0, PI * 1.1, PI * 1.75, 8, wave, 1.5)
	draw_arc(Vector2(5, 7), 8.0, PI * 0.1, PI * 0.75, 8, wave, 1.5)
	draw_line(Vector2(-14, 14), Vector2(-5, 5), Color(0.72, 0.94, 1.0, 0.55), 1.0)
	draw_line(Vector2(14, -14), Vector2(6, -6), Color(0.72, 0.94, 1.0, 0.55), 1.0)
