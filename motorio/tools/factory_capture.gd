extends SceneTree

## Factory Interaction Pass 01 in pictures and numbers -- the playtest scenarios
## A to H, built through the calls the game uses, run, measured, and captured.
##
## Not a test: it prints what happened (MEASURE lines) and saves a picture of
## each scene, so a person can look at both. The asserting versions of these
## are the pass's tests.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path motorio \
##     --audio-driver Dummy --script res://tools/factory_capture.gd -- --out /abs/dir
##
## It deletes the run's save slots, as every Main test does, and leaves the
## settings file as it found it.

const OrePost := preload("res://tests/helpers/ore_post.gd")

var main: Node2D
var out_dir := ""
var sim: Sim

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.max_fps = 60
	_run.call_deferred()

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)

func _measure(line: String) -> void:
	print("MEASURE ", line)

func _zoom(scale: float) -> void:
	main.game_scale = scale
	main._apply_camera_zoom()

func _fresh(seed_value: int = 4242) -> void:
	main.clear_save()
	main._start_run(seed_value)
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.messages.clear()
	sim = main.sim
	sim.has_gun = true
	sim.has_pickaxe = true
	for type: int in Defs.machine_ids():
		sim.unlocked[type] = true
	for item: int in range(Defs.ITEM_NAMES.size()):
		sim.stock[item] = 100
		sim.held_items[item] = true
	sim.stones_in = int(Defs.BASE_LEVELS[-1]["stones"])
	sim._refresh_radius()
	sim.shown_radius = sim.warm_radius
	main.player.warmth = 100.0
	main.time_left = Defs.DAY_SECONDS - 30.0
	main.machine_layer.debug_overlay = false

func _look(at: Vector2, frames: int = 40) -> void:
	main.player.position = at
	main.player.velocity = Vector2.ZERO
	main.player.warmth = 100.0
	await _frames(frames)

