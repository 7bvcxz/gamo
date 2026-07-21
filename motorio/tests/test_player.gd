extends SceneTree

var failures := 0

func _initialize() -> void:
	var player := load("res://scenes/Player.tscn").instantiate() as CharacterBody2D
	root.add_child(player)
	var sprite := player.get_node("Character") as Sprite2D
	player.set("character", sprite)
	_assert(player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "player uses floating top-down motion")
	_assert(sprite.hframes == 4 and sprite.vframes == 3, "character has a 4x3 animation sheet")
	_assert(_action_has_key("move_left", KEY_LEFT), "left arrow is mapped to move_left")
	_assert(_action_has_key("move_right", KEY_RIGHT), "right arrow is mapped to move_right")
	_assert(_action_has_key("move_up", KEY_UP), "up arrow is mapped to move_up")
	_assert(_action_has_key("move_down", KEY_DOWN), "down arrow is mapped to move_down")

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
	_assert(sprite.frame == 4, "walk keeps one registered source frame")
	var walk_rotation_min := sprite.rotation
	var walk_rotation_max := sprite.rotation
	for step in range(1, 13):
		player.call("_update_character_animation", 1.0 / 60.0, Vector2.DOWN, false)
		_assert(sprite.frame == 4, "walk source frame remains stable")
		walk_rotation_min = min(walk_rotation_min, sprite.rotation)
		walk_rotation_max = max(walk_rotation_max, sprite.rotation)
	_assert(walk_rotation_max - walk_rotation_min > 0.05, "walk animation has visible body motion")
	player.call("_update_character_animation", 0.0, Vector2.DOWN, true)
	_assert(sprite.frame == 8, "run keeps one registered source frame")
	for step in range(1, 13):
		player.call("_update_character_animation", 1.0 / 60.0, Vector2.DOWN, true)
		_assert(sprite.frame == 8, "run source frame remains stable")

	player.set("facing", Vector2.RIGHT)
	player.call("_update_character_animation", 0.0, Vector2.RIGHT, false)
	var right_foot := _sprite_foot(sprite, Vector2(249.0, 321.0))
	player.set("facing", Vector2.LEFT)
	player.call("_update_character_animation", 0.0, Vector2.LEFT, false)
	var left_foot := _sprite_foot(sprite, Vector2(249.0, 321.0))
	_assert(right_foot.distance_to(left_foot) < 0.01, "left-right flip keeps the same foot anchor")
	if failures == 0:
		print("PLAYER_TEST: PASS")
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("PLAYER_TEST failed: %s" % label)
		failures += 1

func _sprite_foot(sprite: Sprite2D, anchor: Vector2) -> Vector2:
	var delta := anchor - Vector2(181.0, 181.0)
	if sprite.flip_h:
		delta.x = -delta.x
	return sprite.position + (delta * sprite.scale).rotated(sprite.rotation)

func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event and key_event.keycode == keycode:
			return true
	return false
