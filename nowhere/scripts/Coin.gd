extends Area2D

signal collected

const RADIUS := 8.0

func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.85, 0.2))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.7, 0.55, 0.0), false, 2.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
