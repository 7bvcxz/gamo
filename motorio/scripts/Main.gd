extends Node2D

const TILE_SIZE := 32
const WORLD_TILES := 100
const WORLD_SIZE := TILE_SIZE * WORLD_TILES
const REGION_SIZE := 5
const SPAWN_SEED := 20260720
const PUSH_TILE_SCENE := preload("res://scenes/PushTile.tscn")
const CONVEYOR_SCENE := preload("res://scenes/Conveyor.tscn")
const CARDINAL_DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

@onready var player: CharacterBody2D = $Player
@onready var base: StaticBody2D = $Base
@onready var info: Label = $UI/Info
@onready var version_label: Label = $UI/Version
@onready var touch_controls: TouchControls = $UI/TouchControls

func _ready() -> void:
	var world_center := Vector2(WORLD_SIZE, WORLD_SIZE) / 2.0
	base.position = world_center
	player.position = world_center + Vector2(0, TILE_SIZE * 3)
	player.world_bounds = Rect2(0.0, 0.0, WORLD_SIZE, WORLD_SIZE)
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	touch_controls.player = player
	_create_world_walls()
	_populate_world()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_SIZE
	camera.limit_bottom = WORLD_SIZE
	camera.limit_smoothed = true
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
		if abs(cell.x - center_tile.x) <= 2 and abs(cell.y - center_tile.y) <= 2:
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
