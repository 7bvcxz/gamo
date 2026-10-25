extends "res://tests/framework/test_case.gd"

## Momo as persistent agents: they wander their own land only, the same way
## every time from the same state, sleep at night, can be hired, assigned to a
## building with a free spot, released, and put down elsewhere.

var sim: Simulation
var momos: MomoSystem
var world: WorldSystem
var buildings: BuildingSystem
var economy: EconomySystem


func before_each() -> void:
	sim = Simulation.new_game()
	momos = sim.system(&"momo")
	world = sim.system(&"world")
	buildings = sim.system(&"buildings")
	economy = sim.system(&"economy")


func _on_land(p: Vector2) -> bool:
	return world.is_owned(Vector2i(floori(p.x), floori(p.y)))


func test_wandering_never_leaves_the_island() -> void:
	economy.earn(1000, "test")
	for cell: Array in [[2, 0], [3, 0], [3, 1], [3, 2], [-1, 1]]:
		sim.execute({"type": "land.buy", "cell": cell})
	sim.execute({"type": "momo.hire"})
	var moved := 0.0
	var last := momos.position_of(1)
	for i in 6000:
		sim.advance_ms(100)
		for id: int in momos.ids():
			assert_true(_on_land(momos.position_of(id)), "Momo %d stays on land at %d ms (%s)" % [id, sim.now_ms(), momos.position_of(id)])
		moved += momos.position_of(1).distance_to(last)
		last = momos.position_of(1)
	assert_true(moved > 3.0, "and actually wanders (%.1f tiles in 10 minutes)" % moved)


func test_wandering_is_reproducible_across_a_save() -> void:
	sim.advance_ms(20000)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var m2: MomoSystem = copy.system(&"momo")
	for i in 200:
		sim.advance_ms(250)
		copy.advance_ms(250)
		assert_true(momos.position_of(1).distance_to(m2.position_of(1)) < 0.0001, "same walk after loading (%d)" % i)


func test_momo_rest_at_night() -> void:
	sim.advance_to(int(0.72 * sim.clock.day_ms) + 8000)
	var p := momos.position_of(1)
	sim.advance_to(int(0.91 * sim.clock.day_ms))
	assert_eq(momos.position_of(1), p, "no strolls during the night")
	sim.advance_to(sim.clock.next_day_start_ms() + 15000)
	assert_ne(momos.position_of(1), p, "and up and about in the morning")


func test_hiring_costs_from_data_and_grows() -> void:
	assert_eq(momos.hire_cost(), 30, "the first hire is $30")
	assert_eq(sim.execute({"type": "momo.hire"})["reason"], "err.not_enough_money", "$10 cannot hire")
	economy.earn(200, "test")
	var r := sim.execute({"type": "momo.hire"})
	assert_true(r["ok"], "hired")
	assert_eq(economy.money, 210 - 30, "paid $30")
	assert_true(r["next_cost"] > 30, "the next one costs more ($%d)" % r["next_cost"])
	assert_true(_on_land(momos.position_of(int(r["id"]))), "the new Momo is on the island")
	assert_eq(momos.ids().size(), 2, "two Momo")


func test_assign_respects_worker_spots() -> void:
	economy.earn(200, "test")
	sim.execute({"type": "momo.hire"})
	var farm := buildings.place_instant("farm", Vector2i(1, 1))
	assert_true(sim.execute({"type": "momo.assign", "momo": 1, "building": farm})["ok"], "the farm takes one worker")
	assert_eq(momos.workers_at(farm), [1] as Array[int], "Momo 1 works there")
	assert_eq(sim.execute({"type": "momo.assign", "momo": 2, "building": farm})["reason"], "err.slots_full", "but only one")
	sim.advance_ms(10000)
	assert_true(momos.position_of(1).distance_to(momos.work_spot(farm)) < 0.001, "walked to the farm and stands there")
	sim.advance_ms(60000)
	assert_true(momos.position_of(1).distance_to(momos.work_spot(farm)) < 0.001, "and stays: no wandering while assigned")


func test_release_and_put_down() -> void:
	var farm := buildings.place_instant("farm", Vector2i(1, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	assert_true(sim.execute({"type": "momo.unassign", "momo": 1})["ok"], "released")
	assert_eq(momos.get_momo(1)["assigned"], 0, "free again")
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	assert_true(sim.execute({"type": "momo.move", "momo": 1, "pos": [0.3, 0.3]})["ok"], "put down on land")
	assert_eq(momos.get_momo(1)["assigned"], 0, "dropping off the building releases it")
	assert_eq(momos.position_of(1), Vector2(0.3, 0.3), "where it was put")
	assert_eq(sim.execute({"type": "momo.move", "momo": 1, "pos": [5.0, 5.0]})["reason"], "err.not_owned", "not into the sea")


func test_a_cancelled_building_lets_its_worker_go() -> void:
	economy.earn(100, "test")
	var id: int = sim.execute({"type": "building.place", "building": "farm", "anchor": [0, 0]})["id"]
	sim.execute({"type": "momo.assign", "momo": 1, "building": id})
	sim.execute({"type": "building.cancel", "id": id})
	assert_eq(momos.get_momo(1)["assigned"], 0, "released when the building went")
