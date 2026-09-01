extends SceneTree

## The canonical 18~23 minutes, as contracts: the story stays off the main path
## with every asset preserved behind its flag, iron is whole inside the Lv8
## circle and absent from the Lv7 one, and the factory ladder that follows it
## (제조기 → 조립기 → Mk.2) is exactly the one the foundation steps built.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_story_sign_hidden_from_main_path()
	_test_footprints_hidden_from_main_path()
	_test_village_assets_preserved()
	_test_iron_reachable_at_lv8()
	_test_iron_not_prematurely_reachable()
	_test_factory_ladder_regression()
	if failures == 0:
		print("PASS test_golden_iron")
	else:
		print("FAIL test_golden_iron (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- test_story_sign_hidden_from_main_path -------------------------------------

func _test_story_sign_hidden_from_main_path() -> void:
	_assert(Defs.STORY_ON_MAIN_PATH == false, "기본값은 숨김이다")
	var sim := Sim.new()
	sim.setup(90001)
	_assert(sim.sign_cell == Vector2i(9999, 9999), "표지판이 세계에 없다")
	_assert(sim.village.is_empty(), "마을 건물도 없다")
	_assert(sim.village_rect.size == Vector2i.ZERO, "마을 자리도 비어 있다")
	# And the seven villagers do not wait in their pattern. The ordinary scatter
	# may drop a cat anywhere -- that square is ordinary snow now -- so what is
	# asserted is the *pattern*: the seven authored offsets are never all filled.
	var would_be: Vector2i = sim.core_cell + Defs.VILLAGE_OFFSET \
		- Vector2i(Defs.VILLAGE_CELLS.x / 2, Defs.VILLAGE_CELLS.y / 2)
	var patterned := 0
	for local: Vector2i in Defs.VILLAGE_FROZEN:
		if sim.frozen_cats.has(would_be + local):
			patterned += 1
	_assert(patterned < Defs.VILLAGE_FROZEN.size(),
		"마을 고양이 일곱이 제 무늬대로 잠들어 있지 않다 (%d)" % patterned)
	sim.free()

# --- test_footprints_hidden_from_main_path -------------------------------------

func _test_footprints_hidden_from_main_path() -> void:
	var sim := Sim.new()
	sim.setup(90002)
	_assert(sim.trail.is_empty(), "발자국이 한 칸도 없다")
	sim.free()

# --- test_village_assets_preserved ----------------------------------------------

func _test_village_assets_preserved() -> void:
	# The flag, not a deletion: flipped on, everything generates as it always
	# did -- houses, well, fire, gate, seven frozen cats, sign, and the trail
	# walking from one to the other one cell at a time.
	var sim := Sim.new()
	sim.story_enabled = true
	sim.setup(90003)
	_assert(sim.sign_cell == sim.core_cell + Defs.SIGN_OFFSET, "표지판이 제자리에 선다")
	_assert(sim.village.size() == Defs.VILLAGE_PIECES.size(),
		"마을 조각 %d개가 전부 있다 (%d)" % [Defs.VILLAGE_PIECES.size(), sim.village.size()])
	var villagers := 0
	for local: Vector2i in Defs.VILLAGE_FROZEN:
		if sim.frozen_cats.has(sim.village_rect.position + local):
			villagers += 1
	_assert(villagers == Defs.VILLAGE_FROZEN.size(),
		"얼어붙은 주민 %d마리도 그대로다 (%d)" % [Defs.VILLAGE_FROZEN.size(), villagers])
	_assert(not sim.trail.is_empty(), "발자국도 이어진다")
	# And the flag survives the save: a run that has seen the village keeps it.
	var save: Dictionary = sim.to_save()
	var fresh := Sim.new()
	fresh.setup(90003)
	_assert(fresh.sign_cell == Vector2i(9999, 9999), "새 세계는 여전히 숨김이고")
	fresh.from_save(save)
	_assert(fresh.story_enabled and fresh.sign_cell != Vector2i(9999, 9999),
		"마을을 본 세이브는 마을을 지킨다")
	fresh.free()
	sim.free()

# --- test_iron_reachable_at_heat_21 / Lv8 ---------------------------------------

func _test_iron_reachable_at_lv8() -> void:
	var missing := 0
	var partial := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(91000 + index)
		sim.begin_crash()
		sim.search_kit()
		sim.stones_in = int(Defs.BASE_LEVELS[7]["stones"])   # display Lv8, radius 22
		sim._refresh_radius()
		var reachable := 0
		for cell: Vector2i in sim.ore:
			if int(sim.ore[cell]) == Defs.ITEM_IRON and sim.can_touch(cell):
				reachable += 1
		if reachable < 1:
			missing += 1
		elif reachable < Defs.FIRST_IRON_SIZE:
			partial += 1
		sim.free()
	_assert(missing == 0, "Lv8(22칸)에는 철이 반드시 있다 (%d회 실패)" % missing)
	_assert(partial == 0,
		"그리고 첫 패치(%d칸)가 여유 있게 통째로 들어온다 (%d회 실패)" % [Defs.FIRST_IRON_SIZE, partial])

# --- test_iron_not_prematurely_reachable ----------------------------------------

func _test_iron_not_prematurely_reachable() -> void:
	var early := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(91000 + index)
		sim.begin_crash()
		sim.search_kit()
		sim.stones_in = int(Defs.BASE_LEVELS[6]["stones"])   # display Lv7, radius 19
		sim._refresh_radius()
		for cell: Vector2i in sim.ore:
			if int(sim.ore[cell]) == Defs.ITEM_IRON and sim.can_touch(cell):
				early += 1
				break
		sim.free()
	_assert(early == 0, "Lv7(19칸)에서는 철에 닿지 않는다 (%d회 실패)" % early)

# --- test_existing_manufacturer/assembler_progression_regression -----------------

## The foundation this overnight must not regress, asked as one walk: iron opens
## the manufacturer, plates and wire open the assembler, the motor opens Mk.2,
## and the whole ladder is reachable from a pickaxe.
func _test_factory_ladder_regression() -> void:
	var sim := Sim.new()
	sim.setup(92000)
	_assert(sim.note_resource_seen(Defs.ITEM_IRON).has(Defs.M_MANUFACTURER),
		"첫 철이 제조기를 연다")
	sim.note_resource_seen(Defs.ITEM_IRON_PLATE)
	_assert(not sim.is_unlocked(Defs.M_ASSEMBLER), "철판만으로 조립기는 아직이다")
	_assert(sim.note_resource_seen(Defs.ITEM_COPPER_WIRE).has(Defs.M_ASSEMBLER),
		"철판과 전선이 조립기를 연다")
	_assert(sim.note_resource_seen(Defs.ITEM_ELECTRIC_MOTOR).has(Defs.M_MINER_MK2),
		"첫 전동기가 Mk.2 를 연다")
	_assert(Defs.recipe_dependency_errors().is_empty(), "의존성 매듭이 없다")
	_assert(Defs.reachability_errors().is_empty(),
		"사다리 전체에 닿을 수 있다 (%s)" % str(Defs.reachability_errors()))
	sim.free()
