extends SceneTree

## The machine registry, and the eight lists that used to be written beside it.
##
## A machine's name, short name, build cost, build-list line, unlock materials,
## hotbar position, colour, whether you can walk on it and whether it has a
## facing were nine separate declarations indexed by machine number, plus three
## matches keyed on it. Adding 제조기 meant editing twelve places, none of which
## knew about the others.
##
## So most of this file guards the table, and the rest guards the *translation*:
## every value the migration moved is pinned here as a literal from before it.
## That is the only form the claim "the game is identical" can take.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_table_is_wellformed()
	_test_validator_catches_broken_machines()
	_test_every_machine_is_reachable()
	_test_metadata_snapshot()
	_test_joins_to_the_other_registries()
	await _test_save_round_trip()
	if failures == 0:
		print("PASS test_machines")
	else:
		print("FAIL test_machines (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- The table ----------------------------------------------------------------

func _test_table_is_wellformed() -> void:
	_assert(Defs.machine_errors().is_empty(),
		"지금 표에는 잘못이 없다 (%s)" % str(Defs.machine_errors()))
	_assert(Defs.MACHINES.size() == 8, "기계는 여덟이다 (%d)" % Defs.MACHINES.size())

	# Two rows claiming one hotbar seat would leave the row's order up to the
	# sort's stability rather than to the table.
	var seats: Dictionary = {}
	var clash := ""
	for row: Dictionary in Defs.MACHINES:
		var seat: int = int(row["build_order"])
		if seat < 0:
			continue
		if seats.has(seat):
			clash = "%d <- %s, %s" % [seat, seats[seat], row["key"]]
		seats[seat] = String(row["key"])
	_assert(clash == "", "핫바 자리를 두 기계가 다투지 않는다 (%s)" % clash)

## Pointed at data that is wrong on purpose. A validator that has only ever seen
## a correct table is a validator nobody has watched work.
func _test_validator_catches_broken_machines() -> void:
	var good: Array = Defs.MACHINES.duplicate(true)
	_assert(Defs.machine_errors(good).is_empty(), "복사본도 통과한다")

	var rows: Array = Defs.MACHINES.duplicate(true)
	var extra: Dictionary = (rows[0] as Dictionary).duplicate(true)
	extra["key"] = "other"
	rows.append(extra)
	_assert(Defs.machine_errors(rows).size() > 0, "번호가 겹치면 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	extra = (rows[0] as Dictionary).duplicate(true)
	extra["id"] = 77
	rows.append(extra)
	_assert(Defs.machine_errors(rows).size() > 0, "key 가 겹치면 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	rows[1]["cost"] = {4242: 1}
	_assert(Defs.machine_errors(rows).size() > 0, "건설 비용이 없는 자원을 가리키면 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	rows[1]["cost"] = {Defs.ITEM_HEATSTONE: 0}
	_assert(Defs.machine_errors(rows).size() > 0, "건설 비용 수량 0 을 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	rows[2]["unlock"] = [4242]
	_assert(Defs.machine_errors(rows).size() > 0, "해금 조건이 없는 자원을 가리키면 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	rows[1]["production"] = "conveyor_belt_of_dreams"
	_assert(Defs.machine_errors(rows).size() > 0, "없는 production 을 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	rows[1]["group"] = "somewhere"
	_assert(Defs.machine_errors(rows).size() > 0, "없는 group 을 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	rows[1]["key"] = "Miner Two"
	_assert(Defs.machine_errors(rows).size() > 0, "key 에 대문자와 공백이 있으면 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	rows[1]["power_draw"] = -1.0
	_assert(Defs.machine_errors(rows).size() > 0, "전력 값이 음수면 잡는다")

	rows = Defs.MACHINES.duplicate(true)
	(rows[1] as Dictionary).erase("cost")
	_assert(Defs.machine_errors(rows).size() > 0, "항목이 빠지면 잡는다")

# --- Every machine answers -----------------------------------------------------

func _test_every_machine_is_reachable() -> void:
	var unreachable := ""
	for type: int in Defs.machine_ids():
		var row: Dictionary = Defs.machine(type)
		var key: String = String(row.get("key", ""))
		if row.is_empty() or Defs.machine_by_key(key) != row or not Defs.is_machine_type(type):
			unreachable = "%d/%s" % [type, key]
		if Defs.machine_name(type) != Defs.MACHINE_NAMES[type]:
			unreachable = "%d 이름 불일치" % type
		if Defs.machine_color(type) != row["color"]:
			unreachable = "%d 색 불일치" % type
	_assert(unreachable == "", "모든 기계가 번호로도 key 로도 조회된다 (%s)" % unreachable)

	_assert(Defs.machine(9999).is_empty(), "없는 번호는 빈 행을 준다")
	_assert(Defs.machine_color(9999) == Defs.COL_MACHINE, "없는 번호도 색은 답한다")
	_assert(not Defs.is_machine_type(9999), "그리고 없는 번호라고 말한다")
	_assert(Defs.machine_by_key("furnace").is_empty(), "없는 key 도 마찬가지")

	_assert(Defs.machines_of_group(Defs.GROUP_LOGISTICS)
		== [Defs.M_BELT, Defs.M_SPLITTER], "물류는 벨트와 분배기다")
	_assert(Defs.machines_of_group(Defs.GROUP_POWER) == [Defs.M_GENERATOR], "전력은 발전기다")

# --- Nothing changed for the player -------------------------------------------

## Pinned by hand, from before the migration. Nine lists moved into one table,
## and this is the file that can say none of them moved a value with them.
func _test_metadata_snapshot() -> void:
	_assert(Defs.MACHINE_NAMES == ["열 코어", "채굴기", "컨테이너 벨트", "발전기", "분배기",
		"제조기", "조립기", "채굴기 Mk.2"], "이름이 그대로다 (%s)" % str(Defs.MACHINE_NAMES))
	_assert(Defs.MACHINE_SHORT == ["코어", "채굴기", "벨트", "발전기", "분배기", "제조기",
		"조립기", "Mk.2"], "약칭이 그대로다 (%s)" % str(Defs.MACHINE_SHORT))
	_assert(Defs.MACHINE_HINTS == ["", "채굴을 더 빠르게 할 수 있는 장치",
		"자원을 기지까지 끊김 없이 나릅니다", "열석을 태워 전력 1.0을 공급합니다",
		"한 줄로 들어온 자원을 여러 줄로 균등하게 나눕니다",
		"광석을 가공해 부품을 만듭니다 · 전력 필요 · Z로 품목 선택",
		"부품 두 가지를 한꺼번에 받아 조립합니다 · 전력 필요",
		"같은 광맥에서 두 배로 캡니다 · 고양이 1마리 또는 전력"], "건설 목록 설명이 그대로다")

	# Costs, which are balance. A digit moved here is a different game.
	_assert(Defs.MACHINE_COSTS[Defs.M_CORE].is_empty(), "코어는 짓는 것이 아니다")
	_assert(Defs.MACHINE_COSTS[Defs.M_MINER] == {Defs.ITEM_HEATSTONE: 5, Defs.ITEM_COPPER: 1},
		"채굴기 열석 5 + 구리 1 — 구리 기술이다")
	_assert(Defs.MACHINE_COSTS[Defs.M_BELT] == {Defs.ITEM_COPPER: 3}, "벨트 구리 3")
	_assert(Defs.MACHINE_COSTS[Defs.M_GENERATOR]
		== {Defs.ITEM_COPPER: 5, Defs.ITEM_ENERGY_CORE: 1},
		"발전기 구리 5 + 에너지 코어 1 — 코어는 열쇠가 아니라 재료다")
	_assert(Defs.MACHINE_COSTS[Defs.M_SPLITTER] == {Defs.ITEM_COPPER: 2}, "분배기 구리 2")
	# Bootstrap, spelled out: everything the first manufacturer costs comes out of
	# the ground with a pickaxe. `test_iron` holds the same fact from the other
	# side, by asking whether any recipe makes these.
	_assert(Defs.MACHINE_COSTS[Defs.M_MANUFACTURER]
		== {Defs.ITEM_IRON: 10, Defs.ITEM_COPPER: 5, Defs.ITEM_HEATSTONE: 3},
		"제조기 철 10 · 구리 5 · 열석 3")

	# Unlock, which is progression order.
	_assert(Defs.MACHINE_UNLOCK_ITEMS[Defs.M_MINER] == [], "채굴기는 재료가 열지 않는다")
	_assert(Defs.MACHINE_UNLOCK_ITEMS[Defs.M_BELT] == [Defs.UNLOCK_POWER], "벨트는 첫 와트가 연다")
	_assert(Defs.MACHINE_UNLOCK_ITEMS[Defs.M_SPLITTER] == [Defs.UNLOCK_POWER], "분배기도 같은 문이다")
	_assert(Defs.MACHINE_UNLOCK_ITEMS[Defs.M_GENERATOR]
		== [Defs.ITEM_COPPER, Defs.ITEM_ENERGY_CORE], "발전기는 구리와 에너지 코어")
	_assert(Defs.MACHINE_UNLOCK_ITEMS[Defs.M_MANUFACTURER] == [Defs.ITEM_IRON],
		"제조기는 첫 철이 연다")
	_assert(Defs.MACHINE_UNLOCK_ITEMS[Defs.M_ASSEMBLER]
		== [Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE], "조립기는 두 중간재가 연다")
	_assert(Defs.MACHINE_UNLOCK_ITEMS[Defs.M_MINER_MK2] == [Defs.ITEM_ELECTRIC_MOTOR],
		"Mk.2 는 첫 전동기가 연다")

	# Hotbar order is the order they are earned, which is not id order: the
	# splitter comes before the generator.
	_assert(Defs.BUILDABLE == [Defs.M_MINER, Defs.M_BELT, Defs.M_SPLITTER, Defs.M_GENERATOR,
		Defs.M_MANUFACTURER, Defs.M_ASSEMBLER, Defs.M_MINER_MK2],
		"핫바 순서가 그대로다 (%s)" % str(Defs.BUILDABLE))
	_assert(Defs.WALKABLE_MACHINES.size() == 2
		and Defs.M_BELT in Defs.WALKABLE_MACHINES
		and Defs.M_SPLITTER in Defs.WALKABLE_MACHINES, "밟을 수 있는 것은 벨트와 분배기뿐이다")
	# The manufacturer joined them in 1.0.34: it pours its output at the cell it
	# faces, so which way it points is a decision the player makes.
	_assert(Defs.DIRECTIONAL_MACHINES.size() == 6
		and Defs.M_MINER in Defs.DIRECTIONAL_MACHINES
		and Defs.M_BELT in Defs.DIRECTIONAL_MACHINES
		and Defs.M_SPLITTER in Defs.DIRECTIONAL_MACHINES
		and Defs.M_MANUFACTURER in Defs.DIRECTIONAL_MACHINES
		and Defs.M_ASSEMBLER in Defs.DIRECTIONAL_MACHINES
		and Defs.M_MINER_MK2 in Defs.DIRECTIONAL_MACHINES, "방향이 있는 것은 여섯이다")

	_assert(Defs.machine_color(Defs.M_CORE) == Defs.COL_CORE, "코어 색")
	_assert(Defs.machine_color(Defs.M_MINER) == Defs.COL_CAT_FUR, "채굴기 색")
	_assert(Defs.machine_color(Defs.M_BELT) == Defs.COL_BELT_RIM, "벨트 색")
	_assert(Defs.machine_color(Defs.M_GENERATOR) == Color8(120, 190, 235), "발전기 색")
	_assert(Defs.machine_color(Defs.M_SPLITTER) == Color8(150, 210, 160), "분배기 색")
	_assert(Defs.machine_color(Defs.M_MANUFACTURER) == Color8(196, 168, 120), "제조기 색")
	_assert(is_equal_approx(Defs.machine_power_draw(Defs.M_MANUFACTURER),
		Defs.MANUFACTURER_POWER), "제조기 소비 %.2f" % Defs.machine_power_draw(Defs.M_MANUFACTURER))

	# Power, which is balance too. The registry carries which machine has it; the
	# numbers keep their own named constants and their reasons.
	_assert(is_equal_approx(Defs.machine_power_draw(Defs.M_MINER), Defs.MINER_POWER_DRAW),
		"채굴기 소비 %.2f" % Defs.machine_power_draw(Defs.M_MINER))
	_assert(is_equal_approx(Defs.machine_power_output(Defs.M_GENERATOR), Defs.GENERATOR_OUTPUT),
		"발전기 생산 %.2f" % Defs.machine_power_output(Defs.M_GENERATOR))
	_assert(is_zero_approx(Defs.machine_power_draw(Defs.M_BELT)), "벨트는 전력이 필요 없다")

	# And the two sentences the build list composes from all of it.
	_assert(Defs.unlock_line(Defs.M_GENERATOR).contains("에너지 코어를"),
		"발전기 해금 문구: %s" % Defs.unlock_line(Defs.M_GENERATOR))
	_assert(Defs.machine_previewed(Defs.M_MINER), "채굴기는 잠긴 채로도 목록에 나온다")
	_assert(not Defs.machine_previewed(Defs.M_GENERATOR), "발전기는 구리를 보기 전에는 없다")

# --- The joins ----------------------------------------------------------------

## Three registries now, and the value of that is only real if they agree.
func _test_joins_to_the_other_registries() -> void:
	# Every build cost points at a material that exists.
	var bad := ""
	for type: int in Defs.machine_ids():
		for item_id: int in Defs.MACHINE_COSTS[type]:
			if not Defs.has_item(item_id):
				bad = "%s -> %d" % [Defs.machine_name(type), item_id]
		for item_id: int in Defs.MACHINE_UNLOCK_ITEMS[type]:
			if not Defs.has_item(item_id):
				bad = "%s 해금 -> %d" % [Defs.machine_name(type), item_id]
	_assert(bad == "", "비용과 해금이 실재하는 자원을 가리킨다 (%s)" % bad)

	# Every recipe points at a machine that runs recipes. Empty today, on both
	# sides, and the check is what makes the first row safe.
	_assert(Defs.recipe_errors().is_empty(), "레시피와 기계가 어긋나지 않는다")
	_assert(Defs.RECIPE_MACHINES == [Defs.M_MANUFACTURER, Defs.M_ASSEMBLER],
		"레시피를 도는 기계는 제조기와 조립기다 (%s)" % str(Defs.RECIPE_MACHINES))
	_assert(Defs.machine_uses_recipes(Defs.M_MANUFACTURER), "제조기는 레시피로 돈다")
	_assert(not Defs.machine_uses_recipes(Defs.M_MINER), "채굴기는 세계에서 캔다")
	_assert(not Defs.machine_uses_recipes(Defs.M_GENERATOR), "발전기는 전력을 낸다")
	_assert(Defs.machine_production(Defs.M_MINER) == Defs.PROD_MINER, "채굴기의 tick 은 miner")
	_assert(Defs.machine_production(Defs.M_BELT) == Defs.PROD_LOGISTICS, "벨트는 logistics")

# --- Saves --------------------------------------------------------------------

## `Machine.type` is a registry number written into every save. Building one of
## each and reading them back is the regression that matters.
func _test_save_round_trip() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	var sim = main.sim
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.power_ever = true
	sim._check_unlocks()
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	sim.unlocked[Defs.M_MINER] = true
	sim.note_resource_seen(Defs.ITEM_IRON)
	sim.note_resource_seen(Defs.ITEM_IRON_PLATE)
	sim.note_resource_seen(Defs.ITEM_COPPER_WIRE)
	sim.note_resource_seen(Defs.ITEM_ELECTRIC_MOTOR)
	# Whatever the table asks for, rather than three names written down here. The
	# point of the check below is that every buildable machine round-trips, and a
	# hand-kept purse turns a new machine into a failure of this test rather than
	# a test of that machine.
	for type: int in Defs.BUILDABLE:
		for item_id: int in Defs.MACHINE_COSTS[type]:
			sim.stock[item_id] = 500

	var placed: Dictionary = {}
	var at: Vector2i = sim.core_cell + Vector2i(4, 4)
	for type: int in Defs.BUILDABLE:
		var cell: Vector2i = at
		at += Vector2i(0, 2)
		sim.ore.erase(cell)
		sim.machines.erase(cell)
		if Defs.machine_mines(type):
			sim.ore[cell] = Defs.ITEM_HEATSTONE
		if sim.build(type, cell, Vector2i.RIGHT):
			placed[cell] = type
	_assert(placed.size() == Defs.BUILDABLE.size(),
		"지을 수 있는 기계를 전부 세웠다 (%d/%d)" % [placed.size(), Defs.BUILDABLE.size()])

	var fresh := Sim.new()
	fresh.setup(4242)
	fresh.from_save(sim.to_save())
	var wrong := ""
	for cell: Vector2i in placed:
		var back = fresh.machine_at(cell)
		if back == null or back.type != int(placed[cell]):
			wrong = "%s: %s" % [str(cell), "없음" if back == null else str(back.type)]
	_assert(wrong == "", "번호 그대로 돌아온다 (%s)" % wrong)

	main.clear_save()
	fresh.free()
	main.free()
