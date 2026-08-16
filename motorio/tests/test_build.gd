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
	# Main loads any save it finds on _ready, and a sibling test leaves one
	# behind. Start from a guaranteed-pristine world or the seam this test picks
	# may already have someone else's factory on it.
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	_open(main.sim)
	# Slot one is the pickaxe now, and this file is about the gun.
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	# Rejections are announced on a world-space popup rather than the centre
	# banner, so the signal is the channel-independent place to read them.
	main.sim.build_rejected.connect(_on_rejected)

	# Stand one tile south of a seam and look north at it.
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in main.sim.ore:
		if not main.sim.is_structure(cell + Vector2i(0, 1)):
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "the map has a seam approachable from the south")

	main.player.position = main.sim.cell_centre(seam + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	_assert(main.player.facing_cell() == seam, "the player is facing the seam")

	# The rule layer has always agreed this is legal.
	main.selected_index = 0
	_assert(main.selected_type() == Defs.M_MINER, "the miner is the first hotbar slot")
	_assert(main.sim.can_afford(Defs.M_MINER), "there are materials for a miner")
	_assert(main.sim.can_build(Defs.M_MINER, seam) == "", "can_build accepts a miner on ore")

	# ...but pressing the key is what the player actually does.
	main._primary_action()
	var built = main.sim.machine_at(seam)
	_assert(built != null, "pressing Z in front of ore builds the miner")
	if built != null:
		_assert(built.type == Defs.M_MINER, "and what was built is a miner")

	# The structure notice must not eat the press. It exists to explain that ore
	# cannot be harvested, not to veto construction on top of it.
	main.selected_index = Defs.BUILDABLE.find(Defs.M_BELT)
	_assert(main.selected_type() == Defs.M_BELT, "the belt has its own hotbar slot")
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

	# --- Carrying a cat --------------------------------------------------------
	# The carry has to be visible and exclusive: the cat rides just in front of
	# her facing the same way, and both hands are full while it does.
	main.sim.grant_cats(1)
	_assert(main.sim.cats.size() >= 1, "a cat exists to carry")
	var kitty = main.sim.cats[0]
	kitty.pos = main.sim.cell_centre(main.player.facing_cell())
	main._primary_action()
	_assert(main.sim.carried_cat == kitty, "the cat is picked up")

	for heading: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		main.player.facing = heading
		main._process(0.0)
		var ahead: Vector2 = main.player.position + Vector2(heading) * float(Defs.TILE) * Defs.CARRY_AHEAD
		_assert(kitty.pos.distance_to(ahead) < 0.5,
			"the carried cat sits ahead facing %s" % heading)
		_assert(kitty.heading == Vector2(heading), "and looks the same way she does: %s" % heading)
		_assert(main.player.carried_cat_heading == Vector2(heading),
			"the actor is told which way to draw it: %s" % heading)
	_assert(main.player.carrying_cat, "the actor knows a cat is being carried")

	# The carried cat is drawn on its own canvas item because a Node2D paints
	# before its children: drawn in the actor's own _draw it would come out
	# behind the character sprite. Assert the wiring, since a headless renderer
	# cannot be screenshotted to check the result.
	var layer: Node2D = main.player.carry_layer
	_assert(layer != null, "the actor has a canvas item for the carried cat")
	_assert(layer.get_parent() == main.player, "it rides with the player")
	_assert(layer.z_index > main.player.character.z_index,
		"and is stacked above the character sprite, not behind it")
	_assert(layer.draw.is_connected(main.player._draw_carried_cat),
		"its draw pass is connected, so the cat is actually painted")
	_assert(main.player.carried_cat_pos.distance_to(kitty.pos) < 0.5,
		"and it paints from the cat's own position")

	# Both hands full: no picking anything else up.
	main.player.facing = Vector2i.UP
	main.player.position = main.sim.cell_centre(seam + Vector2i(0, 1))
	_assert(main.sim.machine_at(seam) != null, "there is a machine that could be removed")
	main._try_demolish()
	_assert(main.sim.machine_at(seam) != null,
		"a machine cannot be removed while carrying a cat")

	var others: int = main.sim.cats.size()
	main._primary_action()   # facing the miner -> places the cat on it
	_assert(main.sim.carried_cat == null, "placing the cat releases the carry")
	_assert(main.sim.cats.size() == others, "and no cat was lost doing it")
	main._process(0.0)
	_assert(not main.player.carrying_cat, "the actor stops drawing it once released")

	# Released, the hands are free again.
	main._try_demolish()
	_assert(main.sim.machine_at(seam) == null, "and machines can be removed again")

	if failures == 0:
		print("BUILD_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("BUILD_TEST: FAIL - " + message)
		failures += 1

## Machines are bought with materials from an unlocked hotbar, so a test that
## wants to build has to open and fund the base first.
func _open(sim) -> void:
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
	sim.stock[Defs.ITEM_ENERGY] = 500
