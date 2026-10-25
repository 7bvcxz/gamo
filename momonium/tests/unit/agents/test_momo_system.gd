extends "res://tests/framework/test_case.gd"

func test_the_game_starts_with_one_momo_on_the_island() -> void:
	var sim := Simulation.new_game()
	var momos: MomoSystem = sim.system(&"momo")
	assert_eq(momos.ids().size(), 1, "one Momo, as in the reference")
	var p := momos.position_of(1)
	var world: WorldSystem = sim.system(&"world")
	assert_true(world.is_owned(Vector2i(floori(p.x), floori(p.y))), "standing on the island")
	assert_eq(momos.get_momo(1)["name"], "momo.name.0", "named Momo")
	assert_eq(momos.get_momo(1)["assigned"], 0, "not working anywhere yet")


func test_momos_survive_a_save() -> void:
	var sim := Simulation.new_game()
	var momos: MomoSystem = sim.system(&"momo")
	momos.add_momo(Vector2(1.5, 0.5))
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var m2: MomoSystem = copy.system(&"momo")
	assert_eq(m2.ids(), [1, 2] as Array[int], "both Momo")
	assert_eq(m2.position_of(2), Vector2(1.5, 0.5), "where they stood")
	assert_eq(m2.get_momo(2)["name"], "momo.name.1", "with their names")
