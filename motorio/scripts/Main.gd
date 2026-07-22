extends Node2D

const TILE_SIZE := 32
const WORLD_TILES := 100
const WORLD_SIZE := TILE_SIZE * WORLD_TILES
const REGION_SIZE := 10
const START_CLEAR_RADIUS := 20
const SPAWN_SEED := 20260720
const PUSH_TILE_SCENE := preload("res://scenes/PushTile.tscn")
const CONVEYOR_SCENE := preload("res://scenes/Conveyor.tscn")
const CAT_BLOCK_SCENE := preload("res://scenes/CatBlock.tscn")
const PILLAR_BLOCK_SCENE := preload("res://scenes/PillarBlock.tscn")
const BOX_GENERATOR_SCENE := preload("res://scenes/BoxGenerator.tscn")
const SPLITTER_SCENE := preload("res://scenes/Splitter.tscn")
const RESOURCE_DEPOSIT_SCENE := preload("res://scenes/ResourceDeposit.tscn")
const WATER_TILE_SCENE := preload("res://scenes/WaterTile.tscn")
const BRIDGE_SCENE := preload("res://scenes/Bridge.tscn")
const FACILITY_SCENE := preload("res://scenes/FacilityBlock.tscn")
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
@onready var throughput_label: Label = $UI/Throughput
@onready var quest_ui: Control = $UI/Quest
@onready var economy_ui: Control = $UI/Economy
@onready var tutorial_ui: Control = $UI/Tutorial
@onready var survival_status: Label = $UI/SurvivalStatus
@onready var shelter_ui: Control = $UI/Shelter
@onready var climate_ui: Control = $UI/Climate

var box_count := 0
var mineral_count := 0
var inventory: Array[Dictionary] = []
var selected_slot := 0
var preview_visible := false
var placement_rotation := 0
var placement_preview: RigidBody2D
var base_menu_open := false
var fabricator_status := "상자 3개 필요"
var fabricator_selection := 0
var collect_action_held := false
var placement_action_held := false
var placement_hold_elapsed := 0.0
var placement_rotated_during_hold := false
var quest_step := 0
var automated_boxes_delivered := 0
var base_level := 1
var elapsed_time := 0.0
var automated_delivery_times: Array[float] = []
var celebration_remaining := 0.0
var celebration_text := ""
var cat_crafted := false
var generator_crafted := false
var bridge_crafted := false
var resource_counts := {"copper": 0, "coal": 0, "crystal": 0, "oil": 0, "uranium": 0}
var electricity := 0
var fish := 0
var tutorial_step := 0
var tutorial_start_position := Vector2.ZERO
var tutorial_moved := false
var tutorial_picked := false
var tutorial_rotated := false
var tutorial_placed := false
var tutorial_delivered := false
var tutorial_menu_opened := false
var day_number := 1
var day_time := 0.0
var temperature := 100.0
var shelter_open := false
var night_warning_shown := false
var heat_tech := 0
var power_tech := 0
var food_tech := 0

func _ready() -> void:
	add_to_group("main_controller")
	var world_center := Vector2(WORLD_SIZE, WORLD_SIZE) / 2.0 + Vector2.ONE * (TILE_SIZE / 2.0)
	base.position = world_center
	base.connect("box_received", _on_base_box_received)
	base.connect("mineral_received", _on_base_mineral_received)
	base.connect("resource_received", _on_base_resource_received)
	player.position = world_center + Vector2(0, TILE_SIZE * 4)
	player.world_bounds = Rect2(0.0, 0.0, WORLD_SIZE, WORLD_SIZE)
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	touch_controls.player = player
	touch_controls.main_controller = self
	inventory_ui.main_controller = self
	base_menu.main_controller = self
	quest_ui.main_controller = self
	economy_ui.main_controller = self
	tutorial_ui.main_controller = self
	shelter_ui.main_controller = self
	climate_ui.main_controller = self
	tutorial_start_position = player.position
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
	box_label.text = "상자  %d" % box_count
	tutorial_delivered = true
	_refresh_tutorial()
	if quest_step == 0:
		_advance_quest("첫 납품 완료")
	if _box.get_meta("automated_box", false):
		automated_boxes_delivered += 1
		automated_delivery_times.append(elapsed_time)
		if quest_step == 4 and automated_boxes_delivered >= 3:
			_advance_quest("자동화 완료 - 기지 업그레이드 가능")

func _on_base_mineral_received(_resource: RigidBody2D) -> void:
	mineral_count += 1
	mineral_label.text = "미네랄  %d" % mineral_count
	_check_mineral_quest()

