extends SceneTree

## Two lines meeting, and the machine built out of what they make.
##
## Everything before this was a chain: one material in, another out, and a
## factory you could read left to right. 전동기 needs 철판 *and* 전선 at the same
## time, which is the first thing in this game that cannot be solved by building
## one more of what you already have -- and 채굴기 Mk.2 is the reason to bother.
##
## What is worth testing is the "and". That the machine waits rather than eating
## half a craft, that neither side can be starved without the other side being
## held, that two belts arriving from two directions both land, and that the
## ladder they make has no rung standing on itself. The last one has its own
## section: a cycle is the failure that no amount of playing finds, because a
## machine nobody can build simply never appears.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_the_item()
	_test_the_recipe()
	_test_the_machine()
	_test_bootstrap()
	_test_the_whole_ladder_is_reachable()
	_test_a_cycle_is_caught()
	await _test_it_waits_for_both()
	await _test_one_cycle_eats_exactly_what_it_says()
	await _test_the_face_takes_both_and_nothing_else()
	await _test_power()
	await _test_two_belts_meet()
	await _test_the_save()
	await _test_mk2_opens_on_the_first_motor()
	await _test_mk2_digs_twice_as_fast()
	await _test_end_to_end()
	if failures == 0:
		print("PASS test_assembler")
	else:
		print("FAIL test_assembler (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- The material -------------------------------------------------------------

func _test_the_item() -> void:
	_assert(Defs.item_kind(Defs.ITEM_ELECTRIC_MOTOR) == Defs.KIND_INTERMEDIATE,
		"전동기는 intermediate 다")
	_assert(Defs.item_by_key("electric_motor") == Defs.item(Defs.ITEM_ELECTRIC_MOTOR),
		"key 로도 찾힌다")
	_assert(Defs.item_atlas(Defs.ITEM_ELECTRIC_MOTOR) == "", "광맥이 아니라 시트가 없다")
	_assert(not Defs.ORE_TIERS.has(Defs.ITEM_ELECTRIC_MOTOR), "잔해가 전동기를 주지 않는다")
	_assert(Defs.COUNTED_ITEMS.has(Defs.ITEM_ELECTRIC_MOTOR), "자원 패널에 나온다")
	# It rides the same belts as its own ingredients, so it may not look like
	# either of them.
	for other: int in [Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE, Defs.ITEM_IRON,
			Defs.ITEM_COPPER]:
		_assert(Defs.item_color(Defs.ITEM_ELECTRIC_MOTOR) != Defs.item_color(other),
			"%s 와 다른 색이다" % Defs.item_short(other))

# --- The recipe ---------------------------------------------------------------

func _test_the_recipe() -> void:
	var recipe: Dictionary = Defs.recipe_by_key("electric_motor")
	_assert(not recipe.is_empty(), "전동기 레시피가 있다")
	_assert(int(recipe["machine"]) == Defs.M_ASSEMBLER, "조립기의 것이다")
	_assert(Defs.recipes_producing_item(Defs.ITEM_ELECTRIC_MOTOR) == [recipe],
		"전동기를 만드는 유일한 것")
	# Two ports, and this is the whole point of the step. A one-port assembler
	# would be a manufacturer with a different name.
	var inputs: Array = recipe["inputs"]
	_assert(inputs.size() == 2, "재료가 두 가지다 (%d)" % inputs.size())
	var need: Dictionary = {}
	for port: Dictionary in inputs:
		need[int(port["item"])] = int(port["amount"])
	_assert(int(need.get(Defs.ITEM_IRON_PLATE, 0)) == 2, "철판 둘")
	_assert(int(need.get(Defs.ITEM_COPPER_WIRE, 0)) == 4, "전선 넷")
	_assert(int((recipe["outputs"] as Array)[0]["amount"]) == 1, "전동기 하나가 나온다")
	var seconds: float = float(recipe["seconds"])
	_assert(seconds >= 5.0 and seconds <= 8.0, "한 주기는 5~8초다 (%.1f)" % seconds)
	# Both materials come off the machine before it. If either one needed a third
	# machine, the player would meet two new buildings in one step.
	for item_id: int in need:
		for maker: Dictionary in Defs.recipes_producing_item(item_id):
			_assert(int(maker["machine"]) == Defs.M_MANUFACTURER,
				"%s 는 제조기가 만든다" % Defs.item_short(item_id))
	_assert(Defs.recipe_errors().is_empty(), "표에 잘못이 없다 (%s)" % str(Defs.recipe_errors()))

func _test_the_machine() -> void:
	_assert(Defs.machine_errors().is_empty(), "기계 표에 잘못이 없다 (%s)"
		% str(Defs.machine_errors()))
	_assert(Defs.machine_by_key("assembler") == Defs.machine(Defs.M_ASSEMBLER), "key 로도 찾힌다")
	_assert(Defs.machine_uses_recipes(Defs.M_ASSEMBLER), "레시피 tick 이 돌린다")
	_assert(not Defs.machine_mines(Defs.M_ASSEMBLER), "채굴기는 아니다")
	_assert(Defs.machine_power_draw(Defs.M_ASSEMBLER) > 0.0, "전력을 쓴다")
	_assert(not Defs.WALKABLE_MACHINES.has(Defs.M_ASSEMBLER), "밟고 지나갈 수 없다")
	_assert(Defs.DIRECTIONAL_MACHINES.has(Defs.M_ASSEMBLER), "방향이 있다 — 앞칸으로 내놓는다")
	_assert(Defs.recipes_for_machine(Defs.M_ASSEMBLER).size() == 1, "고를 것은 아직 하나다")
	# The window opens on it anyway. One recipe means there is nothing to choose
	# and everything to read: 철판 0/2 · 전선 4/4 is the answer to "both lines are
	# running and nothing is coming out", which is this machine's first question.
	_assert(not Defs.recipes_for_machine(Defs.M_ASSEMBLER).is_empty(),
		"그래도 창은 열린다 — 무엇이 모자란지는 여기에만 적혀 있다")
	# Three lines in the build list, read off the recipe rather than written.
	var io: Array[String] = Defs.machine_io(Defs.M_ASSEMBLER)
	_assert(io.size() == 3 and io[0].contains("철판") and io[0].contains("전선"),
		"건설 목록이 두 재료를 다 말한다 (%s)" % str(io))

# --- Bootstrap ----------------------------------------------------------------

## The rule this whole step is balanced on: an 조립기 that cost a 전동기 would be a
## machine nobody could ever build, because a 전동기 only comes out of an 조립기.
func _test_bootstrap() -> void:
	var cost: Dictionary = Defs.MACHINE_COSTS[Defs.M_ASSEMBLER]
	_assert(not cost.has(Defs.ITEM_ELECTRIC_MOTOR), "조립기 비용에 전동기가 없다")
	_assert(not cost.is_empty(), "그래도 공짜는 아니다")
	# Everything it costs is something the machine before it makes, or something
	# a pickaxe finds. Asked of the tables rather than of the numbers, so a cost
	# edited later is still checked.
	for item_id: int in cost:
		var makers: Array[Dictionary] = Defs.recipes_producing_item(item_id)
		var reachable: bool = makers.is_empty()
		for maker: Dictionary in makers:
			if int(maker["machine"]) != Defs.M_ASSEMBLER:
				reachable = true
		_assert(reachable, "%s 는 조립기 없이 손에 넣을 수 있다" % Defs.item_short(item_id))
	_assert(Defs.recipe_dependency_errors().is_empty(),
		"의존성 매듭이 없다 (%s)" % str(Defs.recipe_dependency_errors()))
	# And Mk.2 is allowed to cost one, because a 채굴기 does not make 전동기.
	_assert(Defs.MACHINE_COSTS[Defs.M_MINER_MK2].has(Defs.ITEM_ELECTRIC_MOTOR),
		"Mk.2 는 전동기를 요구해도 된다 — 채굴기가 전동기를 만들지 않는다")

# --- The dependency graph -------------------------------------------------------

## Not "is this one machine buildable without itself" but "can a run that starts
## with a pickaxe get here at all". Every rung, by name, because the ladder this
## step builds is the first one long enough to break in the middle.
func _test_the_whole_ladder_is_reachable() -> void:
	_assert(Defs.reachability_errors().is_empty(),
		"닿지 못하는 것이 없다 (%s)" % str(Defs.reachability_errors()))
	var reach: Dictionary = Defs.production_reach()
	var built: Dictionary = reach["machines"]
	var have: Dictionary = reach["items"]
	for type: int in [Defs.M_MINER, Defs.M_BELT, Defs.M_GENERATOR, Defs.M_MANUFACTURER,
			Defs.M_ASSEMBLER, Defs.M_MINER_MK2]:
		_assert(built.has(type), "%s 에 도달할 수 있다" % Defs.machine_name(type))
	for item_id: int in [Defs.ITEM_IRON, Defs.ITEM_COPPER, Defs.ITEM_IRON_PLATE,
			Defs.ITEM_COPPER_WIRE, Defs.ITEM_ELECTRIC_MOTOR]:
		_assert(have.has(item_id), "%s 를 만들 수 있다" % Defs.item_short(item_id))
	# Every buildable machine, not only the ones named above -- a machine added
	# later has to answer this without this list being edited.
	for type: int in Defs.BUILDABLE:
		_assert(built.has(type), "%s 도 마찬가지" % Defs.machine_name(type))

## The check pointed at data that is wrong on purpose. A validator that has only
## ever seen correct tables is a validator nobody has watched work.
func _test_a_cycle_is_caught() -> void:
	# 1. The knot the old check was written for: a machine costing its own output.
	var items: Array = [
		{"id": 0, "key": "ore", "name": "광석", "retired": false},
		{"id": 1, "key": "part", "name": "부품", "retired": false},
	]
	var self_cycle_machines: Array = [
		{"id": 0, "key": "rig", "name": "가짜조립기", "cost": {1: 1}},
	]
	var self_cycle_recipes: Array = [
		{"id": 0, "key": "part", "machine": 0,
			"inputs": [{"item": 0, "amount": 1}], "outputs": [{"item": 1, "amount": 1}]},
	]
	_assert(not Defs.reachability_errors(items, self_cycle_recipes,
		self_cycle_machines).is_empty(), "자기 산출물을 요구하는 기계를 잡는다")

	# 2. The one the old check cannot see. Neither machine costs its own output,
	# so "can this be built without itself" says yes for both -- and they are
	# still waiting on each other, which means neither is ever built.
	var pair_items: Array = [
		{"id": 0, "key": "ore", "name": "광석", "retired": false},
		{"id": 1, "key": "widget", "name": "가부품", "retired": false},
		{"id": 2, "key": "gizmo", "name": "나부품", "retired": false},
	]
	var pair_machines: Array = [
		{"id": 0, "key": "a", "name": "가기계", "cost": {2: 1}},
		{"id": 1, "key": "b", "name": "나기계", "cost": {1: 1}},
	]
	var pair_recipes: Array = [
		{"id": 0, "key": "widget", "machine": 0,
			"inputs": [{"item": 0, "amount": 1}], "outputs": [{"item": 1, "amount": 1}]},
		{"id": 1, "key": "gizmo", "machine": 1,
			"inputs": [{"item": 0, "amount": 1}], "outputs": [{"item": 2, "amount": 1}]},
	]
	var costs: Array = [{2: 1}, {1: 1}]
	_assert(Defs.recipe_dependency_errors(pair_recipes, costs).is_empty(),
		"서로를 기다리는 두 기계는 '자기 자신 없이' 검사를 통과한다 — 그것이 이 검사가 있는 이유다")
	var caught: Array[String] = Defs.reachability_errors(pair_items, pair_recipes, pair_machines)
	_assert(caught.size() >= 2, "도달 검사는 둘 다 잡는다 (%s)" % str(caught))

	# 3. And it does not cry wolf: a ladder with no knot in it is silent.
	var fine_machines: Array = [
		{"id": 0, "key": "a", "name": "가기계", "cost": {0: 1}},
		{"id": 1, "key": "b", "name": "나기계", "cost": {1: 1}},
	]
	_assert(Defs.reachability_errors(pair_items, pair_recipes, fine_machines).is_empty(),
		"멀쩡한 사다리에는 아무 말도 하지 않는다")

# --- Two materials, one machine -------------------------------------------------

## Half the materials is not half a craft. It is no craft at all, and the half
## that did arrive stays where it is.
func _test_it_waits_for_both() -> void:
	var main := await _world()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	var recipe: Dictionary = sim.recipe_of(machine)
	_assert(String(recipe["key"]) == "electric_motor", "조립기는 전동기를 만든다")

	# Plates only.
	machine.buffer[Defs.ITEM_IRON_PLATE] = 2
	for step in 100:
		sim.tick(0.1)
	_assert(is_zero_approx(machine.progress), "전선이 없으면 시계가 돌지 않는다 (%.2f)"
		% machine.progress)
	_assert(int(machine.buffer.get(Defs.ITEM_IRON_PLATE, 0)) == 2, "철판을 먹지도 않는다")
	_assert(machine.outbox.is_empty(), "그리고 아무것도 나오지 않는다")
	_assert(not machine.operated, "'돌고 있다'고 말하지도 않는다")
	_assert(sim.meter_status(machine) == "재료 없음", "계기가 재료 없음이라고 말한다 (%s)"
		% sim.meter_status(machine))

	# Wire only, from empty. The other half of the same sentence.
	machine.buffer.clear()
	machine.buffer[Defs.ITEM_COPPER_WIRE] = 4
	for step in 100:
		sim.tick(0.1)
	_assert(is_zero_approx(machine.progress), "철판이 없어도 마찬가지다")
	_assert(int(machine.buffer.get(Defs.ITEM_COPPER_WIRE, 0)) == 4, "전선도 그대로 있다")

	# Not enough of one of them is the same as none of it.
	machine.buffer[Defs.ITEM_IRON_PLATE] = 1
	for step in 100:
		sim.tick(0.1)
	_assert(is_zero_approx(machine.progress), "철판이 하나뿐이어도 시작하지 않는다")

	# And now both.
	machine.buffer[Defs.ITEM_IRON_PLATE] = 2
	sim.tick(0.5)
	_assert(machine.progress > 0.0, "둘 다 차면 돈다 (%.2f)" % machine.progress)
	main.free()

func _test_one_cycle_eats_exactly_what_it_says() -> void:
	var main := await _world()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	var ahead: Vector2i = _PLANT + Vector2i.RIGHT

	# One craft's worth plus one spare of each, so an over-eating machine shows up
	# as a missing spare rather than as nothing at all.
	machine.buffer[Defs.ITEM_IRON_PLATE] = 3
	machine.buffer[Defs.ITEM_COPPER_WIRE] = 5
	var span: float = float(sim.recipe_of(machine)["seconds"])
	for step in int(span / 0.1) + 4:
		sim.tick(0.1)
	_assert(int(machine.buffer.get(Defs.ITEM_IRON_PLATE, 0)) == 1,
		"철판 둘만 먹었다 (%d 남음)" % int(machine.buffer.get(Defs.ITEM_IRON_PLATE, 0)))
	_assert(int(machine.buffer.get(Defs.ITEM_COPPER_WIRE, 0)) == 1,
		"전선 넷만 먹었다 (%d 남음)" % int(machine.buffer.get(Defs.ITEM_COPPER_WIRE, 0)))
	var made: int = _made(sim, machine, ahead, Defs.ITEM_ELECTRIC_MOTOR)
	_assert(made == 1, "전동기 하나가 나왔다 (%d)" % made)
	main.free()

## The input face takes what the recipe asks for and nothing else, and it takes
## it from whichever side it arrives on. A mis-aimed belt backs up on the belt,
## where the player can see it.
func _test_the_face_takes_both_and_nothing_else() -> void:
	var main := await _world()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)

	_assert(sim._accept_into(_PLANT, Defs.ITEM_IRON_PLATE, _PLANT + Vector2i.LEFT),
		"서쪽에서 온 철판을 받고")
	_assert(sim._accept_into(_PLANT, Defs.ITEM_COPPER_WIRE, _PLANT + Vector2i.UP),
		"북쪽에서 온 전선도 받는다")
	_assert(not sim._accept_into(_PLANT, Defs.ITEM_IRON, _PLANT + Vector2i.LEFT),
		"철광석은 받지 않는다 — 이 기계가 쓰지 않는 재료다")
	_assert(not sim._accept_into(_PLANT, Defs.ITEM_COPPER, _PLANT + Vector2i.LEFT),
		"구리광석도 마찬가지")

	# Two cycles' worth, per material, and then it stops taking. A machine that
	# accepted forever is a warehouse, and the queue belongs on the belt.
	var cap: int = 2 * Defs.RECIPE_INPUT_CYCLES
	for step in 20:
		sim._accept_into(_PLANT, Defs.ITEM_IRON_PLATE, _PLANT + Vector2i.LEFT)
	_assert(int(machine.buffer.get(Defs.ITEM_IRON_PLATE, 0)) == cap,
		"철판은 두 주기치까지만 (%d/%d)" % [int(machine.buffer.get(Defs.ITEM_IRON_PLATE, 0)), cap])
	var wire_cap: int = 4 * Defs.RECIPE_INPUT_CYCLES
	for step in 20:
		sim._accept_into(_PLANT, Defs.ITEM_COPPER_WIRE, _PLANT + Vector2i.UP)
	_assert(int(machine.buffer.get(Defs.ITEM_COPPER_WIRE, 0)) == wire_cap,
		"전선도 그렇고, 그 수는 재료마다 다르다 (%d/%d)"
		% [int(machine.buffer.get(Defs.ITEM_COPPER_WIRE, 0)), wire_cap])
	main.free()

