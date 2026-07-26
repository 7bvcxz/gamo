extends RigidBody2D
class_name Smelter

const TILE_SIZE := 32.0
const MINERAL_COST := 2
const COAL_COST := 1
const SMELT_SECONDS := 2.0
const PLATE_SCENE := preload("res://scenes/WorldResource.tscn")

@export var direction := Vector2.RIGHT:
	set(value):
		direction = _cardinal(value)
		rotation = direction.angle()

var stored_minerals := 0
var stored_coal := 0
var pending_plates := 0
var smelt_remaining := 0.0
var production_flash := 0.0
var heat_phase := 0.0

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	add_to_group("smelter")
	freeze = true
	rotation = direction.angle()
	$ResourceInput.body_entered.connect(_on_resource_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	heat_phase = fmod(heat_phase + delta * (4.0 if is_smelting() else 1.0), TAU)
	production_flash = maxf(0.0, production_flash - delta)
	if smelt_remaining > 0.0:
		smelt_remaining = maxf(0.0, smelt_remaining - delta)
		if smelt_remaining <= 0.0:
			pending_plates += 1
	if pending_plates > 0:
		_try_output_plate()
	_start_smelt_if_ready()
	if WorldView.is_on_screen(global_position):
		queue_redraw()

func is_smelting() -> bool:
	return smelt_remaining > 0.0

func _on_resource_entered(body: Node2D) -> void:
	var resource := body as RigidBody2D
	if resource == null or resource.has_meta("smelter_received"):
		return
	if resource.is_in_group("mined_resource"):
		stored_minerals += 1
	elif resource.is_in_group("resource_coal"):
		stored_coal += 1
	else:
		return
	resource.set_meta("smelter_received", true)
	resource.queue_free()
	_start_smelt_if_ready()
	queue_redraw()

func _start_smelt_if_ready() -> void:
	if smelt_remaining > 0.0 or pending_plates > 0:
		return
	if stored_minerals < MINERAL_COST or stored_coal < COAL_COST:
		return
	stored_minerals -= MINERAL_COST
	stored_coal -= COAL_COST
	smelt_remaining = SMELT_SECONDS

func _try_output_plate() -> void:
	if pending_plates <= 0 or not is_inside_tree():
		return
	var target := global_position + direction * TILE_SIZE * 1.5
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * 30.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, target)
	query.collision_mask = 63
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return
	var plate := PLATE_SCENE.instantiate() as WorldResource
	plate.resource_type = "plate"
	plate.global_position = target
	plate.set_meta("automated_plate", true)
	get_parent().add_child(plate)
	pending_plates -= 1
	production_flash = 0.5
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
	UIVisuals.draw_panel(self, Rect2(-31, -15, 62, 30), Color("3d3038"), Color("8d7a6a"), 6, 2)
	UIVisuals.draw_panel(self, Rect2(-25, -10, 18, 20), Color("1c1417"), Color("6d5b52"), 5, 1)
	# Furnace mouth glows while a batch is melting.
	var glow: float = 0.35 + (0.45 + sin(heat_phase) * 0.2 if is_smelting() else 0.0)
	draw_circle(Vector2(-16, 0), 6.0, Color(1.0, 0.55, 0.2, glow))
	draw_circle(Vector2(-17, -2), 2.0, Color(1.0, 0.88, 0.6, glow))
	UIVisuals.draw_panel(self, Rect2(4, -10, 21, 20), Color("55402f"), Color("c08a4a"), 3, 1)
	draw_line(Vector2(8, 4), Vector2(21, 4), Color("e0b169"), 2.0)
	draw_line(Vector2(8, -1), Vector2(21, -1), Color("e0b169"), 2.0)
	draw_polygon(PackedVector2Array([Vector2(30, 0), Vector2(22, -6), Vector2(22, 6)]), PackedColorArray([Color("ffd067")]))
	if production_flash > 0.0:
		draw_circle(Vector2(30, 0), 10.0 + production_flash * 10.0, Color(1.0, 0.72, 0.35, production_flash), false, 3.0)
	var font := UIFont.FONT
	draw_string(font, Vector2(-6, 11), "%d/%d" % [stored_minerals, MINERAL_COST], HORIZONTAL_ALIGNMENT_CENTER, 12, 8, Color("cfe4e0"))
	draw_string(font, Vector2(6, 11), "%d/%d" % [stored_coal, COAL_COST], HORIZONTAL_ALIGNMENT_CENTER, 12, 8, Color("f0c07a"))
