extends SceneTree

## The contract a non-square machine will be held to (Factory Interaction Pass
## 01). No machine today is non-square, so this test registers one -- a 4x6 with
## a belt's ports -- for the length of the test and nothing else:
##
##   - turned a quarter it covers 6x4 (Grid.rotated), anchored the same way;
##   - every port sits on the turned edge it names, the front output points where
##     it faces, and each side keeps its length (a whole side of 6 stays 6);
##   - `rotate_machine` moves it onto the new cells and the occupancy map follows
##     (no cell answers for it twice, none of the old cells still does);
##   - a turn whose new cells are taken is refused and nothing moves;
##   - four turns come back to the same footprint and ports.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_non_square_rotation_contract")
	else:
		print("FAIL test_non_square_rotation_contract (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


const FAKE := 990

func _register() -> void:
	var row: Dictionary = {"id": FAKE, "key": "test_4x6", "name": "시험 4x6", "short": "시험",
		"size": Vector2i(4, 6), "directional": true, "walkable": false, "ports": Defs.PORTS_THROUGH}
	Defs._machines_by_id[FAKE] = row
	Defs.DIRECTIONAL_MACHINES.append(FAKE)

func _unregister() -> void:
	Defs._machines_by_id.erase(FAKE)
	Defs.DIRECTIONAL_MACHINES.erase(FAKE)

func _test() -> void:
	_register()
	var sim: Sim = Factory.world()
	var anchor: Vector2i = Factory.at(sim, Vector2i(10, 10))
	var machine := Sim.Machine.new()
	machine.type = FAKE
	machine.cell = anchor
	machine.dir = Vector2i.RIGHT
	sim.add_machine(machine)
	var start_rect: Rect2i = sim.machine_rect(machine)
	var start_ports: Array[Dictionary] = sim.machine_ports(machine)
	_assert(start_rect.size == Vector2i(4, 6), "동향은 4x6")
	var rect: Rect2i = start_rect
	for turn in 4:
		_assert(sim.rotate_machine(anchor), "%d번째로 돌린다" % (turn + 1))
		var now: Rect2i = sim.machine_rect(machine)
		_assert(now.size == Grid.rotated(Vector2i(4, 6), machine.dir), "%s 는 %s 을 덮는다" % [machine.dir, now.size])
		var stale := 0
		for cell: Vector2i in Grid.cells_in(rect.merge(now)):
			var there: Sim.Machine = sim.machine_at(cell)
			if now.has_point(cell) and there != machine:
				stale += 1
			if not now.has_point(cell) and there == machine:
				stale += 1
		_assert(stale == 0, "%s: 점유 맵이 새 발자국과 같다 (%d건)" % [machine.dir, stale])
		var sides: Dictionary = {}
		for port: Dictionary in sim.machine_ports(machine):
			var d: Vector2i = port["dir"]
			var on_edge: bool = now.has_point(port["inside"]) and not now.has_point(port["outside"])
			_assert(on_edge, "%s: %s 포트는 가장자리에 있다" % [machine.dir, port["side"]])
			sides[port["side"]] = int(sides.get(port["side"], 0)) + 1
			if String(port["kind"]) == Defs.PORT_OUTPUT:
				_assert(d == machine.dir, "%s: 출력은 향하는 쪽" % machine.dir)
		# Front is one cell (the output); the whole back is the side 6 long, the
		# two sides 4 long, whichever way it faces.
		_assert(int(sides.get(Defs.SIDE_BACK, 0)) == 6 and int(sides.get(Defs.SIDE_LEFT, 0)) == 4
			and int(sides.get(Defs.SIDE_RIGHT, 0)) == 4, "%s: 면의 길이가 그대로다 (%s)" % [machine.dir, sides])
		rect = now
	_assert(sim.machine_rect(machine) == start_rect and sim.machine_ports(machine) == start_ports,
		"네 번 돌리면 발자국과 포트가 제자리다")
	# Something in the way of the turn: refused, nothing moves.
	var turned: Rect2i = Defs.machine_footprint(FAKE, anchor, Vector2i.DOWN)
	var blocker: Vector2i = Vector2i.ZERO
	for cell: Vector2i in Grid.cells_in(turned):
		if not start_rect.has_point(cell):
			blocker = cell
			break
	_assert(Factory.put(sim, Defs.M_BELT, blocker, Vector2i.RIGHT) != null, "돌아갈 자리에 벨트를 둔다")
	_assert(not sim.rotate_machine(anchor), "자리가 막히면 돌지 않는다")
	_assert(machine.dir == Vector2i.RIGHT and sim.machine_rect(machine) == start_rect,
		"그리고 아무것도 움직이지 않았다")
	sim.free()
	_unregister()
