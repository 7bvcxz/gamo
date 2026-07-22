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
	draw_rect(tile, Color(0.03, 0.10, 0.11, 0.32))
	UIVisuals.draw_panel(self, tile.grow(-2), Color("31565c"), Color("6f9293"), 5, 2)
	draw_set_transform(Vector2.ZERO, direction.angle())
	draw_line(Vector2(-12, 0), Vector2(-2, 0), Color("ffd067"), 3.0)
	draw_line(Vector2(-2, 0), Vector2(8, -9), Color("ffd067"), 3.0)
	draw_line(Vector2(-2, 0), Vector2(8, 9), Color("ffd067"), 3.0)
	draw_polygon(PackedVector2Array([Vector2(11, -9), Vector2(5, -13), Vector2(5, -5)]), PackedColorArray([Color("efb94c")]))
	draw_polygon(PackedVector2Array([Vector2(11, 9), Vector2(5, 5), Vector2(5, 13)]), PackedColorArray([Color("efb94c")]))
	draw_set_transform(Vector2.ZERO)
