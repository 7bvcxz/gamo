extends SceneTree

## Iron, the manufacturer, and the first material this planet does not contain.
##
## Everything before this was dug, picked up, or fell out of the ship. A plate is
## the first thing that exists because a machine made it, and the chain that
## makes it -- seam, pickaxe, machine, power, plate -- is the smallest complete
## statement of what Motorio is going to be. So this file walks it end to end
## rather than only checking the pieces.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_items()
	_test_iron_is_out_there_and_not_underfoot()
	_test_bootstrap()
	_test_recipe()
	_test_unlocks_on_first_iron()
	await _test_power()
	await _test_the_whole_chain()
	await _test_blocked_costs_nothing()
	await _test_survives_a_save()
	if failures == 0:
		print("PASS test_iron")
	else:
		print("FAIL test_iron (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- The two materials --------------------------------------------------------

func _test_items() -> void:
	_assert(Defs.item_kind(Defs.ITEM_IRON) == Defs.KIND_RAW, "철광석은 raw 다")
	_assert(Defs.item_by_key("iron") == Defs.item(Defs.ITEM_IRON), "key 로도 찾힌다")
	_assert(Defs.item_atlas(Defs.ITEM_IRON) == "iron_6.png", "철은 시트를 갖는다")
	_assert(Defs.ORE_TIERS == [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON],
		"광맥 사다리 끝에 붙는다 (%s)" % str(Defs.ORE_TIERS))

	# The first intermediate. Nothing else in the game has this kind, and the day
	# a second one does is the day the tech tree has started.
	_assert(Defs.item_kind(Defs.ITEM_IRON_PLATE) == Defs.KIND_INTERMEDIATE, "철판은 intermediate 다")
	_assert(Defs.items_of_kind(Defs.KIND_INTERMEDIATE).has(Defs.ITEM_IRON_PLATE),
		"철판이 중간재 목록에 있다")
	_assert(Defs.item_atlas(Defs.ITEM_IRON_PLATE) == "", "철판은 광맥이 아니라 시트가 없다")
	_assert(not Defs.ORE_TIERS.has(Defs.ITEM_IRON_PLATE), "그리고 잔해가 철판을 주지 않는다")
	_assert(Defs.COUNTED_ITEMS.has(Defs.ITEM_IRON) and Defs.COUNTED_ITEMS.has(Defs.ITEM_IRON_PLATE),
		"둘 다 자원 패널에 나온다")

# --- Where it is --------------------------------------------------------------

## Iron must not be underfoot at the start and must be reachable by the rung the
## design puts it on, on every seed. A pinned patch is the only way the second
## half of that is a promise rather than a probability.
func _test_iron_is_out_there_and_not_underfoot() -> void:
	var reach: float = float(Defs.BASE_LEVELS[7]["radius"])
	var opening: float = float(Defs.BASE_LEVELS[0]["radius"])
	var copper_rung: float = float(Defs.BASE_LEVELS[4]["radius"])
	var seeds := 200
	var missing := 0
	var too_close := 0
	var nearest_sum := 0.0
	for seed_value in seeds:
		var sim := Sim.new()
		sim.setup(seed_value * 977 + 13)
		var nearest: float = 9999.0
		for cell: Vector2i in sim.ore:
			if int(sim.ore[cell]) != Defs.ITEM_IRON:
				continue
			nearest = minf(nearest, Vector2(cell - sim.core_cell).length())
		if nearest > reach:
			missing += 1
		if nearest <= copper_rung:
			too_close += 1
		nearest_sum += nearest
		sim.free()
	_assert(missing == 0,
		"200시드 모두 표시 Lv8(%.0f칸) 안에 철이 있다 (%d회 실패)" % [reach, missing])
	_assert(too_close == 0,
		"그리고 구리 단계(%.0f칸) 안에는 없다 (%d회)" % [copper_rung, too_close])
	print("       가장 가까운 철 평균 %.1f칸 · 시작 반경 %.0f칸" % [nearest_sum / float(seeds), opening])

	# And it is a seam like any other: minable by hand, slower than the ores
	# before it, drawn from the sheet that was already cut for it.
	var sim := Sim.new()
	sim.setup(4242)
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) == Defs.ITEM_IRON:
			seam = cell
	_assert(seam != Vector2i(9999, 9999), "시드 4242 에도 철 광맥이 있다")
	_assert(sim.mine_period(Defs.ITEM_IRON) > sim.mine_period(Defs.ITEM_COPPER),
		"채굴기가 구리보다 철에서 느리다 (%.0f vs %.0f)"
		% [sim.mine_period(Defs.ITEM_IRON), sim.mine_period(Defs.ITEM_COPPER)])
	sim.free()