func _on_base_resource_received(_resource: RigidBody2D, resource_type: String) -> void:
	if resource_counts.has(resource_type):
		resource_counts[resource_type] += 1
		economy_ui.queue_redraw()
		_refresh_quest_progress()

func consume_resource(resource_type: String, amount: int) -> bool:
	if not resource_counts.has(resource_type) or resource_counts[resource_type] < amount:
		return false
	resource_counts[resource_type] -= amount
	economy_ui.queue_redraw()
	return true

func add_electricity(amount: int) -> void:
	electricity += amount
	economy_ui.queue_redraw()
	_refresh_quest_progress()

func add_fish(amount: int) -> void:
	fish += amount
	economy_ui.queue_redraw()
	_refresh_quest_progress()

func power_output_amount() -> int:
	return 5 + power_tech * 2

func food_output_amount() -> int:
	return 2 + food_tech

func safe_radius_tiles() -> int:
	return 8 + base_level * 3 + heat_tech * 4 + mini(_facility_count("power_generator"), _cat_count("electric")) * 2

func cold_exposure() -> float:
	var distance_tiles: float = player.global_position.distance_to(base.global_position) / TILE_SIZE
	return clampf((distance_tiles - float(safe_radius_tiles())) / 6.0, 0.0, 1.0)

func power_per_minute() -> int:
	return mini(_facility_count("power_generator"), _cat_count("electric")) * power_output_amount() * 20

func food_per_minute() -> int:
	return mini(_facility_count("fishing_spot"), _cat_count("fisher")) * food_output_amount() * 20

func heat_per_minute() -> int:
	return safe_radius_tiles() * 2

func _facility_count(group_name: String) -> int:
	return get_tree().get_nodes_in_group(group_name).size()

func _cat_count(role: String) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("cat_worker"):
		if (node as CatBlock).worker_type == role:
			count += 1
	return count

func worker_has_equipment_slot(cat: CatBlock, role: String, facility_group: String) -> bool:
	var equipment_count := _facility_count(facility_group)
	if equipment_count <= 0:
		return false
	var earlier_workers := 0
	for node in get_tree().get_nodes_in_group("cat_worker"):
		var other := node as CatBlock
		if other and other.worker_type == role and other._has_nearby_facility(facility_group) and other.get_instance_id() < cat.get_instance_id():
			earlier_workers += 1
	return earlier_workers < equipment_count

func ui_stage() -> int:
	if not tutorial_complete():
		return 0
	if quest_step < 5:
		return 1
	if quest_step < 8:
		return 2
	if quest_step < 10:
		return 3
	return 4

func cats_should_rest() -> bool:
	return day_time >= 660.0 or shelter_open

func consume_fish(amount: int) -> bool:
	if fish < amount:
		return false
	fish -= amount
	economy_ui.queue_redraw()
	return true

func try_mine_deposit(deposit: ResourceDeposit, worker_type: String, cat_hunger: float) -> bool:
	if deposit.required_worker != worker_type:
		return false
	if deposit.requires_fed_cat and cat_hunger < 35.0:
		return false
	if electricity < deposit.power_cost or resource_counts["oil"] < deposit.oil_cost:
		return false
	electricity -= deposit.power_cost
	resource_counts["oil"] -= deposit.oil_cost
	economy_ui.queue_redraw()
	return true

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
	if shelter_open:
		_sleep_until_morning()
		return
	if base_menu_open:
		_craft_selected_block()
		return
	if day_time >= 660.0 and _is_shelter_nearby():
		_enter_shelter(false)
	elif _is_base_in_front():
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
	tutorial_rotated = true
	_refresh_tutorial()
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
		item = {"type": "cat", "direction": (closest as CatBlock).direction, "worker": (closest as CatBlock).worker_type, "hunger": (closest as CatBlock).hunger}
	elif closest is PillarBlock:
		item = {"type": "pillar"}
	elif closest is BoxGenerator:
		item = {"type": "box_generator", "direction": (closest as BoxGenerator).direction}
	elif closest is SplitterBlock:
		item = {"type": "splitter", "direction": (closest as SplitterBlock).direction}
	elif closest is BridgeBlock:
		item = {"type": "bridge"}
	elif closest is FacilityBlock:
		item = {"type": "facility", "facility": (closest as FacilityBlock).facility_type}
	inventory.append(item)
	tutorial_picked = true
	_refresh_tutorial()
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
		cat.worker_type = item.get("worker", "miner")
		cat.hunger = item.get("hunger", 100.0)
		block = cat
	elif item["type"] == "pillar":
		block = PILLAR_BLOCK_SCENE.instantiate() as PillarBlock
	elif item["type"] == "box_generator":
		var generator := BOX_GENERATOR_SCENE.instantiate() as BoxGenerator
		generator.direction = place_direction
		block = generator
	elif item["type"] == "splitter":
		var splitter := SPLITTER_SCENE.instantiate() as SplitterBlock
		splitter.direction = place_direction
		block = splitter
	elif item["type"] == "bridge":
		block = BRIDGE_SCENE.instantiate() as BridgeBlock
	elif item["type"] == "facility":
		var facility := FACILITY_SCENE.instantiate() as FacilityBlock
		facility.facility_type = item.get("facility", "power_generator")
		block = facility
	else:
		block = PUSH_TILE_SCENE.instantiate() as RigidBody2D
	block.position = target + place_direction * (TILE_SIZE * 0.5) if item_type == "box_generator" else target
	if _is_base_entrance_cell(target):
		block.add_collision_exception_with(base)
	add_child(block)
	tutorial_placed = true
	_refresh_tutorial()
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
		placement_preview = _create_placement_preview(item)
	placement_preview.position = _front_cell_center()
	if placement_preview is ConveyorBlock:
		(placement_preview as ConveyorBlock).direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
	elif placement_preview is CatBlock:
		var preview_cat := placement_preview as CatBlock
		preview_cat.direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
		preview_cat.worker_type = item.get("worker", "miner")
	elif placement_preview is BoxGenerator:
		(placement_preview as BoxGenerator).direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
	elif placement_preview is SplitterBlock:
		(placement_preview as SplitterBlock).direction = Vector2.RIGHT.rotated(placement_rotation * PI / 2.0).round()
	placement_preview.position = _preview_position(item_type)
	placement_preview.queue_redraw()

