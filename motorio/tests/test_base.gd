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
	var entrances := base.find_children("Entrance*", "Area2D", false, false)
	_assert(entrances.size() == 3, "base has three intake entrances and one output")
	for entrance in entrances:
		var entrance_shape := entrance.get_child(0) as CollisionShape2D
		var rectangle := entrance_shape.shape as RectangleShape2D
		_assert(rectangle.size == Vector2.ONE * TILE_SIZE - Vector2.ONE * 4.0, "entrance detector fits inside one tile")
	_assert(main.get("box_count") == 0, "base starts with zero boxes")

	var collision := player.move_and_collide(Vector2(0, -30), true)
	_assert(collision != null, "player cannot move through base")
	_assert(collision.get_collider() == base, "player collision target is base")

	var box := load("res://scenes/PushTile.tscn").instantiate() as RigidBody2D
	box.position = base.position + Vector2.UP * 72.0
	main.add_child(box)
	await physics_frame
	await process_frame
	_assert(main.get("box_count") == 1, "entering box increments count once")
	_assert(not is_instance_valid(box), "received box is removed")
	var box_label := main.get_node("UI/BoxCount") as Label
	_assert(box_label.text == "BOX  1", "box count is shown in top-right UI")

	print("BASE_TEST: PASS")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("BASE_TEST: FAIL - " + message)
		quit(1)