# --- The grid -------------------------------------------------------------------

func _test_power() -> void:
	var main := await _world()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	machine.buffer[Defs.ITEM_IRON_PLATE] = 2
	machine.buffer[Defs.ITEM_COPPER_WIRE] = 4

	# No grid at all is a stop, not a slowdown -- and nothing is eaten.
	for cell: Vector2i in sim.machines:
		if sim.machines[cell].type == Defs.M_GENERATOR:
			sim.machines[cell].buffer.clear()
	sim.tick(1.0)
	_assert(is_zero_approx(machine.progress), "전력이 없으면 멈춘다 (%.2f)" % machine.progress)
	_assert(int(machine.buffer.get(Defs.ITEM_IRON_PLATE, 0)) == 2, "재료도 그대로다")
	_assert(not machine.operated, "죽은 그리드 위에서 가동 중이라고 말하지 않는다")
	_assert(sim.meter_status(machine) == "전력 없음", "계기가 전력 없음이라고 말한다")

	# One generator against an assembler's 1.5: two thirds of the pace, and the
	# machine still finishes -- it just takes longer.
	_fuel(sim, 1)
	sim.tick(0.0)
	_assert(is_equal_approx(sim.power_draw, Defs.ASSEMBLER_POWER),
		"일감이 있는 조립기가 그리드를 끈다 (%.2f)" % sim.power_draw)
	var before: float = machine.progress
	sim.tick(1.0)
	var slow: float = machine.progress - before
	var want: float = Defs.GENERATOR_OUTPUT / Defs.ASSEMBLER_POWER
	_assert(absf(slow - want) < 0.02, "%.2f 배로 느려진다 (%.2f)" % [want, slow])

	# Enough capacity, full speed.
	_fuel(sim, 2)
	sim.tick(0.0)
	before = machine.progress
	sim.tick(1.0)
	_assert(absf((machine.progress - before) - 1.0) < 0.02, "전력이 차면 제 속도다")
	main.free()

