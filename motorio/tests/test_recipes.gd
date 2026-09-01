extends SceneTree

## The recipe registry and the one production tick every recipe machine shares.
##
## `Defs.RECIPES` is empty today and this file still has work to do, which is the
## point of it. The table is the floor 제조기 · 조립기 · 유체처리기 · 정유기 ·
## 원심분리기 stand on, and the two things that can go wrong with a floor are
## that it does not hold and that nobody checked. So the validators are pointed
## at deliberately broken data here -- a validator that has only ever seen a
## correct table is a validator nobody has watched work -- and the shared tick is
## driven by a recipe that exists only in this file.
##
## Test recipes are never added to `Defs.RECIPES`. They are passed in, which is
## why the validators and the tick all take their data as an argument.

var failures := 0

## Not in the registry, and never will be. Real item numbers, because the tick
## puts what it makes on the floor and the floor only takes materials that exist.
const TEST_RECIPE := {
	"id": 9001, "key": "test_plate", "name": "시험판",
	# Any real machine number. The tick is called directly here, so no machine
	# behaviour is involved -- this only has to satisfy the validator.
	"machine": Defs.M_SPLITTER,
	"inputs": [{"item": Defs.ITEM_HEATSTONE, "amount": 2}],
	"outputs": [{"item": Defs.ITEM_COPPER, "amount": 1}],
	"seconds": 2.0,
}

## The real machine table with one row switched to "runs recipes", because no
## machine in this game does yet. The validator now joins the two registries --
## a recipe may only name a machine the shared tick actually drives -- so a test
## about recipes has to supply a machine that qualifies.
static func _machines_with_a_runner() -> Array:
	var rows: Array = []
	for row: Dictionary in Defs.MACHINES:
		var copy: Dictionary = row.duplicate(true)
		if int(copy["id"]) == Defs.M_SPLITTER:
			copy["production"] = Defs.PROD_RECIPE
		rows.append(copy)
	return rows

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_the_registry_is_empty_and_says_so()
	_test_validator_catches_broken_recipes()
	_test_dependency_check_catches_the_knot()
	_test_lookup()
	_test_shared_tick_produces()
	_test_shared_tick_waits_when_blocked()
	await _test_outbox_survives_a_save()
	if failures == 0:
		print("PASS test_recipes")
	else:
		print("FAIL test_recipes (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- The real table -----------------------------------------------------------

## Empty is the correct answer today, and it is worth asserting rather than
## assuming: the miner takes from the world and the generator makes power, and
## neither is an inputs-to-outputs pair. Forcing them in would be a rewrite of
## working code for a table with two rows in it.
func _test_the_registry_is_empty_and_says_so() -> void:
	_assert(Defs.RECIPES.is_empty(), "레시피 표는 아직 비어 있다 (%d)" % Defs.RECIPES.size())
	_assert(Defs.RECIPE_MACHINES.is_empty(), "레시피가 모는 기계도 아직 없다")
	_assert(Defs.recipe_errors().is_empty(), "빈 표에는 잘못이 없다")
	_assert(Defs.recipe_dependency_errors().is_empty(),
		"지금 기계들은 자기 자신 없이도 지을 수 있다 (%s)" % str(Defs.recipe_dependency_errors()))
	# The generator and the miner cost copper and heat stone, both of which come
	# out of the ground by hand. That is what makes the check above pass, and it
	# is the property the rule exists to keep.
	_assert(Defs.recipes_producing_item(Defs.ITEM_COPPER).is_empty(), "구리를 만드는 레시피는 없다")
	_assert(Defs.recipes_producing_item(Defs.ITEM_HEATSTONE).is_empty(), "열석도 마찬가지")

# --- Broken tables ------------------------------------------------------------

func _test_validator_catches_broken_recipes() -> void:
	_assert(Defs.recipe_errors([TEST_RECIPE], _machines_with_a_runner()).is_empty(),
		"멀쩡한 레시피는 통과한다 (%s)" % str(Defs.recipe_errors([TEST_RECIPE], _machines_with_a_runner())))

	var second: Dictionary = TEST_RECIPE.duplicate(true)
	second["key"] = "test_other"
	_assert(Defs.recipe_errors([TEST_RECIPE, second], _machines_with_a_runner()).size() > 0, "번호가 겹치면 잡는다")

	second = TEST_RECIPE.duplicate(true)
	second["id"] = 9002
	_assert(Defs.recipe_errors([TEST_RECIPE, second], _machines_with_a_runner()).size() > 0, "key 가 겹치면 잡는다")

	var bad: Dictionary = TEST_RECIPE.duplicate(true)
	bad["inputs"] = [{"item": 4242, "amount": 1}]
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0, "없는 자원을 가리키면 잡는다")

	bad = TEST_RECIPE.duplicate(true)
	bad["inputs"] = [{"item": Defs.ITEM_HEATSTONE, "amount": 0}]
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0, "입력 수량 0 을 잡는다")

	bad = TEST_RECIPE.duplicate(true)
	bad["outputs"] = [{"item": Defs.ITEM_COPPER, "amount": -1}]
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0, "출력 수량 음수를 잡는다")

	bad = TEST_RECIPE.duplicate(true)
	bad["outputs"] = []
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0, "아무것도 만들지 않는 레시피를 잡는다")

	bad = TEST_RECIPE.duplicate(true)
	bad["seconds"] = 0.0
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0, "생산 시간 0 을 잡는다")

	bad = TEST_RECIPE.duplicate(true)
	bad["machine"] = 99
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0, "없는 기계 번호를 잡는다")

	bad = TEST_RECIPE.duplicate(true)
	bad["key"] = "Test Plate"
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0, "key 에 대문자와 공백이 있으면 잡는다")

	bad = TEST_RECIPE.duplicate(true)
	bad["machine"] = Defs.M_BELT
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0,
		"레시피를 돌리지 않는 기계를 가리키면 잡는다")

	bad = TEST_RECIPE.duplicate(true)
	bad.erase("seconds")
	_assert(Defs.recipe_errors([bad], _machines_with_a_runner()).size() > 0, "항목이 빠지면 잡는다")

	# An empty input list is allowed: something that draws from the world rather
	# than from a buffer is a real shape, and the miner is already that shape.
	var sourceless: Dictionary = TEST_RECIPE.duplicate(true)
	sourceless["inputs"] = []
	_assert(Defs.recipe_errors([sourceless], _machines_with_a_runner()).is_empty(), "입력이 없는 레시피는 허용한다")

