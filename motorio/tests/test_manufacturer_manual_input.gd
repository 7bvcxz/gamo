extends SceneTree

## A manufacturer is loaded by hand (Factory Interaction Pass 01): what its
## recipe asks for goes in up to two cycles' worth and no further, what it does not
## use is refused, and a machine loaded only by hand makes its part.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_manufacturer_manual_input")
	else:
		print("FAIL test_manufacturer_manual_input (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _test() -> void:
	var sim: Sim = Factory.world()
	Factory.power(sim)
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, Factory.at(sim, Vector2i(6, 6)), Vector2i.RIGHT)
	_assert(machine != null, "제조기")
	var recipe: Dictionary = sim.recipe_of(machine)
	var wanted: int = int(recipe["inputs"][0]["item"])
	var amount: int = int(recipe["inputs"][0]["amount"])
	var cap: int = amount * Defs.RECIPE_INPUT_CYCLES
	sim.stock[wanted] = 30
	_assert(sim.hand_inputs(machine) == [wanted], "손으로 넣을 것은 레시피의 재료다")
	_assert(sim.insert_by_hand(machine, wanted, -1) == cap, "두 주기치까지 들어간다 (%d)" % cap)
	_assert(int(sim.stock[wanted]) == 30 - cap, "가방에서 그만큼 빠졌다")
	_assert(sim.insert_by_hand(machine, wanted, 1) == 0, "더는 안 들어간다")
	var other: int = Defs.ITEM_HEATSTONE if wanted != Defs.ITEM_HEATSTONE else Defs.ITEM_COPPER
	_assert(sim.insert_by_hand(machine, other, 1) == 0, "쓰지 않는 재료는 받지 않는다")
	var made: int = int(recipe["outputs"][0]["item"])
	var ahead: Vector2i = sim.output_cell(machine)
	Factory.run(sim, float(recipe["seconds"]) + 1.0)
	var out: int = sim.output_waiting(machine) + (1 if sim.ground.get(ahead, -1) == made else 0)
	_assert(out >= 1, "손으로만 넣은 재료로 %s%s 만들었다" % [Defs.item_name(made), Defs.object_of(Defs.item_name(made))])
	sim.free()
