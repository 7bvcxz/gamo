extends "res://tests/framework/test_case.gd"

## The manager: a Momo at an office moves stuck or switched-off workers to
## where there is work, by priority, a few per review, never the player's
## pinned Momo or itself, never instantly -- and leaves free Momo to play
## unless a high-priority spot needs them.

var sim: Simulation
var momos: MomoSystem
var bs: BuildingSystem
var manager: ManagerSystem
var office := 0


func before_each() -> void:
	sim = Simulation.new_game()
	momos = sim.system(&"momo")
	bs = sim.system(&"buildings")
	manager = sim.system(&"manager")
	(sim.system(&"economy") as EconomySystem).earn(2000, "test")
	for i in 3:
		sim.execute({"type": "momo.hire"})
	office = bs.place_instant("office", Vector2i(0, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": office})


func _stuck_smelter_worker(momo: int) -> int:
	var sm := bs.place_instant("smelter", Vector2i(1, 1))
	sim.execute({"type": "momo.assign", "momo": momo, "building": sm})
	sim.execute({"type": "momo.pin", "momo": momo, "pinned": false})
	return sm


func test_no_office_no_management() -> void:
	sim = Simulation.new_game()
	var m: ManagerSystem = sim.system(&"manager")
	assert_eq(m.manager(), 0, "nobody manages")
	sim.advance_ms(200000)
	assert_eq(m.moves_made, 0, "nothing moved")


func test_a_stuck_worker_goes_where_the_work_is() -> void:
	var sm := _stuck_smelter_worker(2)
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	sim.advance_ms(30000)
	assert_eq(int(momos.get_momo(2)["assigned"]), sm, "not yet: stuck only a short while")
	sim.advance_ms(60000)
	assert_eq(int(momos.get_momo(2)["assigned"]), farm, "stuck 40 s without ore: moved to the farm")
	assert_eq((momos.get_momo(2)["history"] as Array).back()["by"], "manager", "by the manager")
	assert_false(momos.get_momo(2)["pinned"], "and it stays the manager's to move")


func test_moves_are_walks_not_jumps() -> void:
	_stuck_smelter_worker(2)
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var arrived := [-1]
	var moved := [-1]
	var clock := sim.clock
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"manager_moved":
			moved[0] = clock.now_ms
		elif t == &"momo_arrived" and int(p["id"]) == 2 and int(p["building"]) == farm:
			arrived[0] = clock.now_ms)
	sim.advance_ms(120000)
	assert_true(moved[0] > 0 and arrived[0] > moved[0], "it arrives after it was sent (%d -> %d)" % [moved[0], arrived[0]])


func test_the_players_momo_stays() -> void:
	var sm := bs.place_instant("smelter", Vector2i(1, 1))
	sim.execute({"type": "momo.assign", "momo": 2, "building": sm})
	bs.place_instant("farm", Vector2i(1, 0))
	sim.advance_ms(200000)
	assert_eq(int(momos.get_momo(2)["assigned"]), sm, "pinned by the player: never moved")


func test_off_sends_workers_elsewhere() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var farm2 := bs.place_instant("farm", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 2, "building": farm})
	sim.execute({"type": "momo.pin", "momo": 2, "pinned": false})
	sim.execute({"type": "building.priority", "id": farm, "priority": "off"})
	sim.advance_ms(25000)
	assert_eq(int(momos.get_momo(2)["assigned"]), farm2, "an 'off' farm loses its worker at the next review")


func test_free_momo_play_unless_a_high_spot_needs_them() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	sim.advance_ms(60000)
	assert_eq(int(momos.get_momo(3)["assigned"]), 0, "a normal spot does not pull a playing Momo")
	sim.execute({"type": "building.priority", "id": farm, "priority": "high"})
	sim.advance_ms(25000)
	assert_eq(momos.workers_at(farm).size(), 1, "a high-priority spot does")


