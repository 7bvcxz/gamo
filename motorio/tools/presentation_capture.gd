extends SceneTree

## The first five minutes, in pictures -- the real game, for looking, not
## asserting (Quality Pass 01). The Visual North Star is a painting of where the
## game is going; these are what it is.
##
## Each moment is reached through the calls the game itself makes, then held for
## the frames the presentation needs, and saved at the zoom the game opens at in
## two window sizes:
##
##   opening_start   the first panel of the story
##   grim_wake_lying her in the snow, the first frame of play
##   grim_wake       on her knees, halfway up
##   base_deploying  the case unfolding into the fire
##   base_deployed   the fire lit, the heat spreading
##   pickaxe_craft   the ring on the fire while it makes the pickaxe
##   pickaxe_flight  the pickaxe on its way to her
##   pickaxe_acquired  in her hand, slot 1 lit
##   first_cat       a frozen cat thawing by the fire
##   first_cat_work  the cat at its post
##   shelter_night   the cats asleep in the shelter
##   wake_up         morning, getting out of bed
##
## Needs a real renderer (Xvfb is enough):
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path motorio --audio-driver Dummy \
##     --script res://tools/presentation_capture.gd -- --out /abs/dir [--only a,b]
##
## Put the output under motorio/test-results/ (gitignored). It deletes the run's
## save slots, as every Main test does.
var main: Node2D
var out_dir := ""
var only: PackedStringArray = []
var size_tag := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
		if args[i] == "--only":
			only = args[i + 1].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _wanted(name: String) -> bool:
	return only.is_empty() or only.has(name)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [size_tag, name]))
	print("shot ", size_tag, " ", name)