# --- Two belts ------------------------------------------------------------------

## The layout this whole step exists to make possible: a plate line coming in
## from the west, a wire line coming down from the north, and one machine that
## needs both. No belt learned anything about either material to do it.
func _test_two_belts_meet() -> void:
	var main := await _world()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	var west: Vector2i = _clear(sim, _PLANT + Vector2i.LEFT)
	var north: Vector2i = _clear(sim, _PLANT + Vector2i.UP)
	var out_belt: Vector2i = _clear(sim, _PLANT + Vector2i.RIGHT)
	_assert(sim.build(Defs.M_BELT, west, Vector2i.RIGHT), "서쪽에서 들어오는 벨트")
	_assert(sim.build(Defs.M_BELT, north, Vector2i.DOWN), "북쪽에서 내려오는 벨트")
	_assert(sim.build(Defs.M_BELT, out_belt, Vector2i.RIGHT), "앞으로 나가는 벨트")
	for index in 2:
		sim.machine_at(west).items.append({"type": Defs.ITEM_IRON_PLATE, "t": 0.9 - float(index) * 0.5})
	for index in 4:
		sim.machine_at(north).items.append({"type": Defs.ITEM_COPPER_WIRE, "t": 0.9 - float(index) * 0.22})

	for step in 300:
		sim.tick(0.1)
	var landed_plate: bool = int(machine.buffer.get(Defs.ITEM_IRON_PLATE, 0)) > 0 \
		or int(machine.meter_in.get(Defs.ITEM_IRON_PLATE, 0.0)) > 0
	var motors: int = int(sim.stock.get(Defs.ITEM_ELECTRIC_MOTOR, 0)) \
		+ int(machine.outbox.get(Defs.ITEM_ELECTRIC_MOTOR, 0)) \
		+ _on_floor(sim, out_belt + Vector2i.RIGHT, Defs.ITEM_ELECTRIC_MOTOR)
	for item: Dictionary in sim.machine_at(out_belt).items:
		if int(item["type"]) == Defs.ITEM_ELECTRIC_MOTOR:
			motors += 1
	_assert(motors >= 1, "두 벨트가 만나 전동기가 나온다 (%d)" % motors)
	_assert(sim.machine_at(west).items.is_empty(), "서쪽 벨트가 다 비웠다")
	_assert(sim.machine_at(north).items.is_empty(), "북쪽 벨트도 다 비웠다")

