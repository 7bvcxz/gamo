extends SceneTree

## The buses, the mix between inside and outside, and where a sound is.
##
## The shelter used to hear the factory: `deliver` beeped for every item a belt
## brought to the core, with no position, at the same level six hundred tiles
## away behind a shut door. Two things fix it and both are checked here -- a
## world sound is played at its place and not at all out of earshot, and going
## inside moves the outside buses down (eased, not cut).

var failures := 0

const Audio := preload("res://scripts/Audio.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_buses()
	await _test_mix()
	await _test_distance()
	await _test_shelter_hears_no_factory()
	if failures == 0:
		print("PASS test_audio_mix")
	else:
		print("FAIL test_audio_mix (%d)" % failures)
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
	return audio

## The layout the direction document draws, loaded from the project.
func _test_buses() -> void:
	var sends := {"Music": "Master", "Ambient": "Master", "SFX": "Master",
		"Machine": "SFX", "Character": "SFX", "Environment": "SFX", "UI": "Master",
		"Interior": "Master"}
	for bus: String in sends:
		var index: int = AudioServer.get_bus_index(bus)
		_assert(index >= 0, "%s 버스가 있다" % bus)
		if index >= 0:
			_assert(String(AudioServer.get_bus_send(index)) == String(sends[bus]),
				"%s 는 %s 로 간다" % [bus, sends[bus]])
	# Music goes to its own bus, so the score can be mixed without the effects.
	var music: Node = load("res://scripts/Music.gd").new()
	root.add_child(music)
	await process_frame
	var voice: AudioStreamPlayer = music.get_child(0)
	_assert(String(voice.bus) == "Music", "음악은 Music 버스로 간다 (%s)" % voice.bus)
	music.free()

func _test_mix() -> void:
	_assert(Zone.mix(Zone.FIELD) == "outside" and Zone.mix(Zone.HOME) == "inside",
		"장소 표가 믹스를 정한다")
	var audio: Node = _audio()
	await process_frame
	for step in 30:
		audio.set_mix("outside", 0.05)
	_assert(audio.bus_level("Ambient") > 0.99 and audio.bus_level("Interior") < 0.01,
		"밖: 바람은 있고 방 안 소리는 없다")
	# A door is a fade: one frame in, nothing has arrived yet.
	audio.set_mix("inside", 0.05)
	var one: float = audio.bus_level("Interior")
	_assert(one > 0.0 and one < 0.5, "문이 닫히는 첫 프레임은 아직 전환 중이다 (%.2f)" % one)
	for step in 30:
		audio.set_mix("inside", 0.05)
	_assert(audio.bus_level("Ambient") < 0.01, "안: 바람 버스가 내려간다 (%.3f)" % audio.bus_level("Ambient"))
	_assert(audio.bus_level("Machine") < 0.01, "안: 기계 버스가 내려간다 (%.3f)" % audio.bus_level("Machine"))
	_assert(audio.bus_level("Character") > 0.99, "안: 그녀와 고양이는 그대로다")
	_assert(audio.bus_level("Interior") > 0.99, "안: 방 안 소리가 올라온다")
	_assert(audio.bus_level("UI") > 0.99, "안: UI 는 그대로다")
	var engine: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambient"))
	_assert(engine < -40.0, "믹서에도 실제로 내려가 있다 (%.0f dB)" % engine)
	for step in 30:
		audio.set_mix("outside", 0.05)
	_assert(audio.bus_level("Ambient") > 0.99 and audio.bus_level("Interior") < 0.01,
		"다시 밖으로 나오면 되돌아온다")
	audio.free()

func _test_distance() -> void:
	var audio: Node = _audio()
	await process_frame
	_assert(Audio.distance_db(0.0) == 0.0, "바로 옆은 제 크기")
	_assert(Audio.distance_db(Audio.NEAR) == 0.0, "NEAR 까지는 제 크기")
	_assert(Audio.distance_db(Audio.FAR) <= Audio.FAR_DB + 0.01, "FAR 에서는 가장 작다")
	var previous := 1.0
	var falls := true
	for step in 20:
		var db: float = Audio.distance_db(Audio.NEAR + (Audio.FAR - Audio.NEAR) * float(step) / 19.0)
		if db > previous:
			falls = false
		previous = db
	_assert(falls, "멀수록 작아진다")
	audio.listener = Vector2.ZERO
	_assert(audio.play_at("deliver", Vector2(Audio.NEAR, 0.0)), "들리는 거리의 소리는 난다")
	audio.advance(1.0)
	_assert(not audio.play_at("deliver", Vector2(Audio.FAR + 32.0, 0.0)),
		"귀 밖의 소리는 아예 틀지 않는다")
	audio.free()

## The real case: a belt delivering to the core while she sleeps in the shelter.
func _test_shelter_hears_no_factory() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.open_room()
	for step in 40:
		main._update_ambience(0.05)
	var audio: Node = main.audio
	var before: int = int(audio.started.get("deliver", 0))
	audio.advance(1.0)
	main._on_item_delivered(Defs.ITEM_HEATSTONE, main.sim.core_cell)
	_assert(int(audio.started.get("deliver", 0)) == before,
		"숙소 안에서는 기지의 배달 소리가 나지 않는다")
	_assert(audio.bus_level("Machine") < 0.01, "기계 버스도 내려가 있다")
	main.close_room()
	for step in 40:
		main._update_ambience(0.05)
	main.player.position = main.sim.core_centre() + Vector2(0.0, 3.0 * float(Grid.TILE))
	main._update_ambience(0.05)
	audio.advance(1.0)
	main._on_item_delivered(Defs.ITEM_HEATSTONE, main.sim.core_cell)
	_assert(int(audio.started.get("deliver", 0)) == before + 1,
		"기지 옆에서는 배달 소리가 난다")
	main.clear_save()
	main.free()
