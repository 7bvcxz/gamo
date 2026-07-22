extends RigidBody2D
class_name CatBlock

const TILE_SIZE := 32.0
const MINE_INTERVAL := 3.0
const SPARK_DURATION := 0.45
const RESOURCE_SCENE := preload("res://scenes/MinedResource.tscn")
const WORLD_RESOURCE_SCENE := preload("res://scenes/WorldResource.tscn")

@export var direction := Vector2.RIGHT
@export var active_on_ready := true
@export var worker_type := "miner"
var mine_elapsed := 0.0
var spark_remaining := 0.0
var hunger := 100.0

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	add_to_group("cat_worker")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active_on_ready:
		return
	var main := get_tree().get_first_node_in_group("main_controller")
	if main and main.cats_should_rest():
		return
	mine_elapsed += delta
	if spark_remaining > 0.0:
		spark_remaining = maxf(0.0, spark_remaining - delta)
		queue_redraw()
	var work_interval := MINE_INTERVAL * (3.0 if hunger <= 0.0 else (1.8 if hunger < 35.0 else 1.0))
	while mine_elapsed >= work_interval:
		mine_elapsed -= work_interval
		spark_remaining = SPARK_DURATION
		if worker_type == "electric":
			_generate_power()
		elif worker_type == "fisher":
			_catch_fish()
		elif worker_type == "server":
			_serve_fish()
		else:
			_mine_front_resource()
		queue_redraw()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length_squared() < 4.0:
		state.linear_velocity = Vector2.ZERO

func _mine_front_resource() -> void:
	var target := global_position + direction * TILE_SIZE
	var mineral: MineralBlock = null
	for node in get_tree().get_nodes_in_group("mineral_block"):
		var candidate := node as MineralBlock
		if candidate and candidate.global_position.distance_to(target) < 18.0:
			mineral = candidate
			break
	if mineral:
		_drop_resource("mineral", RESOURCE_SCENE)
		_consume_hunger(5.0)
		return
	for node in get_tree().get_nodes_in_group("resource_deposit"):
		var deposit := node as ResourceDeposit
		if deposit == null or deposit.global_position.distance_to(target) >= 18.0:
			continue
		var main := get_tree().get_first_node_in_group("main_controller")
		if main and main.try_mine_deposit(deposit, worker_type, hunger):
			var resource := WORLD_RESOURCE_SCENE.instantiate() as WorldResource
			resource.resource_type = deposit.resource_type
			_drop_resource(deposit.resource_type, resource)
			_consume_hunger(7.0)
		return

func _drop_resource(_type: String, scene_or_node) -> void:
	var resource: RigidBody2D
	if scene_or_node is PackedScene:
		resource = scene_or_node.instantiate() as RigidBody2D
	else:
		resource = scene_or_node as RigidBody2D
	resource.global_position = global_position - direction * 24.0
	get_parent().add_child(resource)

func _generate_power() -> void:
	var main := get_tree().get_first_node_in_group("main_controller")
	if main and main.worker_has_equipment_slot(self, "electric", "power_generator") and main.consume_resource("coal", 1):
		main.add_electricity(main.power_output_amount())
		_consume_hunger(5.0)

func _catch_fish() -> void:
	var main := get_tree().get_first_node_in_group("main_controller")
	if main and main.worker_has_equipment_slot(self, "fisher", "fishing_spot"):
		main.add_fish(main.food_output_amount())
		_consume_hunger(4.0)

func _serve_fish() -> void:
	var main := get_tree().get_first_node_in_group("main_controller")
	if main == null or not main.consume_fish(1):
		return
	for node in get_tree().get_nodes_in_group("cat_worker"):
		var cat := node as CatBlock
		if cat and cat != self and cat.global_position.distance_to(global_position) <= TILE_SIZE * 4.0:
			cat.hunger = minf(100.0, cat.hunger + 35.0)
	hunger = minf(100.0, hunger + 20.0)

func _has_nearby_facility(group_name: String) -> bool:
	for node in get_tree().get_nodes_in_group(group_name):
		if (node as Node2D).global_position.distance_to(global_position) <= TILE_SIZE * 1.5:
			return true
	return false

func _consume_hunger(amount: float) -> void:
	hunger = maxf(0.0, hunger - amount)

func _draw() -> void:
	var body_color: Color = {"miner": Color("d99a56"), "pressure": Color("6686a3"), "electric": Color("d7bd4f"), "fisher": Color("69b9cf"), "server": Color("78b589")}.get(worker_type, Color("d99a56"))
	var fur := Color("f3c983")
	draw_circle(Vector2(3, 5), 13.0, Color(0.02, 0.025, 0.025, 0.32))
	draw_set_transform(Vector2.ZERO, direction.angle())
	# Curled tail, soft body, role-colored winter vest and forward-facing head.
	draw_arc(Vector2(-7, 6), 8.0, 0.15, PI * 1.45, 14, fur.darkened(0.18), 4.0)
	draw_circle(Vector2(-3, 0), 11.0, fur)
	draw_circle(Vector2(-5, -7), 3.5, fur.lightened(0.08))
	draw_circle(Vector2(-5, 7), 3.5, fur.lightened(0.08))
	draw_rect(Rect2(-9, -8, 12, 16), body_color)
	draw_rect(Rect2(-7, -6, 10, 12), body_color.lightened(0.15), false, 2.0)
	draw_circle(Vector2(7, 0), 8.5, Color("fff0cf"))
	draw_polygon(PackedVector2Array([Vector2(2, -5), Vector2(4, -13), Vector2(8, -7)]), PackedColorArray([Color("fff0cf")]))
	draw_polygon(PackedVector2Array([Vector2(8, -7), Vector2(12, -13), Vector2(13, -4)]), PackedColorArray([Color("fff0cf")]))
	draw_polygon(PackedVector2Array([Vector2(4, -7), Vector2(5, -10), Vector2(7, -7)]), PackedColorArray([Color("e9a8a0")]))
	draw_polygon(PackedVector2Array([Vector2(9, -7), Vector2(11, -10), Vector2(11, -6)]), PackedColorArray([Color("e9a8a0")]))
	draw_circle(Vector2(9, -3), 1.25, Color("332c2b"))
	draw_circle(Vector2(9, 3), 1.25, Color("332c2b"))
	draw_circle(Vector2(13, 0), 1.2, Color("d27f7b"))
	draw_line(Vector2(13, 0), Vector2(15, -2), Color("694b45"), 1.0)
	draw_line(Vector2(13, 0), Vector2(15, 2), Color("694b45"), 1.0)
	draw_line(Vector2(5, -1), Vector2(1, -2), Color("8b6856"), 1.0)
	draw_line(Vector2(5, 1), Vector2(1, 2), Color("8b6856"), 1.0)
	draw_circle(Vector2(1, 0), 2.0, Color("f0d35d"))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-13, 13, 26, 3), Color("252b29"))
	draw_rect(Rect2(-13, 13, 26.0 * hunger / 100.0, 3), Color("8ee36b") if hunger >= 35.0 else Color("e36b52"))
	if spark_remaining > 0.0:
		var spark_center := direction * TILE_SIZE
		var pulse := 1.0 + spark_remaining / SPARK_DURATION
		draw_circle(spark_center, 3.0 * pulse, Color(0.75, 1.0, 0.9, 0.85), false, 2.0)
		for angle_index in range(4):
			var ray := Vector2.from_angle(angle_index * PI / 2.0) * 8.0 * pulse
			draw_line(spark_center - ray * 0.35, spark_center + ray, Color("d5fff0"), 2.0)