func _create_placement_preview(item: Dictionary) -> RigidBody2D:
	var item_type: String = item["type"]
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
	elif item_type == "splitter":
		block = SPLITTER_SCENE.instantiate() as SplitterBlock
	elif item_type == "bridge":
		block = BRIDGE_SCENE.instantiate() as BridgeBlock
	elif item_type == "facility":
		var facility := FACILITY_SCENE.instantiate() as FacilityBlock
		facility.facility_type = item.get("facility", "power_generator")
		block = facility
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
	if item_type in ["conveyor", "splitter"]:
		return true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(62.0, 30.0) if item_type == "box_generator" else Vector2.ONE * 30.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	var center := target + direction * (TILE_SIZE * 0.5) if item_type == "box_generator" else target
	query.transform = Transform2D(direction.angle() if item_type == "box_generator" else 0.0, center)
	query.collision_mask = 63
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var results := get_world_2d().direct_space_state.intersect_shape(query, 8)
	if item_type == "bridge":
		if results.is_empty():
			return false
		for result in results:
			if not (result["collider"] is WaterTile):
				return false
		return true
	if _is_base_entrance_cell(target):
		results = results.filter(func(result): return result["collider"] != base)
	return results.is_empty()

func _is_base_entrance_cell(target: Vector2) -> bool:
	for direction in base.ENTRANCE_DIRECTIONS:
		if target.distance_to(base.global_position + direction * base.ENTRANCE_DISTANCE) < 2.0:
			return true
	return false

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

func _is_shelter_nearby() -> bool:
	var shelter_position: Vector2 = base.global_position + base.SHELTER_DIRECTION * base.SHELTER_DISTANCE
	return player.global_position.distance_to(shelter_position) <= 58.0

func _enter_shelter(rescued: bool) -> void:
	if shelter_open:
		return
	shelter_open = true
	base_menu_open = false
	player.controls_locked = true
	player.position = base.global_position + base.SHELTER_DIRECTION * 118.0
	if rescued:
		celebration_text = "고양이들이 기지로 데려왔어요"
		celebration_remaining = 3.0
	shelter_ui.queue_redraw()

func _sleep_until_morning() -> void:
	day_number += 1
	day_time = 0.0
	temperature = 100.0
	night_warning_shown = false
	shelter_open = false
	player.controls_locked = false
	for node in get_tree().get_nodes_in_group("cat_worker"):
		var cat := node as CatBlock
		if cat:
			cat.hunger = minf(100.0, cat.hunger + 25.0)
	celebration_text = "%d일차 - 체온을 유지하세요" % day_number
	celebration_remaining = 2.5
	shelter_ui.queue_redraw()

func _open_base_menu() -> void:
	base_menu_open = true
	_sync_placement_preview()
	_update_fabricator_status()
	player.controls_locked = true
	tutorial_menu_opened = true
	_refresh_tutorial()
	base_menu.queue_redraw()

func close_base_menu_action() -> void:
	if base_menu_open:
		_close_base_menu()

