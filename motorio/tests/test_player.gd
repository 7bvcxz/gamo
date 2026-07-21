extends SceneTree

var failures := 0

func _initialize() -> void:
	var player := load("res://scenes/Player.tscn").instantiate() as CharacterBody2D
	root.add_child(player)
	var sprite := player.get_node("Character") as Sprite2D
	player.set("character", sprite)
	_assert(player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "player uses floating top-down motion")
	_assert(sprite.hframes == 4 and sprite.vframes == 3, "character has a 4x3 animation sheet")

	player.call("_update_character_animation", 0.0, Vector2.ZERO, false)
	_assert(sprite.frame == 0, "idle keeps one registered source frame")
	var idle_x := sprite.position.x
	for step in range(1, 13):
		player.call("_update_character_animation", 1.0 / 60.0, Vector2.ZERO, false)
		_assert(sprite.frame == 0, "idle source frame remains stable")
		_assert(abs(sprite.position.x - idle_x) < 0.001, "idle has no horizontal jitter")
		var idle_foot := sprite.position + (Vector2(249.0, 339.0) - Vector2(181.0, 181.0)) * sprite.scale
		_assert(idle_foot.distance_to(Vector2(0.0, 13.0)) < 0.01, "idle breathing keeps feet fixed")
	player.call("_update_character_animation", 0.0, Vector2.DOWN, false)
	_assert(sprite.frame >= 4 and sprite.frame <= 7, "walk animation row")
	player.call("_update_character_animation", 0.0, Vector2.DOWN, true)
	_assert(sprite.frame >= 8 and sprite.frame <= 11, "run animation row")
	if failures == 0:
		print("PLAYER_TEST: PASS")
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("PLAYER_TEST failed: %s" % label)
		failures += 1