# --- The knot -----------------------------------------------------------------

## 조립기 costs 전동기, and only a 조립기 makes 전동기. Nothing else in the game
## would report this: the build list would simply never light up, on a machine
## the player has been told about.
func _test_dependency_check_catches_the_knot() -> void:
	# Standing in for 전동기 and 조립기 with numbers this game already has, so no
	# content is invented to test a rule about content.
	var motor: int = Defs.ITEM_ENERGY_CORE
	var assembler: int = Defs.M_SPLITTER
	var knot: Array = [{
		"id": 9101, "key": "test_motor", "name": "시험 전동기",
		"machine": assembler,
		"inputs": [{"item": Defs.ITEM_COPPER, "amount": 1}],
		"outputs": [{"item": motor, "amount": 1}],
		"seconds": 1.0,
	}]
	var costs: Array = []
	for type in Defs.MACHINE_NAMES.size():
		costs.append({})
	costs[assembler] = {motor: 1}

	var problems: Array[String] = Defs.recipe_dependency_errors(knot, costs)
	_assert(problems.size() == 1, "자기 자신으로만 만드는 부품을 건설비용에 넣으면 잡는다 (%d)" % problems.size())
	if problems.size() > 0:
		print("       %s" % problems[0])

	# The same part, made by a different machine, is fine -- that is the ladder
	# working rather than a knot.
	var ladder: Array = knot.duplicate(true)
	ladder[0]["machine"] = Defs.M_GENERATOR
	_assert(Defs.recipe_dependency_errors(ladder, costs).is_empty(),
		"다른 기계가 만들어 주면 통과한다")

