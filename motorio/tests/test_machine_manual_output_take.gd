extends SceneTree

## What a machine made is taken by hand (Factory Interaction Pass 01): all of it
## goes into the bag in one move, the machine stops saying it is blocked, and the
## take is not counted as income a second time (`collected` does not move). An
## empty output takes nothing.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_machine_manual_output_take")
	else:
		print("FAIL test_machine_manual_output_take (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _test() -> void:
	var sim: Sim = Factory.world()
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, Factory.at(sim, Vector2i(6, 6)), Vector2i.RIGHT)
	var plate: int = Defs.ITEM_IRON_PLATE
	sim.stock[plate] = 2
	var collected: int = int(sim.collected.get(plate, 0))
	machine.outbox[plate] = 3
	machine.stalled = true
	_assert(sim.output_waiting(machine) == 3, "셋이 기다린다")
	var taken: Dictionary = sim.take_by_hand(machine)
	_assert(int(taken.get(plate, 0)) == 3, "셋을 꺼냈다")
	_assert(int(sim.stock[plate]) == 5, "가방 2 → 5")
	_assert(machine.outbox.is_empty() and sim.output_waiting(machine) == 0, "기계는 비었다")
	_assert(not machine.stalled, "막혔다고 하지 않는다")
	_assert(int(sim.collected.get(plate, 0)) == collected, "번 것으로 다시 세지 않는다")
	_assert(sim.take_by_hand(machine).is_empty(), "빈 것은 아무것도 꺼내지 않는다")
	_assert(int(sim.stock[plate]) == 5, "가방도 그대로")
	sim.free()