# --- The machine that makes the thing it is not made of ------------------------

## The rule the whole ladder rests on. A manufacturer that cost plates would be a
## machine nobody could ever build, and nothing in the game would say so.
func _test_bootstrap() -> void:
	var cost: Dictionary = Defs.MACHINE_COSTS[Defs.M_MANUFACTURER]
	_assert(not cost.has(Defs.ITEM_IRON_PLATE), "제조기 건설 비용에 철판이 없다")
	for item_id: int in cost:
		_assert(Defs.recipes_producing_item(item_id).is_empty(),
			"%s 는 기계 없이 손에 넣을 수 있다" % Defs.item_name(item_id))
	_assert(Defs.recipe_dependency_errors().is_empty(),
		"의존성 매듭이 없다 (%s)" % str(Defs.recipe_dependency_errors()))
	_assert(Defs.machine_errors().is_empty(), "기계 표에 잘못이 없다")
	_assert(Defs.recipe_errors().is_empty(), "레시피 표에 잘못이 없다")
	_assert(Defs.machine_uses_recipes(Defs.M_MANUFACTURER), "제조기는 레시피로 돈다")
	_assert(Defs.RECIPE_MACHINES.has(Defs.M_MANUFACTURER), "레시피를 도는 기계에 제조기가 있다")

# --- The recipe ---------------------------------------------------------------

func _test_recipe() -> void:
	var recipe: Dictionary = Defs.recipe_by_key("iron_plate")
	_assert(not recipe.is_empty(), "철판 레시피가 있다")
	_assert(int(recipe["machine"]) == Defs.M_MANUFACTURER, "제조기의 것이다")
	_assert(Defs.recipe_for_machine(Defs.M_MANUFACTURER) == recipe,
		"제조기를 놓으면 이것이 고른 레시피가 된다")
	_assert(Defs.recipes_using_item(Defs.ITEM_IRON) == [recipe], "철을 쓰는 레시피는 이것뿐")
	_assert(Defs.recipes_for_machine(Defs.M_MANUFACTURER).size() >= 2,
		"제조기는 고를 것이 둘 이상이다")
	_assert(Defs.recipes_producing_item(Defs.ITEM_IRON_PLATE) == [recipe], "철판을 만드는 것도")
	_assert(float(recipe["seconds"]) > 0.0 and float(recipe["seconds"]) <= 5.0,
		"생산 시간이 눈에 보이는 범위다 (%.1f초)" % float(recipe["seconds"]))
	_assert(Defs.recipe_dump(recipe).contains("철광석 x1")
		and Defs.recipe_dump(recipe).contains("철판 x1"), "덤프가 읽힌다")

# --- Finding iron opens the machine -------------------------------------------

func _test_unlocks_on_first_iron() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_assert(not sim.is_unlocked(Defs.M_MANUFACTURER), "철을 보기 전에는 제조기가 없다")
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.power_ever = true
	sim._check_unlocks()
	_assert(not sim.is_unlocked(Defs.M_MANUFACTURER), "열석과 구리로도 열리지 않는다")
	_assert(sim.note_resource_seen(Defs.ITEM_IRON).has(Defs.M_MANUFACTURER),
		"첫 철이 제조기를 연다")
	_assert(sim.is_unlocked(Defs.M_MANUFACTURER), "그리고 열린 채로 있다")
	sim.free()

# --- Power --------------------------------------------------------------------

