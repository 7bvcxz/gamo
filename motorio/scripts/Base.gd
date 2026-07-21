extends StaticBody2D

const RADIUS := 72.0
const TILE_SIZE := 32.0
const ENTRANCE_DISTANCE := 72.0
const ENTRANCE_DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
const EXIT_DIRECTION := Vector2.DOWN

signal box_received(box: RigidBody2D)

func _ready() -> void:
	_create_entrances()
	queue_redraw()

func _create_entrances() -> void:
	for index in ENTRANCE_DIRECTIONS.size():
		var entrance := Area2D.new()
		entrance.name = "Entrance%d" % index
		entrance.position = ENTRANCE_DIRECTIONS[index] * ENTRANCE_DISTANCE
		entrance.collision_layer = 0
		entrance.collision_mask = 4
		entrance.monitoring = true
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2.ONE * 28.0
		collision.shape = shape
		entrance.add_child(collision)
		entrance.body_entered.connect(_on_entrance_body_entered)
		add_child(entrance)

func _on_entrance_body_entered(body: Node2D) -> void:
	var box := body as RigidBody2D
	if box == null or box.has_meta("base_received"):
		return
	box.set_meta("base_received", true)
	box_received.emit(box)
	box.queue_free()

func _draw() -> void:
	# Compact circular hub with a raised industrial center.
	draw_circle(Vector2(4, 7), RADIUS, Color(0.02, 0.03, 0.025, 0.42))
	draw_circle(Vector2.ZERO, RADIUS, Color("53605b"))
	draw_circle(Vector2.ZERO, 63.0, Color("283b35"))
	draw_arc(Vector2.ZERO, 63.0, 0.0, TAU, 64, Color("d69b35"), 4.0)

	for angle_index in range(8):
		var angle := angle_index * TAU / 8.0
		var bolt_position := Vector2.from_angle(angle) * 54.0
		draw_circle(bolt_position, 4.0, Color("d9c99d"))

	draw_circle(Vector2.ZERO, 34.0, Color("192722"))
	draw_circle(Vector2.ZERO, 24.0, Color("be7e2c"))
	draw_polygon(
		PackedVector2Array([Vector2(0, -17), Vector2(15, 10), Vector2(-15, 10)]),
		PackedColorArray([Color("f0c04f")])
	)

	for direction in ENTRANCE_DIRECTIONS:
		var center: Vector2 = direction * ENTRANCE_DISTANCE
		var entrance_rect := Rect2(center - Vector2.ONE * TILE_SIZE / 2.0, Vector2.ONE * TILE_SIZE)
		draw_rect(entrance_rect, Color("36434a"))
		draw_rect(entrance_rect.grow(-3.0), Color("d69b35"), false, 3.0)
		draw_rect(entrance_rect.grow(-8.0), Color("101b1d"))
	var exit_center := EXIT_DIRECTION * ENTRANCE_DISTANCE
	var exit_rect := Rect2(exit_center - Vector2.ONE * TILE_SIZE / 2.0, Vector2.ONE * TILE_SIZE)
	draw_rect(exit_rect, Color("335d58"))
	draw_rect(exit_rect.grow(-3.0), Color("6ed0b0"), false, 3.0)
	draw_polygon(PackedVector2Array([exit_center + Vector2(-7, -5), exit_center + Vector2(7, -5), exit_center + Vector2(0, 8)]), PackedColorArray([Color("b8f0cf")]))
