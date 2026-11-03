extends "res://tests/framework/test_case.gd"

## The six experiments the launcher shows: A to F in order, stable ids (their
## direct links), a picture that exists in the game's atlas, and a script
## that runs -- the experiment's own once it is built, the stub until then.


func test_six_experiments_a_to_f() -> void:
	var letters: Array[String] = []
	for e: Dictionary in LabRegistry.EXPERIMENTS:
		letters.append(String(e["letter"]))
	assert_eq(letters, ["A", "B", "C", "D", "E", "F"] as Array[String], "A..F in order")
	assert_eq(LabRegistry.ids(), ["island", "evolution", "rock", "harvest", "tycoon", "tree"] as Array[String], "the direct links' ids")


func test_every_tile_has_a_picture_and_a_title() -> void:
	for e: Dictionary in LabRegistry.EXPERIMENTS:
		assert_true(LabAtlas.has(String(e["icon"])), "%s's picture %s is in the atlas" % [e["id"], e["icon"]])
		assert_true(String(e["title"]).length() > 3, "%s has a title" % e["id"])
		assert_true(e["color"] is Color, "%s has a colour" % e["id"])


func test_every_experiment_runs_something() -> void:
	for id: String in LabRegistry.ids():
		var path := LabRegistry.script_path(id)
		assert_true(ResourceLoader.exists(path), "%s: %s exists" % [id, path])
		var script: GDScript = load(path)
		var inst: Object = script.new()
		assert_true(inst is LabExperiment, "%s runs a LabExperiment" % id)
		(inst as Node).free()
		if not LabRegistry.playable(id):
			assert_eq(path, LabRegistry.STUB, "%s is not built yet: the stub" % id)


func test_unknown_ids_are_not_experiments() -> void:
	assert_false(LabRegistry.has("momonium"), "not an experiment")
	assert_false(LabRegistry.has(""), "empty is the launcher")
	assert_eq(LabRegistry.find("nope"), {}, "nothing found")


func test_two_tracks_beside_their_baselines() -> void:
	assert_eq(LabRegistry.track_ids(), ["rock-plus", "tycoon-plus"] as Array[String], "C+ and E+")
	assert_eq(LabRegistry.base_of("rock-plus"), "rock", "C+ grows from C")
	assert_eq(LabRegistry.base_of("tycoon-plus"), "tycoon", "E+ grows from E")
	assert_eq(LabRegistry.base_of("rock"), "rock", "an experiment is its own baseline")
	assert_eq(LabRegistry.track_of("rock"), "rock-plus", "C's track")
	assert_eq(LabRegistry.track_of("island"), "", "A has none")
	assert_eq(LabRegistry.ids().size(), 6, "the six are still six: a track is not a seventh tile")
	for id: String in LabRegistry.track_ids():
		assert_true(LabRegistry.routable(id), "%s has a direct link" % id)
		assert_true(LabRegistry.playable(id), "%s plays" % id)
		assert_false(LabRegistry.has(id), "%s is not one of the six" % id)
		assert_ne(LabRegistry.script_path(id), LabRegistry.script_path(LabRegistry.base_of(id)), "%s runs its own script, so the baseline's never changes for it" % id)
	assert_eq(LabRegistry.label("rock-plus"), "C+ · Break & Upgrade", "the run's title says C+")
	assert_eq(LabRegistry.label("rock"), "C · Break & Upgrade", "and the baseline's says C")
