extends SceneTree

## Copper into wire, and the choice that makes the manufacturer a machine.
##
## Iron gave the game its first production chain. This gives it the first
## *decision*: the same box, two things it could be making, and the player says
## which. Everything worth testing here is about that word "which" -- that the
## machine holds its own answer, that changing it neither loses nor makes
## material, that the two lines cannot be fed each other's ore, and that the
## answer survives being put down.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_the_item()
	_test_the_recipe()
	_test_the_machine_offers_both()
	await _test_choosing()
	await _test_changing_loses_nothing()
	await _test_the_lines_do_not_mix()
	await _test_a_second_machine_inherits()
	await _test_the_choice_survives_a_save()
	await _test_the_copper_line()
	if failures == 0:
		print("PASS test_wire")
	else:
		print("FAIL test_wire (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- The material -------------------------------------------------------------

func _test_the_item() -> void:
	_assert(Defs.item_kind(Defs.ITEM_COPPER_WIRE) == Defs.KIND_INTERMEDIATE, "전선은 intermediate 다")
	_assert(Defs.item_by_key("copper_wire") == Defs.item(Defs.ITEM_COPPER_WIRE), "key 로도 찾힌다")
	_assert(Defs.item_atlas(Defs.ITEM_COPPER_WIRE) == "", "광맥이 아니라 시트가 없다")
	_assert(not Defs.ORE_TIERS.has(Defs.ITEM_COPPER_WIRE), "잔해가 전선을 주지 않는다")
	_assert(Defs.COUNTED_ITEMS.has(Defs.ITEM_COPPER_WIRE), "자원 패널에 나온다")
	_assert(Defs.item_color(Defs.ITEM_COPPER_WIRE) != Defs.item_color(Defs.ITEM_COPPER),
		"구리광석과 다른 색이다 — 한 벨트에 둘 다 실린다")
	_assert(Defs.item_color(Defs.ITEM_COPPER_WIRE) != Defs.item_color(Defs.ITEM_IRON_PLATE),
		"철판과도 다르다")

# --- The recipe ---------------------------------------------------------------

func _test_the_recipe() -> void:
	var recipe: Dictionary = Defs.recipe_by_key("copper_wire")
	_assert(not recipe.is_empty(), "전선 레시피가 있다")
	_assert(int(recipe["machine"]) == Defs.M_MANUFACTURER, "제조기의 것이다")
	_assert(Defs.recipes_producing_item(Defs.ITEM_COPPER_WIRE) == [recipe], "전선을 만드는 유일한 것")
	# One in, two out -- the first recipe in the game that is not one-for-one.
	_assert(int((recipe["inputs"] as Array)[0]["amount"]) == 1, "구리 한 개를 먹고")
	_assert(int((recipe["outputs"] as Array)[0]["amount"]) == 2, "전선 두 개를 낸다")
	_assert(Defs.recipe_errors().is_empty(), "표에 잘못이 없다")
	_assert(Defs.recipe_dependency_errors().is_empty(),
		"의존성 매듭이 없다 (%s)" % str(Defs.recipe_dependency_errors()))
	# Bootstrap, still. Wire may not become something the first manufacturer needs.
	var cost: Dictionary = Defs.MACHINE_COSTS[Defs.M_MANUFACTURER]
	_assert(not cost.has(Defs.ITEM_COPPER_WIRE), "제조기 건설 비용에 전선이 없다")
	_assert(not cost.has(Defs.ITEM_IRON_PLATE), "철판도 없다")

func _test_the_machine_offers_both() -> void:
	var rows: Array[Dictionary] = Defs.recipes_for_machine(Defs.M_MANUFACTURER)
	_assert(rows.size() == 2, "제조기가 고를 수 있는 것은 둘이다 (%d)" % rows.size())
	var keys: Array[String] = []
	for row: Dictionary in rows:
		keys.append(String(row["key"]))
	_assert(keys.has("iron_plate") and keys.has("copper_wire"), "철판과 전선 (%s)" % str(keys))

# --- Choosing -----------------------------------------------------------------

func _test_choosing() -> void:
	var main := await _run_with_a_machine()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)

	# A new machine with nobody having chosen anything runs the type's first row.
	_assert(String(sim.recipe_of(machine)["key"]) == "iron_plate",
		"처음 세운 제조기는 철판부터다")
	_assert(sim.set_recipe(machine, "copper_wire"), "전선으로 바꾼다")
	_assert(String(sim.recipe_of(machine)["key"]) == "copper_wire", "그리고 바뀐다")
	_assert(not sim.set_recipe(machine, "copper_wire"), "같은 것을 다시 고르면 아무 일도 없다")
	_assert(not sim.set_recipe(machine, "nothing_by_this_name"), "없는 레시피는 거절한다")
	# A recipe belonging to a different machine is not this machine's to run.
	_assert(not sim.set_recipe(machine, ""), "빈 이름도 거절한다")
	main.free()

