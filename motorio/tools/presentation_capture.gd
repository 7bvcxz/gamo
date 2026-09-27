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
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await _frames(3)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _resize(size)
		await _opening()
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
