extends SceneTree

## Night, bed and morning (Quality Pass 01).
##
## * Night cats stay in. Walking out of the shelter after dark ran the morning's
##   code: every cat with a post was sent back to it, and worked the rest of the
##   night. She may go out into the dark; the crew stays asleep until morning.
## * Going to bed, she lies down as the light goes.
## * Morning used to hide her for the whole dawn and put her on the floor,
##   standing, when the door opened -- a teleport. Now she is in bed through the
##   dawn, sits up and stands as the light comes, and steps off the bed.
## * A cat put to work is heard -- its own tap, not the build thunk -- and the
##   first automation of a run gets the small reward.
## * A cat thawing out sheds ice.
## * The night's captions speak plainly, like everything else she says.

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_test_night_cats_stay_in()
	_test_day_door_lets_them_out()
	_test_bed_to_morning()
	_test_first_work()
	_test_thaw()
	_test_captions()
	_test_new_game_from_the_shelter()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_night_sleep")
	else:
		print("FAIL test_night_sleep (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _fresh() -> void:
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.messages.clear()
	# The ear follows her once a frame; a test that calls handlers directly has
	# to give it that frame, or it is still wherever the last case left it.
	main._update_ambience(1.0 / 30.0)

## Two cats with posts: bare seams near the fire.
func _crew() -> Array:
	var sim = main.sim
	var seams: Array = []
	for cell: Vector2i in sim.ore_nodes:
		if sim.machine_at(cell) == null:
			seams.append(cell)
		if seams.size() >= 2:
			break
	var crew: Array = []
	for seam: Vector2i in seams:
		var cat := Sim.Cat.new()
		cat.pos = sim.post_stand(seam) if sim.has_method("post_stand") else sim.cell_centre(seam)
		cat.assigned = seam
		cat.state = Defs.CAT_WORKING
		sim.cats.append(cat)
		crew.append(cat)
	return crew

func _play(seconds: float) -> void:
	var dt := 1.0 / 30.0
	for step in int(seconds / dt):
		main._process_play(dt)

func _test_night_cats_stay_in() -> void:
	_fresh()
	var crew: Array = _crew()
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	_play(0.2)
	_assert(main.night_rest_sent, "밤이 되면 고양이들을 집으로 보낸다")
	for cat: Sim.Cat in crew:
		_assert(cat.state == Defs.CAT_TO_SHELTER, "고양이가 숙소로 간다 (%d)" % cat.state)
	# She goes in, and back out into the dark.
	main.player.position = main.shelter_doorstep()
	main.open_room()
	main.close_room()
	var working := 0
	for cat: Sim.Cat in crew:
		if cat.state == Defs.CAT_TO_MINER or cat.state == Defs.CAT_WORKING:
			working += 1
	_assert(working == 0, "밤에 문을 나서도 고양이들은 일하러 나오지 않는다 (%d마리)" % working)
	_play(5.0)
	var asleep := 0
	for cat: Sim.Cat in crew:
		if cat.state == Defs.CAT_ASLEEP:
			asleep += 1
	_assert(asleep == crew.size(), "밤새 숙소에서 잔다 (%d/%d)" % [asleep, crew.size()])
	# Morning lets them out.
	main.time_left = Defs.DAY_SECONDS
	_play(0.2)
	var out := 0
	for cat: Sim.Cat in crew:
		if cat.state == Defs.CAT_TO_MINER:
			out += 1
	_assert(out == crew.size(), "아침이 되면 제자리로 간다 (%d/%d)" % [out, crew.size()])

func _test_day_door_lets_them_out() -> void:
	_fresh()
	var crew: Array = _crew()
	main.player.position = main.shelter_doorstep()
	main.open_room()
	main.close_room()
	var out := 0
	for cat: Sim.Cat in crew:
		if cat.state == Defs.CAT_TO_MINER:
			out += 1
	_assert(out == crew.size(), "낮에 문을 나서면 고양이들도 일하러 간다 (%d/%d)" % [out, crew.size()])

func _test_bed_to_morning() -> void:
	_fresh()
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	main.player.position = main.shelter_doorstep()
	main.open_room()
	main.player.position = main.room_sleep_point()
	main.room_sleeping = true
	main.player.locked = true
	var dt := 1.0 / 30.0
	var lay := false
	var steps := 0
	while main.state == main.State.PLAY and steps < 300:
		if main.room_fade > 0.9 and main.player.collapse > 0.9:
			lay = true
		main._process(dt)
		steps += 1
	_assert(lay, "불이 꺼지는 동안 침대에 눕는다")
	_assert(main.state == main.State.DAYBREAK, "아침 연출로 넘어간다")
	_assert(main.player.visible, "새벽에도 그녀가 보인다 — 침대에")
	_assert(main.player.collapse > 0.9, "누운 채로 (%.2f)" % main.player.collapse)
	_assert(main.player.position.distance_to(main.room_sleep_point()) < 1.0, "베개 위에서")
	var last: Vector2 = main.player.position
	var worst := 0.0
	var sat := false
	steps = 0
	while main.state == main.State.DAYBREAK and steps < 600:
		main._process(dt)
		worst = maxf(worst, main.player.position.distance_to(last))
		last = main.player.position
		if main.player.collapse > 0.1 and main.player.collapse < 0.9:
			sat = true
		steps += 1
	_assert(sat, "빛이 들면 몸을 일으킨다")
	_assert(worst < 8.0, "순간이동 없이 침대에서 내려온다 (한 프레임 최대 %.1fpx)" % worst)
	_assert(main.state == main.State.PLAY and not main.player.locked, "그리고 하루가 시작된다")
	_assert(main.player.position.distance_to(Defs.room_centre(Defs.ROOM_WAKE)) < 1.0,
		"아침의 자리에 선다")
	_assert(main.player.collapse == 0.0, "서 있다")

func _test_first_work() -> void:
	_fresh()
	var audio: Node = main.audio
	audio.advance(1.0)
	var taps: int = int(audio.started.get("cat_tap", 0))
	var rewards: int = int(audio.started.get("finish", 0))
	var at: Vector2 = main.player.position + Vector2(20.0, 0.0)
	main._cat_starts_work(at)
	_assert(int(audio.started.get("cat_tap", 0)) == taps + 1, "고양이가 자기 작업음으로 일을 시작한다")
	_assert(int(audio.started.get("finish", 0)) == rewards + 1, "첫 자동화에는 작은 보상이 울린다")
	audio.advance(1.0)
	main._cat_starts_work(at)
	_assert(int(audio.started.get("finish", 0)) == rewards + 1, "두 번째부터는 조용하다")

func _test_thaw() -> void:
	_fresh()
	var audio: Node = main.audio
	audio.advance(10.0)
	var meows: int = int(audio.started.get("meow", 0))
	var frost: int = int(audio.started.get("frost", 0))
	main._on_cat_thawed(1, main.player.position + Vector2(24.0, 0.0))
	_assert(int(audio.started.get("meow", 0)) == meows + 1, "깨어난 고양이가 운다")
	_assert(int(audio.started.get("frost", 0)) == frost + 1, "얼음이 부서지는 소리가 난다")

func _test_captions() -> void:
	var hud: String = FileAccess.get_file_as_string("res://scripts/HUD.gd")
	for word: String in ["돌아옵니다", "들어왔습니다", "밝아옵니다"]:
		_assert(not hud.contains(word), "밤의 자막이 존댓말 안내가 아니다 (%s)" % word)

## 처음부터 from the settings panel while she is in the shelter, or during a dawn.
## The new world used to inherit `indoors` (so its ground was not drawn -- a black
## disc under the fire) and the room's fade to black.
func _test_new_game_from_the_shelter() -> void:
	_fresh()
	main.player.position = main.shelter_doorstep()
	main.open_room()
	main.room_fade = 0.6
	_assert(main.sim.indoors, "(숙소 안이다)")
	main._start_run()
	_assert(not main.sim.indoors, "새 세계는 바깥에서 시작한다")
	_assert(main.room_fade == 0.0 and not main.room_open, "방의 어둠도 따라오지 않는다")