## The manufacturer is the first machine that cannot run on a cat. No grid is a
## stop, half a grid is half speed, and neither loses anything.
func _test_power() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	var sim = main.sim
	_open(sim)

	var plant: Vector2i = _clear_cell(sim, Vector2i(6, -6))
	_assert(sim.build(Defs.M_MANUFACTURER, plant, Vector2i.RIGHT), "제조기를 세운다")
	var machine: Sim.Machine = sim.machine_at(plant)
	machine.buffer[Defs.ITEM_IRON] = 2

	# No generator anywhere: the grid has no capacity at all.
	sim.tick(1.0)
	_assert(is_zero_approx(machine.progress), "전력이 없으면 진행하지 않는다 (%.2f)" % machine.progress)
	_assert(int(machine.buffer.get(Defs.ITEM_IRON, 0)) == 2, "재료도 그대로다")
	_assert(sim.meter_status(machine) == "전력 없음",
		"그리고 그렇게 말한다 (%s)" % sim.meter_status(machine))
	_assert(sim.power_draw > 0.0, "일감이 있으므로 전력을 요구한다 (%.1f)" % sim.power_draw)

	# One generator, one manufacturer: full speed.
	sim.stock[Defs.ITEM_ENERGY_CORE] = 10
	var plantside: Vector2i = _clear_cell(sim, Vector2i(-6, -6))
	_assert(sim.build(Defs.M_GENERATOR, plantside, Vector2i.RIGHT), "발전기를 세운다")
	sim.machine_at(plantside).buffer[Defs.GENERATOR_FUEL] = 4
	machine.progress = 0.0
	sim.tick(1.0)
	_assert(machine.progress > 0.9 and machine.progress < 1.1,
		"전력이 차면 제 속도로 돈다 (%.2f)" % machine.progress)

	# A second manufacturer doubles the draw against one generator, so both run
	# at half. Proportional, not first-come.
	var second: Vector2i = _clear_cell(sim, Vector2i(6, -8))
	_assert(sim.build(Defs.M_MANUFACTURER, second, Vector2i.RIGHT), "제조기를 하나 더 세운다")
	sim.machine_at(second).buffer[Defs.ITEM_IRON] = 2
	machine.progress = 0.0
	sim.machine_at(second).progress = 0.0
	sim.tick(1.0)
	_assert(machine.progress > 0.4 and machine.progress < 0.6,
		"발전기 하나에 제조기 둘이면 절반 속도다 (%.2f)" % machine.progress)
	_assert(int(machine.buffer.get(Defs.ITEM_IRON, 0)) == 2, "느려져도 재료를 먹지 않는다")

	main.clear_save()
	main.free()

# --- Seam to plate ------------------------------------------------------------

