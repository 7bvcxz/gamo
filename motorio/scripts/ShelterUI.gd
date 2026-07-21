extends Control

var main_controller
var meow_phase := 0.0

func _process(delta: float) -> void:
	meow_phase = fmod(meow_phase + delta, 4.0)
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.shelter_open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("101b22"))
	var center := size / 2.0
	var glow_radius := minf(size.x, size.y) * 0.22
	for ring in range(5, 0, -1):
		draw_circle(center, glow_radius * float(ring) / 5.0, Color(0.9, 0.36, 0.08, 0.035 * ring))
	draw_circle(center + Vector2(0, 12), 30.0, Color("55351f"))
	draw_polygon(PackedVector2Array([center + Vector2(-18, 12), center + Vector2(0, -32), center + Vector2(18, 12)]), PackedColorArray([Color("f08a2d")]))
	draw_polygon(PackedVector2Array([center + Vector2(-8, 8), center + Vector2(3, -20), center + Vector2(11, 8)]), PackedColorArray([Color("ffd85a")]))
	var cats: Array = get_tree().get_nodes_in_group("cat_worker")
	var shown := mini(cats.size(), 12)
	for index in shown:
		var angle := TAU * float(index) / float(maxi(shown, 1)) - PI / 2.0
		var cat_position := center + Vector2.from_angle(angle) * minf(150.0, size.x * 0.34)
		draw_circle(cat_position, 13.0, Color("d9a45e"))
		draw_polygon(PackedVector2Array([cat_position + Vector2(-10, -7), cat_position + Vector2(-6, -17), cat_position + Vector2(-2, -7)]), PackedColorArray([Color("f0c47a")]))
		draw_polygon(PackedVector2Array([cat_position + Vector2(2, -7), cat_position + Vector2(6, -17), cat_position + Vector2(10, -7)]), PackedColorArray([Color("f0c47a")]))
		if int(meow_phase + index) % 4 == 0:
			var font := ThemeDB.fallback_font
			draw_string(font, cat_position + Vector2(-18, -23), "MEOW", HORIZONTAL_ALIGNMENT_CENTER, 36, 9, Color("fff0cf"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 44), "NIGHT %d  •  HOME WITH THE CATS" % main_controller.day_number, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color("f4d18a"))
	draw_string(font, Vector2(0, size.y - 54), "Z / TAP Z  —  SLEEP UNTIL MORNING", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color.WHITE)
	draw_string(font, Vector2(0, size.y - 28), "Tomorrow the warm frontier grows again.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("aebdb7"))
