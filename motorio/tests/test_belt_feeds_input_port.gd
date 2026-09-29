extends SceneTree

## A belt ending at an input port feeds the machine (Factory Interaction Pass 01):
## iron ore on a belt into a manufacturer's back, and into each of its sides, ends
## up in its buffer -- through the simulation's own tick, not a call.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test(Defs.SIDE_BACK)
	_test(Defs.SIDE_LEFT)
	_test(Defs.SIDE_RIGHT)
	if failures == 0:
		print("PASS test_belt_feeds_input_port")
	else:
		print("FAIL test_belt_feeds_input_port (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _test(side: String) -> void:
	var sim: Sim = Factory.world()
	Factory.power(sim)
	var anchor: Vector2i = Factory.at(sim, Vector2i(8, 8))
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, anchor, Vector2i.RIGHT)
	_assert(machine != null, "제조기")
	if machine == null:
		return
	sim.set_recipe(machine, Defs.recipe_for_machine(Defs.M_MANUFACTURER)["key"])
	var wanted: int = int(sim.recipe_of(machine)["inputs"][0]["item"])
	var port: Dictionary = {}
	for candidate: Dictionary in sim.machine_input_ports(machine):
		if String(candidate["side"]) == side:
			port = candidate
			break
	var into: Vector2i = -(port["dir"] as Vector2i)
	var belt: Sim.Machine = Factory.put(sim, Defs.M_BELT, port["outside"], into)
	_assert(belt != null, "%s 입력 앞에 기계 쪽을 향한 벨트" % side)
	belt.items.append({"type": wanted, "t": 0.0})
	Factory.run(sim, 4.0)
	var took: int = int(machine.buffer.get(wanted, 0)) + int(machine.outbox.get(wanted, 0))
	_assert(belt.items.is_empty(), "%s: 벨트가 비었다" % side)
	_assert(took == 1 or machine.progress > 0.0 or not machine.outbox.is_empty(),
		"%s: 제조기가 그것을 받았다 (buffer %s)" % [side, str(machine.buffer)])
	sim.free()
