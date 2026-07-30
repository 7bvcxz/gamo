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

	# Machines are not structures: the player walks over belts and stands on
	# their own miners.
	sim.heat = 300
	sim.build(Defs.M_BELT, empty, Vector2i.RIGHT)
	_assert(not sim.blocks_player(empty), "a belt does not block the player")

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

	if failures == 0:
		print("TILES_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("TILES_TEST: FAIL - " + message)
		failures += 1
