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
	# Cohesive arctic brass habitat: soft snow footing, insulated teal hull and warm core.
	draw_set_transform(Vector2(7, 12), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, RADIUS + 5.0, Color(0.06, 0.13, 0.15, 0.28))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO, RADIUS + 4.0, Color("d9e4e3"))
	draw_arc(Vector2.ZERO, RADIUS + 2.0, PI * 0.1, PI * 0.9, 72, Color(1.0, 1.0, 1.0, 0.75), 5.0)
	draw_circle(Vector2.ZERO, RADIUS - 3.0, Color("294b50"))
	draw_circle(Vector2.ZERO, 87.0, Color("17363a"))
	draw_arc(Vector2.ZERO, 91.0, 0.0, TAU, 72, Color("dcae55"), 4.0)
	draw_arc(Vector2.ZERO, 82.0, 0.0, TAU, 72, Color(0.55, 0.76, 0.76, 0.75), 2.0)
	for seam_index in range(12):
		var seam_angle := seam_index * TAU / 12.0
		var seam_start := Vector2.from_angle(seam_angle) * 84.0
		var seam_end := Vector2.from_angle(seam_angle) * 93.0
		draw_line(seam_start, seam_end, Color("9fb6b3"), 2.0)
	for panel_index in range(8):
		var panel_angle := panel_index * TAU / 8.0 + PI / 8.0
		var panel_center := Vector2.from_angle(panel_angle) * 62.0
		draw_circle(panel_center + Vector2(1, 2), 13.0, Color(0.02, 0.08, 0.09, 0.55))
		draw_circle(panel_center, 12.0, Color("31565a"))
		draw_arc(panel_center, 9.0, 0.0, TAU, 20, Color("89b8b5"), 2.0)
		if panel_index % 2 == 0:
			draw_circle(panel_center, 5.0, Color("f2c35b"))
			draw_circle(panel_center + Vector2(-1.5, -1.5), 1.8, Color(1.0, 0.95, 0.70, 0.9))

	for angle_index in range(8):
		var angle := angle_index * TAU / 8.0
		var bolt_position := Vector2.from_angle(angle) * 78.0
		draw_circle(bolt_position, 4.0, Color("d9c99d"))

	draw_circle(Vector2(2, 4), 48.0, Color(0.01, 0.04, 0.05, 0.6))
	draw_circle(Vector2.ZERO, 47.0, Color("10292c"))
	draw_arc(Vector2.ZERO, 43.0, 0.0, TAU, 48, Color("80aaa5"), 3.0)
	draw_circle(Vector2.ZERO, 35.0, Color("714124"))
	draw_circle(Vector2.ZERO, 29.0, Color("d98730"))
	draw_circle(Vector2(-4, -5), 23.0, Color(1.0, 0.68, 0.24, 0.32))
	draw_polygon(
		PackedVector2Array([Vector2(0, -23), Vector2(20, 14), Vector2(-20, 14)]),
		PackedColorArray([Color("ffd65c")])
	)
	draw_circle(Vector2(-8, -5), 4.0, Color(1, 0.93, 0.65, 0.7))

	var entrance_font := UIFont.FONT
	for direction in ENTRANCE_DIRECTIONS:
		var center: Vector2 = direction * ENTRANCE_DISTANCE
		var entrance_rect := Rect2(center - Vector2.ONE * TILE_SIZE / 2.0, Vector2.ONE * TILE_SIZE)
		UIVisuals.draw_panel(self, entrance_rect, Color("173236"), Color("d8aa51"), 5, 2)
		draw_circle(center, 10.0, Color(0.03, 0.11, 0.12, 0.88))
		draw_string(entrance_font, center + Vector2(-12, 4), "IN", HORIZONTAL_ALIGNMENT_CENTER, 24, 9, Color("ffd46c"))
	var exit_center := EXIT_DIRECTION * ENTRANCE_DISTANCE
	var exit_rect := Rect2(exit_center - Vector2.ONE * TILE_SIZE / 2.0, Vector2.ONE * TILE_SIZE)
	UIVisuals.draw_panel(self, exit_rect, Color("173a3a"), Color("70d5b5"), 5, 2)
	draw_polygon(PackedVector2Array([exit_center + Vector2(-7, -5), exit_center + Vector2(7, -5), exit_center + Vector2(0, 8)]), PackedColorArray([Color("b8f0cf")]))
	var exit_font := UIFont.FONT
	draw_string(exit_font, exit_center + Vector2(-12, 14), "OUT", HORIZONTAL_ALIGNMENT_CENTER, 24, 8, Color("d2ffea"))
	var shelter_center := SHELTER_DIRECTION * SHELTER_DISTANCE
	draw_circle(shelter_center + Vector2(1, 2), 16.0, Color(0.10, 0.05, 0.04, 0.38))
	draw_circle(shelter_center, 15.0, Color("6f3f32"))
	draw_arc(shelter_center, 14.0, PI, TAU, 20, Color("f0bd4f"), 3.0)
	draw_circle(shelter_center + Vector2(0, 3), 4.0, Color("ffb13d"))
	draw_string(exit_font, shelter_center + Vector2(-16, 25), "숙소", HORIZONTAL_ALIGNMENT_CENTER, 32, 8, Color("8a563c"))