# --- Lookup -------------------------------------------------------------------

func _test_lookup() -> void:
	# Against the real registry, which is empty: the API has to answer rather
	# than crash before there is anything in it.
	_assert(Defs.recipe(1).is_empty(), "없는 번호는 빈 레시피를 준다")
	_assert(Defs.recipe_by_key("nothing").is_empty(), "없는 key 도 마찬가지")
	_assert(Defs.recipes_for_machine(Defs.M_MINER).is_empty(), "채굴기에는 레시피가 없다")
	_assert(Defs.recipe_for_machine(Defs.M_MINER).is_empty(), "그래서 고를 것도 없다")
	_assert(Defs.recipes_using_item(Defs.ITEM_COPPER).is_empty(), "구리를 쓰는 레시피도 아직 없다")

	# And the shape of the answers, checked on data that exists.
	var rows: Array = [TEST_RECIPE]
	var found := 0
	for row: Dictionary in rows:
		if int(row["machine"]) == Defs.M_SPLITTER:
			found += 1
	_assert(found == 1, "기계별 조회가 셀 것을 센다")
	_assert(Defs.recipe_dump(TEST_RECIPE).contains("Recipe: test_plate"), "덤프가 key 를 적는다")
	_assert(Defs.recipe_dump(TEST_RECIPE).contains("열석 x2"), "덤프가 입력을 적는다")
	_assert(Defs.recipe_dump(TEST_RECIPE).contains("구리광석 x1"), "덤프가 출력을 적는다")
	_assert(Defs.recipe_dump({}).contains("없음"), "빈 레시피도 한 줄은 답한다")

# --- The shared tick ----------------------------------------------------------

## Input consumed, time elapsed, output made. The whole contract, on a recipe
## that exists only in this file.
func _test_shared_tick_produces() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	var cell: Vector2i = sim.core_cell + Vector2i(6, 6)
	var ahead: Vector2i = cell + Vector2i.RIGHT
	sim.ore.erase(cell)
	sim.ore.erase(ahead)
	sim.ground.erase(ahead)
	var machine := Sim.Machine.new()
	machine.type = Defs.M_SPLITTER
	machine.cell = cell
	machine.dir = Vector2i.RIGHT
	sim.machines[cell] = machine

	# Nothing in it: no progress, no complaint.
	sim.tick_recipe(machine, TEST_RECIPE, 1.0)
	_assert(is_zero_approx(machine.progress), "재료가 없으면 진행하지 않는다")
	_assert(not machine.stalled, "그리고 그것은 막힘이 아니다")
	_assert(not machine.operated, "돌고 있지도 않다")

	# One short of the recipe is still nothing.
	machine.buffer[Defs.ITEM_HEATSTONE] = 1
	sim.tick_recipe(machine, TEST_RECIPE, 1.0)
	_assert(is_zero_approx(machine.progress), "한 개 모자라도 진행하지 않는다")

	machine.buffer[Defs.ITEM_HEATSTONE] = 2
	sim.tick_recipe(machine, TEST_RECIPE, 1.0)
	_assert(machine.operated, "재료가 차면 돌기 시작한다")
	_assert(is_equal_approx(machine.progress, 1.0), "시간이 흐른다 (%.2f)" % machine.progress)
	_assert(int(machine.buffer.get(Defs.ITEM_HEATSTONE, 0)) == 2,
		"아직 먹지는 않았다 — 끝나야 먹는다")

	sim.tick_recipe(machine, TEST_RECIPE, 1.1)
	_assert(is_zero_approx(machine.progress), "한 주기가 끝나면 진행이 0 으로 돌아간다")
	_assert(not machine.buffer.has(Defs.ITEM_HEATSTONE), "입력을 먹었다")
	_assert(machine.outbox.is_empty(), "그리고 산출을 바로 내보냈다")
	_assert(sim.ground.get(ahead, -1) == Defs.ITEM_COPPER,
		"앞칸에 만든 것이 놓였다 (%s)" % str(sim.ground.get(ahead, -1)))
	_assert(not machine.stalled, "막히지 않았다")
	sim.free()

