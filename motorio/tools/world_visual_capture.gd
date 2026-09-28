extends SceneTree

## World Visual Pass 01 in pictures -- for looking, not asserting.
##
## Every scene the pass changed, built through the calls the tests use and saved
## at play zoom (and a close-up where the subject is small): the snow on its
## own, a heat stone node and a copper node, a post on a node, a post with its
## cat at work, seven posts and seven cats, the base, the hut, a generator, a
## middle-game factory, out in the cold, and night.
##
## Needs a real renderer (Xvfb is enough):
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path motorio \
##     --audio-driver Dummy --script res://tools/world_visual_capture.gd -- --out /abs/dir
##
## It deletes the run's save slots, as every Main test does, and does not write
## the settings file (the zoom is set on the camera, not through the setter).

var main: Node2D
var out_dir := ""
var sim: Sim

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Frame waits are counted, so they have to take real time.
	Engine.max_fps = 60
	_run.call_deferred()

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)

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
	for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON, Defs.ITEM_ENERGY_CORE,
			Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE, Defs.ITEM_ELECTRIC_MOTOR]:
		sim.stock[item] = 500
	# A fire past its fourth step, so the field in these pictures is warm ground.
	sim.stones_in = 60
	sim._refresh_radius()
	sim.shown_radius = sim.warm_radius
	main.player.warmth = 100.0
	main.time_left = Defs.DAY_SECONDS - 30.0

func _look(at: Vector2, frames: int = 50) -> void:
	main.player.position = at
	main.player.velocity = Vector2.ZERO
	main.player.warmth = 100.0
	await _frames(frames)

