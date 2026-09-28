extends RefCounted

## Shared by the ore-output tests (World Visual Pass 01).
##
## The report was "a copper post puts out heat stone". The simulation's tick was
## right all along: the post honestly mined the node it stood on. What was wrong
## was *which* node that was -- the gun, told its aim would put a four by four
## over her, skipped the copper she was facing and went on down the probe to the
## next seam, usually heat stone. So these tests do not build posts by calling
## the simulation with a known cell. They stand her in front of a node the way a
## player does, take the anchor the gun takes, build there, put a cat on it and
## read what actually comes out.

const NONE := Vector2i(9999, 9999)
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## A world with everything open and enough in stock to build any rig.
static func fresh(main: Node) -> void:
	main.clear_save()
	main._start_run(4242)
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim: Sim = main.sim
	for type: int in Defs.MINER_MACHINES:
		sim.unlocked[type] = true
	for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON,
			Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE, Defs.ITEM_ELECTRIC_MOTOR]:
		sim.stock[item] = 500
	sim.cats.clear()
	# A fire big enough that every node these tests use is in reach, and her
	# kept warm: the cold is not what they are about.
	sim.stones_in = 400
	sim._refresh_radius()
	main.player.warmth = 100.0

## A node of `kind` on clear ground `offset` from the fire, with a real
## neighbour of another kind ORE_PITCH behind it on the far side from where she
## stands -- exactly the layout the gun used to fall through to.
static func field(main: Node, kind: int, offset: Vector2i, decoy: int) -> Vector2i:
	var sim: Sim = main.sim
	var node: Vector2i = sim.core_cell + offset
	var area := Rect2i(node - Vector2i(8, 8), Vector2i(18, 18))
	for cell: Vector2i in Grid.cells_in(area):
		sim.erase_ore_at(cell)
		sim.ground.erase(cell)
		sim.drops.erase(cell)
		sim.remove_machine(cell)
		sim.mined_rocks[Grid.tile_of(cell)] = true
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for key: Vector2i in props.keys():
			if sim.prop_rect(key).intersects(area):
				props.erase(key)
	sim.put_ore(node, kind)
	for side: Vector2i in SIDES:
		sim.put_ore(node + side * Defs.ORE_PITCH, decoy)
	sim._grid_dirty = true
	return node

## Every place she might stand to aim at `node` -- each side, on its near row and
## one to three cells off -- and where the gun puts the post from there.
## Returns the anchors that were a *different* node: the bug.
static func stray_aims(main: Node, node: Vector2i, type: int) -> Array[String]:
	var sim: Sim = main.sim
	var strays: Array[String] = []
	var rect: Rect2i = Sim.ore_rect(node)
	for facing: Vector2i in SIDES:
		# 0 is standing on the node's near row, facing across it: where the old
		# aim walked on past the node (its post would land on her) to the one
		# behind.
		for back in [0, 1, 2, 3]:
			for lane in [0, 1]:
				# Stand `back` cells short of the node's near edge, facing it.
				var near: Vector2i = node
				if facing == Vector2i.UP:
					near = Vector2i(rect.position.x + lane, rect.end.y - 1 + back)
				elif facing == Vector2i.DOWN:
					near = Vector2i(rect.position.x + lane, rect.position.y - back)
				elif facing == Vector2i.LEFT:
					near = Vector2i(rect.end.x - 1 + back, rect.position.y + lane)
				else:
					near = Vector2i(rect.position.x - back, rect.position.y + lane)
				main.player.position = Grid.centre(near)
				main.player.facing = facing
				main.build_dir = facing
				var anchor: Vector2i = main.build_anchor(type)
				var aimed: Vector2i = sim.ore_origin_at(anchor)
				if aimed != NONE and aimed != node:
					strays.append("%s from %s facing %s -> %s (%s)" % [
						Defs.ITEM_NAMES[sim.ore_type_at(node)], near - node, facing, aimed - node,
						Defs.ITEM_NAMES[sim.ore_type_at(aimed)]])
	return strays

## Builds a rig of `type` on `node` the way the player does -- standing two cells
## south of it, facing it, and taking the gun's anchor -- puts a cat on it and
## runs the real game for `seconds`. Returns {"built": bool, "anchor": cell,
## "out": {item: count}} counting everything that landed on the output cell.
static func run_post(main: Node, node: Vector2i, type: int, seconds: float) -> Dictionary:
	var sim: Sim = main.sim
	var rect: Rect2i = Sim.ore_rect(node)
	main.player.position = Grid.centre(Vector2i(rect.position.x, rect.end.y + 1))
	main.player.facing = Vector2i.UP
	main.build_dir = Vector2i.UP
	var anchor: Vector2i = main.build_anchor(type)
	var built: bool = sim.build(type, anchor, Vector2i.UP, main.body_cells())
	var result := {"built": built, "anchor": anchor, "out": {}}
	if not built:
		return result
	var post: Sim.Machine = sim.machine_at(anchor)
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[sim.cats.size() - 1]
	sim.place_cat(anchor)
	# Out of the way, and kept warm: the test is about the post, not about her.
	main.player.position = Grid.centre(node + Vector2i(-6, 6))
	var out_cell: Vector2i = sim.output_cell(post)
	var out: Dictionary = {}
	var dt := 1.0 / 30.0
	for step in int(seconds / dt):
		main.player.warmth = 100.0
		main._process_play(dt)
		# Emptied every tick the way a belt would, so a full cell never stalls it.
		if sim.ground.has(out_cell):
			var item: int = int(sim.ground[out_cell])
			out[item] = int(out.get(item, 0)) + sim.ground_count(out_cell)
			sim.ground.erase(out_cell)
			sim.ground_stack.erase(out_cell)
	result["out"] = out
	return result