# --- Saves ----------------------------------------------------------------------

func _test_the_save() -> void:
	var main := await _world()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	machine.buffer[Defs.ITEM_IRON_PLATE] = 3
	machine.buffer[Defs.ITEM_COPPER_WIRE] = 5
	sim.tick(1.0)
	var mid: float = machine.progress
	# After the tick, not before: a machine with a clear exit hands its output on
	# the same frame, so an outbox set first is an empty outbox by the time the
	# save is written. What is under test here is that the field round-trips.
	machine.outbox[Defs.ITEM_ELECTRIC_MOTOR] = 1

	# And a Mk.2 on a seam, so the save carries both new machine numbers.
	var seam: Vector2i = _clear(sim, Vector2i(3, 6))
	sim.ore[seam] = Defs.ITEM_HEATSTONE
	sim.note_resource_seen(Defs.ITEM_ELECTRIC_MOTOR)
	for item_id: int in Defs.MACHINE_COSTS[Defs.M_MINER_MK2]:
		sim.stock[item_id] = 50
	_assert(sim.build(Defs.M_MINER_MK2, seam, Vector2i.UP), "Mk.2 도 세운다")

	var fresh := Sim.new()
	fresh.setup(4242)
	fresh.from_save(sim.to_save())
	var back = fresh.machine_at(_PLANT)
	_assert(back != null, "조립기가 돌아온다")
	if back != null:
		_assert(back.type == Defs.M_ASSEMBLER, "번호 그대로")
		_assert(int(back.buffer.get(Defs.ITEM_IRON_PLATE, 0)) == 3, "철판 셋")
		_assert(int(back.buffer.get(Defs.ITEM_COPPER_WIRE, 0)) == 5, "전선 다섯 — 둘 다 왕복한다")
		_assert(int(back.outbox.get(Defs.ITEM_ELECTRIC_MOTOR, 0)) == 1, "내놓지 못한 전동기도")
		_assert(is_equal_approx(back.progress, mid), "진행도까지 (%.2f)" % back.progress)
	var rig = fresh.machine_at(seam)
	_assert(rig != null and rig.type == Defs.M_MINER_MK2, "Mk.2 도 돌아온다")
	_assert(int(fresh.stock.get(Defs.ITEM_ELECTRIC_MOTOR, 0))
		== int(sim.stock.get(Defs.ITEM_ELECTRIC_MOTOR, 0)), "전동기 보유량도 그대로")
	fresh.free()
	main.free()

