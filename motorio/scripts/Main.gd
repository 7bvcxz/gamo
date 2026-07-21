extends Node2D

const TILE_SIZE := 32
const WORLD_TILES := 100
const WORLD_SIZE := TILE_SIZE * WORLD_TILES
const REGION_SIZE := 5
const SPAWN_SEED := 20260720
const PUSH_TILE_SCENE := preload("res://scenes/PushTile.tscn")
const CONVEYOR_SCENE := preload("res://scenes/Conveyor.tscn")
const CARDINAL_DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const INVENTORY_CAPACITY := 5
const MODE_IN := 0
const MODE_OUT := 1

@onready var player: CharacterBody2D = $Player
@onready var base: StaticBody2D = $Base
@onready var info: Label = $UI/Info
@onready var box_label: Label = $UI/BoxCount
@onready var mode_label: Label = $UI/Mode
@onready var inventory_ui: Control = $UI/Inventory
@onready var version_label: Label = $UI/Version
@onready var touch_controls: TouchControls = $UI/TouchControls

var box_count := 0
var interaction_mode := MODE_IN
var inventory: Array[Dictionary] = []
var selected_slot := 0
var preview_visible := false
var placement_rotation := 0

func _ready() -> void:
	var world_center := Vector2(WORLD_SIZE, WORLD_SIZE) / 2.0
	base.position = world_center
	base.connect("box_received", _on_base_box_received)
	player.position = world_center + Vector2(0, TILE_SIZE * 3)
	player.world_bounds = Rect2(0.0, 0.0, WORLD_SIZE, WORLD_SIZE)
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	touch_controls.player = player
	touch_controls.main_controller = self
	inventory_ui.main_controller = self
	_update_interaction_ui()
	_create_world_walls()
	_populate_world()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_SIZE
	camera.limit_bottom = WORLD_SIZE
	camera.limit_smoothed = true
	queue_redraw()

func _on_base_box_received(_box: RigidBody2D) -> void:
	box_count += 1
	box_label.text = "BOX  %d" % box_count

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_C:
			toggle_interaction_mode()
		KEY_Z:
			primary_action()
		KEY_X:
			preview_action()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			select_inventory_slot(int(key.physical_keycode - KEY_1))

func toggle_interaction_mode() -> void:
	interaction_mode = MODE_OUT if interaction_mode == MODE_IN else MODE_IN
	preview_visible = false
	placement_rotation = 0
	_update_interaction_ui()

func primary_action() -> void:
	if interaction_mode == MODE_IN:
		_pick_up_front_block()
	else:
		_place_selected_block()

func preview_action() -> void:
	if interaction_mode != MODE_OUT or inventory.is_empty():
		return
	if preview_visible:
		placement_rotation = (placement_rotation + 1) % 4
	else:
		preview_visible = true
	queue_redraw()

func select_inventory_slot(slot: int) -> void:
	selected_slot = clampi(slot, 0, INVENTORY_CAPACITY - 1)
	placement_rotation = 0
	_update_interaction_ui()

func _pick_up_front_block() -> void:
	if inventory.size() >= INVENTORY_CAPACITY:
		return
	var target := _front_cell_center()
	var closest: RigidBody2D = null
	var closest_distance := 26.0
	for node in get_tree().get_nodes_in_group("pickup_block"):
		var block := node as RigidBody2D
		if block == null or block.has_meta("base_received"):
			continue
		var distance := block.global_position.distance_to(target)
		if distance < closest_distance:
			closest = block
			closest_distance = distance
	if closest == null:
		return
	var item := {"type": "box"}
	if closest is ConveyorBlock:
		item = {"type": "conveyor", "direction": (closest as ConveyorBlock).direction}
	inventory.append(item)
	closest.queue_free()
	selected_slot = 0 if inventory.size() == 1 else selected_slot
	_update_interaction_ui()

func _place_selected_block() -> void:
	if inventory.is_empty() or selected_slot >= inventory.size():
		return
	var target := _front_cell_center()
	if not _can_place_at(target):
		return
	var item := inventory[selected_slot]
	var block: RigidBody2D
	if item["type"] == "conveyor":
		var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorBlock
		conveyor.direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
		block = conveyor
	else:
		block = PUSH_TILE_SCENE.instantiate() as RigidBody2D
	block.position = target
	add_child(block)
	inventory.remove_at(selected_slot)
	selected_slot = clampi(selected_slot, 0, maxi(0, inventory.size() - 1))
	preview_visible = false
	placement_rotation = 0
	_update_interaction_ui()

func _can_place_at(target: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * 30.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, target)
	query.collision_mask = 31
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _front_direction() -> Vector2:
	if abs(player.facing.x) > abs(player.facing.y):
		return Vector2(sign(player.facing.x), 0.0)
	return Vector2(0.0, sign(player.facing.y))

func _front_cell_center() -> Vector2:
	var player_cell := Vector2i(player.position / TILE_SIZE)
	return _cell_center(player_cell + Vector2i(_front_direction()))

