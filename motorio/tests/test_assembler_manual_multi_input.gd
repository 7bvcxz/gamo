extends SceneTree

## An assembler takes both of its materials by hand, into one buffer (Factory
## Interaction Pass 01): each fills to its own cap, and with one material by hand
## and the other off a belt it still assembles -- the buffer does not care which
## door a part came through.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_assembler_manual_multi_input")
	else:
		print("FAIL test_assembler_manual_multi_input (%d)" % failures)
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
	var machine: Sim.Machine = Factory.put(sim, Defs.M_ASSEMBLER, Factory.at(sim, Vector2i(6, 6)), Vector2i.RIGHT)
	_assert(machine != null, "조립기")
	var recipe: Dictionary = sim.recipe_of(machine)
	var inputs: Array = recipe["inputs"]
	_assert(inputs.size() >= 2, "재료가 둘 이상")
	_assert(sim.hand_inputs(machine).size() == inputs.size(), "창에 재료마다 한 줄")
	# The first by hand, the second off a belt at the back.
	var first: int = int(inputs[0]["item"])
	var second: int = int(inputs[1]["item"])
	sim.stock[first] = 40
	var moved: int = sim.insert_by_hand(machine, first, -1)
	_assert(moved == int(inputs[0]["amount"]) * Defs.RECIPE_INPUT_CYCLES, "첫 재료는 손으로 (%d)" % moved)
	var back: Dictionary = {}
	for port: Dictionary in sim.machine_input_ports(machine):
		if String(port["side"]) == Defs.SIDE_BACK:
			back = port
			break
	var belt: Sim.Machine = Factory.put(sim, Defs.M_BELT, back["outside"], Vector2i.RIGHT)
	var made: int = int(recipe["outputs"][0]["item"])
	var ahead: Vector2i = sim.output_cell(machine)
	var got := 0
	for step in 600:
		if belt.items.is_empty():
			belt.items.append({"type": second, "t": 0.0})
		sim.tick(0.05)
		if sim.ground.get(ahead, -1) == made:
			got += sim.ground_count(ahead)
			sim.ground.erase(ahead)
			sim.ground_stack.erase(ahead)
		got += sim.take_by_hand(machine).get(made, 0)
	_assert(got >= 1, "한쪽은 손, 한쪽은 벨트로 %s%s 조립했다 (%d)" % [Defs.item_name(made), Defs.object_of(Defs.item_name(made)), got])
	# And both by hand.
	var sim2: Sim = Factory.world()
	Factory.power(sim2)
	var both: Sim.Machine = Factory.put(sim2, Defs.M_ASSEMBLER, Factory.at(sim2, Vector2i(6, 6)), Vector2i.RIGHT)
	for port: Dictionary in inputs:
		sim2.stock[int(port["item"])] = 40
		sim2.insert_by_hand(both, int(port["item"]), -1)
	_assert(sim2.recipe_inputs_ready(both, recipe), "둘 다 손으로 넣으면 준비가 된다")
	sim.free()
	sim2.free()