# --- Mk.2 -----------------------------------------------------------------------

## Making one is what opens it, not banking one. A factory that has been turning
## out 전동기 for a minute with nothing in the build list to spend them on is a
## factory whose reward is invisible until the player happens to walk home.
func _test_mk2_opens_on_the_first_motor() -> void:
	var main := await _world()
	var sim = main.sim
	var machine: Sim.Machine = sim.machine_at(_PLANT)
	_assert(not sim.is_unlocked(Defs.M_MINER_MK2), "전동기를 만들기 전에는 잠겨 있다")
	_assert(not Defs.machine_previewed(Defs.M_MINER_MK2), "건설 목록에 미리 나오지도 않는다")

	machine.buffer[Defs.ITEM_IRON_PLATE] = 2
	machine.buffer[Defs.ITEM_COPPER_WIRE] = 4
	for step in int(float(sim.recipe_of(machine)["seconds"]) / 0.1) + 4:
		sim.tick(0.1)
	_assert(sim.is_unlocked(Defs.M_MINER_MK2), "첫 전동기가 Mk.2 를 연다")
	_assert(sim.take_unlocks().has(Defs.M_MINER_MK2), "그리고 말해 준다")

	# Opened is not afforded. The cost is two of them plus plate and wire, so the
	# build list lights up and then asks for the rest of the run's work.
	var cost: Dictionary = Defs.MACHINE_COSTS[Defs.M_MINER_MK2]
	_assert(int(cost.get(Defs.ITEM_ELECTRIC_MOTOR, 0)) == 2, "전동기 둘이 든다")
	_assert(int(cost.get(Defs.ITEM_IRON_PLATE, 0)) == 8, "철판 여덟도")
	_assert(int(cost.get(Defs.ITEM_COPPER_WIRE, 0)) == 6, "전선 여섯도")
	sim.stock[Defs.ITEM_ELECTRIC_MOTOR] = 0
	_assert(not sim.can_afford(Defs.M_MINER_MK2), "열렸다고 살 수 있는 것은 아니다")
	main.free()

