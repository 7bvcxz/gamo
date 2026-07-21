extends StaticBody2D
class_name ResourceDeposit

@export var resource_type := "copper"
@export var required_worker := "miner"
@export var power_cost := 0
@export var oil_cost := 0
@export var requires_fed_cat := false

func _ready() -> void:
	add_to_group("fixed")
	add_to_group("resource_deposit")
	add_to_group("deposit_%s" % resource_type)
	queue_redraw()

func resource_color() -> Color:
	return {
		"copper": Color("d77c42"),
		"coal": Color("596168"),
		"crystal": Color("b28cff"),
		"oil": Color("33415c"),
		"uranium": Color("8ee35d"),
	}.get(resource_type, Color.WHITE)

func _draw() -> void:
	var color := resource_color()
	draw_polygon(PackedVector2Array([Vector2(-14, 10), Vector2(-10, -8), Vector2(0, -15), Vector2(12, -9), Vector2(15, 9), Vector2(4, 14)]), PackedColorArray([color.darkened(0.28)]))
	draw_polygon(PackedVector2Array([Vector2(-9, 7), Vector2(-6, -5), Vector2(1, -11), Vector2(9, -6), Vector2(11, 7), Vector2(3, 10)]), PackedColorArray([color]))
	draw_circle(Vector2(-3, -3), 3.0, color.lightened(0.35))
	if power_cost > 0:
		draw_line(Vector2(-4, 13), Vector2(0, 7), Color("f6dc58"), 2.0)
		draw_line(Vector2(0, 7), Vector2(4, 13), Color("f6dc58"), 2.0)