# --- The policy ---------------------------------------------------------------

## Inputs are eaten at the end of a cycle, so a change mid-craft has nothing to
## refund -- resetting the clock loses nothing. What the buffer holds is the real
## question: iron sitting in a machine that now wants copper would be stranded,
## because the input face only takes what the recipe asks for. It goes back out
## the front, through the exit the output already uses.
func _test_changing_loses_nothing() -> void:
	var main := await _run_with_a_machine()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	var ahead: Vector2i = _PLANT + Vector2i.RIGHT

	machine.buffer[Defs.ITEM_IRON] = 2
	sim.tick(1.0)
	_assert(machine.progress > 0.5, "철판을 만들다 말고 (%.2f)" % machine.progress)
	_assert(int(machine.buffer.get(Defs.ITEM_IRON, 0)) == 2, "재료는 아직 그대로다")

	var floor_before: int = sim.ground_count(ahead)
	_assert(sim.set_recipe(machine, "copper_wire"), "전선으로 바꾼다")
	_assert(is_zero_approx(machine.progress), "진행은 0 으로 돌아간다")
	_assert(not machine.buffer.has(Defs.ITEM_IRON), "쓰지 못할 철은 안에 남지 않는다")
	# Two iron went in and two iron came back: out the front, or still owed.
	var returned: int = sim.ground_count(ahead) - floor_before \
		+ int(machine.outbox.get(Defs.ITEM_IRON, 0))
	_assert(returned == 2, "넣었던 철 두 개가 그대로 돌아온다 (%d)" % returned)
	_assert(sim.ground.get(ahead, -1) == Defs.ITEM_IRON or returned == 2, "앞칸으로 나온다")
	main.free()

# --- The two lines --------------------------------------------------------------

func _test_the_lines_do_not_mix() -> void:
	var main := await _run_with_a_machine()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	var side: Vector2i = _PLANT + Vector2i.LEFT

	# On plates: copper is not something this machine wants.
	_assert(sim._accept_into(_PLANT, Defs.ITEM_IRON, side), "철판 설정에서 철을 받고")
	_assert(not sim._accept_into(_PLANT, Defs.ITEM_COPPER, side), "구리는 받지 않는다")

	sim.set_recipe(machine, "copper_wire")
	machine.buffer.clear()
	machine.outbox.clear()
	_assert(sim._accept_into(_PLANT, Defs.ITEM_COPPER, side), "전선 설정에서 구리를 받고")
	_assert(not sim._accept_into(_PLANT, Defs.ITEM_IRON, side), "철은 받지 않는다")

	# And it makes what it was told to, not what it was fed first.
	machine.buffer[Defs.ITEM_COPPER] = 1
	var recipe: Dictionary = sim.recipe_of(machine)
	for step in int(float(recipe["seconds"]) / 0.1) + 6:
		sim.tick(0.1)
	# Counted by kind, not by pile height. The cell in front is still holding the
	# iron the recipe change handed back, and `ground_count` does not say what a
	# tile is holding -- only how much of it. Counting the pile made one copper
	# look like three wires.
	var made: int = int(sim.stock.get(Defs.ITEM_COPPER_WIRE, 0)) \
		+ int(machine.outbox.get(Defs.ITEM_COPPER_WIRE, 0)) \
		+ _on_floor(sim, _PLANT + Vector2i.RIGHT, Defs.ITEM_COPPER_WIRE)
	_assert(made == 2, "구리 하나가 전선 둘이 된다 (%d)" % made)
	_assert(not machine.buffer.has(Defs.ITEM_COPPER), "그리고 구리를 먹었다")
	_assert(sim.ground.get(_PLANT + Vector2i.RIGHT, -1) != Defs.ITEM_IRON_PLATE,
		"철판은 한 개도 나오지 않았다")
	main.free()

# --- The second machine ---------------------------------------------------------

## A player who has just decided this base makes wire did not decide it once.
func _test_a_second_machine_inherits() -> void:
	var main := await _run_with_a_machine()
	var sim = main.sim
	sim.set_recipe(sim.machine_at(_PLANT), "copper_wire")
	var second: Vector2i = _clear(sim, Vector2i(9, 3))
	_assert(sim.build(Defs.M_MANUFACTURER, second, Vector2i.RIGHT), "두 번째 제조기를 세운다")
	_assert(String(sim.recipe_of(sim.machine_at(second))["key"]) == "copper_wire",
		"마지막에 고른 것을 물려받는다 — 철판 전용 기계로 읽히지 않는다")
	main.free()

# --- Saves ----------------------------------------------------------------------

