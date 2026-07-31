extends SceneTree

## Placing a miner the way a player actually does it: walk up to a seam, face
## it, press Z. Sim.can_build already had a test and it passed the whole time --
## the failure was in the input path between the key and the build call, which
## is exactly the gap a rules-only test cannot see.

var failures := 0
var last_reason := ""

func _on_rejected(reason: String, _cell: Vector2i) -> void:
	last_reason = reason

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.state = main.State.PLAY
	# Rejections are announced on a world-space popup rather than the centre
	# banner, so the signal is the channel-independent place to read them.
	main.sim.build_rejected.connect(_on_rejected)

	# Stand one tile south of a frost seam and look north at it.
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in main.sim.ore:
		if main.sim.ore[cell] == Defs.ITEM_FROST and not main.sim.is_structure(cell + Vector2i(0, 1)):
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "the map has a frost seam approachable from the south")

	main.player.position = main.sim.cell_centre(seam + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	_assert(main.player.facing_cell() == seam, "the player is facing the seam")

	# The rule layer has always agreed this is legal.
	main.selected_index = 0
	_assert(main.selected_type() == Defs.M_MINER, "the miner is the first hotbar slot")
	_assert(main.sim.heat >= Defs.MACHINE_COSTS[Defs.M_MINER], "there is heat for a miner")
	_assert(main.sim.can_build(Defs.M_MINER, seam) == "", "can_build accepts a miner on ore")

	# ...but pressing the key is what the player actually does.
	main._primary_action()
	var built = main.sim.machine_at(seam)
	_assert(built != null, "pressing Z in front of ore builds the miner")
	if built != null:
		_assert(built.type == Defs.M_MINER, "and what was built is a miner")

	# The structure notice must not eat the press. It exists to explain that ore
	# cannot be harvested, not to veto construction on top of it.
	main.selected_index = 1
	_assert(main.selected_type() == Defs.M_BELT, "the belt is the second hotbar slot")
	var bare := Vector2i(9999, 9999)
	for cell: Vector2i in main.sim.ore:
		if main.sim.machine_at(cell) == null and not main.sim.is_structure(cell + Vector2i(0, 1)):
			bare = cell
			break
	if bare != Vector2i(9999, 9999):
		main.player.position = main.sim.cell_centre(bare + Vector2i(0, 1))
		main.player.facing = Vector2i.UP
		last_reason = ""
		main._primary_action()
		_assert(main.sim.machine_at(bare) == null, "a belt still cannot go on ore")
		_assert(last_reason.find("광맥") >= 0,
			"and the player is told why, not given a generic refusal: '%s'" % last_reason)

	# A second press on the finished miner must not silently rebuild or refuse
	# for the wrong reason.
	main.selected_index = 0
	main.player.position = main.sim.cell_centre(seam + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	last_reason = ""
	main._primary_action()
	_assert(last_reason.find("이미") >= 0,
		"pressing Z again reports the tile is occupied: '%s'" % last_reason)

	if failures == 0:
		print("BUILD_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("BUILD_TEST: FAIL - " + message)
		failures += 1