func test_priority_order_and_the_move_limit() -> void:
	var a := bs.place_instant("farm", Vector2i(1, 0))
	var b := bs.place_instant("farm", Vector2i(0, 1))
	var c := bs.place_instant("farm", Vector2i(1, 1))
	sim.execute({"type": "building.priority", "id": c, "priority": "high"})
	sim.execute({"type": "building.priority", "id": a, "priority": "low"})
	assert_eq(manager.openings(), [c, b, a] as Array[int], "high, then normal, then low (then by id)")
	for x: int in [a, b, c]:
		sim.execute({"type": "building.priority", "id": x, "priority": "high"})
	var moves := manager.review()
	assert_eq(moves.size(), 2, "at most two moves a review")
	assert_true(momos.workers_at(a).size() + momos.workers_at(b).size() + momos.workers_at(c).size() == 2, "two spots filled")


func test_capacity_and_the_manager_itself() -> void:
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "building.priority", "id": farm, "priority": "high"})
	sim.advance_ms(120000)
	assert_eq(momos.workers_at(farm).size(), 1, "never more than the farm's one spot")
	assert_eq(int(momos.get_momo(1)["assigned"]), office, "the manager stays at the office")


func test_same_moves_whatever_the_step() -> void:
	var out: Array = []
	for chunk: int in [16, 1000, 7777]:
		var s := Simulation.new_game()
		var b2: BuildingSystem = s.system(&"buildings")
		(s.system(&"economy") as EconomySystem).earn(2000, "test")
		for i in 3:
			s.execute({"type": "momo.hire"})
		var off := b2.place_instant("office", Vector2i(0, 0))
		s.execute({"type": "momo.assign", "momo": 1, "building": off})
		var sm := b2.place_instant("smelter", Vector2i(1, 1))
		s.execute({"type": "momo.assign", "momo": 2, "building": sm})
		s.execute({"type": "momo.pin", "momo": 2, "pinned": false})
		var f := b2.place_instant("farm", Vector2i(1, 0))
		s.execute({"type": "building.priority", "id": f, "priority": "high"})
		var t := 0
		var total := 30000 * 10
		while t < total:
			var step := mini(chunk, total - t)
			s.advance_ms(step)
			t += step
		var m: MomoSystem = s.system(&"momo")
		out.append([JSON.stringify(m.save_state()["momos"]), (s.system(&"manager") as ManagerSystem).moves_made])
	assert_eq(out[1], out[0], "1 s steps")
	assert_eq(out[2], out[0], "7.8 s steps")


func test_a_review_is_cheap() -> void:
	sim = Simulation.new_game()
	var b2: BuildingSystem = sim.system(&"buildings")
	var world: WorldSystem = sim.system(&"world")
	for x in 10:
		for y in 6:
			world.add_land(Vector2i(x, y))
	(sim.system(&"economy") as EconomySystem).earn(100000, "test")
	for i in 30:
		sim.execute({"type": "momo.hire"})
	var off := b2.place_instant("office", Vector2i(9, 5))
	sim.execute({"type": "momo.assign", "momo": 1, "building": off})
	for x in 9:
		for y in 6:
			var id := b2.place_instant("farm" if (x + y) % 2 == 0 else "smelter", Vector2i(x, y))
			sim.execute({"type": "building.priority", "id": id, "priority": "high"})
	sim.advance_ms(5000)
	var m: ManagerSystem = sim.system(&"manager")
	var t0 := Time.get_ticks_usec()
	for i in 10:
		m.review()
	var per := (Time.get_ticks_usec() - t0) / 10.0 / 1000.0
	assert_true(per < 30.0, "54 buildings, 31 Momo: a review takes %.2f ms" % per)


func test_manager_state_survives_a_save() -> void:
	_stuck_smelter_worker(2)
	sim.advance_ms(30000)
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_eq((copy.system(&"manager") as ManagerSystem).stuck_since, manager.stuck_since, "how long things have been stuck")
	var state := sim.save_state()
	(state["systems"] as Dictionary).erase("manager")
	state["scheduler"]["events"] = (state["scheduler"]["events"] as Array).filter(func(e: Dictionary) -> bool: return e["type"] != ManagerSystem.REVIEW)
	var old := Simulation.from_save(JSON.parse_string(JSON.stringify(state)))
	assert_false(old.scheduler.events_of(ManagerSystem.REVIEW).is_empty(), "an old save gets its reviews scheduled")