func _test_the_choice_survives_a_save() -> void:
	var main := await _run_with_a_machine()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	sim.set_recipe(machine, "copper_wire")
	machine.buffer[Defs.ITEM_COPPER] = 1
	sim.tick(1.0)
	var mid: float = machine.progress
	_assert(mid > 0.5, "생산 중에 저장한다 (%.2f)" % mid)

	var fresh := Sim.new()
	fresh.setup(4242)
	fresh.from_save(sim.to_save())
	var back = fresh.machine_at(_PLANT)
	_assert(back != null, "제조기가 돌아온다")
	if back != null:
		_assert(String(fresh.recipe_of(back)["key"]) == "copper_wire", "고른 레시피 그대로")
		_assert(is_equal_approx(back.progress, mid), "진행도까지 (%.2f)" % back.progress)
		_assert(int(back.buffer.get(Defs.ITEM_COPPER, 0)) == 1, "넣어 둔 구리도")
	# And a machine built after loading still inherits the choice.
	var later: Vector2i = _clear(fresh, Vector2i(11, 3))
	fresh.stock[Defs.ITEM_IRON] = 500
	fresh.stock[Defs.ITEM_COPPER] = 500
	fresh.stock[Defs.ITEM_HEATSTONE] = 500
	fresh.note_resource_seen(Defs.ITEM_IRON)
	if fresh.build(Defs.M_MANUFACTURER, later, Vector2i.RIGHT):
		_assert(String(fresh.recipe_of(fresh.machine_at(later))["key"]) == "copper_wire",
			"불러온 뒤에 세운 것도 물려받는다")
	fresh.free()
	main.free()

# --- The copper line ------------------------------------------------------------

## Ore, belt, machine, belt. The same pieces the iron line uses, which is the
## point: no recipe gets code of its own.
func _test_the_copper_line() -> void:
	var main := await _run_with_a_machine()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	sim.set_recipe(machine, "copper_wire")

	var feeder: Vector2i = _clear(sim, Vector2i(4, 3))
	var out_belt: Vector2i = _clear(sim, Vector2i(6, 3))
	_assert(sim.build(Defs.M_BELT, feeder, Vector2i.RIGHT), "입구에 벨트")
	_assert(sim.build(Defs.M_BELT, out_belt, Vector2i.RIGHT), "출구에 벨트")
	sim.machine_at(feeder).items.append({"type": Defs.ITEM_COPPER, "t": 0.95})

	for step in 120:
		sim.tick(0.1)
	var wire_out := false
	for item: Dictionary in sim.machine_at(out_belt).items:
		if int(item["type"]) == Defs.ITEM_COPPER_WIRE:
			wire_out = true
	_assert(wire_out or sim.ground_count(out_belt + Vector2i.RIGHT) > 0
			or int(machine.outbox.get(Defs.ITEM_COPPER_WIRE, 0)) > 0,
		"벨트가 실어 온 구리가 전선이 되어 벨트로 나간다")
	main.free()

# --- Helpers --------------------------------------------------------------------

const _PLANT := Vector2i(5, 3)

func _run_with_a_machine() -> Node2D:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	var sim = main.sim
	if not sim.base_placed:
		sim.carried_kit = Defs.KIT_BASE
		sim.place_base(sim.core_cell)
	sim.stones_in = maxi(sim.stones_in, int(Defs.BASE_LEVELS[-1]["stones"]))
	sim._refresh_radius()
	for item_id: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON,
			Defs.ITEM_ENERGY_CORE]:
		sim.note_resource_seen(item_id)
		sim.stock[item_id] = 500
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	sim.power_ever = true
	sim._check_unlocks()
	sim.unlocked[Defs.M_MINER] = true
	if sim.core_cell != Vector2i.ZERO:
		push_error("이 파일은 기지가 원점에 있다고 가정한다")
	var plant: Vector2i = _clear(sim, _PLANT)
	_clear(sim, plant + Vector2i.RIGHT)
	_clear(sim, plant + Vector2i.LEFT)
	sim.build(Defs.M_MANUFACTURER, plant, Vector2i.RIGHT)
	# Power, or nothing turns and every timing below measures the grid instead.
	var plantside: Vector2i = _clear(sim, Vector2i(-5, 3))
	sim.build(Defs.M_GENERATOR, plantside, Vector2i.RIGHT)
	sim.machine_at(plantside).buffer[Defs.GENERATOR_FUEL] = 40
	return main

## Absolute cells, not offsets: the base goes down on `core_cell`, which starts
## at the origin and stays there in these tests, so the two are the same number
## and writing it twice is how they stop being.
func _clear(sim, cell: Vector2i) -> Vector2i:
	sim.ore.erase(cell)
	sim.machines.erase(cell)
	sim.ground.erase(cell)
	sim.ground_stack.erase(cell)
	sim.frozen_cats.erase(cell)
	sim.debris.erase(cell)
	return cell

## How many of one kind are lying on a cell. `ground_count` answers "how many",
## and a tile that is holding something else answers it just as happily.
func _on_floor(sim, cell: Vector2i, item_type: int) -> int:
	return sim.ground_count(cell) if int(sim.ground.get(cell, -1)) == item_type else 0
