extends SceneTree

## A turned machine is fed at its turned back and pours at its turned front
## (Factory Interaction Pass 01): a powered manufacturer in each of the four
## directions, a belt of its ore into the back port and a belt away from the
## output port, run for real -- the product arrives on the output belt.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test(Vector2i.RIGHT)
	_test(Vector2i.DOWN)
	_test(Vector2i.LEFT)
	_test(Vector2i.UP)
	if failures == 0:
		print("PASS test_rotated_machine_belt_io")
	else:
		print("FAIL test_rotated_machine_belt_io (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _test(dir: Vector2i) -> void:
	var sim: Sim = Factory.world()
	Factory.power(sim)
	var anchor: Vector2i = Factory.at(sim, Vector2i(10, 10))
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, anchor, dir)
	_assert(machine != null, "제조기 %s" % dir)
	if machine == null:
		return
	var recipe: Dictionary = sim.recipe_of(machine)
	var wanted: int = int(recipe["inputs"][0]["item"])
	var made: int = int(recipe["outputs"][0]["item"])
	var back: Dictionary = {}
	for port: Dictionary in sim.machine_input_ports(machine):
		if String(port["side"]) == Defs.SIDE_BACK:
			back = port
			break
	var feed: Sim.Machine = Factory.put(sim, Defs.M_BELT, back["outside"], dir)
	var out: Dictionary = sim.machine_output_ports(machine)[0]
	var away: Sim.Machine = Factory.put(sim, Defs.M_BELT, out["outside"], dir)
	var beyond: Sim.Machine = Factory.put(sim, Defs.M_BELT, (out["outside"] as Vector2i) + dir, dir)
	_assert(feed != null and away != null and beyond != null, "%s: 앞뒤 벨트" % dir)
	var got := 0
	for step in 800:
		if feed.items.is_empty():
			feed.items.append({"type": wanted, "t": 0.0})
		sim.tick(0.05)
		for belt: Sim.Machine in [away, beyond]:
			for item: Dictionary in belt.items:
				if int(item["type"]) == made:
					got += 1
			belt.items.clear()
	_assert(got > 0, "%s: 돌린 방향의 출력 벨트로 %s%s 나왔다 (%d)" % [dir, Defs.item_name(made), Defs.subject(Defs.item_name(made)), got])
	sim.free()