## Same seam, same one worker, twice the pace. And still a rig: it goes on ore,
## it goes nowhere else, and it does nothing without a cat or a grid.
func _test_mk2_digs_twice_as_fast() -> void:
	var main := await _world()
	var sim = main.sim
	_assert(Defs.machine_mines(Defs.M_MINER_MK2), "Mk.2 는 채굴기다")
	_assert(Defs.MINER_MACHINES == [Defs.M_MINER, Defs.M_MINER_MK2],
		"채굴기는 둘이다 (%s)" % str(Defs.MINER_MACHINES))
	_assert(is_equal_approx(Defs.machine_mine_rate(Defs.M_MINER), 1.0), "채굴기는 기준 속도")
	_assert(is_equal_approx(Defs.machine_mine_rate(Defs.M_MINER_MK2), 2.0), "Mk.2 는 두 배")
	_assert(Defs.machine_power_draw(Defs.M_MINER_MK2)
		> Defs.machine_power_draw(Defs.M_MINER), "두 배로 일하니 전력도 더 쓴다")

	sim.note_resource_seen(Defs.ITEM_ELECTRIC_MOTOR)
	for item_id: int in Defs.MACHINE_COSTS[Defs.M_MINER_MK2]:
		sim.stock[item_id] = 50
	var slow: Vector2i = _clear(sim, Vector2i(3, 8))
	var fast: Vector2i = _clear(sim, Vector2i(3, 10))
	for cell: Vector2i in [slow, fast]:
		sim.ore[cell] = Defs.ITEM_COPPER
		sim.purity[cell] = Defs.PURITY_NORMAL
	_assert(sim.build(Defs.M_MINER, slow, Vector2i.UP), "채굴기 하나")
	_assert(sim.build(Defs.M_MINER_MK2, fast, Vector2i.UP), "Mk.2 하나")
	var one: float = sim.machine_period(sim.machine_at(slow))
	var two: float = sim.machine_period(sim.machine_at(fast))
	_assert(is_equal_approx(two * 2.0, one), "같은 광맥에서 절반의 시간 (%.1f vs %.1f)" % [two, one])
	_assert(is_equal_approx(sim.design_rates(sim.machine_at(fast))["out"][Defs.ITEM_COPPER],
		sim.design_rates(sim.machine_at(slow))["out"][Defs.ITEM_COPPER] * 2.0),
		"계기의 설계 처리량도 두 배다")

	# A seam, and only a seam.
	_assert(sim.can_build(Defs.M_MINER_MK2, _clear(sim, Vector2i(3, 12)))
		== "광맥 위에만 설치할 수 있습니다", "빈 땅에는 못 짓는다")
	# And it is inert without a worker, exactly like the first rig.
	sim.machine_at(fast).operated = false
	sim._tick_miner(sim.machine_at(fast), 100.0)
	_assert(is_zero_approx(sim.machine_at(fast).progress), "일손이 없으면 아무것도 안 한다")

	# Twice the pace, measured rather than declared. Both rigs on the grid.
	_fuel(sim, 4)
	for step in 1200:
		sim.tick(0.1)
	# Counted the same way on both sides, and only from the pile each rig pours
	# into. `meter_out` is a rate over a window, and adding it to one side of a
	# comparison is comparing two different quantities.
	var slow_out: int = _on_floor(sim, slow + Vector2i.UP, Defs.ITEM_COPPER)
	var fast_out: int = _on_floor(sim, fast + Vector2i.UP, Defs.ITEM_COPPER)
	_assert(slow_out >= 5, "채굴기가 두 배 안에서 셀 만큼 캤다 (%d)" % slow_out)
	_assert(fast_out >= slow_out * 2 - 1,
		"120초 동안 Mk.2 가 두 배 캔다 (%d vs %d)" % [fast_out, slow_out])
	main.free()

