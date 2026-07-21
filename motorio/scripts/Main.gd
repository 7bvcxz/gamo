extends Node2D

const TILE_SIZE := 32
const WORLD_TILES := 100
const WORLD_SIZE := TILE_SIZE * WORLD_TILES
const REGION_SIZE := 5
const SPAWN_SEED := 20260720
const PUSH_TILE_SCENE := preload("res://scenes/PushTile.tscn")
const CONVEYOR_SCENE := preload("res://scenes/Conveyor.tscn")
const CAT_BLOCK_SCENE := preload("res://scenes/CatBlock.tscn")
const PILLAR_BLOCK_SCENE := preload("res://scenes/PillarBlock.tscn")
const BOX_GENERATOR_SCENE := preload("res://scenes/BoxGenerator.tscn")
const MINERAL_SCENE := preload("res://scenes/Mineral.tscn")
const CARDINAL_DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const INVENTORY_CAPACITY := 5
const RESOURCE_COLLECT_RADIUS := TILE_SIZE * 1.5
const PLACEMENT_ROTATE_INTERVAL := 0.7

@onready var player: CharacterBody2D = $Player
@onready var base: StaticBody2D = $Base
@onready var info: Label = $UI/Info
@onready var box_label: Label = $UI/BoxCount
@onready var mineral_label: Label = $UI/MineralCount
@onready var inventory_ui: Control = $UI/Inventory
@onready var base_menu: Control = $UI/BaseMenu
@onready var minimap: Control = $UI/Minimap
@onready var version_label: Label = $UI/Version
@onready var touch_controls: TouchControls = $UI/TouchControls

var box_count := 0
var mineral_count := 0
var inventory: Array[Dictionary] = []
var selected_slot := 0
var preview_visible := false
var placement_rotation := 0
var placement_preview: RigidBody2D
var base_menu_open := false
var fabricator_status := "3 BOX REQUIRED"
var fabricator_selection := 0
var collect_action_held := false
var placement_action_held := false
var placement_hold_elapsed := 0.0
var placement_rotated_during_hold := false

func _ready() -> void:
	var world_center := Vector2(WORLD_SIZE, WORLD_SIZE) / 2.0 + Vector2.ONE * (TILE_SIZE / 2.0)
	base.position = world_center
	base.connect("box_received", _on_base_box_received)
	base.connect("mineral_received", _on_base_mineral_received)
	player.position = world_center + Vector2(0, TILE_SIZE * 4)
	player.world_bounds = Rect2(0.0, 0.0, WORLD_SIZE, WORLD_SIZE)
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	touch_controls.player = player
	touch_controls.main_controller = self
	inventory_ui.main_controller = self
	base_menu.main_controller = self
	minimap.main_controller = self
	_update_interaction_ui()
	_create_world_walls()
	_populate_world()
	minimap.refresh_snapshot()
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

func _on_base_mineral_received(_resource: RigidBody2D) -> void:
	mineral_count += 1
	mineral_label.text = "MINERAL  %d" % mineral_count

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if key.physical_keycode == KEY_Z:
		collect_action_held = key.pressed
		if key.pressed:
			primary_action()
		return
	if key.physical_keycode == KEY_X:
		if key.pressed:
			begin_placement_action()
		else:
			end_placement_action()
		return
	if key.pressed and key.keycode == KEY_ESCAPE and base_menu_open:
		_close_base_menu()
		return
	if not key.pressed:
		return
	match key.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			select_inventory_slot(int(key.physical_keycode - KEY_1))

func primary_action() -> void:
	if base_menu_open:
		_craft_selected_block()
		return
	if _is_base_in_front():
		_open_base_menu()
	else:
		_pick_up_front_block()

func begin_placement_action() -> void:
	placement_action_held = true
	placement_hold_elapsed = 0.0
	placement_rotated_during_hold = false

func end_placement_action() -> void:
	if not placement_action_held:
		return
	placement_action_held = false
	placement_hold_elapsed = 0.0
	if base_menu_open:
		_cycle_fabricator_recipe()
		return
	if not placement_rotated_during_hold:
		_place_selected_block()

func cancel_placement_action() -> void:
	placement_action_held = false
	placement_hold_elapsed = 0.0
	placement_rotated_during_hold = false

func _rotate_placement() -> void:
	if inventory.is_empty() or selected_slot >= inventory.size():
		return
	placement_rotation = (placement_rotation + 1) % 4
	placement_rotated_during_hold = true
	_sync_placement_preview()

