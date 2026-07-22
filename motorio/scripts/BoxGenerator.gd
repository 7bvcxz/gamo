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
var production_flash := 0.0
var press_phase := 0.0

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	add_to_group("box_generator")
	freeze = true
	rotation = direction.angle()
	$MineralInput.body_entered.connect(_on_mineral_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	press_phase = fmod(press_phase + delta * (5.0 if stored_minerals > 0 or pending_boxes > 0 else 1.0), TAU)
	production_flash = maxf(0.0, production_flash - delta)
	if pending_boxes > 0:
		_try_output_box()
	queue_redraw()

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
	box.set_meta("automated_box", true)
	get_parent().add_child(box)
	pending_boxes -= 1
	production_flash = 0.45
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
	draw_rect(Rect2(-29, -12, 62, 30), Color(0.03, 0.09, 0.10, 0.28))
	UIVisuals.draw_panel(self, Rect2(-31, -15, 62, 30), Color("294d53"), Color("779598"), 6, 2)
	UIVisuals.draw_panel(self, Rect2(-25, -10, 19, 20), Color("123338"), Color("5d8586"), 5, 1)
	draw_circle(Vector2(-15, 0), 6.0, Color("67c8c7"))
	draw_circle(Vector2(-17, -2), 2.0, Color(0.86, 1.0, 0.98, 0.65))
	var press_offset := sin(press_phase) * 1.5 if stored_minerals > 0 or pending_boxes > 0 else 0.0
	UIVisuals.draw_panel(self, Rect2(5 + press_offset, -10, 20, 20), Color("976237"), Color("d2a259"), 3, 1)
	draw_line(Vector2(8, -7), Vector2(22, 7), Color("c39455"), 2.0)
	draw_line(Vector2(22, -7), Vector2(8, 7), Color("c39455"), 2.0)
	draw_polygon(PackedVector2Array([Vector2(30, 0), Vector2(22, -6), Vector2(22, 6)]), PackedColorArray([Color("ffd067")]))
	if production_flash > 0.0:
		draw_circle(Vector2(30, 0), 10.0 + production_flash * 10.0, Color(1.0, 0.82, 0.3, production_flash), false, 3.0)
	var font := UIFont.FONT
	draw_string(font, Vector2(-3, 11), "%d/3" % stored_minerals, HORIZONTAL_ALIGNMENT_CENTER, 8, 9, Color.WHITE)
