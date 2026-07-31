extends SceneTree

## The reported bug was the character "teleporting" slightly between animation
## frames. The sheet's drawings sit at different offsets inside their cells, so
## any fixed slicing shifts them. This proves every frame's foot lands on the
## same spot, which is the property the player actually sees.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scale := Vector2(PlayerActor.SPRITE_SCALE, PlayerActor.SPRITE_SCALE)

	_assert(PlayerActor.FRAME_REGIONS.size() == 12, "every sheet frame has a measured region")
	_assert(PlayerActor.FRAME_FOOT.size() == 12, "every sheet frame has a measured foot anchor")

	# No region may overlap another, or a frame would show part of its neighbour.
	for a in 12:
		var ra: Rect2 = PlayerActor.FRAME_REGIONS[a]
		_assert(ra.size.x > 0.0 and ra.size.y > 0.0, "frame %d has a real region" % a)
		var foot: Vector2 = PlayerActor.FRAME_FOOT[a]
		_assert(foot.x >= 0.0 and foot.x <= ra.size.x, "frame %d foot sits inside its region" % a)
		_assert(foot.y >= 0.0 and foot.y <= ra.size.y, "frame %d foot is on its own drawing" % a)
		for b in range(a + 1, 12):
			var rb: Rect2 = PlayerActor.FRAME_REGIONS[b]
			_assert(not ra.intersects(rb), "frames %d and %d do not share pixels" % [a, b])

	# Vertical consistency: the drawn bottom edge must sit at the same height for
	# every frame, or the character bobs when the pose changes.
	for row in 3:
		var bottoms: Array[float] = []
		for column in 4:
			var index: int = row * 4 + column
			var region: Rect2 = PlayerActor.FRAME_REGIONS[index]
			var offset: Vector2 = PlayerActor.foot_offset(index, scale, 0.0, false)
			var placed_y: float = PlayerActor.TARGET_FOOT.y - offset.y
			bottoms.append(placed_y + region.size.y * 0.5 * scale.y)
		for column in range(1, 4):
			_assert(absf(bottoms[column] - bottoms[0]) < 2.0,
				"row %d frame %d keeps the same ground line" % [row, column])

	# Horizontal anchoring is by drawing centre, so no frame may introduce any
	# sideways offset at all. The previous cell-grid slicing spread the idle row
	# by 16.5px on screen, which is the teleport the player reported.
	for index in 12:
		var offset: Vector2 = PlayerActor.foot_offset(index, scale, 0.0, false)
		_assert(is_zero_approx(offset.x), "frame %d introduces no horizontal shift" % index)
		var mirrored: Vector2 = PlayerActor.foot_offset(index, scale, 0.0, true)
		_assert(mirrored.is_equal_approx(offset), "frame %d anchors identically when mirrored" % index)

	# --- Which way she is drawn --------------------------------------------------
	# Standing still used to snap her back to facing right, because the flip came
	# from Defs.facing_view -- the cat's table, where west is a separate drawing
	# rather than a mirror. Idle must keep the direction she was last walking.
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	var actor: PlayerActor = main.player

	actor._animate(0.1, Vector2.LEFT, false)
	_assert(actor.character.flip_h, "walking left mirrors her")
	actor._animate(0.1, Vector2.ZERO, false)
	_assert(actor.character.flip_h, "and she is still facing left after stopping")

	actor._animate(0.1, Vector2.RIGHT, false)
	_assert(not actor.character.flip_h, "walking right un-mirrors her")
	actor._animate(0.1, Vector2.ZERO, false)
	_assert(not actor.character.flip_h, "and she stays facing right after stopping")

	# Pure vertical movement has no horizontal heading to adopt, so it must leave
	# the existing one alone rather than resetting it.
	actor._animate(0.1, Vector2.LEFT, false)
	actor._animate(0.1, Vector2.UP, false)
	_assert(actor.character.flip_h, "walking straight up keeps the last horizontal facing")
	actor._animate(0.1, Vector2.DOWN, false)
	_assert(actor.character.flip_h, "and so does walking straight down")
	actor._animate(0.1, Vector2.ZERO, false)
	_assert(actor.character.flip_h, "and stopping after that still faces left")

	# Diagonals carry a horizontal component and should be honoured.
	actor._animate(0.1, Vector2(0.7, -0.7), false)
	_assert(not actor.character.flip_h, "walking up-right faces right")
	actor._animate(0.1, Vector2(-0.7, -0.7), false)
	_assert(actor.character.flip_h, "walking up-left faces left")

	# Sprinting and idling share the orientation; only the motion differs.
	actor._animate(0.1, Vector2.LEFT, true)
	_assert(actor.character.flip_h, "sprinting left faces left")
	actor._animate(0.1, Vector2.ZERO, false)
	_assert(actor.character.flip_h, "and idling after a sprint keeps it")

	if failures == 0:
		print("ANIMATION_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("ANIMATION_TEST: FAIL - " + message)
		failures += 1