func select_inventory_slot(slot: int) -> void:
	selected_slot = clampi(slot, 0, INVENTORY_CAPACITY - 1)
	_sync_placement_preview()
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
	elif closest is CatBlock:
		item = {"type": "cat", "direction": (closest as CatBlock).direction}
	elif closest is PillarBlock:
		item = {"type": "pillar"}
	elif closest is BoxGenerator:
		item = {"type": "box_generator", "direction": (closest as BoxGenerator).direction}
	inventory.append(item)
	closest.queue_free()
	selected_slot = 0 if inventory.size() == 1 else selected_slot
	_sync_placement_preview()
	_update_interaction_ui()

func _place_selected_block() -> void:
	if inventory.is_empty() or selected_slot >= inventory.size():
		return
	var target := _front_cell_center()
	var item := inventory[selected_slot]
	var item_type: String = item["type"]
	var place_direction := Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
	if not _can_place_item_at(target, item_type, place_direction):
		return
	var block: RigidBody2D
	if item["type"] == "conveyor":
		var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorBlock
		conveyor.direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
		block = conveyor
	elif item["type"] == "cat":
		var cat := CAT_BLOCK_SCENE.instantiate() as CatBlock
		cat.direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
		cat.active_on_ready = true
		block = cat
	elif item["type"] == "pillar":
		block = PILLAR_BLOCK_SCENE.instantiate() as PillarBlock
	elif item["type"] == "box_generator":
		var generator := BOX_GENERATOR_SCENE.instantiate() as BoxGenerator
		generator.direction = place_direction
		block = generator
	else:
		block = PUSH_TILE_SCENE.instantiate() as RigidBody2D
	block.position = target + place_direction * (TILE_SIZE * 0.5) if item_type == "box_generator" else target
	add_child(block)
	inventory.remove_at(selected_slot)
	selected_slot = clampi(selected_slot, 0, maxi(0, inventory.size() - 1))
	_sync_placement_preview()
	_update_interaction_ui()

func _sync_placement_preview() -> void:
	var should_show := selected_slot < inventory.size() and not base_menu_open
	preview_visible = should_show
	if not should_show:
		if is_instance_valid(placement_preview):
			placement_preview.queue_free()
		placement_preview = null
		return
	var item: Dictionary = inventory[selected_slot]
	var item_type: String = item["type"]
	if is_instance_valid(placement_preview) and placement_preview.get_meta("preview_type", "") != item_type:
		placement_preview.free()
		placement_preview = null
	if not is_instance_valid(placement_preview):
		placement_preview = _create_placement_preview(item_type)
	placement_preview.position = _front_cell_center()
	if placement_preview is ConveyorBlock:
		(placement_preview as ConveyorBlock).direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
	elif placement_preview is CatBlock:
		(placement_preview as CatBlock).direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
	elif placement_preview is BoxGenerator:
		(placement_preview as BoxGenerator).direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
	placement_preview.position = _preview_position(item_type)
	placement_preview.queue_redraw()

func _create_placement_preview(item_type: String) -> RigidBody2D:
	var block: RigidBody2D
	if item_type == "conveyor":
		block = CONVEYOR_SCENE.instantiate() as RigidBody2D
	elif item_type == "cat":
		var cat := CAT_BLOCK_SCENE.instantiate() as CatBlock
		cat.active_on_ready = false
		block = cat
	elif item_type == "pillar":
		block = PILLAR_BLOCK_SCENE.instantiate() as PillarBlock
	elif item_type == "box_generator":
		block = BOX_GENERATOR_SCENE.instantiate() as BoxGenerator
	else:
		block = PUSH_TILE_SCENE.instantiate() as RigidBody2D
	block.set_meta("placement_preview", true)
	block.set_meta("preview_type", item_type)
	block.modulate.a = 0.5
	block.z_index = 20
	block.collision_layer = 0
	block.collision_mask = 0
	block.freeze = true
	add_child(block)
	for group_name in ["pickup_block", "solid", "machine", "transport_floor", "box_block"]:
		block.remove_from_group(group_name)
	for child in block.find_children("*", "CollisionShape2D", true, false):
		(child as CollisionShape2D).disabled = true
	var detector := block.get_node_or_null("Detector") as Area2D
	if detector:
		detector.monitoring = false
	block.process_mode = Node.PROCESS_MODE_DISABLED
	return block

func _can_place_at(target: Vector2) -> bool:
	return _can_place_item_at(target, "box", Vector2.RIGHT)