func _update_interaction_ui() -> void:
	mode_label.text = "MODE  %s" % ("IN" if interaction_mode == MODE_IN else "OUT")
	inventory_ui.queue_redraw()
	queue_redraw()

func _populate_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SPAWN_SEED
	var center_tile := Vector2i(WORLD_TILES / 2, WORLD_TILES / 2)
	var player_tile := Vector2i(player.position / TILE_SIZE)

	for region_y in range(0, WORLD_TILES, REGION_SIZE):
		for region_x in range(0, WORLD_TILES, REGION_SIZE):
			var occupied: Dictionary[Vector2i, bool] = {}
			var box_cell := _random_free_cell(rng, region_x, region_y, occupied, center_tile, player_tile)
			occupied[box_cell] = true
			var belt_cell := _random_free_cell(rng, region_x, region_y, occupied, center_tile, player_tile)

			var box := PUSH_TILE_SCENE.instantiate() as RigidBody2D
			box.position = _cell_center(box_cell)
			add_child(box)

			var belt := CONVEYOR_SCENE.instantiate() as ConveyorBlock
			belt.direction = CARDINAL_DIRECTIONS[rng.randi_range(0, CARDINAL_DIRECTIONS.size() - 1)]
			belt.position = _cell_center(belt_cell)
			add_child(belt)

func _random_free_cell(
	rng: RandomNumberGenerator,
	region_x: int,
	region_y: int,
	occupied: Dictionary[Vector2i, bool],
	center_tile: Vector2i,
	player_tile: Vector2i
) -> Vector2i:
	while true:
		var cell := Vector2i(
			region_x + rng.randi_range(0, REGION_SIZE - 1),
			region_y + rng.randi_range(0, REGION_SIZE - 1)
		)
		if occupied.has(cell):
			continue
		if abs(cell.x - center_tile.x) <= 3 and abs(cell.y - center_tile.y) <= 3:
			continue
		if abs(cell.x - player_tile.x) <= 1 and abs(cell.y - player_tile.y) <= 1:
			continue
		return cell
	return Vector2i(region_x, region_y)

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * (TILE_SIZE / 2.0)

func _process(_delta: float) -> void:
	var tile := Vector2i(player.position / TILE_SIZE) + Vector2i.ONE
	info.text = "POS  %d, %d" % [tile.x, tile.y]
	if preview_visible:
		queue_redraw()

func _create_world_walls() -> void:
	var half_world := WORLD_SIZE / 2.0
	var walls := [
		[Vector2(half_world, -16), Vector2(WORLD_SIZE + 64, 32)],
		[Vector2(half_world, WORLD_SIZE + 16), Vector2(WORLD_SIZE + 64, 32)],
		[Vector2(-16, half_world), Vector2(32, WORLD_SIZE + 64)],
		[Vector2(WORLD_SIZE + 16, half_world), Vector2(32, WORLD_SIZE + 64)],
	]
	for wall_data in walls:
		var wall := StaticBody2D.new()
		wall.collision_layer = 8
		wall.collision_mask = 7
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall_data[1]
		collision.shape = shape
		wall.position = wall_data[0]
		wall.add_child(collision)
		add_child(wall)

func _draw() -> void:
	# Base terrain.
	draw_rect(Rect2(0, 0, WORLD_SIZE, WORLD_SIZE), Color("243b32"))

	# Deterministic patches break up the grid and hint at future resource fields.
	for y in range(WORLD_TILES):
		for x in range(WORLD_TILES):
			var noise_value := (x * 37 + y * 73 + x * y * 3) % 97
			if noise_value < 8:
				var cell := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				draw_rect(cell, Color("29473a"))

	# One-pixel grid: 100 × 100 cells.
	var grid_color := Color(0.42, 0.58, 0.47, 0.18)
	for i in range(WORLD_TILES + 1):
		var p := float(i * TILE_SIZE)
		draw_line(Vector2(p, 0), Vector2(p, WORLD_SIZE), grid_color, 1.0)
		draw_line(Vector2(0, p), Vector2(WORLD_SIZE, p), grid_color, 1.0)

	# World border.
	draw_rect(Rect2(1, 1, WORLD_SIZE - 2, WORLD_SIZE - 2), Color("9abd78"), false, 3.0)

	if preview_visible and interaction_mode == MODE_OUT and not inventory.is_empty():
		var target := _front_cell_center()
		var valid := _can_place_at(target)
		var color := Color(0.3, 0.9, 0.55, 0.45) if valid else Color(0.95, 0.25, 0.22, 0.45)
		draw_rect(Rect2(target - Vector2.ONE * 15.0, Vector2.ONE * 30.0), color)
		if inventory[selected_slot]["type"] == "conveyor":
			var direction := Vector2.RIGHT.rotated(placement_rotation * PI / 2.0)
			draw_line(target - direction * 8.0, target + direction * 8.0, Color.WHITE, 3.0)
