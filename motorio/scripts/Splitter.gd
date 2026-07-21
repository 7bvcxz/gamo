extends RigidBody2D
class_name SplitterBlock

const PUSH_SPEED := 105.0

@export var direction := Vector2.RIGHT
var send_left := true

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("transport_floor")
	add_to_group("splitter_block")
	$Detector.body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var item := body as RigidBody2D
	if item == null or item == self:
		return
	var branch := direction.rotated(-PI / 2.0 if send_left else PI / 2.0).round()
	item.linear_velocity = branch * PUSH_SPEED
	send_left = not send_left

func _draw() -> void:
	var tile := Rect2(-16, -16, 32, 32)
	draw_rect(tile, Color("38464c"))
	draw_rect(tile.grow(-2), Color("718087"), false, 2.0)
	draw_set_transform(Vector2.ZERO, direction.angle())
	draw_line(Vector2(-12, 0), Vector2(-2, 0), Color("efb94c"), 3.0)
	draw_line(Vector2(-2, 0), Vector2(8, -9), Color("efb94c"), 3.0)
	draw_line(Vector2(-2, 0), Vector2(8, 9), Color("efb94c"), 3.0)
	draw_polygon(PackedVector2Array([Vector2(11, -9), Vector2(5, -13), Vector2(5, -5)]), PackedColorArray([Color("efb94c")]))
	draw_polygon(PackedVector2Array([Vector2(11, 9), Vector2(5, 5), Vector2(5, 13)]), PackedColorArray([Color("efb94c")]))
	draw_set_transform(Vector2.ZERO)
