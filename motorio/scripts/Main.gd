extends Node2D

const TILE_SIZE := 32
const WORLD_TILES := 100
const WORLD_SIZE := TILE_SIZE * WORLD_TILES

@onready var player: CharacterBody2D = $Player
@onready var info: Label = $UI/Info

func _ready() -> void:
	player.position = Vector2(WORLD_SIZE, WORLD_SIZE) / 2.0
	player.world_bounds = Rect2(0.0, 0.0, WORLD_SIZE, WORLD_SIZE)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_SIZE
	camera.limit_bottom = WORLD_SIZE
	camera.limit_smoothed = true
	queue_redraw()

func _process(_delta: float) -> void:
	var tile := Vector2i(player.position / TILE_SIZE) + Vector2i.ONE
	info.text = "WASD / 방향키로 이동\n위치  %d, %d" % [tile.x, tile.y]

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
