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
