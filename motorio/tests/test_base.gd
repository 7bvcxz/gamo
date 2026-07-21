extends SceneTree

const TILE_SIZE := 32.0
const WORLD_SIZE := 3200.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = scene.instantiate()
	root.add_child(main)
	await physics_frame

	var base := main.get_node("Base") as StaticBody2D
	var player := main.get_node("Player") as CharacterBody2D
	var shape_node := base.get_node("CollisionShape2D") as CollisionShape2D
	var circle := shape_node.shape as CircleShape2D
	var world_center := Vector2(WORLD_SIZE, WORLD_SIZE) / 2.0

	_assert(base.position == world_center, "base is centered in world")
	_assert(circle.radius * 2.0 <= TILE_SIZE * 5.0, "base fits inside 5x5 tiles")
	_assert(player.position.distance_to(base.position) > circle.radius + 11.0, "player starts outside base")

	var collision := player.move_and_collide(Vector2(0, -30), true)
	_assert(collision != null, "player cannot move through base")
	_assert(collision.get_collider() == base, "player collision target is base")

	print("BASE_TEST: PASS")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("BASE_TEST: FAIL - " + message)
		quit(1)
