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
	_assert(sprite.frame >= 0 and sprite.frame <= 3, "idle animation row")
	player.call("_update_character_animation", 0.0, Vector2.DOWN, false)
	_assert(sprite.frame >= 4 and sprite.frame <= 7, "walk animation row")
	player.call("_update_character_animation", 0.0, Vector2.DOWN, true)
	_assert(sprite.frame >= 8 and sprite.frame <= 11, "run animation row")
	var idle_feet: Array[Vector2] = []
	var anchors := [Vector2(249.0, 339.0), Vector2(193.5, 339.0), Vector2(199.0, 339.0), Vector2(91.5, 339.0)]
	for frame_index in range(4):
		player.call("_set_character_frame", frame_index)
		idle_feet.append(sprite.position + (anchors[frame_index] - Vector2(181.0, 181.0)) * 0.115)
	for foot in idle_feet:
		_assert(foot.distance_to(Vector2(0.0, 13.0)) < 0.01, "idle frames share one foot anchor")

	if failures == 0:
		print("PLAYER_TEST: PASS")
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("PLAYER_TEST failed: %s" % label)
		failures += 1