# --- The whole thing ------------------------------------------------------------

## Ore in the snow to a machine built out of what the factory made, with nothing
## placed by hand except the machines. This is the run the step is for.
func _test_end_to_end() -> void:
	var main := await _world()
	var sim = main.sim
	sim.machines.erase(_PLANT)

	# Two seams, two rigs, two manufacturers -- one on plates, one on wire -- and
	# one assembler where the lines meet.
	var iron_seam: Vector2i = _clear(sim, Vector2i(2, -2))
	var copper_seam: Vector2i = _clear(sim, Vector2i(2, 6))
	sim.ore[iron_seam] = Defs.ITEM_IRON
	sim.ore[copper_seam] = Defs.ITEM_COPPER
	sim.purity[iron_seam] = Defs.PURITY_NORMAL
	sim.purity[copper_seam] = Defs.PURITY_NORMAL
	var plate_plant: Vector2i = _clear(sim, Vector2i(4, -2))
	var wire_plant: Vector2i = _clear(sim, Vector2i(4, 6))
	var joint: Vector2i = _clear(sim, Vector2i(6, 2))
	_clear(sim, joint + Vector2i.RIGHT)

	_assert(sim.build(Defs.M_MINER, iron_seam, Vector2i.RIGHT), "철 광맥에 채굴기")
	_assert(sim.build(Defs.M_MINER, copper_seam, Vector2i.RIGHT), "구리 광맥에 채굴기")
	_assert(sim.build(Defs.M_MANUFACTURER, plate_plant, Vector2i.DOWN), "철판 공장")
	_assert(sim.build(Defs.M_MANUFACTURER, wire_plant, Vector2i.UP), "전선 공장")
	_assert(sim.set_recipe(sim.machine_at(wire_plant), "copper_wire"), "한쪽은 전선으로 돌린다")
	_assert(String(sim.recipe_of(sim.machine_at(plate_plant))["key"]) == "iron_plate",
		"다른 쪽은 철판 그대로")
	_assert(sim.build(Defs.M_ASSEMBLER, joint, Vector2i.RIGHT), "둘 사이에 조립기")

	# Belts: seam to plant, plant to the joint. Straight lines, both directions.
	for cell: Vector2i in [Vector2i(3, -2), Vector2i(3, 6)]:
		sim.build(Defs.M_BELT, _clear(sim, cell), Vector2i.RIGHT)
	for y in range(-1, 2):
		sim.build(Defs.M_BELT, _clear(sim, Vector2i(4, y)), Vector2i.DOWN)
	for y in range(5, 2, -1):
		sim.build(Defs.M_BELT, _clear(sim, Vector2i(4, y)), Vector2i.UP)
	sim.build(Defs.M_BELT, _clear(sim, Vector2i(4, 2)), Vector2i.RIGHT)
	sim.build(Defs.M_BELT, _clear(sim, Vector2i(5, 2)), Vector2i.RIGHT)
	_fuel(sim, 6)

	for step in 3000:
		sim.tick(0.1)
	var assembler: Sim.Machine = sim.machine_at(joint)
	var motors: int = _made(sim, assembler, joint + Vector2i.RIGHT, Defs.ITEM_ELECTRIC_MOTOR)
	_assert(motors >= 1, "광맥에서 시작해 전동기까지 갔다 (%d)" % motors)
	_assert(sim.is_unlocked(Defs.M_MINER_MK2), "그리고 Mk.2 가 열렸다")

	# The last rung: pay for one out of what the run produced, and put it down.
	for item_id: int in Defs.MACHINE_COSTS[Defs.M_MINER_MK2]:
		sim.stock[item_id] = maxi(int(sim.stock.get(item_id, 0)),
			int(Defs.MACHINE_COSTS[Defs.M_MINER_MK2][item_id]))
	var upgrade: Vector2i = _clear(sim, Vector2i(2, 10))
	sim.ore[upgrade] = Defs.ITEM_IRON
	_assert(sim.build(Defs.M_MINER_MK2, upgrade, Vector2i.RIGHT),
		"그 전동기로 Mk.2 를 세운다 — 이 단계의 끝")
	main.free()

