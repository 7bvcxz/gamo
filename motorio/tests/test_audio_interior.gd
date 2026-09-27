extends SceneTree

## The shelter, heard from inside (Quality Pass 01).
##
## Warm, quiet, muffled: the stove and the cats asleep, and the plateau gone --
## no wind, no factory, no generator hum. The door is a fade rather than a cut.
## And the purr belongs to the cats: a shelter she walks into alone has a fire in
## it and nothing else.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_inside_and_out()
	if failures == 0:
		print("PASS test_audio_interior")
	else:
		print("FAIL test_audio_interior (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _settle(main: Node2D, seconds: float) -> void:
	for step in int(seconds / 0.05):
		main.audio.advance(0.05)
		main._update_ambience(0.05)

func _test_inside_and_out() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var audio: Node = main.audio
	# A running generator by the fire, so there is something outside to hum.
	var sim = main.sim
	var generator := Sim.Machine.new()
	generator.type = Defs.M_GENERATOR
	generator.cell = sim.core_cell + Vector2i(8, 8)
	generator.operated = true
	sim.add_machine(generator)
	main.player.position = sim.machine_centre_at(generator.cell) + Vector2(0.0, 40.0)
	_settle(main, 3.0)
	_assert(audio.bed_level("wind") > 0.3, "밖: 바람이 분다 (%.2f)" % audio.bed_level("wind"))
	_assert(audio.bed_level("hearth") < 0.05, "밖: 난로 소리는 없다")
	_assert(audio.emitting("hum").size() == 1, "밖: 발전기가 웅웅거린다")

	# In, alone.
	main.open_room()
	main._update_ambience(0.05)
	var first: float = audio.bed_level("hearth")
	_assert(first > 0.0 and first < 0.5, "문이 닫히는 첫 순간은 아직 전환 중이다 (%.2f)" % first)
	_settle(main, 3.0)
	_assert(audio.bed_level("hearth") > 0.9, "안: 난로가 따뜻하게 탄다 (%.2f)" % audio.bed_level("hearth"))
	_assert(audio.bed_level("wind") < 0.05, "안: 바람이 없다 (%.2f)" % audio.bed_level("wind"))
	_assert(audio.emitting("hum").is_empty(), "안: 발전기 소리가 없다")
	_assert(audio.bus_level("Machine") < 0.01 and audio.bus_level("Ambient") < 0.01,
		"안: 바깥 버스가 내려가 있다")
	_assert(audio.bus_level("Interior") > 0.99, "안: 방의 버스가 올라와 있다")
	_assert(audio.bed_level("purr") < 0.05, "혼자면 가르랑 소리는 없다 (%.2f)" % audio.bed_level("purr"))

	# The cats come in and lie down.
	for cat: Sim.Cat in sim.cats:
		cat.pos = Defs.room_centre(Defs.ROOM_ENTRY)
	if sim.cats.is_empty():
		var cat := Sim.Cat.new()
		cat.pos = Defs.room_centre(Defs.ROOM_ENTRY)
		sim.cats.append(cat)
	_settle(main, 3.0)
	_assert(audio.cats_inside > 0, "방 안의 고양이를 센다 (%d)" % audio.cats_inside)
	_assert(audio.bed_level("purr") > 0.4, "고양이가 있으면 가르랑거린다 (%.2f)" % audio.bed_level("purr"))

	# And out again.
	main.close_room()
	main.player.position = sim.machine_centre_at(generator.cell) + Vector2(0.0, 40.0)
	_settle(main, 3.0)
	_assert(audio.bed_level("hearth") < 0.05 and audio.bed_level("purr") < 0.05,
		"나오면 방 안 소리가 멎는다")
	_assert(audio.bed_level("wind") > 0.3, "바람이 돌아온다")
	_assert(audio.emitting("hum").size() == 1, "발전기 소리가 돌아온다")
	main.clear_save()
	main.free()