func _close_base_menu() -> void:
	base_menu_open = false
	player.controls_locked = false
	base_menu.queue_redraw()

func _cycle_fabricator_recipe() -> void:
	fabricator_selection = (fabricator_selection + 1) % fabricator_recipe_count()
	_update_fabricator_status()
	base_menu.queue_redraw()

func _craft_selected_block() -> void:
	if not recipe_unlocked(fabricator_selection):
		fabricator_status = "잠김 - 기지 %d단계 필요" % recipe_unlock_level(fabricator_selection)
		return
	var cost := recipe_cost(fabricator_selection)
	if not _can_afford(cost):
		fabricator_status = "자원이 부족합니다"
		return
	_spend_cost(cost)
	if fabricator_selection == 15:
		_upgrade_base()
		base_menu.queue_redraw()
		return
	if fabricator_selection >= 12:
		_apply_technology(fabricator_selection)
		base_menu.queue_redraw()
		return
	var block := _create_recipe_block(fabricator_selection)
	fabricator_status = "%s 제작 완료" % recipe_label(fabricator_selection)
	if fabricator_selection == 0:
		cat_crafted = true
	elif fabricator_selection == 2:
		generator_crafted = true
	elif fabricator_selection == 4:
		bridge_crafted = true
	_refresh_quest_progress()
	block.position = _find_fabricator_output_position(block)
	add_child(block)
	base_menu.queue_redraw()

func _update_fabricator_status() -> void:
	if not recipe_unlocked(fabricator_selection):
		fabricator_status = "잠김 - 기지 %d단계 필요" % recipe_unlock_level(fabricator_selection)
	else:
		fabricator_status = "제작 가능" if _can_afford(recipe_cost(fabricator_selection)) else "%s 필요" % recipe_cost_text(fabricator_selection)

func fabricator_recipe_count() -> int:
	return 16

func recipe_label(index: int) -> String:
	return ["채굴 고양이", "기둥", "상자 생성기", "분배기", "다리", "컨베이어", "발전기", "전기 고양이", "압력 고양이", "낚시장", "낚시 고양이", "서빙 고양이", "열 기술", "전력 기술", "식량 기술", "기지 업그레이드"][index]

func recipe_unlock_level(index: int) -> int:
	return [1, 1, 1, 2, 3, 2, 5, 5, 7, 4, 4, 4, 3, 5, 4, 1][index]

func recipe_unlocked(index: int) -> bool:
	return base_level >= recipe_unlock_level(index) and not (index == 15 and base_level >= 7)

func recipe_cost(index: int) -> Dictionary:
	var standard: Array[Dictionary] = [
		{"box": 3}, {"box": 3}, {"mineral": 10}, {"box": 5}, {"copper": 3}, {"copper": 1},
		{"copper": 8, "coal": 5}, {"box": 5, "copper": 5}, {"box": 5, "copper": 6},
		{"copper": 5}, {"box": 4, "copper": 3}, {"box": 4, "copper": 3},
	]
	if index < standard.size():
		return standard[index]
	if index == 15:
		return base_upgrade_cost()
	if index == 12:
		return {"copper": 5 + heat_tech * 2, "crystal": 2 + heat_tech}
	if index == 13:
		return {"copper": 5 + power_tech * 2, "crystal": 3 + power_tech * 2}
	return {"copper": 4 + food_tech * 2, "fish": 5 + food_tech * 3}

func base_upgrade_cost() -> Dictionary:
	return [{"box": 5}, {"box": 25}, {"mineral": 100}, {"copper": 5}, {"copper": 25}, {"fish": 25}][clampi(base_level - 1, 0, 5)]

func _upgrade_base() -> void:
	base_level = mini(base_level + 1, 7)
	fabricator_status = "기지 %d단계 완료 · 온기 %d칸" % [base_level, safe_radius_tiles()]
	celebration_text = fabricator_status
	celebration_remaining = 4.0
	queue_redraw()

func recipe_cost_text(index: int) -> String:
	var parts: Array[String] = []
	var names := {"box": "상자", "mineral": "미네랄", "copper": "구리", "coal": "석탄", "crystal": "수정", "oil": "석유", "uranium": "우라늄", "fish": "물고기"}
	for key in recipe_cost(index):
		parts.append("%s %d" % [names.get(key, key), recipe_cost(index)[key]])
	return " + ".join(parts)

func _can_afford(cost: Dictionary) -> bool:
	for key in cost:
		var available: int
		if key == "box": available = box_count
		elif key == "mineral": available = mineral_count
		elif key == "fish": available = fish
		else: available = resource_counts.get(key, 0)
		if available < cost[key]:
			return false
	return true

