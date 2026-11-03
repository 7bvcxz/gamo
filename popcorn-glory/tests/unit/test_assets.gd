extends "res://tests/framework/test_case.gd"

## The art and sound the game ships: the atlas was rebuilt after the last change
## to any SVG source, every sound loads, the SFX bus is declared (a bus added at
## run time is silent on the web), and nothing the game does not use can ride
## into the pack.


func test_the_atlas_matches_its_sources() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/sprites.json"))
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlas/sprites.json"))
	assert_true(PopAtlas.ready(), "the atlas loads")
	for name: String in manifest["sprites"]:
		assert_true(atlas["regions"].has(name), "%s is in the atlas" % name)
		var svg := FileAccess.get_file_as_string("res://art_src/" + String(manifest["sprites"][name]["source"]))
		assert_eq(String(atlas["regions"][name]["sha"]), svg.sha256_text().substr(0, 16),
			"%s: rebuild the atlas (tools/build_atlas.gd) after changing its SVG" % name)
		var r := PopAtlas.region(name)
		assert_true(r.size.x > 8 and r.size.y > 8, "%s has a region %s" % [name, r])


func test_every_sound_loads() -> void:
	for n: String in PopAudio.NAMES:
		var path := "res://assets/audio/%s.ogg" % n
		assert_true(ResourceLoader.exists(path), "%s exists (tools/build_audio.py)" % path)
		var s: AudioStream = load(path)
		assert_true(s != null and s.get_length() > 0.03, "%s plays for %.2f s" % [n, s.get_length() if s else 0.0])


func test_the_sfx_bus_is_declared() -> void:
	assert_true(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus from default_bus_layout.tres")


func test_export_keeps_what_the_game_reads_and_leaves_the_rest() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "presets load")
	var inc := String(cfg.get_value("preset.0", "include_filter", ""))
	for pattern: String in ["data/*.json", "assets/atlas/*.json"]:
		assert_true(inc.contains(pattern), "include_filter has %s" % pattern)
	for folder: String in ["art_src", "design", "evidence", "tests/e2e"]:
		assert_true(FileAccess.file_exists("res://%s/.gdignore" % folder), "%s has a .gdignore" % folder)
