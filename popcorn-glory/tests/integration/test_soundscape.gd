extends "res://tests/framework/test_case.gd"

## Step 43: the factory's sound (app/audio.gd, app/soundscape.gd, design/SOUND.md).
## - every sound of the grammar is a file the game loads, and every file has its row in SOUND.md
## - the beds grow with the factory: one machine is barely there, forty are a lively floor;
##   the rhythm only joins a crowded floor; a stopped belt is silent
## - voices are limited by class: a flood of machine sounds never holds more than MACHINE_VOICES,
##   and the hand's Perfect Pop still finds a voice in the middle of it
## - while the hand holds the kettle the machines and the beds are ducked
## - one sale is one cash sound: asked exactly once per sale over three minutes of forty machines
## - a hidden tab stops the beds and the loops; the beds come back after; nothing is made per frame
## - calm (the reduced-audio option): no beds, no machine sounds, the hand still heard

const Main := preload("res://app/main.tscn")
const PLAN: Array = preload("res://tests/unit/test_factory_rules.gd").FORTY_PLAN
var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	app.save_prefix = "test."
	PopSaveStore.clear("test.factory.v1")
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	app.audio.set_level(0)
	app.audio.set_paused(false)
	PopSaveStore.clear("sound")
	app.queue_free()
	await tree.process_frame


func _open() -> Node:
	app.open("factory")
	app.clock.set_pause("dev", true)
	await tree.process_frame
	return app.frame.play


func _build(n: int) -> void:
	app.dev_build(PLAN.slice(0, n), 8, 3)


