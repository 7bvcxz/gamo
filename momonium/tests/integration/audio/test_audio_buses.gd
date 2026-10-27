extends "res://tests/framework/test_case.gd"

## Step 65: the published game was silent. Godot's web build plays sounds as
## browser "samples", and a bus added at run time (AudioServer.add_bus) never
## reaches that graph -- the three buses this game made in code routed every
## player into nothing, while every play() and bus volume looked right. The
## buses are declared in the project's bus layout, loaded before any code
## runs, and the audio service never adds one.

const BUSES := ["Music", "Ambience", "Effects"]


func test_the_project_declares_the_buses() -> void:
	var path := String(ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres"))
	assert_true(ResourceLoader.exists(path), "a bus layout at %s" % path)
	var layout: AudioBusLayout = load(path)
	assert_true(layout != null, "it loads")
	var names: Array[String] = []
	for i in range(1, 4):
		names.append(String(layout.get("bus/%d/name" % i)))
		assert_eq(String(layout.get("bus/%d/send" % i)), "Master", "bus %d sends to Master" % i)
	assert_eq(names, ["Music", "Ambience", "Effects"] as Array[String], "Music, Ambience, Effects, in order")


func test_the_buses_exist_before_any_code_runs() -> void:
	for bus: String in BUSES:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "%s is there from the start" % bus)


func test_the_audio_service_adds_no_bus() -> void:
	var before := AudioServer.bus_count
	var sim := Simulation.new_game()
	var settings := SettingsStore.new()
	var audio := AudioService.new()
	tree.root.add_child(audio)
	audio.setup(sim, settings)
	assert_eq(AudioServer.bus_count, before, "no bus added at run time (on the web that one would be silent)")
	for bus: String in BUSES:
		var players := audio.find_children("*", "AudioStreamPlayer", false, false).filter(func(p: Node) -> bool: return (p as AudioStreamPlayer).bus == bus)
		assert_true(not players.is_empty(), "players on %s" % bus)
	audio.queue_free()
	await tree.process_frame
