extends SceneTree

## Where a manufacturer facing east takes in, as world cells (Factory Interaction
## Pass 01): the whole west edge and the whole north and south edges, each met
## from the cell just outside -- and not the east edge, which is its output side.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_input_port_world_position")
	else:
		print("FAIL test_input_port_world_position (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _test() -> void:
	var sim: Sim = Factory.world()
	var anchor: Vector2i = Factory.at(sim, Vector2i(6, 6))
	var machine: Sim.Machine = Factory.put(sim, Defs.M_MANUFACTURER, anchor, Vector2i.RIGHT)
	_assert(machine != null, "제조기를 동쪽으로 짓는다")
	if machine == null:
		return
	var rect: Rect2i = sim.machine_rect(machine)
	var outside: Dictionary = {}
	for port: Dictionary in sim.machine_input_ports(machine):
		outside[port["outside"]] = port["inside"]
	var want: Dictionary = {}
	for y in range(rect.position.y, rect.end.y):
		want[Vector2i(rect.position.x - 1, y)] = Vector2i(rect.position.x, y)
	for x in range(rect.position.x, rect.end.x):
		want[Vector2i(x, rect.position.y - 1)] = Vector2i(x, rect.position.y)
		want[Vector2i(x, rect.end.y)] = Vector2i(x, rect.end.y - 1)
	_assert(outside == want, "입력은 서·북·남 가장자리 전부다 (%s)" % str(outside.keys()))
	for y in range(rect.position.y, rect.end.y):
		_assert(sim.machine_port_at(machine, Vector2i(rect.end.x, y), Defs.PORT_INPUT).is_empty(),
			"동쪽(출력 면) %d 줄에는 입력이 없다" % y)
	_assert(sim.port_world_cell(sim.machine_input_ports(machine)[0]) == sim.machine_input_ports(machine)[0]["outside"],
		"port_world_cell 은 벨트가 서는 바깥 칸이다")
	sim.free()
