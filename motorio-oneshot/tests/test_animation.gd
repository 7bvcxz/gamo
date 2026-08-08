extends SceneTree

## The reported bug was the character "teleporting" slightly between animation
## frames, and the fix was to stop hand-measuring a sheet that was never in
## register. Grim's sheets come out of tools/sprite normalised -- uniform cells,
## one anchor -- so what is checked here changed with them: not twelve
## measurements agreeing, but that the sheets really are uniform and the one
## anchor really is where the pipeline promised.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scale := Vector2(PlayerActor.SPRITE_SCALE, PlayerActor.SPRITE_SCALE)

	# The sheets are exactly as wide as their frame count says. A sheet and a
	# count that disagree show a sliver of the next frame, or clip the last one.
	for sheet_info: Array in [
		[PlayerActor.IDLE_SHEET, PlayerActor.FRAMES, "idle"],
		[PlayerActor.WALK_SHEET, PlayerActor.FRAMES, "walk"],
		[PlayerActor.WALK_E_SHEET, PlayerActor.FRAMES, "walk east"],
	]:
		var texture: Texture2D = sheet_info[0]
		var frames: int = sheet_info[1]
		var label: String = sheet_info[2]
		_assert(texture.get_height() == int(PlayerActor.CELL),
			"%s sheet is one cell tall" % label)
		_assert(texture.get_width() == frames * int(PlayerActor.CELL),
			"%s sheet is %d cells wide" % [label, frames])

	# The anchor is inside the cell and below its middle, which is what makes it
	# a foot rather than a centre.
	_assert(PlayerActor.FOOT_ANCHOR.y > PlayerActor.CELL * 0.5,
		"the anchor is in the lower half of the cell")
	_assert(PlayerActor.FOOT_ANCHOR.y < PlayerActor.CELL,
		"the anchor is inside the cell")

	# Every motion is the same shape now, and the sheets have to agree with it.
	_assert(PlayerActor.FRAMES == 8, "eight frames")
	_assert(is_equal_approx(PlayerActor.FPS, 10.0), "ten a second")

	# Half scale, so a 128 cell draws as a 64-pixel figure about one tile tall.
	# If this drifts the character silently changes size relative to the world.
	_assert(is_equal_approx(PlayerActor.SPRITE_SCALE, 0.5),
		"the sheet is drawn at half scale")

	# The anchor no longer depends on the frame at all, which is the point of
	# normalising the sheets: every cell is the same size and puts the feet in the
	# same place, so there is one offset rather than twelve measurements. The old
	# per-frame table existed to paper over a sheet whose drawings sat at
	# different offsets, and it spread the idle row 16.5px across the screen.
	var offset: Vector2 = PlayerActor.foot_offset(scale, 0.0)
	_assert(is_zero_approx(offset.x), "the anchor introduces no horizontal shift")
	_assert(offset.y > 0.0, "the anchor sits below the cell centre")
	# Mirroring is exact because the anchor is on the cell's centre line; nothing
	# has to be compensated when she turns.
	_assert(is_zero_approx(PlayerActor.FOOT_ANCHOR.x - PlayerActor.CELL * 0.5),
		"the anchor is on the cell centre line, so a flip is exact")

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
