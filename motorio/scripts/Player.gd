extends CharacterBody2D

const SPEED := 220.0
const RADIUS := 11.0

var world_bounds := Rect2()

func _ready() -> void:
	queue_redraw()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()

	# Keep the complete character inside the 100 × 100 tile world.
	position.x = clamp(position.x, world_bounds.position.x + RADIUS, world_bounds.end.x - RADIUS)
	position.y = clamp(position.y, world_bounds.position.y + RADIUS, world_bounds.end.y - RADIUS)

func _draw() -> void:
	# Compact industrial rover/engineer marker, readable against every terrain tile.
	draw_circle(Vector2.ZERO, 14.0, Color(0.03, 0.05, 0.045, 0.6))
	draw_circle(Vector2.ZERO, RADIUS, Color("f2b84b"))
	draw_circle(Vector2.ZERO, 7.0, Color("37495c"))
	draw_polygon(
		PackedVector2Array([Vector2(0, -10), Vector2(5, 1), Vector2(-5, 1)]),
		PackedColorArray([Color("fff0ad")])
	)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color("fff0ad"), 2.0)
