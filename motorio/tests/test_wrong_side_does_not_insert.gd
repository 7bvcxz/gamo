extends SceneTree

## The wrong side refuses (Factory Interaction Pass 01): a belt aimed at a
## manufacturer's output face, at a mining post, and at a splitter's side does not
## feed them -- the item stays on the belt and the belt says it is blocked. Every
## face used to take, so the output door was also an input door.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_front()
	_test_post()
	_test_splitter_side()
	if failures == 0:
		print("PASS test_wrong_side_does_not_insert")
	else:
		print("FAIL test_wrong_side_does_not_insert (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _test_front() -> void:
	var sim: Sim = Factory.world()
	Factory.power(sim)
	var anchor: Vector2i = Factory.at(sim, Vector2i(8, 8))
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, anchor, Vector2i.RIGHT)
	var wanted: int = int(sim.recipe_of(machine)["inputs"][0]["item"])
	var rect: Rect2i = sim.machine_rect(machine)
	# The front edge's other lane: not the output cell, still the output face.
	for y in range(rect.position.y, rect.end.y):
		var at := Vector2i(rect.end.x, y)
		if sim.machine_at(at) != null:
			continue
		var belt: Sim.Machine = Factory.put(sim, Defs.M_BELT, at, Vector2i.LEFT)
		_assert(belt != null, "앞면 %d 줄에 기계를 향한 벨트" % y)
		belt.items.append({"type": wanted, "t": 0.0})
	Factory.run(sim, 4.0)
	_assert(int(machine.buffer.get(wanted, 0)) == 0, "앞면으로는 한 개도 들어가지 않았다")
	_assert(not sim._accept_into(Vector2i(rect.end.x - 1, rect.position.y), wanted,
		Vector2i(rect.end.x, rect.position.y)), "앞에서 오는 것은 받지 않는다")
	_assert(sim._accept_into(Vector2i(rect.position.x, rect.position.y), wanted,
		Vector2i(rect.position.x - 1, rect.position.y)), "뒤에서 오는 것은 받는다")
	sim.free()

func _test_post() -> void:
	var sim: Sim = Factory.world()
	var node: Vector2i = Factory.at(sim, Vector2i(8, 16))
	sim.put_ore(node, Defs.ITEM_COPPER)
	var post: Sim.Machine = Factory.put(sim, Defs.M_MINER, node, Vector2i.RIGHT)
	var back := Vector2i(sim.machine_rect(post).position.x - 1, node.y)
	var belt: Sim.Machine = Factory.put(sim, Defs.M_BELT, back, Vector2i.RIGHT)
	belt.items.append({"type": Defs.ITEM_COPPER, "t": 0.0})
	Factory.run(sim, 4.0)
	# The belt only says "stalled" once it is full; one item that cannot leave
	# is simply still there.
	_assert(belt.items.size() == 1 and float(belt.items[0]["t"]) >= 1.0,
		"채굴기는 아무것도 받지 않고 벨트 끝에 그대로 있다")
	_assert(post.buffer.is_empty() and post.outbox.is_empty(), "채굴기 안에는 아무것도 없다")
	sim.free()

func _test_splitter_side() -> void:
	var sim: Sim = Factory.world()
	var hub: Vector2i = Factory.at(sim, Vector2i(16, 8))
	var splitter: Sim.Machine = Factory.put(sim, Defs.M_SPLITTER, hub, Vector2i.RIGHT)
	_assert(splitter != null, "분배기")
	_assert(not sim._push_into(hub, Defs.ITEM_COPPER, hub + Vector2i.UP), "옆(출력)에서는 받지 않는다")
	_assert(not sim._push_into(hub, Defs.ITEM_COPPER, hub + Vector2i.RIGHT), "앞에서도 받지 않는다")
	_assert(sim._push_into(hub, Defs.ITEM_COPPER, hub + Vector2i.LEFT), "뒤에서는 받는다")
	sim.free()