## A patch of ground cleared of everything the world put on it.
func _clear(rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.erase_ore_at(cell)
		var standing: Sim.Machine = sim.machine_at(cell)
		if standing != null and standing.type != Defs.M_CORE:
			sim.remove_machine(cell)
		sim.mined_rocks[Grid.tile_of(cell)] = true
	for props: Dictionary in [sim.frozen_cats, sim.debris]:
		for key: Vector2i in props.keys():
			if sim.prop_rect(key).intersects(rect):
				props.erase(key)
	sim._grid_dirty = true

func _post(node: Vector2i, kind: int, type: int = Defs.M_MINER, dir: Vector2i = Vector2i.UP,
		with_cat: bool = true) -> void:
	sim.put_ore(node, kind)
	sim.build(type, node, dir)
	if with_cat:
		sim.grant_cats(1)
		sim.carried_cat = sim.cats[sim.cats.size() - 1]
		sim.place_cat(node)

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await _frames(3)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await _frames(4)
	var east := Vector2i(22, 6)

	# 1. Snow on its own, in the warm, nothing on it.
	await _fresh()
	_zoom(1.0)
	var field: Vector2i = sim.core_cell + east
	_clear(Rect2i(field - Vector2i(20, 14), Vector2i(40, 28)))
	await _look(Grid.centre(field))
	await _save("01_snow_only")
	_zoom(1.6)
	await _frames(20)
	await _save("01b_snow_only_close")

	# 2-3. A heat stone node and a copper node, close.
	sim.put_ore(field + Vector2i(-3, 0), Defs.ITEM_HEATSTONE)
	sim.put_ore(field + Vector2i(3, 0), Defs.ITEM_COPPER)
	await _look(Grid.centre(field + Vector2i(0, 3)))
	await _save("02_ore_heatstone_and_copper_2x2_close")

	# 4-5. A post on heat stone, then its cat at work.
	_zoom(1.6)
	_post(field + Vector2i(-3, 0), Defs.ITEM_HEATSTONE, Defs.M_MINER, Vector2i.UP, false)
	await _look(Grid.centre(field + Vector2i(0, 4)))
	await _save("03_post_on_heatstone_close")
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[sim.cats.size() - 1]
	sim.place_cat(field + Vector2i(-3, 0))
	_post(field + Vector2i(3, 0), Defs.ITEM_COPPER, Defs.M_MINER_MK2)
	await _look(Grid.centre(field + Vector2i(0, 4)), 70)
	await _save("04_posts_with_cats_close")

	# 6. Seven posts and seven cats, a node's pitch apart, at play zoom.
	await _fresh()
	_zoom(1.0)
	var row: Vector2i = sim.core_cell + Vector2i(-12, 14)
	_clear(Rect2i(row - Vector2i(6, 8), Vector2i(Defs.ORE_PITCH * 7 + 12, 18)))
	var kinds: Array[int] = [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON]
	for index in 7:
		_post(row + Vector2i(index * Defs.ORE_PITCH, 0), kinds[index % kinds.size()])
	await _look(Grid.centre(row + Vector2i(3 * Defs.ORE_PITCH, 5)), 80)
	await _save("05_seven_posts_seven_cats")

	# 7-8. The base and the hut.
	await _fresh()
	_zoom(1.2)
	await _look(sim.core_centre() + Vector2(0.0, 90.0))
	await _save("06_base")
	await _look(Grid.rect_centre(sim.shelter_rect()) + Vector2(0.0, 60.0))
	await _save("07_shelter")

	# 9. A generator beside the fire.
	var gen: Vector2i = sim.core_cell + Vector2i(8, -1)
	_clear(Rect2i(gen - Vector2i(2, 2), Vector2i(6, 6)))
	sim.build(Defs.M_GENERATOR, gen, Vector2i.RIGHT)
	var generator: Sim.Machine = sim.machine_at(gen)
	if generator != null:
		generator.buffer[Defs.GENERATOR_FUEL] = 5
	await _look(Grid.centre(gen + Vector2i(0, 4)), 60)
	await _save("08_generator")

	# 10. A middle-game factory: posts on the starter nodes, belts home, a
	# generator, a manufacturer and an assembler.
	await _fresh()
	_zoom(0.9)
	for offset: Vector2i in Sim.STARTER_PATCH:
		_post(sim.core_cell + offset, Defs.ITEM_HEATSTONE)
	for offset: Vector2i in Sim.STARTER_PATCH:
		var node: Vector2i = sim.core_cell + offset
		var out: Vector2i = sim.output_cell(sim.machine_at(node))
		for y in range(out.y, sim.base_rect().end.y - 1, -1):
			sim.build(Defs.M_BELT, Vector2i(out.x, y), Vector2i.UP)
	var plant: Vector2i = sim.core_cell + Vector2i(9, 2)
	_clear(Rect2i(plant - Vector2i(1, 1), Vector2i(10, 6)))
	sim.build(Defs.M_GENERATOR, sim.core_cell + Vector2i(9, -3), Vector2i.RIGHT)
	sim.build(Defs.M_MANUFACTURER, plant, Vector2i.RIGHT)
	sim.build(Defs.M_ASSEMBLER, plant + Vector2i(4, 0), Vector2i.RIGHT)
	for x in range(plant.x + 2, plant.x + 4):
		sim.build(Defs.M_BELT, Vector2i(x, plant.y), Vector2i.RIGHT)
	await _look(sim.core_centre() + Vector2(40.0, 70.0), 90)
	await _save("09_mid_factory")

	# 11. Out in the cold: past the fire, the fog, her breath going.
	main.player.position = sim.core_centre() + Vector2(Grid.px(sim.warm_radius + 5.0), 0.0)
	main.player.warmth = 30.0
	for step in 60:
		main.player.warmth = maxf(20.0, main.player.warmth - 0.2)
		await process_frame
	await _save("10_cold")

	# 12. Night over the same factory.
	main.player.position = sim.core_centre() + Vector2(40.0, 70.0)
	main.player.warmth = 100.0
	main.time_left = Defs.NIGHT_SECONDS * 0.5
	await _frames(90)
	await _save("11_night")

	main.clear_save()
	main.free()
	quit()