func _clear(rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.erase_ore_at(cell)
		sim.ground.erase(cell)
		sim.ground_stack.erase(cell)
		var standing: Sim.Machine = sim.machine_at(cell)
		if standing != null and standing.type != Defs.M_CORE:
			sim.remove_machine(cell)
		sim.mined_rocks[Grid.tile_of(cell)] = true
	for props: Dictionary in [sim.frozen_cats, sim.debris]:
		for key: Vector2i in props.keys():
			if sim.prop_rect(key).intersects(rect):
				props.erase(key)
	sim._grid_dirty = true

func _post(node: Vector2i, kind: int, dir: Vector2i, with_cat: bool = true) -> Sim.Machine:
	sim.put_ore(node, kind)
	sim.build(Defs.M_MINER, node, dir)
	if with_cat:
		sim.grant_cats(1)
		sim.carried_cat = sim.cats[sim.cats.size() - 1]
		sim.place_cat(node)
	return sim.machine_at(node)

func _belts(from: Vector2i, dir: Vector2i, count: int) -> void:
	for i in count:
		sim.build(Defs.M_BELT, from + dir * i, dir)

func _tick(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		sim.tick(0.1)
		t += 0.1

func _named(gained: Dictionary) -> String:
	if gained.is_empty():
		return "nothing"
	var parts: Array[String] = []
	for item: int in gained:
		parts.append("%s %+d" % [Defs.item_name(item), int(gained[item])])
	return ", ".join(parts)

func _gun(on: bool) -> void:
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN if on else main.TOOL_PICKAXE)

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await _frames(3)
	# H zooms through the setter, which saves the settings file: put the
	# player's own values back at the end.
	var kept_game: float = main.game_scale
	var kept_ui: float = main.ui_scale
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await _frames(4)
	var east := Vector2i(24, 4)

	# A. Copper by hand, standing on heat stone. The bug: she mined what was
	#    under her feet. The overlay shows each node's sheet, type and item.
	await _fresh()
	_zoom(1.6)
	var field: Vector2i = sim.core_cell + east
	_clear(Rect2i(field - Vector2i(10, 10), Vector2i(24, 20)))
	var heat: Vector2i = field
	var copper: Vector2i = field + Vector2i(Defs.ORE_PITCH, 0)
	sim.put_ore(heat, Defs.ITEM_HEATSTONE)
	sim.put_ore(copper, Defs.ITEM_COPPER)
	main.machine_layer.debug_overlay = true
	# Through the tests' own swing: what she mined lands on the ground at her
	# feet, so a gain is counted over the bag and the ground together.
	var on_heat: Dictionary = OrePost.swing(main, Grid.centre(heat + Vector2i(1, 0)), Vector2i.RIGHT, Defs.HAND_MINE_PERIOD * 1.6)
	_measure("A hand, standing on heat stone facing copper 3 cells away (out of reach): %s" % _named(on_heat))
	var at_copper: Dictionary = OrePost.swing(main, Grid.centre(copper + Vector2i(-1, 0)), Vector2i.RIGHT, Defs.HAND_MINE_PERIOD * 1.6)
	_measure("A hand, one cell from copper facing it: %s" % _named(at_copper))
	main.player.position = Grid.centre(copper + Vector2i(-1, 0))
	await _frames(30)
	await _save("A_direct_mining_overlay")

	# B. Posts on heat stone, copper and iron, each with a cat, pouring on the
	#    ground: what lands in front of each is its own ore.
	var kinds: Array[int] = [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON]
	var posts: Array[Vector2i] = []
	for i in kinds.size():
		var node: Vector2i = field + Vector2i(i * Defs.ORE_PITCH * 2, 8)
		_clear(Rect2i(node - Vector2i(1, 1), Vector2i(4, 5)))
		_post(node, kinds[i], Vector2i.DOWN)
		posts.append(node)
	_tick(60.0)
	for i in posts.size():
		var out: Vector2i = sim.output_cell(sim.machine_at(posts[i]))
		_measure("B post on %s: %d x %s on its output cell"
			% [Defs.item_name(kinds[i]), sim.ground_count(out), Defs.item_name(int(sim.ground.get(out, -1)))])
	_zoom(1.2)
	await _look(Grid.centre(posts[1] + Vector2i(0, 5)), 40)
	await _save("B_posts_output_overlay")
	main.machine_layer.debug_overlay = false

	# C. Logistics: iron post -> belt -> manufacturer's back; the product out of
	#    its front onto a belt. Powered by a hand-fuelled generator. Gun up, so
	#    the ports show.
	await _fresh()
	_zoom(1.2)
	var plant: Vector2i = sim.core_cell + east + Vector2i(0, 10)
	_clear(Rect2i(plant - Vector2i(14, 8), Vector2i(30, 18)))
	var gen: Vector2i = plant + Vector2i(0, -6)
	sim.build(Defs.M_GENERATOR, gen, Vector2i.RIGHT)
	sim.insert_by_hand(sim.machine_at(gen), Defs.GENERATOR_FUEL, -1)
	sim.build(Defs.M_MANUFACTURER, plant, Vector2i.RIGHT)
	var maker: Sim.Machine = sim.machine_at(plant)
	sim.set_recipe(maker, String(Defs.recipes_for_machine(Defs.M_MANUFACTURER)[0]["key"]))
	var wanted: int = int(sim.recipe_of(maker)["inputs"][0]["item"])
	var iron_node: Vector2i = plant + Vector2i(-9, 0)
	_post(iron_node, wanted, Vector2i.RIGHT)
	var iron_out: Vector2i = sim.output_cell(sim.machine_at(iron_node))
	_belts(iron_out, Vector2i.RIGHT, plant.x - iron_out.x)
	var made_out: Vector2i = sim.output_cell(maker)
	_belts(made_out, Vector2i.RIGHT, 5)
	var made: int = int(sim.recipe_of(maker)["outputs"][0]["item"])
	var before_made := 0
	_tick(90.0)
	var end: Vector2i = made_out + Vector2i.RIGHT * 5
	_measure("C manufacturer fed by belt at its back: %d x %s piled past the output belt, buffer %s"
		% [sim.ground_count(end), Defs.item_name(int(sim.ground.get(end, -1))), str(maker.buffer)])
	_gun(true)
	main.player.position = Grid.centre(plant + Vector2i(0, 5))
	main.player.facing = Vector2i.UP
	await _frames(40)
	await _save("C_logistics_ports_visible")

	# D. Rotation: four manufacturers turned with R to each direction, gun up.
	await _fresh()
	_zoom(1.4)
	var row: Vector2i = sim.core_cell + east + Vector2i(0, 12)
	_clear(Rect2i(row - Vector2i(4, 6), Vector2i(26, 14)))
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for i in dirs.size():
		var cell: Vector2i = row + Vector2i(i * 5, 0)
		sim.build(Defs.M_MANUFACTURER, cell, Vector2i.RIGHT)
		for turn in i:
			sim.rotate_machine(cell)
		_measure("D manufacturer %d faces %s, output %s, inputs %d cells"
			% [i, sim.machine_at(cell).dir, sim.output_cell(sim.machine_at(cell)),
			sim.machine_input_ports(sim.machine_at(cell)).size()])
	_gun(true)
	main.player.position = Grid.centre(row + Vector2i(7, 5))
	main.player.facing = Vector2i.DOWN
	await _frames(40)
	await _save("D_rotation_four_ways_ports")

	# E. Splitters in four orientations, each fed from its back, branches out.
	await _fresh()
	_zoom(1.4)
	var hubs: Vector2i = sim.core_cell + east + Vector2i(0, 12)
	_clear(Rect2i(hubs - Vector2i(6, 8), Vector2i(34, 16)))
	var splitters: Array[Sim.Machine] = []
	var counts: Array[Vector2i] = []
	for i in dirs.size():
		var hub: Vector2i = hubs + Vector2i(i * 7, 0)
		sim.build(Defs.M_SPLITTER, hub, dirs[i])
		var splitter: Sim.Machine = sim.machine_at(hub)
		splitters.append(splitter)
		counts.append(Vector2i.ZERO)
		sim.build(Defs.M_BELT, hub - dirs[i], dirs[i])
		for port: Dictionary in sim.machine_output_ports(splitter):
			_belts(port["outside"], port["dir"], 2)
	for step in 240:
		for i in splitters.size():
			var feed: Sim.Machine = sim.machine_at(splitters[i].cell - dirs[i])
			if feed != null and feed.items.is_empty():
				feed.items.append({"type": Defs.ITEM_COPPER, "t": 0.0})
		sim.tick(0.1)
	for i in splitters.size():
		var outs: Array[Dictionary] = sim.machine_output_ports(splitters[i])
		var a_end: Vector2i = (outs[0]["outside"] as Vector2i) + (outs[0]["dir"] as Vector2i) * 2
		var b_end: Vector2i = (outs[1]["outside"] as Vector2i) + (outs[1]["dir"] as Vector2i) * 2
		_measure("E splitter facing %s: A (right) %d, B (left) %d"
			% [dirs[i], sim.ground_count(a_end), sim.ground_count(b_end)])
	_gun(true)
	main.player.position = Grid.centre(hubs + Vector2i(10, 6))
	await _frames(40)
	await _save("E_splitter_four_orientations")

	# F. Five heat stone posts -> one belt -> splitter -> two generators.
	await _fresh()
	_zoom(0.9)
	var start: Vector2i = sim.core_cell + east + Vector2i(-2, 12)
	_clear(Rect2i(start - Vector2i(4, 8), Vector2i(Defs.ORE_PITCH * 5 + 16, 20)))
	for i in 5:
		_post(start + Vector2i(i * Defs.ORE_PITCH, 0), Defs.ITEM_HEATSTONE, Vector2i.DOWN)
	var line_y: int = start.y + 2
	var hub_x: int = start.x + Defs.ORE_PITCH * 5 + 2
	_belts(Vector2i(start.x, line_y), Vector2i.RIGHT, hub_x - start.x)
	sim.build(Defs.M_SPLITTER, Vector2i(hub_x, line_y), Vector2i.RIGHT)
	_belts(Vector2i(hub_x, line_y + 1), Vector2i.DOWN, 2)
	_belts(Vector2i(hub_x, line_y - 1), Vector2i.UP, 2)
	var south: Vector2i = Vector2i(hub_x, line_y + 3)
	var north: Vector2i = Vector2i(hub_x, line_y - 4)
	sim.build(Defs.M_GENERATOR, south, Vector2i.RIGHT)
	sim.build(Defs.M_GENERATOR, north, Vector2i.RIGHT)
	var gens: Array[Sim.Machine] = [sim.machine_at(south), sim.machine_at(north)]
	var fed: Array[int] = [0, 0]
	var last: Array[int] = [0, 0]
	var powered := 0.0
	for step in 1200:
		sim.tick(0.1)
		for g in 2:
			if gens[g] == null:
				continue
			var now: int = int(gens[g].buffer.get(Defs.GENERATOR_FUEL, 0))
			if now > last[g]:
				fed[g] += now - last[g]
			last[g] = now
		powered = maxf(powered, sim.power_capacity)
	_measure("F 5 posts -> splitter -> 2 generators over 120 s: south got %d, north got %d, peak power %.1f"
		% [fed[0], fed[1], powered])
	_gun(true)
	main.player.position = Grid.centre(Vector2i(hub_x - 6, line_y + 6))
	await _frames(40)
	await _save("F_five_posts_splitter_generators")

	# G. The generator's window, fuel by hand.
	var g_cell: Vector2i = south
	main.player.position = Grid.centre(g_cell + Vector2i(-2, 0))
	main.player.facing = Vector2i.RIGHT
	_gun(false)
	main._open_machine_menu(g_cell)
	main.menu_index = 1
	await _frames(20)
	await _save("G_generator_hand_fuel_window")
	main.close_machine_menu()

	# H. Zoom: near and far over the same factory.
	for scale: float in [Defs.GAME_SCALE_MAX, Defs.GAME_SCALE_MIN]:
		main.set_game_scale(scale, true)
		for f in 30:
			main._apply_camera_zoom(1.0 / 60.0)
			await process_frame
		_measure("H zoom %.2f: camera %.3f, hud scale %s" % [scale, main.camera.zoom.x, main.hud.scale])
		await _save("H_zoom_%s" % ("near" if scale > 1.0 else "far"))

	main.set_game_scale(kept_game)
	main.set_ui_scale(kept_ui)
	main.clear_save()
	main.free()
	quit()
