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
		[PlayerActor.RUN_SHEET, PlayerActor.FRAMES, "run"],
		[PlayerActor.RUN_E_SHEET, PlayerActor.FRAMES, "run east"],
		[PlayerActor.WALK_N_SHEET, PlayerActor.FRAMES, "walk north"],
		[PlayerActor.RUN_N_SHEET, PlayerActor.FRAMES, "run north"],
		[PlayerActor.MINE_SHEET, PlayerActor.FRAMES, "mine"],
		[PlayerActor.MINE_W_SHEET, PlayerActor.FRAMES, "mine west"],
		[PlayerActor.MINE_N_SHEET, PlayerActor.FRAMES, "mine north"],
		[MachineLayer.CAT_IDLE_SHEET, MachineLayer.CAT_FRAMES, "cat idle"],
		[MachineLayer.CAT_WALK_SHEET, MachineLayer.CAT_FRAMES, "cat walk"],
		[MachineLayer.CAT_WALK_E_SHEET, MachineLayer.CAT_FRAMES, "cat walk east"],
		[MachineLayer.CAT_WALK_N_SHEET, MachineLayer.CAT_FRAMES, "cat walk north"],
	]:
		var texture: Texture2D = sheet_info[0]
		var frames: int = sheet_info[1]
		var label: String = sheet_info[2]
		# Cells are the same size for the cat as for the player; only the size it
		# is drawn at differs.
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
	# The run is faster on purpose: its source stride is 0.58s and eight frames at
	# ten would stretch it to 0.80s, arriving slower than it was generated.
	_assert(PlayerActor.RUN_FPS > PlayerActor.FPS, "the run plays faster than the walk")
	var stride: float = PlayerActor.FRAMES / PlayerActor.RUN_FPS
	_assert(stride > 0.5 and stride < 0.65, "a run stride lands near its source 0.58s (%.2f)" % stride)

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

	# No rocking, standing or moving. The body used to tilt left and right in time
	# with the stride -- added when the walk was four drawings that did not move on
	# their own -- and the sheet carries that lean itself now, so doing it again
	# reads as a wobble. Driven rather than read off a constant, because the
	# rotation is assigned in three places and any of them could put it back.
	# Moving plays the sheet and nothing else: no rocking, no squash, no hop. Each
	# of those was added for a sheet that could not move on its own and each was
	# later caught fighting the drawing, so the absence is asserted rather than
	# assumed. Sampled across a cycle because a single instant would pass even if
	# the motion were still there.
	var flat := Vector2(PlayerActor.SPRITE_SCALE, PlayerActor.SPRITE_SCALE)
	actor.set("_walk_input", Vector2(0, 1))
	for t: float in [0.0, 0.09, 0.17, 0.26, 0.38, 0.51, 0.66]:
		actor.animation_time = t
		for sprinting: bool in [false, true]:
			actor._moving(sprinting)
			_assert(actor.character.scale.is_equal_approx(flat),
				"moving does not squash or stretch at t=%.2f" % t)
			_assert(actor.character.position.is_equal_approx(
				PlayerActor.TARGET_FOOT - PlayerActor.foot_offset(flat, 0.0)),
				"moving does not hop at t=%.2f" % t)

	actor.animation_time = 0.4
	actor._idle()
	_assert(is_zero_approx(actor.character.rotation), "standing still does not tilt")
	for t: float in [0.0, 0.12, 0.31, 0.55, 0.78]:
		actor.animation_time = t
		actor._moving(false)
		_assert(is_zero_approx(actor.character.rotation), "walking does not rock at t=%.2f" % t)
		actor._moving(true)
		_assert(is_zero_approx(actor.character.rotation), "running does not rock at t=%.2f" % t)


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

	# The cat is drawn at nine tenths of Grim, and its shadow sits under its feet
	# rather than under the middle of its cell. Both used to be loose numbers --
	# 44 pixels tall and a shadow four pixels out of place -- and neither could
	# survive changing the other.
	var grim_height: float = PlayerActor.CELL * PlayerActor.SPRITE_SCALE
	_assert(is_equal_approx(MachineLayer.CAT_DRAW, grim_height * 0.9),
		"고양이는 Grim의 0.9배로 그려진다")
	_assert(MachineLayer.CAT_HEAD_FRACTION < MachineLayer.CAT_FOOT_FRACTION,
		"머리는 발보다 위에 있다")

	# The cat, its shadow and everything hung above it come from one function, so
	# they cannot drift apart. This is checked rather than assumed because they
	# did drift: the cat in her arms kept a centre offset from when a cat was 44
	# pixels tall while the ones on the ground moved to anchoring on the feet.
	var stand: Vector2 = Vector2(300.0, 200.0)
	for puff: float in [0.96, 1.0, 1.04]:
		var box: Rect2 = MachineLayer.cat_rect(stand, puff, false, 0.0)
		var feet: float = box.position.y + MachineLayer.CAT_FOOT_FRACTION * box.size.y
		_assert(is_equal_approx(feet, MachineLayer.cat_shadow_at(stand).y),
			"숨을 쉬어도 발이 그림자 위에 있다 (%.2f)" % puff)
		_assert(is_equal_approx(box.get_center().x, stand.x), "좌우 중심이 맞는다")
		_assert(MachineLayer.cat_head_y(box) < feet, "머리가 발 위에 온다")
	# Mirrored, the sprite occupies the same span; only the texture is reversed.
	var right: Rect2 = MachineLayer.cat_rect(stand, 1.0, false, 0.0)
	var left: Rect2 = MachineLayer.cat_rect(stand, 1.0, true, 0.0)
	_assert(is_equal_approx(left.position.x + left.size.x, right.position.x),
		"반전해도 같은 자리를 덮는다")
	_assert(is_equal_approx(left.position.y, right.position.y), "반전이 높이를 바꾸지 않는다")
	# Cats standing in a line must not stand inside each other. The failure this
	# guards is indirect and that is why it needs stating: overlapping cats put
	# one cat's body over the next one's shadow and hunger bar, and what a player
	# sees then is not crowding, it is sprites that have come loose from their
	# own shadows.
	var apart: Rect2 = MachineLayer.cat_rect(stand + Vector2(Defs.CAT_LANE, 0.0), 1.0, false, 0.0)
	var overlap: float = (right.position.x + right.size.x) - apart.position.x
	_assert(overlap < MachineLayer.CAT_DRAW * 0.5,
		"옆 고양이와 절반 넘게 겹치지 않는다 (%.0fpx)" % overlap)
	_assert(Defs.CAT_LANE > MachineLayer.CAT_DRAW * 0.4,
		"간격이 그려지는 크기에 비례한다")

	# Chewing is the one thing allowed to move it off the shadow.
	var chew: Rect2 = MachineLayer.cat_rect(stand, 1.0, false, 4.0)
	_assert(chew.position.y > right.position.y, "먹을 때만 그림자에서 살짝 내려온다")
	# The sprite has to reach above the cat's world position by most of its
	# height, or the shadow is drawn on top of the body instead of under it.
	_assert(MachineLayer.CAT_FOOT_FRACTION * MachineLayer.CAT_DRAW > MachineLayer.CAT_GROUND * 3.0,
		"몸이 그림자 위로 충분히 올라온다")

	# --- What hangs over a cat has to clear the tile above it -------------------
	# A miner facing north drops its output into the cell above itself, and the
	# worker's hunger bar hung in that same cell -- so the recommended arrangement
	# guaranteed a gauge with a crystal through it. The load rode into the bar as
	# well. Measured against the item's own radius and bob rather than eyeballed,
	# so changing either moves this check with it.
	var at := Vector2(400.0, 400.0)
	var body: Rect2 = MachineLayer.cat_rect(at, 1.0, false, 0.0)
	var gauge: Rect2 = MachineLayer.cat_hunger_bar(at, body)
	var load: Vector2 = MachineLayer.cat_load_at(at, body)
	var item_bottom: float = at.y - float(Defs.TILE) \
		+ MachineLayer.GROUND_ITEM_RADIUS + MachineLayer.GROUND_ITEM_BOB
	_assert(gauge.position.y >= item_bottom,
		"허기 막대가 위 칸의 산출물 아래에 있다 (%.1f >= %.1f)" % [gauge.position.y, item_bottom])
	_assert(load.y + MachineLayer.CAT_LOAD_RADIUS <= gauge.position.y,
		"짐 표시가 허기 막대와 겹치지 않는다 (%.1f <= %.1f)"
		% [load.y + MachineLayer.CAT_LOAD_RADIUS, gauge.position.y])
	# And still attached to the animal: a gauge that clears everything by floating
	# away belongs to nobody.
	_assert(gauge.position.y + gauge.size.y <= MachineLayer.cat_head_y(body),
		"막대는 머리 위에 있다")
	_assert(MachineLayer.cat_head_y(body) - gauge.position.y < 12.0,
		"머리에 붙어 있다 (%.1f)" % (MachineLayer.cat_head_y(body) - gauge.position.y))
	_assert(is_equal_approx(gauge.get_center().x, at.x), "막대가 몸 중심에 온다")

	# Three things stack over a working miner and the cell is 32 pixels tall:
	# the item on the next tile, the gauge, and the output arrow. The first fix
	# for this moved the gauge out of the item and straight into the arrow, which
	# is not a fix, so all three gaps are checked at once.
	# The arrow cannot be given clear air -- pulling it down far enough put it
	# inside the cat's head, where its outline read as a second pair of eyes and
	# it stopped being an arrow. So it is allowed to touch the gauge, and bounded
	# instead: a couple of pixels of contact leaves both readable, a machine's
	# worth of overlap does not.
	var arrow_tip: float = at.y - MachineLayer.MINER_ARROW_LIFT - MachineLayer.MINER_ARROW_LENGTH
	var arrow_tail: float = at.y - MachineLayer.MINER_ARROW_LIFT
	var touch: float = minf(arrow_tail, gauge.position.y + gauge.size.y) \
		- maxf(arrow_tip, gauge.position.y)
	_assert(touch <= 3.0, "출력 화살표가 허기 막대를 덮지 않는다 (%.1f픽셀)" % touch)

	# --- What a machine is doing is drawn above the animal doing it -------------
	# A cat is nearly sixty pixels tall standing on a thirty-two pixel cell, so
	# anything a machine draws near its own centre is behind its worker. That hid
	# both of the miner's readouts in exactly the case they exist for: the stall
	# marker, because a miner only stalls while a cat is on it, and the output
	# arrow, because a north-facing miner points straight into the cat. Two miners
	# emitting into each other produced nothing for six minutes in a playtest and
	# the screen said so nowhere.
	#
	# Checked against the source: draw order is not observable from a headless
	# run, and the invariant is exactly "these calls come after that one".
	var layer: String = FileAccess.get_file_as_string("res://scripts/MachineLayer.gd")
	_assert(layer != "", "MachineLayer.gd를 읽었다")
	var cats_at: int = layer.find("\t_draw_cats()")
	var marks_at: int = layer.find("\t_draw_machine_marks(")
	_assert(cats_at >= 0 and marks_at > cats_at,
		"기계 표시가 고양이보다 뒤에 그려진다 (%d < %d)" % [cats_at, marks_at])
	var miner_body: String = layer.substr(layer.find("func _draw_miner"))
	miner_body = miner_body.substr(0, miner_body.find("\nfunc "))
	_assert(miner_body.find("_draw_arrow(") < 0,
		"채굴기 본체는 출력 화살표를 직접 그리지 않는다")
	var marks_body: String = layer.substr(marks_at)
	marks_body = marks_body.substr(0, marks_body.find("\nfunc _draw_stall"))
	_assert(marks_body.find("_draw_arrow(") > 0 and marks_body.find("_draw_stall(") > 0,
		"화살표와 정지 표시가 같은 패스에 있다")

	if failures == 0:
		print("ANIMATION_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("ANIMATION_TEST: FAIL - " + message)
		failures += 1