## The chain, walked. A cell of iron in the ground, a pickaxe, a machine, a
## generator, and a plate on the floor at the other end.
func _test_the_whole_chain() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	var sim = main.sim

	# Dig it by hand, which is how the first one always arrives.
	var seam: Vector2i = _clear_cell(sim, Vector2i(3, 0))
	sim.ore[seam] = Defs.ITEM_IRON
	sim._assign_purity()
	var got: int = sim.hand_mine(seam, sim.hand_period(seam) * 1.1)
	_assert(got == Defs.ITEM_IRON, "곡괭이로 철이 나온다 (%s)" % str(got))
	# `hand_mine` hands back what came out of the ground; putting it in the pack
	# is the caller's job, and that is where the unlock question is asked.
	sim._gain(got, 1)
	_assert(sim.is_unlocked(Defs.M_MANUFACTURER), "가방에 들어간 그 순간 제조기가 열린다")

	_open(sim)
	var plant: Vector2i = _clear_cell(sim, Vector2i(0, 6))
	_assert(sim.is_warm(plant), "제조기 자리가 온기 안이다")
	var ahead: Vector2i = _clear_cell(sim, plant + Vector2i.RIGHT)
	_assert(sim.build(Defs.M_MANUFACTURER, plant, Vector2i.RIGHT), "제조기를 세운다")
	var plantside: Vector2i = _clear_cell(sim, Vector2i(-3, 6))
	sim.build(Defs.M_GENERATOR, plantside, Vector2i.RIGHT)
	sim.machine_at(plantside).buffer[Defs.GENERATOR_FUEL] = 4

	# Fed by hand first: a player standing at the machine with ore in her pack.
	var machine: Sim.Machine = sim.machine_at(plant)
	_assert(sim._accept_into(plant, Defs.ITEM_IRON, plant + Vector2i.LEFT),
		"철을 넣을 수 있다")
	_assert(not sim._accept_into(plant, Defs.ITEM_COPPER, plant + Vector2i.LEFT),
		"레시피가 부르지 않는 것은 받지 않는다")
	var recipe: Dictionary = Defs.recipe_for_machine(Defs.M_MANUFACTURER)
	for step in int(float(recipe["seconds"]) / 0.1) + 4:
		sim.tick(0.1)
	_assert(not machine.buffer.has(Defs.ITEM_IRON), "철을 먹었다")
	_assert(sim.ground.get(ahead, -1) == Defs.ITEM_IRON_PLATE,
		"앞칸에 철판이 놓였다 (%s)" % str(sim.ground.get(ahead, -1)))

	# And onto a belt, which is the arrangement the factory actually wants.
	sim.collect_ground_at(ahead)
	var belt: Vector2i = ahead
	sim.stock[Defs.ITEM_COPPER] = 500
	_assert(sim.build(Defs.M_BELT, belt, Vector2i.RIGHT), "출구에 벨트를 깐다")
	sim._accept_into(plant, Defs.ITEM_IRON, plant + Vector2i.LEFT)
	for step in int(float(recipe["seconds"]) / 0.1) + 6:
		sim.tick(0.1)
	var on_belt := false
	for item: Dictionary in sim.machine_at(belt).items:
		if int(item["type"]) == Defs.ITEM_IRON_PLATE:
			on_belt = true
	_assert(on_belt or sim.ground.get(belt + Vector2i.RIGHT, -1) == Defs.ITEM_IRON_PLATE,
		"철판이 벨트로 나간다")

	# A belt feeding it works the same way round: the machine takes from a belt
	# pointed at it, up to the couple of cycles' worth the buffer holds.
	var feeder: Vector2i = _clear_cell(sim, plant + Vector2i.LEFT)
	_assert(sim.build(Defs.M_BELT, feeder, Vector2i.RIGHT), "입구에 벨트를 깐다")
	sim.machine_at(feeder).items.append({"type": Defs.ITEM_IRON, "t": 0.9})
	for step in 40:
		sim.tick(0.1)
	_assert(int(machine.buffer.get(Defs.ITEM_IRON, 0)) > 0
			or sim.ground.has(plant + Vector2i.RIGHT * 2)
			or not machine.outbox.is_empty()
			or int(sim.stock.get(Defs.ITEM_IRON_PLATE, 0)) > 0,
		"벨트가 실어 온 철이 기계로 들어간다")

	main.clear_save()
	main.free()

# --- A stalled machine is not a working one -----------------------------------

