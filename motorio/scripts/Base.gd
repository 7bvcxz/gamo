extends StaticBody2D

const RADIUS := 96.0
const TILE_SIZE := 32.0
const ENTRANCE_DISTANCE := TILE_SIZE * 3.0
const ENTRANCE_DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
const EXIT_DIRECTION := Vector2.DOWN
const SHELTER_DIRECTION := Vector2(-0.70710678, 0.70710678)
const SHELTER_DISTANCE := 92.0

signal box_received(box: RigidBody2D)
signal mineral_received(resource: RigidBody2D)
signal resource_received(resource: RigidBody2D, resource_type: String)

func _ready() -> void:
	_create_entrances()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	# Keep intake reliable for small, sleeping rigid bodies on low mobile frame rates.
	for group_name in ["box_block", "mined_resource", "world_resource"]:
		for body in get_tree().get_nodes_in_group(group_name):
			if body is not RigidBody2D or body.has_meta("base_received"):
				continue
			for direction in ENTRANCE_DIRECTIONS:
				var center: Vector2 = global_position + direction * ENTRANCE_DISTANCE
				if body.global_position.distance_to(center) < 14.0:
					_on_entrance_body_entered(body)
					break

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
	var resource := body as RigidBody2D
	if resource == null or resource.has_meta("base_received"):
		return
	if resource.is_in_group("box_block"):
		resource.set_meta("base_received", true)
		box_received.emit(resource)
		resource.queue_free()
	elif resource.is_in_group("mined_resource"):
		resource.set_meta("base_received", true)
		mineral_received.emit(resource)
		resource.queue_free()
	elif resource.is_in_group("world_resource"):
		resource.set_meta("base_received", true)
		resource_received.emit(resource, resource.get("resource_type"))
		resource.queue_free()

func _draw() -> void:
	# Compact circular hub with a raised industrial center.
	draw_circle(Vector2(4, 7), RADIUS, Color(0.02, 0.03, 0.025, 0.42))
	draw_circle(Vector2.ZERO, RADIUS, Color("53605b"))
	draw_circle(Vector2.ZERO, 87.0, Color("283b35"))
	draw_arc(Vector2.ZERO, 87.0, 0.0, TAU, 64, Color("d69b35"), 4.0)

	for angle_index in range(8):
		var angle := angle_index * TAU / 8.0
		var bolt_position := Vector2.from_angle(angle) * 78.0
		draw_circle(bolt_position, 4.0, Color("d9c99d"))

	draw_circle(Vector2.ZERO, 44.0, Color("192722"))
	draw_circle(Vector2.ZERO, 32.0, Color("be7e2c"))
	draw_polygon(
		PackedVector2Array([Vector2(0, -22), Vector2(19, 13), Vector2(-19, 13)]),
		PackedColorArray([Color("f0c04f")])
	)

	for direction in ENTRANCE_DIRECTIONS:
		var center: Vector2 = direction * ENTRANCE_DISTANCE
		var entrance_rect := Rect2(center - Vector2.ONE * TILE_SIZE / 2.0, Vector2.ONE * TILE_SIZE)
		draw_rect(entrance_rect, Color("36434a"))
		draw_rect(entrance_rect.grow(-3.0), Color("d69b35"), false, 3.0)
		draw_rect(entrance_rect.grow(-8.0), Color("101b1d"))
		var entrance_font := ThemeDB.fallback_font
		draw_string(entrance_font, center + Vector2(-8, 4), "IN", HORIZONTAL_ALIGNMENT_CENTER, 16, 8, Color("f4d58b"))
	var exit_center := EXIT_DIRECTION * ENTRANCE_DISTANCE
	var exit_rect := Rect2(exit_center - Vector2.ONE * TILE_SIZE / 2.0, Vector2.ONE * TILE_SIZE)
	draw_rect(exit_rect, Color("335d58"))
	draw_rect(exit_rect.grow(-3.0), Color("6ed0b0"), false, 3.0)
	draw_polygon(PackedVector2Array([exit_center + Vector2(-7, -5), exit_center + Vector2(7, -5), exit_center + Vector2(0, 8)]), PackedColorArray([Color("b8f0cf")]))
	var exit_font := ThemeDB.fallback_font
	draw_string(exit_font, exit_center + Vector2(-12, 14), "OUT", HORIZONTAL_ALIGNMENT_CENTER, 24, 8, Color("d2ffea"))
	var shelter_center := SHELTER_DIRECTION * SHELTER_DISTANCE
	draw_circle(shelter_center, 15.0, Color("713f35"))
	draw_arc(shelter_center, 15.0, PI, TAU, 20, Color("f0bd4f"), 3.0)
	draw_string(exit_font, shelter_center + Vector2(-16, 25), "HOME", HORIZONTAL_ALIGNMENT_CENTER, 32, 8, Color("ffd9a0"))
