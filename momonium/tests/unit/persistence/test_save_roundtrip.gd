extends "res://tests/framework/test_case.gd"

const PATH := "user://test_save_roundtrip.json"


func after_each() -> void:
	for p: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_file_roundtrip_restores_the_world() -> void:
	var sim := Simulation.new_game()
	(sim.system(&"economy") as EconomySystem).spend(4, "test")
	sim.advance_ms(47123)
	assert_eq(SaveService.write(sim, PATH), OK, "save written")
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "no temp file left behind")
	var loaded := Simulation.from_save(SaveService.read(PATH))
	assert_eq(_json(loaded.snapshot()), _json(sim.snapshot()), "snapshot identical after a file round trip")
	assert_eq(loaded.clock.day_number(), 2, "47 s is Day 2")


func test_unreadable_save_is_empty_not_a_crash() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	assert_eq(SaveService.read(PATH), {}, "garbage reads as no save")
	assert_eq(SaveService.read("user://does_not_exist.json"), {}, "missing reads as no save")


func test_overwrite_replaces_previous_save() -> void:
	var sim := Simulation.new_game()
	SaveService.write(sim, PATH)
	sim.advance_ms(90000)
	SaveService.write(sim, PATH)
	assert_eq(int(SaveService.read(PATH)["clock"]["now_ms"]), 90000, "the newer save wins")


## Both sides through JSON, so int-vs-float is not mistaken for a difference.
func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))