## Two things a blocked manufacturer must not do: draw power, and look busy.
##
## Both were wrong when this shipped. The power branch asked whether the inputs
## were ready and not whether there was anywhere to put the result, so a machine
## that had done nothing for an hour was slowing every miner on the grid; and
## `tick_recipe` set `operated` before it looked at the delta, so at zero power
## the drawing layer showed a running machine on a dead grid. Neither is visible
## from the power number, which is what makes them worth a test rather than a
## look.
func _test_blocked_costs_nothing() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	var sim = main.sim
	_open(sim)

	var plant: Vector2i = _clear_cell(sim, Vector2i(7, 0))
	var ahead: Vector2i = _clear_cell(sim, plant + Vector2i.RIGHT)
	_assert(sim.build(Defs.M_MANUFACTURER, plant, Vector2i.RIGHT), "제조기를 세운다")
	var machine: Sim.Machine = sim.machine_at(plant)
	var plantside: Vector2i = _clear_cell(sim, Vector2i(-7, 0))
	sim.build(Defs.M_GENERATOR, plantside, Vector2i.RIGHT)
	sim.machine_at(plantside).buffer[Defs.GENERATOR_FUEL] = 8

	machine.buffer[Defs.ITEM_IRON] = 2
	sim.tick(0.5)
	var working: float = sim.power_draw
	_assert(working > 0.0, "일감이 있는 제조기는 전력을 쓴다 (%.1f)" % working)

	# Shut the exit. A seam in front takes nothing and holds no belt.
	sim.ore[ahead] = Defs.ITEM_HEATSTONE
	for step in 60:
		sim.tick(0.1)
	_assert(machine.stalled, "출력이 막히면 막혔다고 말한다")
	_assert(not machine.outbox.is_empty(), "그리고 만든 것을 들고 있다")
	_assert(is_zero_approx(sim.power_draw),
		"막힌 제조기는 전력을 쓰지 않는다 (%.1f)" % sim.power_draw)

	# And with the grid dead, it is not "running" either.
	sim.ore.erase(ahead)
	sim.tick(0.2)
	sim.machine_at(plantside).buffer.clear()
	machine.buffer[Defs.ITEM_IRON] = 2
	sim.tick(0.2)
	_assert(is_zero_approx(sim.power_capacity), "발전기 연료가 떨어졌다")
	_assert(not machine.operated,
		"전력이 없으면 돌고 있다고 말하지 않는다 — 화면이 그것을 읽는다")

	main.clear_save()
	main.free()

# --- Saves --------------------------------------------------------------------

func _test_survives_a_save() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	var sim = main.sim
	_open(sim)
	var plant: Vector2i = _clear_cell(sim, Vector2i(5, 5))
	_assert(sim.build(Defs.M_MANUFACTURER, plant, Vector2i.UP), "제조기를 세운다")
	var machine: Sim.Machine = sim.machine_at(plant)
	machine.buffer[Defs.ITEM_IRON] = 2
	machine.outbox[Defs.ITEM_IRON_PLATE] = 1
	machine.progress = 1.4

	var fresh := Sim.new()
	fresh.setup(4242)
	fresh.from_save(sim.to_save())
	var back = fresh.machine_at(plant)
	_assert(back != null and back.type == Defs.M_MANUFACTURER, "제조기가 돌아온다")
	if back != null:
		_assert(int(back.buffer.get(Defs.ITEM_IRON, 0)) == 2, "넣어 둔 철도")
		_assert(int(back.outbox.get(Defs.ITEM_IRON_PLATE, 0)) == 1, "만들어 둔 철판도")
		_assert(is_equal_approx(back.progress, 1.4), "진행도까지 (%.2f)" % back.progress)
		_assert(back.dir == Vector2i.UP, "그리고 바라보는 방향도")
	fresh.free()
	main.clear_save()
	main.free()

# --- Helpers ------------------------------------------------------------------

## Warm and stocked. Machines outside the fire's circle run at 0.45, which is a
## real rule and exactly the wrong thing to be measuring through when the
## question is about power.
func _open(sim) -> void:
	# No base means no fire and no circle, whatever the stone count says -- and
	# the base goes down out of the kit, so the kit has to be in her arms. Through
	# the real path rather than by setting the flag: a test that lights the fire
	# some other way is a test that stops noticing when lighting it changes.
	if not sim.base_placed:
		sim.carried_kit = Defs.KIT_BASE
		sim.place_base(sim.core_cell)
	sim.stones_in = maxi(sim.stones_in, int(Defs.BASE_LEVELS[-1]["stones"]))
	sim._refresh_radius()
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.power_ever = true
	sim._check_unlocks()
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	sim.note_resource_seen(Defs.ITEM_IRON)
	sim.unlocked[Defs.M_MINER] = true
	for item_id: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON]:
		sim.stock[item_id] = 500

## A cell with nothing on it, so a build cannot fail for a reason this test is
## not about.
func _clear_cell(sim, offset: Vector2i) -> Vector2i:
	var cell: Vector2i = sim.core_cell + offset
	sim.ore.erase(cell)
	sim.machines.erase(cell)
	sim.ground.erase(cell)
	sim.ground_stack.erase(cell)
	sim.frozen_cats.erase(cell)
	sim.shards.erase(cell)
	sim.debris.erase(cell)
	return cell