func _spend_cost(cost: Dictionary) -> void:
	for key in cost:
		if key == "box": box_count -= cost[key]
		elif key == "mineral": mineral_count -= cost[key]
		elif key == "fish": fish -= cost[key]
		else: resource_counts[key] -= cost[key]
	box_label.text = "상자  %d" % box_count
	mineral_label.text = "미네랄  %d" % mineral_count
	economy_ui.queue_redraw()

func _apply_technology(index: int) -> void:
	if index == 12:
		heat_tech += 1
		fabricator_status = "열 기술 %d단계" % heat_tech
	elif index == 13:
		power_tech += 1
		fabricator_status = "전력 기술 %d단계" % power_tech
	else:
		food_tech += 1
		fabricator_status = "식량 기술 %d단계" % food_tech
	celebration_text = fabricator_status
	celebration_remaining = 2.5

func _create_recipe_block(index: int) -> RigidBody2D:
	if index == 0 or index in [7, 8, 10, 11]:
		var cat := CAT_BLOCK_SCENE.instantiate() as CatBlock
		cat.direction = Vector2.DOWN
		cat.active_on_ready = false
		cat.worker_type = {7: "electric", 8: "pressure", 10: "fisher", 11: "server"}.get(index, "miner")
		return cat
	if index == 1: return PILLAR_BLOCK_SCENE.instantiate() as PillarBlock
	if index == 2:
		var generator := BOX_GENERATOR_SCENE.instantiate() as BoxGenerator
		generator.direction = Vector2.DOWN
		return generator
	if index == 3: return SPLITTER_SCENE.instantiate() as SplitterBlock
	if index == 4: return BRIDGE_SCENE.instantiate() as BridgeBlock
	if index == 5: return CONVEYOR_SCENE.instantiate() as ConveyorBlock
	var facility := FACILITY_SCENE.instantiate() as FacilityBlock
	facility.facility_type = "power_generator" if index == 6 else "fishing_spot"
	return facility

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
	_populate_water_ring(occupied, center_tile)
	_populate_starter_zone(occupied, center_tile)
	_populate_tier_resources(occupied, center_tile)

	for region_y in range(0, WORLD_TILES, REGION_SIZE):
		for region_x in range(0, WORLD_TILES, REGION_SIZE):
			var box_cell := _random_free_cell(rng, region_x, region_y, occupied, center_tile, player_tile)
			if box_cell.x < 0:
				continue
			occupied[box_cell] = true
			var belt_cell := _random_free_cell(rng, region_x, region_y, occupied, center_tile, player_tile)
			if belt_cell.x < 0:
				continue
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
	var target_count := int(round(float(WORLD_TILES * WORLD_TILES) / 240.0)) - 1
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

func _populate_starter_zone(occupied: Dictionary[Vector2i, bool], center_tile: Vector2i) -> void:
	var box_offsets: Array[Vector2i] = [Vector2i(4, -1), Vector2i(4, 0), Vector2i(4, 1)]
	for offset: Vector2i in box_offsets:
		var cell: Vector2i = center_tile + offset
		occupied[cell] = true
		var box := PUSH_TILE_SCENE.instantiate() as RigidBody2D
		box.position = _cell_center(cell)
		add_child(box)
	var mineral_offsets: Array[Vector2i] = [Vector2i(6, 0)]
	for index in mineral_offsets.size():
		var cell: Vector2i = center_tile + mineral_offsets[index]
		occupied[cell] = true
		var mineral := MINERAL_SCENE.instantiate() as MineralBlock
		mineral.position = _cell_center(cell)
		mineral.set_meta("clustered_spawn", index > 0)
		mineral.set_meta("starter_mineral", true)
		add_child(mineral)

func _populate_water_ring(occupied: Dictionary[Vector2i, bool], center_tile: Vector2i) -> void:
	# A distant broken river teaches bridges without forming a prison.
	for offset in range(-35, 36):
		if abs(offset) <= 3 or (abs(offset) >= 16 and abs(offset) <= 19):
			continue
		var cell := center_tile + Vector2i(24, offset)
		if occupied.has(cell):
			continue
		occupied[cell] = true
		var water := WATER_TILE_SCENE.instantiate() as WaterTile
		water.position = _cell_center(cell)
		add_child(water)