func _can_place_item_at(target: Vector2, item_type: String, direction: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(62.0, 30.0) if item_type == "box_generator" else Vector2.ONE * 30.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	var center := target + direction * (TILE_SIZE * 0.5) if item_type == "box_generator" else target
	query.transform = Transform2D(direction.angle() if item_type == "box_generator" else 0.0, center)
	query.collision_mask = 63
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _preview_position(item_type: String) -> Vector2:
	var target := _front_cell_center()
	if item_type != "box_generator":
		return target
	var direction := Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
	return target + direction * (TILE_SIZE * 0.5)

func _front_direction() -> Vector2:
	if abs(player.facing.x) > abs(player.facing.y):
		return Vector2(sign(player.facing.x), 0.0)
	return Vector2(0.0, sign(player.facing.y))

func _front_cell_center() -> Vector2:
	var player_cell := Vector2i(player.position / TILE_SIZE)
	return _cell_center(player_cell + Vector2i(_front_direction()))

func _is_base_in_front() -> bool:
	var toward_base := player.global_position.direction_to(base.global_position)
	return player.global_position.distance_to(base.global_position) <= 128.0 and _front_direction().dot(toward_base) > 0.55

func _open_base_menu() -> void:
	base_menu_open = true
	_sync_placement_preview()
	_update_fabricator_status()
	player.controls_locked = true
	base_menu.queue_redraw()

func close_base_menu_action() -> void:
	if base_menu_open:
		_close_base_menu()

func _close_base_menu() -> void:
	base_menu_open = false
	player.controls_locked = false
	base_menu.queue_redraw()

func _cycle_fabricator_recipe() -> void:
	fabricator_selection = (fabricator_selection + 1) % 3
	_update_fabricator_status()
	base_menu.queue_redraw()

func _craft_selected_block() -> void:
	var block: RigidBody2D
	if fabricator_selection == 2:
		if mineral_count < 10:
			fabricator_status = "NOT ENOUGH MINERAL"
			return
		mineral_count -= 10
		mineral_label.text = "MINERAL  %d" % mineral_count
		var generator := BOX_GENERATOR_SCENE.instantiate() as BoxGenerator
		generator.direction = Vector2.DOWN
		block = generator
		fabricator_status = "BOX GENERATOR CREATED"
	else:
		if box_count < 3:
			fabricator_status = "NOT ENOUGH BOX"
			return
		box_count -= 3
		box_label.text = "BOX  %d" % box_count
	if fabricator_selection == 1:
		block = PILLAR_BLOCK_SCENE.instantiate() as PillarBlock
		fabricator_status = "PILLAR CREATED"
	elif fabricator_selection == 0:
		var cat := CAT_BLOCK_SCENE.instantiate() as CatBlock
		cat.direction = Vector2.DOWN
		cat.active_on_ready = false
		block = cat
		fabricator_status = "CAT BLOCK CREATED"
	block.position = _find_fabricator_output_position(block)
	add_child(block)
	base_menu.queue_redraw()

func _update_fabricator_status() -> void:
	if fabricator_selection == 2:
		fabricator_status = "READY" if mineral_count >= 10 else "NEED %d MORE MINERAL" % (10 - mineral_count)
	else:
		fabricator_status = "READY" if box_count >= 3 else "NEED %d MORE BOX" % (3 - box_count)

func _find_fabricator_output_position(block: RigidBody2D = null) -> Vector2:
	var output := base.global_position + Vector2.DOWN * (TILE_SIZE * 4.0)
	for step in range(WORLD_TILES):
		var candidate := output + Vector2.DOWN * (TILE_SIZE * step)
		var shape := RectangleShape2D.new()
		var is_generator := block is BoxGenerator
		shape.size = Vector2(62.0, 30.0) if is_generator else Vector2.ONE * 30.0
		var center := candidate + Vector2.DOWN * (TILE_SIZE * 0.5) if is_generator else candidate
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(PI / 2.0 if is_generator else 0.0, center)
		query.collision_mask = 63
		query.collide_with_areas = false
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return center
	var fallback := output + Vector2.DOWN * (TILE_SIZE * (WORLD_TILES - 1))
	return fallback + Vector2.DOWN * (TILE_SIZE * 0.5) if block is BoxGenerator else fallback

func _update_interaction_ui() -> void:
	inventory_ui.queue_redraw()
	queue_redraw()

func _populate_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SPAWN_SEED
	var center_tile := Vector2i(WORLD_TILES / 2, WORLD_TILES / 2)
	var player_tile := Vector2i(player.position / TILE_SIZE)
	var occupied: Dictionary[Vector2i, bool] = {}

	for region_y in range(0, WORLD_TILES, REGION_SIZE):
		for region_x in range(0, WORLD_TILES, REGION_SIZE):
			var box_cell := _random_free_cell(rng, region_x, region_y, occupied, center_tile, player_tile)
			occupied[box_cell] = true
			var belt_cell := _random_free_cell(rng, region_x, region_y, occupied, center_tile, player_tile)
			occupied[belt_cell] = true

			var box := PUSH_TILE_SCENE.instantiate() as RigidBody2D
			box.position = _cell_center(box_cell)
			add_child(box)

			var belt := CONVEYOR_SCENE.instantiate() as ConveyorBlock
			belt.direction = CARDINAL_DIRECTIONS[rng.randi_range(0, CARDINAL_DIRECTIONS.size() - 1)]
			belt.position = _cell_center(belt_cell)
			add_child(belt)
	_populate_minerals(rng, occupied, center_tile, player_tile)

func _populate_minerals(rng: RandomNumberGenerator, occupied: Dictionary[Vector2i, bool], center_tile: Vector2i, player_tile: Vector2i) -> void:
	var target_count := int(round(float(WORLD_TILES * WORLD_TILES) / 120.0))
	var isolated_count := int(round(target_count * 0.2))
	var mineral_cells: Array[Vector2i] = []
	while mineral_cells.size() < isolated_count:
		var cell := Vector2i(rng.randi_range(0, WORLD_TILES - 1), rng.randi_range(0, WORLD_TILES - 1))
		if not _is_free_mineral_cell(cell, occupied, center_tile, player_tile):
			continue
		var touches_existing := false
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			if mineral_cells.has(cell + direction):
				touches_existing = true
				break
		if touches_existing:
			continue
		_add_mineral(cell, false, occupied, mineral_cells)
	var attempts := 0
	while mineral_cells.size() < target_count and attempts < target_count * 40:
		attempts += 1
		var parent: Vector2i = mineral_cells[rng.randi_range(0, mineral_cells.size() - 1)]
		var direction: Vector2i = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][rng.randi_range(0, 3)]
		var cell := parent + direction
		if not _is_free_mineral_cell(cell, occupied, center_tile, player_tile):
			continue
		_add_mineral(cell, true, occupied, mineral_cells)

