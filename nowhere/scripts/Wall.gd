extends StaticBody2D

@export var size: Vector2 = Vector2(64, 64):
	set(value):
		size = value
		_update_shape()

func _ready() -> void:
	_update_shape()

func _update_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		(shape_node.shape as RectangleShape2D).size = size
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), Color(0.35, 0.35, 0.42))