func _resize(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size
	size_tag = str(size.x)
	await _frames(4)

func _seconds(seconds: float) -> void:
	await _frames(int(seconds * 60.0))

func _run() -> void:
	# Waits are counted in frames, and a headless renderer runs far faster than
	# sixty -- which put "the middle of getting up" at the start of the dawn.
	Engine.max_fps = 60
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await _frames(3)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _resize(size)
		await _opening()
		await _pickaxe()
		await _first_cat()
		await _night()
	main.clear_save()
	quit(0)

func _opening() -> void:
	main.clear_save()
	main._start_new_run()
	await _seconds(1.4)
	if _wanted("opening_start"):
		await _save("opening_start")
	main._end_cutscene()
	await _frames(12)
	if _wanted("grim_wake_lying"):
		await _save("grim_wake_lying")
	await _seconds(Defs.WAKE_LIE + Defs.WAKE_SIT * 0.8)
	if _wanted("grim_wake"):
		await _save("grim_wake")
	await _seconds(Defs.WAKE_SECONDS)
	await _deploy()

func _key(pressed: bool) -> InputEvent:
	var event: InputEvent = (InputMap.action_get_events("build")[0] as InputEvent).duplicate()
	(event as InputEventKey).pressed = pressed
	return event

## Holding Z on the case until it opens, as a player does.
func _deploy() -> void:
	var sim = main.sim
	main.player.position = sim.prop_centre(sim.kit_cell) + Vector2(-Grid.px(1.0), 0.0)
	main.player.facing = Vector2i.RIGHT
	await _frames(20)
	main._unhandled_input(_key(true))
	var frames := 0
	while not sim.base_placed and frames < 600:
		await process_frame
		frames += 1
	await _seconds(0.3)
	if _wanted("base_deploying"):
		await _save("base_deploying")
	main._unhandled_input(_key(false))
	await _seconds(1.0)
	if _wanted("base_deployed"):
		await _save("base_deployed")
	await _upgrade()

## The fire growing a size: fed at the fire, the world answers.
func _upgrade() -> void:
	var sim = main.sim
	main.player.position = sim.core_centre() + Vector2(0.0, Grid.px(2.6))
	main.player.facing = Vector2i.UP
	sim.stock[Defs.ITEM_HEATSTONE] = sim.stones_to_next()
	await _frames(10)
	main._deposit_at_core()
	await _seconds(0.25)
	if _wanted("base_upgrade"):
		await _save("base_upgrade")
	await _seconds(1.5)
	if _wanted("base_upgraded"):
		await _save("base_upgraded")

func _craft_index(id: String) -> int:
	for index in Defs.BASE_CRAFTS.size():
		if String(Defs.BASE_CRAFTS[index]["id"]) == id:
			return index
	return -1

## The pickaxe made at the fire: the ring on the fire, the flight, her hand.
func _pickaxe() -> void:
	var sim = main.sim
	if not sim.shelter_placed:
		sim.shelter_placed = true
		sim.shelter_cell = sim.core_cell + Defs.SHELTER_CELL
		sim.food_cell = sim.shelter_cell + Defs.FOOD_CELL
		sim.carried_kit = Defs.KIT_NONE
	main.player.position = sim.core_centre() + Vector2(Grid.px(2.2), Grid.px(2.2))
	main.player.warmth = 100.0
	await _frames(10)
	main.craft_selected(_craft_index("pickaxe"))
	await _seconds(1.5)
	if _wanted("pickaxe_craft"):
		await _save("pickaxe_craft")
	# The make is three seconds; the flight starts when it ends.
	var frames := 0
	while main.fx.flights() == 0 and frames < 400:
		await process_frame
		frames += 1
	await _seconds(0.3)
	if _wanted("pickaxe_flight"):
		await _save("pickaxe_flight")
	await _seconds(0.7)
	if _wanted("pickaxe_acquired"):
		await _save("pickaxe_acquired")

## A frozen cat by the fire, thawing; awake; and at work on a seam.
func _first_cat() -> void:
	var sim = main.sim
	# Against the base's east wall: the fire thaws what is within a tile and a
	# half of its walls (Sim.can_thaw).
	var cell: Vector2i = sim.core_cell + Vector2i(5, 1)
	sim.frozen_cats[cell] = 0.45
	main.player.position = sim.prop_centre(cell) + Vector2(-Grid.px(1.6), 0.0)
	await _seconds(1.0)
	if _wanted("first_cat"):
		await _save("first_cat")
	sim.frozen_cats[cell] = 0.995
	var frames := 0
	while sim.frozen_cats.has(cell) and frames < 400:
		await process_frame
		frames += 1
	await _seconds(0.35)
	if _wanted("first_cat_awake"):
		await _save("first_cat_awake")
	if sim.cats.is_empty():
		return
	var cat = sim.cats[sim.cats.size() - 1]
	# The nearest bare seam, and the cat put to work on it.
	var seam := Vector2i(9999, 9999)
	var best := INF
	for ore_cell: Vector2i in sim.ore:
		if sim.machine_at(ore_cell) != null:
			continue
		var d: float = Vector2(ore_cell - sim.core_cell).length()
		if d < best:
			best = d
			seam = ore_cell
	if seam == Vector2i(9999, 9999):
		return
	sim.carried_cat = cat
	if sim.place_cat(seam):
		main._cat_starts_work(sim.machine_centre_at(seam))
	main.player.position = sim.cell_centre(seam) + Vector2(-Grid.px(1.8), Grid.px(0.6))
	await _seconds(1.2)
	if _wanted("first_cat_work"):
		await _save("first_cat_work")

## Night: into the shelter with the cats, to bed, and the morning.
func _night() -> void:
	var sim = main.sim
	main.finish_tutorial()
	main.time_left = Defs.NIGHT_SECONDS - 5.0
	main.player.position = main.shelter_doorstep()
	await _seconds(1.0)
	main.open_room()
	await _seconds(3.5)
	if _wanted("shelter_night"):
		await _save("shelter_night")
	main.player.position = main.room_sleep_point()
	main.room_sleeping = true
	main.player.locked = true
	var frames := 0
	while main.state == main.State.PLAY and frames < 400:
		await process_frame
		frames += 1
	await _seconds(Defs.DAWN_SECONDS - Defs.BED_RISE_SECONDS * 0.5)
	if _wanted("wake_up"):
		await _save("wake_up")
	await _seconds(Defs.BED_RISE_SECONDS * 0.5 + Defs.BED_STEP_SECONDS * 0.5)
	if _wanted("wake_up_step"):
		await _save("wake_up_step")
	frames = 0
	while main.state != main.State.PLAY and frames < 600:
		await process_frame
		frames += 1