func _populate_tier_resources(occupied: Dictionary[Vector2i, bool], center_tile: Vector2i) -> void:
	_spawn_resource_tier(occupied, center_tile, "copper", 30, 7, "miner", 0, 0, false)
	_spawn_resource_tier(occupied, center_tile, "coal", 34, 5, "miner", 0, 0, true)
	_spawn_resource_tier(occupied, center_tile, "crystal", 38, 4, "miner", 2, 0, true)
	_spawn_resource_tier(occupied, center_tile, "oil", 42, 3, "pressure", 0, 0, true)
	_spawn_resource_tier(occupied, center_tile, "uranium", 46, 2, "miner", 8, 2, true)

func _spawn_resource_tier(
	occupied: Dictionary[Vector2i, bool], center_tile: Vector2i, resource_type: String,
	radius: int, count: int, worker: String, power_cost: int, oil_cost: int, fed: bool
) -> void:
	for index in count:
		var angle := TAU * float(index) / float(count) + float(radius % 5) * 0.13
		var offset := Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		var cell := center_tile + offset
		while occupied.has(cell):
			cell += Vector2i.RIGHT
		occupied[cell] = true
		var deposit := RESOURCE_DEPOSIT_SCENE.instantiate() as ResourceDeposit
		deposit.resource_type = resource_type
		deposit.required_worker = worker
		deposit.power_cost = power_cost
		deposit.oil_cost = oil_cost
		deposit.requires_fed_cat = fed
		deposit.position = _cell_center(cell)
		deposit.set_meta("tier_radius", radius)
		add_child(deposit)

