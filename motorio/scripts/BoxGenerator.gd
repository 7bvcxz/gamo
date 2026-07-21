extends RigidBody2D
class_name BoxGenerator

const TILE_SIZE := 32.0
const INPUT_COST := 3
const BOX_SCENE := preload("res://scenes/PushTile.tscn")

@export var direction := Vector2.RIGHT:
	set(value):
		direction = _cardinal(value)
		rotation = direction.angle()

var stored_minerals := 0
var pending_boxes := 0

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	add_to_group("box_generator")
	freeze = true
	rotation = direction.angle()
	$MineralInput.body_entered.connect(_on_mineral_entered)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if pending_boxes > 0:
		_try_output_box()

func _on_mineral_entered(body: Node2D) -> void:
	var resource := body as RigidBody2D
	if resource == null or not resource.is_in_group("mined_resource") or resource.has_meta("generator_received"):
		return
	resource.set_meta("generator_received", true)
	resource.queue_free()
	stored_minerals += 1
	while stored_minerals >= INPUT_COST:
		stored_minerals -= INPUT_COST
		pending_boxes += 1
	_try_output_box()
	queue_redraw()

func _try_output_box() -> void:
	if pending_boxes <= 0 or not is_inside_tree():
		return
	var output_position := global_position + direction * TILE_SIZE * 1.5
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * 30.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, output_position)
	query.collision_mask = 63
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return
	var box := BOX_SCENE.instantiate() as RigidBody2D
	box.global_position = output_position
	get_parent().add_child(box)
	pending_boxes -= 1
	queue_redraw()

func input_position() -> Vector2:
	return global_position - direction * TILE_SIZE * 1.5

func output_position() -> Vector2:
	return global_position + direction * TILE_SIZE * 1.5

func _cardinal(value: Vector2) -> Vector2:
	if abs(value.x) >= abs(value.y):
		return Vector2(signf(value.x) if value.x != 0.0 else 1.0, 0.0)
	return Vector2(0.0, signf(value.y))

func _draw() -> void:
	draw_rect(Rect2(-31, -15, 62, 30), Color("344b50"))
	draw_rect(Rect2(-29, -13, 58, 26), Color("587077"), false, 3.0)
	draw_rect(Rect2(-24, -9, 18, 18), Color("18363b"))
	draw_circle(Vector2(-15, 0), 5.0, Color("8ee4df"))
	draw_rect(Rect2(5, -10, 20, 20), Color("79502e"))
	draw_line(Vector2(8, -7), Vector2(22, 7), Color("c39455"), 2.0)
	draw_line(Vector2(22, -7), Vector2(8, 7), Color("c39455"), 2.0)
	draw_polygon(PackedVector2Array([Vector2(30, 0), Vector2(22, -6), Vector2(22, 6)]), PackedColorArray([Color("f0bd4f")]))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-3, 11), "%d/3" % stored_minerals, HORIZONTAL_ALIGNMENT_CENTER, 8, 9, Color.WHITE)