func _is_free_mineral_cell(cell: Vector2i, occupied: Dictionary[Vector2i, bool], center_tile: Vector2i, player_tile: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WORLD_TILES and cell.y < WORLD_TILES and not occupied.has(cell) and not (abs(cell.x - center_tile.x) <= 4 and abs(cell.y - center_tile.y) <= 4) and not (abs(cell.x - player_tile.x) <= 1 and abs(cell.y - player_tile.y) <= 1)

func _add_mineral(cell: Vector2i, clustered: bool, occupied: Dictionary[Vector2i, bool], mineral_cells: Array[Vector2i]) -> void:
	var mineral := MINERAL_SCENE.instantiate() as MineralBlock
	mineral.position = _cell_center(cell)
	mineral.set_meta("clustered_spawn", clustered)
	add_child(mineral)
	occupied[cell] = true
	mineral_cells.append(cell)

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

func _process(delta: float) -> void:
	var tile := Vector2i(player.position / TILE_SIZE) + Vector2i.ONE
	info.text = "POS  %d, %d" % [tile.x, tile.y]
	if placement_action_held and not base_menu_open:
		placement_hold_elapsed += delta
		while placement_hold_elapsed >= PLACEMENT_ROTATE_INTERVAL:
			placement_hold_elapsed -= PLACEMENT_ROTATE_INTERVAL
			_rotate_placement()
	if preview_visible and is_instance_valid(placement_preview):
		placement_preview.position = _front_cell_center()
	if collect_action_held:
		_collect_nearby_mineral_resources()

func _collect_nearby_mineral_resources() -> void:
	for node in get_tree().get_nodes_in_group("mined_resource"):
		var resource := node as RigidBody2D
		if resource == null or resource.has_meta("collected"):
			continue
		if resource.global_position.distance_to(player.global_position) > RESOURCE_COLLECT_RADIUS:
			continue
		resource.set_meta("collected", true)
		resource.queue_free()
		mineral_count += 1
		mineral_label.text = "MINERAL  %d" % mineral_count

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