func _mouse(v: Node, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = v.machine_centre()
	v._gui_input(e)


func _frames(n: int, ms: int = 100) -> void:
	for i in n:
		app.dev_advance(ms)
		await tree.process_frame


func test_every_sound_of_the_grammar_loads_and_is_documented() -> void:
	var doc := FileAccess.get_file_as_string("res://design/SOUND.md")
	assert_true(doc.length() > 0, "design/SOUND.md")
	var files := DirAccess.get_files_at("res://assets/audio")
	var oggs := 0
	for f: String in files:
		if not f.ends_with(".ogg"):
			continue
		oggs += 1
		var n := f.get_basename()
		assert_true(n in PopAudio.NAMES, "%s is a sound the game knows" % n)
		assert_true(doc.contains("`%s`" % n), "%s has its row in SOUND.md (what, how made, where heard)" % n)
	assert_eq(oggs, PopAudio.NAMES.size(), "one file per name")
	for n: String in PopAudio.NAMES:
		assert_true(app.audio._streams.has(n), "%s loaded" % n)
	for b: String in PopAudio.BEDS:
		assert_true((app.audio._streams[b] as AudioStreamOggVorbis).loop, "%s imported as a loop (no copy made)" % b)


func test_the_beds_grow_with_the_factory() -> void:
	var one := PopSoundscape.targets(1, 1, 1, 1)
	var forty := PopSoundscape.targets(30, 6, 44, 14)
	assert_true(float(one["hum"]) < float(forty["hum"]) - 8.0, "one kettle's hum is far quieter than thirty (%.1f vs %.1f dB)" % [one["hum"], forty["hum"]])
	assert_true(float(one["hum"]) <= float(PopSoundscape.BED_DB["hum"]) - 9.0, "one machine: 9 dB under the full floor at least (%.1f dB)" % one["hum"])
	assert_eq(float(one["chug"]), PopSoundscape.SILENT, "no rhythm with one machine")
	assert_eq(float(PopSoundscape.targets(5, 2, 8, 3)["chug"]), PopSoundscape.SILENT, "nor with eight")
	assert_true(float(PopSoundscape.targets(10, 3, 12, 3)["chug"]) > PopSoundscape.SILENT, "the rhythm joins a crowded floor")
	assert_eq(float(PopSoundscape.targets(3, 0, 3, 1)["belt"]), PopSoundscape.SILENT, "a stopped belt is silent")
	assert_eq(float(one["murmur"]), PopSoundscape.SILENT, "one customer: no crowd")
	for k: String in forty:
		assert_true(float(forty[k]) <= float(PopSoundscape.BED_DB[k]) + 0.01, "%s never above its ceiling" % k)
	# All four at their ceiling, summed as amplitudes, with the headroom: far under full scale
	# (the beds' files peak at 0.35-0.45).
	var amp := 0.0
	for k: String in forty:
		amp += 0.45 * db_to_linear(float(forty[k]) + PopAudio.HEADROOM_DB)
	assert_true(amp < 0.2, "the beds at forty machines sum to %.3f of full scale at most" % amp)


func test_the_factory_sets_its_beds_from_what_runs() -> void:
	var v: Node = await _open()
	await _frames(12)
	var quiet := app.audio.debug()
	_build(44)
	await _frames(60)
	var busy := app.audio.debug()
	print("sound43 beds: ", JSON.stringify({"one": quiet["beds"], "forty": busy["beds"], "running": v.motion.running}))
	assert_true(float(busy["beds"]["hum"]["target"]) > float(quiet["beds"]["hum"]["target"]) + 6.0, "the hum grows with the machines")
	assert_true(float(busy["beds"]["chug"]["target"]) > PopSoundscape.SILENT, "forty machines: the rhythm plays")
	assert_true(float(quiet["beds"]["chug"]["target"]) <= PopSoundscape.SILENT, "one machine: no rhythm")
	assert_true(int(busy["beds_playing"]) >= 3, "the beds sound (%d)" % int(busy["beds_playing"]))


func test_a_flood_of_machine_sounds_keeps_its_voices_and_the_hand_is_heard() -> void:
	var a := app.audio
	a.voices_peak = 0
	for i in 500:
		a._last_ms.clear()
		a.play_at(["mpop", "patter", "seal", "coat"][i % 4], float(i % 10) / 9.0)
	var machine := 0
	var now := Time.get_ticks_msec()
	for i in a._voice_until.size():
		if a._voice_until[i] > now and a._voice_class[i] == int(PopAudio.CLASS["machine"]):
			machine += 1
	assert_true(machine <= PopAudio.MACHINE_VOICES, "machine sounds hold %d voices at most (%d)" % [PopAudio.MACHINE_VOICES, machine])
	assert_true(int(a.refused.get("mpop", 0)) > 100, "the rest are refused, not queued")
	for i in 30:
		a._last_ms.clear()
		a.play(["door", "news", "serve"][i % 3])
	assert_true(a.voices() <= PopAudio.POOL + PopAudio.POOL_2D, "never more voices than players")
	var before := int(a.played.get("perfect", 0))
	a.play("perfect")
	assert_eq(int(a.played.get("perfect", 0)), before + 1, "the hand's Perfect Pop finds a voice in the middle of it")
	assert_true(a.voices_peak <= PopAudio.POOL + PopAudio.POOL_2D, "peak %d voices" % a.voices_peak)


func test_holding_the_kettle_ducks_the_machines_and_the_beds() -> void:
	var v: Node = await _open()
	_build(20)
	await _frames(40)
	await tree.create_timer(2.5).timeout   # the beds fade in over real time
	var free_hum := app.audio.bed_db("hum")
	_mouse(v, true)
	await tree.create_timer(1.0).timeout
	assert_true(app.audio.holding, "the audio knows the hand is on the kettle")
	assert_true(int(app.audio.played.get("heat", 0)) == 1 and int(app.audio.played.get("rise", 0)) == 1, "the heat and its anticipation, started once each")
	assert_true(app.audio.bed_db("hum") <= free_hum - 4.0, "the hum ducks while held (%.1f -> %.1f dB)" % [free_hum, app.audio.bed_db("hum")])
	app.dev_advance(app.rules.window_start() + app.rules.window_len() / 3)
	_mouse(v, false)
	await tree.process_frame
	await tree.process_frame   # process_frame is emitted before the nodes' _process
	assert_true(not app.audio.holding, "let go")
	assert_true(int(app.audio.played.get("perfect", 0)) + int(app.audio.played.get("thud", 0)) + int(app.audio.played.get("pop_1", 0)) + int(app.audio.played.get("hiss", 0)) >= 1, "the outcome is heard (%s)" % [app.audio.played])
	assert_eq(int(app.audio.played.get("ding", 0)), 0, "the factory's kettle speaks its own grammar, not the B experiment's chime")


func test_one_sale_is_one_cash_sound() -> void:
	var v: Node = await _open()
	_build(44)
	await _frames(20)
	var sold0 := int(app.rules.stats["sold"])
	var asked0 := int(app.audio.asked.get("cash", 0))
	await _frames(1800)   # three minutes of the game's time
	var sold := int(app.rules.stats["sold"]) - sold0
	var asked := int(app.audio.asked.get("cash", 0)) - asked0
	print("sound43 cash: ", JSON.stringify({"sold": sold, "asked": asked, "played": app.audio.played.get("cash", 0), "refused": app.audio.refused.get("cash", 0), "audio": app.audio.debug()}))
	assert_true(sold > 50, "forty machines sell (%d)" % sold)
	assert_eq(asked, sold, "the cash sound is asked for exactly once per sale")
	assert_eq(int(app.audio.played.get("fanfare", 0)), 0, "no routine fanfare")


func test_a_hidden_tab_is_silent_and_nothing_is_made_per_frame() -> void:
	var v: Node = await _open()
	_build(44)
	await _frames(60)
	assert_true(app.audio.beds_playing() >= 3, "the beds play")
	var starts := app.audio.bed_starts
	app.audio.set_paused(true)
	await _frames(30)
	assert_eq(app.audio.beds_playing(), 0, "hidden: no bed plays")
	_mouse(v, true)
	await tree.process_frame
	assert_true(app.audio._loops.get(0) == null or not (app.audio._loops[0] as AudioStreamPlayer).playing, "hidden: no loop either")
	_mouse(v, false)
	app.audio.set_paused(false)
	await _frames(30)
	assert_true(app.audio.beds_playing() >= 3, "back: the beds play again")
	assert_true(app.audio.bed_starts - starts <= PopAudio.BEDS.size(), "each bed started once again (%d)" % (app.audio.bed_starts - starts))
	# Ten minutes of the game's time with presses: still no stream made per frame.
	var copies := app.audio.loop_copies
	var s0 := app.audio.bed_starts
	for k in 20:
		_mouse(v, true)
		await _frames(10, 120)
		_mouse(v, false)
		await _frames(290)
	assert_eq(app.audio.loop_copies, copies, "no looping copy made (the factory's loops are imported as loops)")
	assert_true(app.audio.bed_starts - s0 <= 4 * PopAudio.BEDS.size(), "beds are not restarted every frame (%d starts)" % (app.audio.bed_starts - s0))


func test_calm_has_no_beds_and_no_machine_sounds_but_the_hand_is_heard() -> void:
	var v: Node = await _open()
	app.audio.set_level_name("calm")
	_build(44)
	await _frames(80)
	assert_eq(app.audio.beds_playing(), 0, "calm: no bed")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambient")), "calm: the Ambient bus is muted")
	for n: String in ["mpop", "patter", "seal", "coat"]:
		assert_eq(int(app.audio.played.get(n, 0)), 0, "calm: no %s" % n)
	_mouse(v, true)
	await tree.process_frame
	assert_eq(int(app.audio.played.get("heat", 0)), 1, "calm: the hand's heat is still heard")
	_mouse(v, false)
