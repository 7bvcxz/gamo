extends SceneTree

## Many things making the same sound (Quality Pass 01).
##
## A factory is the same event from twenty places. Played as it comes, it is a
## wall; this holds the rules that keep it a detail:
##
## * the same recording is not struck twice running (the pickaxe was one sample
##   -- "벽 때리는 소리", again and again),
## * twenty cats at work are the nearest three taps at a time,
## * twenty machines finishing work are three clinks at a time,
## * twenty generators are two hums -- the two nearest -- and none out of earshot,
## * a sound that is already sounding makes the next copy quieter,
## * and in the real game a cat at work is heard at all (it was silent).

var failures := 0

const Audio := preload("res://scripts/Audio.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_takes_rotate()
	await _test_twenty_cats()
	await _test_twenty_machines()
	await _test_twenty_generators()
	await _test_crowd()
	await _test_cat_is_heard_in_game()
	if failures == 0:
		print("PASS test_audio_concurrency")
	else:
		print("FAIL test_audio_concurrency (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _audio() -> Node:
	var audio: Node = Audio.new()
	root.add_child(audio)
	await process_frame
	audio.listener = Vector2.ZERO
	return audio

func _test_takes_rotate() -> void:
	var audio: Node = await _audio()
	for sound: String in ["pick", "step", "cat_tap", "clink", "deliver"]:
		_assert((Audio.BANK[sound] as Array).size() >= 3, "%s 는 테이크가 셋 이상이다" % sound)
	for step in 20:
		audio.advance(0.3)
		audio.play("pick")
	var log: Array = audio.take_log["pick"]
	var repeats := 0
	var seen: Dictionary = {}
	for index in log.size():
		seen[log[index]] = true
		if index > 0 and log[index] == log[index - 1]:
			repeats += 1
	_assert(repeats == 0, "곡괭이가 같은 녹음을 두 번 연달아 치지 않는다")
	_assert(seen.size() >= 4, "스무 번에 네 가지 이상의 테이크가 나온다 (%d)" % seen.size())
	audio.free()

## Twenty working cats on a ring of distances around her.
func _test_twenty_cats() -> void:
	var audio: Node = await _audio()
	var cats: Dictionary = {}
	for index in 20:
		var distance: float = 40.0 + 42.0 * float(index)
		cats[index] = Vector2.RIGHT.rotated(float(index) * 1.3) * distance
	var loudest := 0
	var dt := 0.05
	var near_taps := 0
	var far_taps := 0
	var before: int = 0
	for step in int(30.0 / dt):
		audio.advance(dt)
		audio.work("cat_tap", cats, dt)
		loudest = maxi(loudest, audio.sounding("cat_tap"))
		var now: int = int(audio.started.get("cat_tap", 0))
		if now > before:
			before = now
	var total: int = int(audio.started.get("cat_tap", 0))
	_assert(loudest <= 3, "고양이 스무 마리여도 작업음은 한 번에 셋까지다 (%d)" % loudest)
	_assert(total > 20, "그래도 작업음은 들린다 — 30초에 %d번" % total)
	_assert(float(total) / 30.0 <= 3.8, "스무 마리의 작업음을 다 합쳐도 초당 3.8번 이하다 (%.1f)" % (float(total) / 30.0))
	# Out of earshot, nothing: the far half of the ring is past FAR.
	var out_of_earshot := 0
	for id: int in cats:
		if (cats[id] as Vector2).length() > Audio.FAR:
			out_of_earshot += 1
	_assert(out_of_earshot > 0, "(링의 일부는 귀 밖이다: %d마리)" % out_of_earshot)
	# Nearest first: with the cap full, a nearer sound takes the farthest voice
	# and a farther one is not heard. Shown on the pickaxe -- its takes outlast
	# its gap, so its cap (two) actually fills; a cat's tap is over before three
	# of them can start, which is the gap doing the cap's job.
	var audio2: Node = await _audio()
	audio2.advance(1.0)
	for distance: float in [300.0, 280.0]:
		audio2.play_at("pick", Vector2(distance, 0.0))
		audio2.advance(0.09)
	_assert(audio2.sounding("pick") == 2, "상한이 찼다 (%d)" % audio2.sounding("pick"))
	_assert(not audio2.play_at("pick", Vector2(400.0, 0.0)), "더 먼 소리는 끼어들지 못한다")
	audio2.advance(0.09)
	_assert(audio2.play_at("pick", Vector2(20.0, 0.0)), "더 가까운 소리는 가장 먼 소리를 밀어낸다")
	_assert(audio2.sounding("pick") == 2, "그래도 둘이다")
	audio.free()
	audio2.free()

func _test_twenty_machines() -> void:
	var audio: Node = await _audio()
	var loudest := 0
	var dt := 0.05
	for step in int(10.0 / dt):
		audio.advance(dt)
		# Every machine in a twenty-machine factory finishing at once, every frame.
		for index in 20:
			audio.play_at("clink", Vector2(30.0 * float(index), 0.0))
		loudest = maxi(loudest, audio.sounding("clink"))
	_assert(loudest <= 3, "기계 스무 대가 한꺼번에 끝나도 소리는 셋까지다 (%d)" % loudest)
	var total: int = int(audio.started.get("clink", 0))
	_assert(total <= int(10.0 / 0.2) + 1, "같은 소리의 간격이 지켜진다 (10초에 %d번)" % total)
	audio.free()

func _test_twenty_generators() -> void:
	var audio: Node = await _audio()
	var points: Array = []
	for index in 20:
		points.append(Vector2(60.0 + 40.0 * float(index), 0.0))
	audio.set_emitters("hum", points, 0.05)
	var on: Array[Vector2] = audio.emitting("hum")
	_assert(on.size() == 2, "발전기 스무 대는 험 두 개다 (%d)" % on.size())
	_assert(on.has(Vector2(60.0, 0.0)) and on.has(Vector2(100.0, 0.0)), "가장 가까운 둘이다 %s" % str(on))
	audio.listener = Vector2(0.0, 100000.0)
	audio.set_emitters("hum", points, 0.05)
	_assert(audio.emitting("hum").is_empty(), "귀 밖이면 하나도 울리지 않는다")
	audio.listener = Vector2.ZERO
	audio.set_emitters("hum", [], 0.05)
	_assert(audio.emitting("hum").is_empty(), "발전기가 멈추면 험도 멎는다")
	audio.free()

func _test_crowd() -> void:
	var audio: Node = await _audio()
	audio.advance(1.0)
	# The pickaxe, because its takes outlast its gap: the second really does
	# start while the first is still sounding.
	audio.play_at("pick", Vector2(10.0, 0.0), 0.0)
	var first: float = _volume_of(audio, "pick", 0)
	audio.advance(0.09)
	audio.play_at("pick", Vector2(10.0, 0.0), 0.0)
	var second: float = _volume_of(audio, "pick", 1)
	_assert(second < first - 2.0, "이미 울리는 소리가 있으면 다음 것은 작다 (%.1f < %.1f)" % [second, first])
	audio.free()

## The volume of the n-th most recent start of a sound among the world voices.
func _volume_of(audio: Node, sound: String, newest: int) -> float:
	var found: Array = []
	for voice: Dictionary in audio.get("_world"):
		if String(voice["sound"]) == sound:
			found.append(voice)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ends"]) < float(b["ends"]))
	return float((found[newest]["player"] as AudioStreamPlayer2D).volume_db)

## The real thing: a cat put to work at a rig is heard.
func _test_cat_is_heard_in_game() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim = main.sim
	var cat = sim.cats[0] if not sim.cats.is_empty() else null
	if cat == null:
		cat = Sim.Cat.new()
		sim.cats.append(cat)
	cat.pos = main.player.position + Vector2(40.0, 0.0)
	cat.state = Defs.CAT_WORKING
	var audio: Node = main.audio
	var before: int = int(audio.started.get("cat_tap", 0))
	for step in 80:
		audio.advance(0.05)
		cat.state = Defs.CAT_WORKING
		cat.pos = main.player.position + Vector2(40.0, 0.0)
		main._update_ambience(0.05)
	_assert(int(audio.started.get("cat_tap", 0)) > before, "일하는 고양이의 작업음이 들린다")
	main.clear_save()
	main.free()
