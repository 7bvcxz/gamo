extends Control

var main_controller
var meow_phase := 0.0

func _process(delta: float) -> void:
	meow_phase = fmod(meow_phase + delta, 4.0)
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.shelter_open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("101820"))
	var center := size / 2.0
	# Timber floor, frosted windows, shelves and a round communal rug.
	for plank_y in range(0, int(size.y), 28):
		draw_rect(Rect2(0, plank_y, size.x, 27), Color("26302f") if plank_y / 28 % 2 == 0 else Color("202928"))
		draw_line(Vector2(0, plank_y), Vector2(size.x, plank_y), Color("39443f"), 1.0)
	for window_x in [size.x * 0.18, size.x * 0.82]:
		var window := Rect2(Vector2(window_x - 38, 68), Vector2(76, 58))
		draw_rect(window, Color("8fc4d2"))
		draw_rect(window.grow(-5), Color("dceef2"))
		draw_line(window.get_center() - Vector2(window.size.x / 2.0 - 5, 0), window.get_center() + Vector2(window.size.x / 2.0 - 5, 0), Color("69858c"), 3.0)
		draw_line(window.get_center() - Vector2(0, window.size.y / 2.0 - 5), window.get_center() + Vector2(0, window.size.y / 2.0 - 5), Color("69858c"), 3.0)
	draw_circle(center + Vector2(0, 18), minf(190.0, size.x * 0.38), Color("503d35"))
	draw_circle(center + Vector2(0, 18), minf(174.0, size.x * 0.34), Color("775346"))
	var glow_radius := minf(size.x, size.y) * 0.22
	for ring in range(5, 0, -1):
		draw_circle(center, glow_radius * float(ring) / 5.0, Color(0.9, 0.36, 0.08, 0.035 * ring))
	draw_circle(center + Vector2(0, 12), 30.0, Color("55351f"))
	draw_polygon(PackedVector2Array([center + Vector2(-18, 12), center + Vector2(0, -32), center + Vector2(18, 12)]), PackedColorArray([Color("f08a2d")]))
	draw_polygon(PackedVector2Array([center + Vector2(-8, 8), center + Vector2(3, -20), center + Vector2(11, 8)]), PackedColorArray([Color("ffd85a")]))
	for light_index in range(9):
		var light_x: float = size.x * 0.15 + light_index * size.x * 0.0875
		var light_y: float = 38.0 + sin(float(light_index) * 0.8) * 8.0
		if light_index > 0:
			draw_line(Vector2(size.x * 0.15 + (light_index - 1) * size.x * 0.0875, 38.0 + sin(float(light_index - 1) * 0.8) * 8.0), Vector2(light_x, light_y), Color("665f52"), 2.0)
		draw_circle(Vector2(light_x, light_y), 4.0, Color("ffd56a"))
	var cats: Array = get_tree().get_nodes_in_group("cat_worker")
	var shown := mini(cats.size(), 12)
	for index in shown:
		var angle := TAU * float(index) / float(maxi(shown, 1)) - PI / 2.0
		var cat_position := center + Vector2.from_angle(angle) * minf(150.0, size.x * 0.34)
		draw_rect(Rect2(cat_position + Vector2(-15, 8), Vector2(30, 18)), Color("56706d" if index % 2 == 0 else "6f586c"))
		draw_circle(cat_position, 13.0, Color("d9a45e"))
		draw_polygon(PackedVector2Array([cat_position + Vector2(-10, -7), cat_position + Vector2(-6, -17), cat_position + Vector2(-2, -7)]), PackedColorArray([Color("f0c47a")]))
		draw_polygon(PackedVector2Array([cat_position + Vector2(2, -7), cat_position + Vector2(6, -17), cat_position + Vector2(10, -7)]), PackedColorArray([Color("f0c47a")]))
		draw_circle(cat_position + Vector2(-4, -1), 1.4, Color("382c2a"))
		draw_circle(cat_position + Vector2(4, -1), 1.4, Color("382c2a"))
		draw_line(cat_position + Vector2(-3, 4), cat_position + Vector2(0, 5), Color("8f5b58"), 1.0)
		draw_line(cat_position + Vector2(0, 5), cat_position + Vector2(3, 4), Color("8f5b58"), 1.0)
		if int(meow_phase + index) % 4 == 0:
			var font := UIFont.FONT
			draw_string(font, cat_position + Vector2(-18, -23), "야옹", HORIZONTAL_ALIGNMENT_CENTER, 36, 9, Color("fff0cf"))
	var font := UIFont.FONT
	draw_string(font, Vector2(0, 44), "%d일차 밤  •  고양이들과 함께" % main_controller.day_number, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color("f4d18a"))
	draw_string(font, Vector2(0, size.y - 54), "Z 또는 Z 버튼  —  아침까지 자기", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color.WHITE)
	draw_string(font, Vector2(0, size.y - 28), "내일은 따뜻한 영역을 더 넓혀 보세요.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("aebdb7"))
