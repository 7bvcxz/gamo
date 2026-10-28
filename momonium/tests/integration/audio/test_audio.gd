extends "res://tests/framework/test_case.gd"

## The island's sound: three buses with their own volumes, mute, quiet in
## the background; the sea always, wind and crickets by night, a hum while
## furnaces work, easing rather than jumping; a short sound for each thing
## that happens and for every button; and loops that loop.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var audio: AudioService


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	audio = main.get("audio")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_a_natural_volume_curve() -> void:
	assert_eq(AudioService.volume_db(0.0), -80.0, "off is off")
	assert_near(AudioService.volume_db(1.0), 0.0, 0.001, "full is 0 dB")
	assert_near(AudioService.volume_db(0.5), linear_to_db(0.25), 0.001, "half is a quarter of the power: -12 dB")


func test_settings_reach_the_buses() -> void:
	for bus: String in ["Music", "Ambience", "Effects"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "a %s bus" % bus)
	audio.set_setting("music_volume", 0.5)
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.25), 0.01, "music at half")
	audio.set_setting("sfx_volume", 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "effects at zero: silent")
	assert_eq(float(audio.settings.get_value("music_volume")), 0.5, "kept in the settings")
	audio.set_setting("muted", true)
	assert_true(AudioServer.is_bus_mute(0), "mute: everything")
	audio.set_setting("muted", false)
	assert_false(AudioServer.is_bus_mute(0), "and back")


func test_quiet_in_the_background() -> void:
	audio.set_setting("mute_unfocused", true)
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(AudioServer.is_bus_mute(0), "another app in front: silent")
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(AudioServer.is_bus_mute(0), "back: sound again")
	audio.set_setting("mute_unfocused", false)
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(AudioServer.is_bus_mute(0), "the player chose to keep listening")
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


func test_ambience_follows_the_island() -> void:
	var t := audio.targets()
	assert_eq([t["ocean"], t["crickets"], t["industry"]], [0.75, 0.0, 0.0], "a quiet morning: the sea")
	sim.advance_to(int(sim.clock.day_ms * 0.85))
	t = audio.targets()
	assert_eq(t["crickets"], 0.6, "night: crickets")
	assert_true(float(t["wind"]) > 0.3, "and more wind")
	var bs: BuildingSystem = sim.system(&"buildings")
	var s := bs.place_instant("smelter", Vector2i(1, 0))
	(sim.system(&"inventory") as InventorySystem).add("copper_ore", 10, "test")
	(sim.system(&"inventory") as InventorySystem).add("wood", 10, "test")
	bs.start_stage(s, 0, 1.0)
	assert_eq(audio.targets()["industry"], 0.5, "a furnace at work: its hum")
	audio.level["crickets"] = 0.0
	audio._process(0.5)
	assert_near(float(audio.level["crickets"]), 0.25, 0.001, "easing in, not jumping")


func test_a_burst_stays_under_full_scale() -> void:
	# Step 65: eight effects at once measured 1.3 at the speakers -- clipping.
	# The web's sample playback has no bus limiter, so the service holds it:
	# each effect starts under every one already sounding, none left out.
	audio.played.clear()
	for v: AudioStreamPlayer in audio.voices:
		v.stop()
	var burst: Array[String] = ["build", "built", "research", "land", "momo", "promote"]
	for e: String in burst:
		audio.play(e)
	for e: String in burst:
		assert_eq(int(audio.played.get(e, 0)), 1, "%s is heard" % e)
	var dbs: Array[float] = []
	for v: AudioStreamPlayer in audio.voices:
		if v.playing:
			dbs.append(v.volume_db)
	dbs.sort()
	dbs.reverse()
	assert_eq(dbs.size(), burst.size(), "all of them sounding")
	for i in range(1, dbs.size()):
		assert_true(dbs[i] < dbs[i - 1] - 5.0, "each under the one before it (%s)" % [dbs])
	var total := 0.0
	for d: float in dbs:
		total += db_to_linear(d)
	assert_true(total < 2.0, "the pile stays under two of one (%.2f)" % total)
	for v: AudioStreamPlayer in audio.voices:
		v.stop()
	audio.play("click")
	var lone := audio.voices.filter(func(v: AudioStreamPlayer) -> bool: return v.playing)
	assert_eq(lone.size(), 1, "one click")
	assert_near((lone[0] as AudioStreamPlayer).volume_db, 0.0, 0.01, "alone, at full level")


func test_events_and_buttons_make_sounds() -> void:
	audio.played.clear()
	var bs: BuildingSystem = sim.system(&"buildings")
	sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})
	sim.advance_ms(build_ms(sim, "farm") + 100)
	sim.bus.emit(&"task_completed", {"id": 1, "stage": "harvest", "type": "farm", "worker": 0})
	sim.bus.emit(&"research_completed", {"id": "farm_expansion"})
	sim.bus.emit(&"letter_written", {"id": "x"})
	sim.bus.emit(&"sold", {"items": {}})
	sim.bus.emit(&"tier_promoted", {"tier": 1, "name": "city"})
	sim.execute({"type": "building.demolish", "id": bs.building_at(Vector2i(1, 0))})
	for e: String in ["build", "built", "harvest", "research", "letter", "coin", "promote", "demolish"]:
		assert_true(int(audio.played.get(e, 0)) >= 1, "%s is heard" % e)
	main.call("_on_hud_action", &"settings")
	await tree.process_frame
	var view: SettingsView = main.get("settings_view")
	var clicks := int(audio.played.get("click", 0))
	view.tutorial_button.pressed.emit()
	assert_eq(int(audio.played.get("click", 0)), clicks + 1, "every button clicks")


func test_loops_loop_and_effects_do_not() -> void:
	assert_true((audio.music.stream as AudioStreamOggVorbis).loop, "the music loops")
	assert_near(audio.music.stream.get_length(), 26.67, 0.05, "26.7 s of it")
	for layer: String in AudioService.LAYERS:
		var s: AudioStreamOggVorbis = (audio.layers[layer] as AudioStreamPlayer).stream
		assert_true(s != null and s.loop, "%s loops" % layer)
	for e: String in ["click", "build", "built", "harvest", "research", "letter", "momo", "coin", "land", "promote", "demolish", "refuse",
			"tap_pick", "tap_wood", "tap_metal", "tap_water", "tap_soft", "thunk"]:
		var s: AudioStream = load("res://assets/audio/sfx_%s.ogg" % e)
		assert_true(s != null and s.get_length() < 2.0, "%s: a short sound" % e)
		assert_false((s as AudioStreamOggVorbis).loop, "%s does not loop" % e)


func test_the_settings_sliders() -> void:
	main.call("_on_hud_action", &"settings")
	await tree.process_frame
	var view: SettingsView = main.get("settings_view")
	view.refresh()
	assert_near((view.sliders["music_volume"] as HSlider).value, float(audio.settings.get_value("music_volume")), 0.001, "the slider shows the setting")
	(view.sliders["ambience_volume"] as HSlider).value = 0.25
	assert_eq(float(audio.settings.get_value("ambience_volume")), 0.25, "moving it changes the setting")
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), linear_to_db(0.0625), 0.01, "and the bus")
	view.mute_toggle.button_pressed = true
	assert_true(AudioServer.is_bus_mute(0), "the mute toggle mutes")
	view.mute_toggle.button_pressed = false
