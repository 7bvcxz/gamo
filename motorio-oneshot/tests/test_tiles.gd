extends SceneTree

## Tile attributes describe the terrain itself. STRUCTURE is the first one: it
## blocks the player's body and refuses to be picked up.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim := Sim.new()
	sim.setup(24680)

	# Ore is terrain, so every ore tile is a structure.
	var ore_cell: Vector2i = sim.ore.keys()[0]
	_assert(sim.is_structure(ore_cell), "an ore tile is a structure")
	_assert(sim.has_attribute(ore_cell, Defs.ATTR_STRUCTURE), "the attribute flag is set")
	_assert(sim.blocks_player(ore_cell), "a structure blocks the player")

	var empty := Vector2i(1, 1)
	_assert(not sim.is_structure(empty), "bare ground is not a structure")
	_assert(not sim.blocks_player(empty), "bare ground does not block")

	# Machines are not structures, so a belt can be laid across a walking route.
	# A miner is a different story -- see the placement rules below.
	_open(sim)
	sim.build(Defs.M_BELT, empty, Vector2i.RIGHT)
	_assert(not sim.blocks_player(empty), "a belt does not block the player")

	# The core is the exception: it is a building, so it stops the body.
	_assert(sim.is_structure(sim.core_cell), "the core is a structure")
	_assert(sim.blocks_player(sim.core_cell), "the core blocks the player")
	_assert(sim.tile_attributes(sim.core_cell) & Defs.ATTR_STRUCTURE,
		"the core carries the structure bit")
	_assert(not sim.demolish(sim.core_cell), "the core cannot be picked up")
	_assert(sim.machine_at(sim.core_cell) != null, "the core survives the attempt")

	# Where each machine may go. The miner is the only one that may sit on ore,
	# and the only one that is required to.
	_assert(sim.can_build(Defs.M_MINER, ore_cell) == "", "a miner may be built on ore")
	_assert(sim.can_build(Defs.M_MINER, empty) != "", "a miner may not be built off ore")
	_assert(sim.can_build(Defs.M_BELT, ore_cell) != "", "a belt may not be built on ore")
	_assert(sim.can_build(Defs.M_EXCHANGER, ore_cell) != "", "a furnace may not be built on ore")
	_assert(sim.can_build(Defs.M_BELT, sim.core_cell) != "", "nothing may be built on the core")

	# And the consequence of the two rules meeting: because a miner always sits
	# on ore, and ore is a structure, its tile keeps blocking the player.
	_assert(sim.build(Defs.M_MINER, ore_cell, Vector2i.RIGHT), "the miner is placed on the ore")
	_assert(sim.blocks_player(ore_cell), "a miner on ore still blocks the player")

	# Attributes are flags, so the system can carry more than one later.
	_assert(Defs.ATTR_NONE == 0, "the empty attribute set is zero")
	_assert(Defs.ATTR_STRUCTURE != 0, "structure is a real flag")
	_assert(sim.tile_attributes(empty) == Defs.ATTR_NONE, "bare ground has no attributes")
	_assert(sim.tile_attributes(ore_cell) & Defs.ATTR_STRUCTURE, "ore carries the structure bit")
	sim.free()

	# The player's body must not be able to enter a structure from any side.
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	# Ore generates in clusters, so pick a seam whose approaches are clear or the
	# test would be starting the player inside a different structure.
	var target := Vector2i(9999, 9999)
	for cell: Vector2i in main.sim.ore:
		var clear := true
		for approach: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			for distance in [1, 2, 3]:
				var probe: Vector2i = cell - Vector2i(approach) * distance
				if main.sim.is_structure(probe):
					clear = false
		if clear:
			target = cell
			break
	_assert(target != Vector2i(9999, 9999), "the map has a seam with clear approaches")
	var centre: Vector2 = main.sim.cell_centre(target)
	for approach: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		main.player.position = centre - approach * float(Defs.TILE) * 2.0
		var before: Vector2 = main.player.position
		for step in 40:
			main.player._move(approach * 6.0)
		var cell: Vector2i = Vector2i((main.player.position / float(Defs.TILE)).floor())
		_assert(cell != target, "the player cannot walk into a structure from %s" % approach)
		_assert(main.player.position.distance_to(before) > 1.0,
			"the player still moved toward it from %s" % approach)

	# Sliding: pushing diagonally into a wall should still travel along it.
	main.player.position = centre + Vector2(0, float(Defs.TILE) * 2.0)
	var start_x: float = main.player.position.x
	for step in 30:
		main.player._move(Vector2(4.0, -4.0))
	_assert(main.player.position.x > start_x + 5.0, "the player slides along a structure instead of sticking")

	# Walking into the core. The starting ore sits directly south of it, so the
	# approach has to be chosen from a side that is actually clear -- otherwise
	# the test would be proving that ore blocks, which it already knows.
	var core: Vector2i = main.sim.core_cell
	var lane := Vector2.ZERO
	for approach: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var clear := true
		for distance in [1, 2, 3]:
			if main.sim.is_structure(core - Vector2i(approach) * distance):
				clear = false
		if clear:
			lane = approach
			break
	_assert(lane != Vector2.ZERO, "the core has at least one clear approach")
	main.player.position = main.sim.cell_centre(core) - lane * float(Defs.TILE) * 2.5
	var approached_from: Vector2 = main.player.position
	for step in 40:
		main.player._move(lane * 6.0)
	_assert(main.player.cell() != core, "the player cannot walk into the core")
	_assert(main.player.position.distance_to(approached_from) > 1.0,
		"but does travel up to it")

	# A save written before a tile became a structure can drop the player inside
	# one. Collision must let them walk out rather than sealing them in.
	main.player.position = main.sim.cell_centre(main.sim.core_cell)
	_assert(main.sim.blocks_player(main.player.cell()), "the player starts inside the core")
	var trapped_at: Vector2 = main.player.position
	for step in 40:
		main.player._move(Vector2(0.0, 6.0))
	_assert(main.player.position.distance_to(trapped_at) > float(Defs.TILE),
		"a player inside a structure can walk back out")
	_assert(not main.sim.blocks_player(main.player.cell()), "and ends up on free ground")

	# Having escaped, normal collision applies again.
	var settled: Vector2 = main.player.position
	for step in 40:
		main.player._move(Vector2(0.0, -6.0))
	_assert(main.player.position.y < settled.y, "the player can move back toward the core")
	_assert(not main.sim.blocks_player(main.player.cell()),
		"but cannot re-enter it now that collision is live again")

	if failures == 0:
		print("TILES_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("TILES_TEST: FAIL - " + message)
		failures += 1

## Machines are bought with materials from an unlocked hotbar, so a test that
## wants to build has to open and fund the base first.
func _open(sim) -> void:
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
	sim.stock[Defs.ITEM_ENERGY] = 500
