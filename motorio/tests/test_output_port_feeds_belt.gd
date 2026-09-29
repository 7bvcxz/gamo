extends SceneTree

## What a machine makes goes onto the belt at its output port (Factory
## Interaction Pass 01): a manufacturer with a finished part and a belt leading
## away from its output port hands it over, and a post with a cat pours onto the
## belt at its port.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_manufacturer()
	_test_post()
	if failures == 0:
		print("PASS test_output_port_feeds_belt")
	else:
		print("FAIL test_output_port_feeds_belt (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _test_manufacturer() -> void:
	var sim: Sim = Factory.world()
	var anchor: Vector2i = Factory.at(sim, Vector2i(8, 8))
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, anchor, Vector2i.DOWN)
	_assert(machine != null, "제조기(남향)")
	if machine == null:
		return
	var port: Dictionary = sim.machine_output_ports(machine)[0]
	var belt: Sim.Machine = Factory.put(sim, Defs.M_BELT, port["outside"], Vector2i.DOWN)
	_assert(belt != null, "출력 포트 앞에 벨트")
	machine.outbox[Defs.ITEM_IRON_PLATE] = 1
	sim._drain_outbox(machine)
	_assert(machine.outbox.is_empty(), "산출이 나갔다")
	_assert(belt.items.size() == 1 and int(belt.items[0]["type"]) == Defs.ITEM_IRON_PLATE,
		"출력 포트의 벨트에 올라갔다")
	sim.free()

func _test_post() -> void:
	var sim: Sim = Factory.world()
	var node: Vector2i = Factory.at(sim, Vector2i(8, 16))
	sim.put_ore(node, Defs.ITEM_COPPER)
	var post: Sim.Machine = Factory.put(sim, Defs.M_MINER, node, Vector2i.LEFT)
	_assert(post != null, "채굴기(서향)")
	if post == null:
		return
	var port: Dictionary = sim.machine_output_ports(post)[0]
	var belt: Sim.Machine = Factory.put(sim, Defs.M_BELT, port["outside"], Vector2i.UP)
	_assert(belt != null, "채굴기 출력 포트에 벨트")
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[sim.cats.size() - 1]
	sim.place_cat(node)
	var seen := 0
	for step in 400:
		sim.tick(0.1)
		seen += belt.items.size()
		belt.items.clear()
	_assert(seen > 0, "채굴기가 출력 포트의 벨트에 구리를 올렸다 (%d)" % seen)
	sim.free()
