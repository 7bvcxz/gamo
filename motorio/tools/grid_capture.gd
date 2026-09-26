extends SceneTree

## Grid v2 in pictures -- for looking, not asserting.
##
## The things the grid change is about, each built through the same calls the
## tests use and saved at the zoom the game opens at, in two window sizes: the
## crash site, the base and the hut, the single-cell seams, a mining post's ghost
## (clear, then over a stray seam), three posts side by side with their cats,
## belts home through the lane, her walking, and a cat going round the base.
##
## Needs a real renderer (Xvfb is enough), like hud_capture:
##
##   DISPLAY=:99 godot --path motorio --audio-driver Dummy \
##     --script res://tools/grid_capture.gd -- --out /abs/dir
##
## Put the output under motorio/test-results/ (gitignored). It deletes the run's
## save slots, as every Main test does.
var main: Node2D
var out_dir := ""
var sim: Sim

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " zoom=", main.camera.zoom, " player=", main.player.position)

func _resize(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size
	await _frames(4)

func _fresh(crash: bool) -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.messages.clear()
	sim = main.sim
	if not crash:
		main.finish_tutorial()
		main.messages.clear()
	main.player.warmth = 100.0

func _look(at: Vector2) -> void:
	main.player.position = at
	main.player.velocity = Vector2.ZERO
	await _frames(40)

func _open() -> void:
	sim.has_gun = true
	sim.has_pickaxe = true
	for t in [Defs.M_MINER, Defs.M_BELT, Defs.M_SPLITTER, Defs.M_GENERATOR]:
		sim.unlocked[t] = true
	for item in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_CRYSTAL]:
		sim.stock[item] = 500

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await _frames(3)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _resize(size)
		var tag := "%d" % size.x
		# 1. The starting area: the crash, the case two walks away.
		await _fresh(true)
		await _frames(40)
		await _save(tag + "_01_start")
		# 2-3. The base unfolded and the hut beside it.
		await _fresh(false)
		await _look(sim.core_centre() + Vector2(-40, 70))
		await _save(tag + "_02_base_and_hut")
		# 4. The starter seams: three single-cell nodes south of the fire.
		await _look(Grid.centre(sim.core_cell + Vector2i(1, 11)))
		await _save(tag + "_04_ore_nodes")
		# 5. Placing a post: the ghost, green, then red over a stray seam.
		_open()
		main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
		main.selected_index = Defs.BUILDABLE.find(Defs.M_MINER)
		var seam: Vector2i = sim.core_cell + Sim.STARTER_PATCH[1]
		var rect: Rect2i = Defs.machine_footprint(Defs.M_MINER, seam)
		main.player.facing = Vector2i.UP
		await _look(Grid.centre(Vector2i(seam.x, rect.end.y)) + Vector2(0, 2))
		main.player.facing = Vector2i.UP
		await _frames(6)
		await _save(tag + "_05a_post_ghost")
		sim.ore[rect.end - Vector2i.ONE] = Defs.ITEM_COPPER
		await _frames(6)
		await _save(tag + "_05b_post_ghost_blocked")
		sim.ore.erase(rect.end - Vector2i.ONE)
		# 6-7. Cats at work on posts, three side by side.
		for offset in Sim.STARTER_PATCH:
			sim.build(Defs.M_MINER, sim.core_cell + offset, Vector2i.UP)
		sim.grant_cats(3)
		for i in 3:
			sim.carried_cat = sim.cats[i]
			sim.place_cat(sim.core_cell + Sim.STARTER_PATCH[i])
		main.tool_index = 0
		await _look(Grid.centre(sim.core_cell + Vector2i(1, 13)))
		await _frames(60)
		await _save(tag + "_06_cats_on_parallel_posts")
		# 8. Belts home through the lane.
		var mid: Vector2i = sim.output_cell(sim.machine_at(sim.core_cell + Sim.STARTER_PATCH[1]))
		sim.build(Defs.M_BELT, mid, Vector2i.UP)
		sim.build(Defs.M_BELT, mid + Vector2i.UP, Vector2i.UP)
		var west: Vector2i = sim.output_cell(sim.machine_at(sim.core_cell + Sim.STARTER_PATCH[0]))
		sim.build(Defs.M_BELT, west, Vector2i.UP)
		sim.build(Defs.M_BELT, west + Vector2i.UP, Vector2i.UP)
		var east: Vector2i = sim.output_cell(sim.machine_at(sim.core_cell + Sim.STARTER_PATCH[2]))
		sim.build(Defs.M_BELT, east, Vector2i.UP)
		sim.build(Defs.M_BELT, east + Vector2i.UP, Vector2i.LEFT)
		sim.build(Defs.M_BELT, east + Vector2i(-1, -1), Vector2i.UP)
		for i in 3:
			sim.machine_at(sim.core_cell + Sim.STARTER_PATCH[i]).progress = 0.95
		# South of the posts, looking up the lane.
		await _look(Grid.centre(sim.core_cell + Vector2i(1, 13)))
		await create_timer(4.0).timeout
		await _save(tag + "_08_belts_home")
		# 9. Walking: three frames of her moving east along the lane's south side.
		main.player.touch_direction = Vector2.RIGHT
		for step in 3:
			await create_timer(0.35).timeout
			await _save(tag + "_09_walk_%d" % step)
		main.player.touch_direction = Vector2.ZERO
		# 10. A cat going round the base: from its east wall to its west.
		var cat: Sim.Cat = sim.cats[0]
		cat.assigned = Vector2i(9999, 9999)
		cat.state = Defs.CAT_HAUL_TO_ITEM
		var span: Rect2 = Grid.rect_px(sim.base_rect())
		cat.pos = Vector2(span.end.x + 20, span.get_center().y)
		# North of the base, where the cat's detour shows.
		await _look(sim.core_centre() + Vector2(0, -110))
		var goal := Vector2(span.position.x - 20, span.get_center().y)
		for i in 60:
			sim._step_toward(cat, goal, 0.05)
			await process_frame
		await _save(tag + "_10_cat_round_base")
	main.clear_save()
	print("grid_capture: done")
	quit(0)