func _is_free_mineral_cell(cell: Vector2i, occupied: Dictionary[Vector2i, bool], center_tile: Vector2i, player_tile: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WORLD_TILES and cell.y < WORLD_TILES and not occupied.has(cell) and not (abs(cell.x - center_tile.x) <= START_CLEAR_RADIUS and abs(cell.y - center_tile.y) <= START_CLEAR_RADIUS) and not (abs(cell.x - player_tile.x) <= 1 and abs(cell.y - player_tile.y) <= 1)

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
	for attempt in 200:
		var cell := Vector2i(
			region_x + rng.randi_range(0, REGION_SIZE - 1),
			region_y + rng.randi_range(0, REGION_SIZE - 1)
		)
		if occupied.has(cell):
			continue
		if abs(cell.x - center_tile.x) <= START_CLEAR_RADIUS and abs(cell.y - center_tile.y) <= START_CLEAR_RADIUS:
			continue
		if abs(cell.x - player_tile.x) <= 1 and abs(cell.y - player_tile.y) <= 1:
			continue
		return cell
	return Vector2i(-1, -1)

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * (TILE_SIZE / 2.0)

func _process(delta: float) -> void:
	elapsed_time += delta
	_update_survival(delta)
	_update_staged_ui()
	celebration_remaining = maxf(0.0, celebration_remaining - delta)
	while not automated_delivery_times.is_empty() and automated_delivery_times[0] < elapsed_time - 60.0:
		automated_delivery_times.pop_front()
	throughput_label.text = "기지 %d단계\n분당 상자  %d" % [base_level, automated_delivery_times.size()]
	var tile := Vector2i(player.position / TILE_SIZE) + Vector2i.ONE
	info.text = "위치  %d, %d" % [tile.x, tile.y]
	if not tutorial_moved and player.position.distance_to(tutorial_start_position) >= 20.0:
		tutorial_moved = true
		_refresh_tutorial()
	if placement_action_held and not base_menu_open:
		placement_hold_elapsed += delta
		while placement_hold_elapsed >= PLACEMENT_ROTATE_INTERVAL:
			placement_hold_elapsed -= PLACEMENT_ROTATE_INTERVAL
			_rotate_placement()
	if preview_visible and is_instance_valid(placement_preview):
		var preview_type: String = placement_preview.get_meta("preview_type", "box")
		placement_preview.position = _preview_position(preview_type)
	if collect_action_held:
		_collect_nearby_mineral_resources()

func _update_survival(delta: float) -> void:
	if not shelter_open and tutorial_complete():
		day_time += delta
		var distance_tiles := player.global_position.distance_to(base.global_position) / TILE_SIZE
		var warm_radius := float(safe_radius_tiles())
		if distance_tiles > warm_radius:
			var exposure := 1.0 + (distance_tiles - warm_radius) * 0.45
			temperature = maxf(0.0, temperature - delta * exposure * 8.0)
		else:
			temperature = minf(100.0, temperature + delta * 5.0)
		if day_time >= 660.0 and not night_warning_shown:
			night_warning_shown = true
			celebration_text = "밤이 옵니다 - 기지로 돌아가세요"
			celebration_remaining = 4.0
		if day_time >= 720.0:
			_enter_shelter(true)
	elif not tutorial_complete():
		temperature = 100.0
	var minute := int(day_time) / 60
	var second := int(day_time) % 60
	survival_status.text = "%d일  %02d:%02d   체온 %d   온기 %d" % [day_number, minute, second, int(temperature), safe_radius_tiles()]
	if ui_stage() >= 3:
		survival_status.text += "\n전력 +%d/분   식량 +%d/분   열 %d" % [power_per_minute(), food_per_minute(), heat_per_minute()]
	if temperature < 35.0:
		survival_status.modulate = Color("ff9d8a")
	else:
		survival_status.modulate = Color.WHITE

func _update_staged_ui() -> void:
	var stage := ui_stage()
	box_label.visible = stage >= 1
	mineral_label.visible = stage >= 1
	throughput_label.visible = stage >= 1
	economy_ui.visible = stage >= 2
	minimap.visible = stage >= 2
	$UI/WorldSize.visible = stage >= 2

func _collect_nearby_mineral_resources() -> void:
	var collectable := get_tree().get_nodes_in_group("mined_resource") + get_tree().get_nodes_in_group("world_resource")
	for node in collectable:
		var resource := node as RigidBody2D
		if resource == null or resource.has_meta("collected"):
			continue
		if resource.global_position.distance_to(player.global_position) > RESOURCE_COLLECT_RADIUS:
			continue
		resource.set_meta("collected", true)
		resource.queue_free()
		if resource.is_in_group("world_resource"):
			var resource_type: String = resource.get("resource_type")
			resource_counts[resource_type] += 1
			economy_ui.queue_redraw()
		else:
			mineral_count += 1
			mineral_label.text = "미네랄  %d" % mineral_count
	_check_mineral_quest()
	_refresh_quest_progress()

func _check_mineral_quest() -> void:
	if quest_step == 2 and mineral_count >= 10:
		_advance_quest("재료 준비 완료")

func _advance_quest(message: String) -> void:
	quest_step = mini(quest_step + 1, 12)
	celebration_text = message
	celebration_remaining = 2.5
	quest_ui.queue_redraw()
	_refresh_quest_progress()

func _refresh_quest_progress() -> void:
	if quest_step == 1 and cat_crafted:
		_advance_quest("채굴 고양이 가동")
	elif quest_step == 2 and mineral_count >= 10:
		_advance_quest("재료 준비 완료")
	elif quest_step == 3 and generator_crafted:
		_advance_quest("상자 생성기 가동")
	elif quest_step == 4 and automated_boxes_delivered >= 3:
		_advance_quest("자동화 완료 - 기지 업그레이드 가능")
	elif quest_step == 5 and resource_counts["copper"] >= 3:
		_advance_quest("구리 도구 해금")
	elif quest_step == 6 and bridge_crafted:
		_advance_quest("외부 지역 개방")
	elif quest_step == 7 and fish >= 5:
		_advance_quest("고양이 식사 완료")
	elif quest_step == 8 and electricity >= 10:
		_advance_quest("전력망 가동")
	elif quest_step == 9 and resource_counts["crystal"] >= 5:
		_advance_quest("수정 시대 개막")
	elif quest_step == 10 and resource_counts["oil"] >= 5:
		_advance_quest("압력망 가동")
	elif quest_step == 11 and resource_counts["uranium"] >= 1:
		_advance_quest("심층 공장 완성")

func quest_title() -> String:
	return ["1  첫 상자 납품", "2  채굴 고양이 제작", "3  미네랄 수집", "4  상자 생성기 제작", "5  상자 자동화", "6  구리 시대", "7  물길 건너기", "8  고양이 먹이", "9  전력망", "10  수정 시대", "11  석유 압력", "12  심층 에너지", "모든 목표 완료"][quest_step]

func quest_detail() -> String:
	return [
		"상자 1개를 기지의 금색 투입구로 미세요.",
		"기지에서 채굴 고양이를 만드세요. (상자 3개)",
		"미네랄 10개를 모으세요.",
		"기지에서 상자 생성기를 만드세요. (미네랄 10개)",
		"생성된 상자를 기지에 납품하세요. %d/3" % automated_boxes_delivered,
		"구리를 채굴해 납품하세요. %d/3" % mini(resource_counts["copper"], 3),
		"다리를 만들고 물길을 건너세요. (구리 3개)",
		"낚시장 옆에 낚시 고양이를, 작업 고양이 옆에 서빙 고양이를 두세요. 물고기 %d/5" % mini(fish, 5),
		"고양이에게 먹이를 주고 발전기와 전기 고양이를 만드세요. %d/10" % mini(electricity, 10),
		"전력을 사용해 수정을 납품하세요. %d/5" % mini(resource_counts["crystal"], 5),
		"압력 고양이로 석유를 납품하세요. %d/5" % mini(resource_counts["oil"], 5),
		"전력과 석유를 사용해 우라늄 1개를 납품하세요.",
		"모든 설비가 가동 중입니다. 자유롭게 자동화를 확장하세요.",
	][quest_step]

func quest_unlock_help() -> String:
	return [
		"채굴 고양이는 앞 1칸의 미네랄을 캐서 뒤로 자원을 놓습니다.",
		"기지 제작소에서 채굴 고양이를 만들고 원석을 바라보게 설치하세요.",
		"Z를 누르고 있으면 주변의 작은 미네랄 자원을 회수합니다.",
		"상자 생성기는 뒤로 미네랄 3개를 받아 앞에서 상자를 만듭니다.",
		"기지 업그레이드로 분배기·컨베이어 등 다음 제작법을 여세요.",
		"구리 원석 앞에 채굴 고양이를 두면 별도 전력 없이 채굴합니다.",
		"다리는 물 타일 위에 겹쳐 설치하며 그 한 칸의 통행을 엽니다.",
		"낚시장 옆 낚시 고양이가 물고기를 만들고 서빙 고양이가 배식합니다.",
		"석탄과 발전기 옆 전기 고양이가 전력을 생산합니다.",
		"수정은 채굴할 때 전력이 필요합니다. 발전 설비를 먼저 늘리세요.",
		"석유는 압력 고양이만 채굴할 수 있습니다.",
		"우라늄 채굴은 전력과 석유를 함께 소비합니다.",
		"기지 레벨과 기술을 높여 온기와 생산량을 계속 확장하세요.",
	][quest_step]

func tutorial_complete() -> bool:
	return tutorial_step >= 6

func tutorial_title() -> String:
	return ["정비공 이동", "블록 줍기", "설치 방향 회전", "블록 설치", "기지에 납품", "제작 메뉴 열기"][tutorial_step]

func tutorial_detail() -> String:
	return [
		"WASD·방향키 또는 오른쪽 이동 휠을 드래그하세요.",
		"1×1 블록을 바라보고 Z를 누르세요. 모바일은 왼쪽 Z 버튼입니다.",
		"X를 0.7초 누를 때마다 설치 방향이 90도 회전합니다.",
		"X를 짧게 눌러 앞쪽의 표시된 칸에 설치하세요.",
		"갈색 상자를 금색 투입구로 미세요. 초록색 출구에서 물건이 나옵니다.",
		"기지를 보고 Z를 누르세요. X 선택·Z 제작·RUN 또는 Esc 닫기입니다.",
	][tutorial_step]

func _refresh_tutorial() -> void:
	var before := tutorial_step
	while tutorial_step < 6:
		var tutorial_flags: Array[bool] = [tutorial_moved, tutorial_picked, tutorial_rotated, tutorial_placed, tutorial_delivered, tutorial_menu_opened]
		var done: bool = tutorial_flags[tutorial_step]
		if not done:
			break
		tutorial_step += 1
	if before < 6 and tutorial_step >= 6:
		celebration_text = "기초 완료 - 이제 자동화를 시작하세요"
		celebration_remaining = 3.0
	tutorial_ui.queue_redraw()
	quest_ui.queue_redraw()

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
	# Snow terrain.
	draw_rect(Rect2(0, 0, WORLD_SIZE, WORLD_SIZE), Color("edf1f2"))

	# Deterministic patches break up the grid and hint at future resource fields.
	for y in range(WORLD_TILES):
		for x in range(WORLD_TILES):
			var noise_value := (x * 37 + y * 73 + x * y * 3) % 97
			if noise_value < 8:
				var cell := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				draw_rect(cell, Color("e4eaec"))

	# Warm ground glow communicates the safe radius before the fog boundary.
	var warm_radius := float(safe_radius_tiles() * TILE_SIZE)
	for ring in range(8, 0, -1):
		var ratio := float(ring) / 8.0
		draw_circle(base.position, warm_radius * ratio, Color(1.0, 0.55, 0.18, 0.018 + (1.0 - ratio) * 0.018))

	# One-pixel grid: 100 × 100 cells.
	var grid_color := Color(0.42, 0.49, 0.52, 0.18)
	for i in range(WORLD_TILES + 1):
		var p := float(i * TILE_SIZE)
		draw_line(Vector2(p, 0), Vector2(p, WORLD_SIZE), grid_color, 1.0)
		draw_line(Vector2(0, p), Vector2(WORLD_SIZE, p), grid_color, 1.0)

	# World border.
	draw_rect(Rect2(1, 1, WORLD_SIZE - 2, WORLD_SIZE - 2), Color("788a91"), false, 3.0)