# --- Helpers --------------------------------------------------------------------

const _PLANT := Vector2i(5, 3)

## A warm world with a fire, an assembler at `_PLANT` facing east, and enough
## generators to run it. Nothing else is unlocked by hand that the run would not
## have unlocked itself by the time an assembler exists.
func _world() -> Node2D:
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
			Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE, Defs.ITEM_ENERGY_CORE]:
		sim.note_resource_seen(item_id)
		sim.stock[item_id] = 500
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	sim.unlocked[Defs.M_MINER] = true
	if sim.core_cell != Vector2i.ZERO:
		push_error("이 파일은 기지가 원점에 있다고 가정한다")
	for cell: Vector2i in [_PLANT, _PLANT + Vector2i.RIGHT, _PLANT + Vector2i.LEFT,
			_PLANT + Vector2i.UP, _PLANT + Vector2i.DOWN]:
		_clear(sim, cell)
	sim.build(Defs.M_ASSEMBLER, _PLANT, Vector2i.RIGHT)
	_fuel(sim, 3)
	return main

## Generators west of the plant, fuelled. Written as a count because the number
## that matters is capacity against draw, and the draw changes with what is being
## tested rather than with what is built.
func _fuel(sim, count: int) -> void:
	var placed := 0
	for index in count:
		var cell: Vector2i = _clear(sim, Vector2i(-4 - index, 3))
		if not sim.machines.has(cell):
			sim.build(Defs.M_GENERATOR, cell, Vector2i.RIGHT)
		if sim.machines.has(cell):
			# Deep, on purpose. Four stones is forty seconds, and a test that runs
			# for five minutes was measuring a dead grid rather than the thing it
			# was written for -- the end-to-end run produced exactly one plate.
			sim.machines[cell].buffer[Defs.GENERATOR_FUEL] = 4000
			placed += 1
	# Every other generator in the world goes dark, so a count means a capacity.
	for cell: Vector2i in sim.machines:
		if sim.machines[cell].type != Defs.M_GENERATOR:
			continue
		if cell.x > -4 or cell.x < -4 - count + 1 or cell.y != 3:
			sim.machines[cell].buffer.clear()
	sim._recount_power()

func _clear(sim, cell: Vector2i) -> Vector2i:
	sim.ore.erase(cell)
	sim.machines.erase(cell)
	sim.ground.erase(cell)
	sim.ground_stack.erase(cell)
	sim.frozen_cats.erase(cell)
	sim.debris.erase(cell)
	return cell

## Everything one machine has made of a kind, wherever it ended up: still owed,
## lying in front, or banked.
func _made(sim, machine, ahead: Vector2i, item_type: int) -> int:
	return int(machine.outbox.get(item_type, 0)) \
		+ _on_floor(sim, ahead, item_type) \
		+ int(sim.stock.get(item_type, 0)) - _STOCK_BASE.get(item_type, 0)

const _STOCK_BASE := {}

## How many of one kind are lying on a cell. `ground_count` answers "how many",
## and a tile holding something else answers it just as happily.
func _on_floor(sim, cell: Vector2i, item_type: int) -> int:
	return sim.ground_count(cell) if int(sim.ground.get(cell, -1)) == item_type else 0
