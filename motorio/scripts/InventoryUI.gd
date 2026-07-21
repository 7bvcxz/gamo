extends Control

const SLOT_SIZE := 36.0
const SLOT_GAP := 6.0
const SLOT_COUNT := 5

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null:
		return
	var total_width: float = SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * SLOT_GAP
	var start := Vector2((size.x - total_width) / 2.0, size.y - 48.0)
	var items: Array = main_controller.inventory
	for index in SLOT_COUNT:
		var rect := Rect2(start + Vector2(index * (SLOT_SIZE + SLOT_GAP), 0.0), Vector2.ONE * SLOT_SIZE)
		draw_rect(rect, Color(0.07, 0.1, 0.09, 0.82))
		var selected: bool = index == main_controller.selected_slot
		draw_rect(rect, Color("f2bd45") if selected else Color("7e9187"), false, 3.0 if selected else 1.0)
		if index < items.size():
			var item: Dictionary = items[index]
			var inner: Rect2 = rect.grow(-7.0)
			if item["type"] == "conveyor":
				draw_rect(inner, Color("46535b"))
				draw_polyline(PackedVector2Array([inner.position + Vector2(5, 4), inner.get_center(), inner.position + Vector2(5, inner.size.y - 4)]), Color("e0a83d"), 2.0)
			elif item["type"] == "cat":
				draw_rect(inner, Color("d99a56"))
				draw_circle(inner.get_center(), 7.0, Color("fff0cf"))
				draw_circle(inner.get_center() + Vector2(2, -2), 1.2, Color("382c2a"))
			elif item["type"] == "pillar":
				draw_rect(inner, Color("777f82"))
				draw_rect(inner.grow(-4.0), Color("b8c0be"))
				draw_line(inner.position + Vector2(7, 5), inner.position + Vector2(7, inner.size.y - 5), Color(1, 1, 1, 0.4), 2.0)
			elif item["type"] == "box_generator":
				draw_rect(inner, Color("405b61"))
				draw_circle(inner.position + Vector2(7, inner.size.y / 2.0), 4.0, Color("8ee4df"))
				draw_rect(Rect2(inner.position + Vector2(12, 5), Vector2(10, 12)), Color("8b5a30"))
				draw_polygon(PackedVector2Array([inner.position + Vector2(25, 11), inner.position + Vector2(20, 7), inner.position + Vector2(20, 15)]), PackedColorArray([Color("f0bd4f")]))
			else:
				draw_rect(inner, Color("8b5a30"))
				draw_line(inner.position, inner.end, Color("4f2f19"), 2.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, rect.position + Vector2(3, 11), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.92, 0.88))
