extends "res://tests/framework/test_case.gd"

var sim: Simulation
var world: WorldSystem
var field: ShoreField


func before_each() -> void:
	sim = Simulation.new_game()
	world = sim.system(&"world")
	field = ShoreField.new()


func test_field_is_land_coast_and_sea() -> void:
	field.build(world)
	assert_true(field.sample(Vector2(1.0, 1.0)) > 0.9, "middle of the island is land (%f)" % field.sample(Vector2(1, 1)))
	assert_between(field.sample(Vector2(2.0, 1.0)), 0.3, 0.7, "the coastline is about half")
	assert_true(field.sample(Vector2(4.5, 1.0)) < 0.05, "two and a half tiles out is open sea")
	assert_true(field.sample(Vector2(2.5, 1.0)) < field.sample(Vector2(2.1, 1.0)), "falls off with distance")
	assert_eq(field.sample(Vector2(500, 500)), 0.0, "far outside the texture is sea")


func test_field_follows_new_land() -> void:
	field.build(world)
	var before := field.sample(Vector2(2.5, 0.5))
	world.add_land(Vector2i(2, 0))
	field.build(world)
	assert_true(field.sample(Vector2(2.5, 0.5)) > 0.9 and before < 0.6, "the new cell becomes land in the field")


func test_large_island_stays_cheap_and_small() -> void:
	var cells: Array = []
	for y in 120:
		for x in 120:
			cells.append([x, y, "grass"])
	world.load_state({"land": cells})
	var t0 := Time.get_ticks_usec()
	field.build(world)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_true(field.texture.get_width() <= ShoreField.MAX_SIZE and field.texture.get_height() <= ShoreField.MAX_SIZE, "texture capped at %d" % ShoreField.MAX_SIZE)
	assert_true(ms < 250.0, "14,400-cell island field in %.1f ms" % ms)
	assert_true(field.sample(Vector2(60, 60)) > 0.9, "still land in the middle")
	assert_true(field.sample(Vector2(121.5, 60)) < 0.5, "and sea past the coast")