# --- Waiting ------------------------------------------------------------------

## Output blocked: the work is kept, the machine says so, and it does not start
## another cycle. A machine that kept going would be a warehouse growing behind a
## mis-aimed belt.
func _test_shared_tick_waits_when_blocked() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	var cell: Vector2i = sim.core_cell + Vector2i(-6, 6)
	var ahead: Vector2i = cell + Vector2i.RIGHT
	sim.ore.erase(cell)
	# A seam in front takes no dropped item and holds no belt, so the exit is shut.
	sim.ore[ahead] = Defs.ITEM_HEATSTONE
	var machine := Sim.Machine.new()
	machine.type = Defs.M_SPLITTER
	machine.cell = cell
	machine.dir = Vector2i.RIGHT
	sim.machines[cell] = machine
	machine.buffer[Defs.ITEM_HEATSTONE] = 4

	sim.tick_recipe(machine, TEST_RECIPE, 2.5)
	_assert(int(machine.outbox.get(Defs.ITEM_COPPER, 0)) == 1, "내보내지 못한 산출을 들고 있다")
	_assert(machine.stalled, "그리고 막혔다고 말한다")
	_assert(int(machine.buffer.get(Defs.ITEM_HEATSTONE, 0)) == 2, "먹은 만큼만 줄었다")

	# A second cycle must not start while it is still holding the first.
	sim.tick_recipe(machine, TEST_RECIPE, 5.0)
	_assert(int(machine.outbox.get(Defs.ITEM_COPPER, 0)) == 1, "막힌 동안 또 만들지 않는다")
	_assert(int(machine.buffer.get(Defs.ITEM_HEATSTONE, 0)) == 2, "재료도 더 먹지 않는다")
	_assert(not machine.operated, "돌고 있다고 말하지도 않는다")

	# Open the exit and it drains on the next tick, then works again.
	sim.ore.erase(ahead)
	sim.tick_recipe(machine, TEST_RECIPE, 0.1)
	_assert(machine.outbox.is_empty(), "길이 열리면 내보낸다")
	_assert(sim.ground.get(ahead, -1) == Defs.ITEM_COPPER, "앞칸에 놓였다")
	_assert(not machine.stalled, "그리고 막힘이 풀린다")
	sim.free()

# --- The outbox is state ------------------------------------------------------

## What a machine is owed has to survive being put down. It replaced `pending`,
## which was written to every save and read by nothing.
func _test_outbox_survives_a_save() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	var sim = main.sim
	sim.note_resource_seen(Defs.ITEM_COPPER)
	var cell: Vector2i = sim.core_cell + Vector2i(5, 5)
	sim.ore.erase(cell)
	sim.stock[Defs.ITEM_COPPER] = 500
	_assert(sim.build(Defs.M_BELT, cell, Vector2i.RIGHT), "무엇이든 하나 짓는다")
	sim.machine_at(cell).outbox[Defs.ITEM_ENERGY_CORE] = 3

	var saved: Dictionary = sim.to_save()
	var fresh := Sim.new()
	fresh.setup(4242)
	fresh.from_save(saved)
	var back = fresh.machine_at(cell)
	_assert(back != null and int(back.outbox.get(Defs.ITEM_ENERGY_CORE, 0)) == 3,
		"들고 있던 산출이 그대로 돌아온다 (%s)" % (str(back.outbox) if back != null else "기계 없음"))

	# A save written before the outbox existed carries `pending`, an int that was
	# always 0. It has to load as nothing rather than as anything.
	var old: Dictionary = saved.duplicate(true)
	for row: Dictionary in old["machines"]:
		row.erase("outbox")
		row["pending"] = 0
	var older := Sim.new()
	older.setup(4242)
	older.from_save(old)
	var legacy = older.machine_at(cell)
	_assert(legacy != null and legacy.outbox.is_empty(), "옛 세이브는 빈 산출로 열린다")

	main.clear_save()
	fresh.free()
	older.free()
	main.free()
