extends SceneTree

## Turning a machine turns its ports (Factory Interaction Pass 01): for every
## machine with a facing and each of the four ways, the output points where it
## faces, the back input points the other way, the side inputs point across, and
## four quarter turns bring every port back to where it started.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test()
	if failures == 0:
		print("PASS test_ports_rotate_with_machine")
	else:
		print("FAIL test_ports_rotate_with_machine (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

static func _turn(dir: Vector2i) -> Vector2i:
	return Vector2i(-dir.y, dir.x)

func _test() -> void:
	for type: int in Defs.DIRECTIONAL_MACHINES:
		var name: String = Defs.machine_name(type)
		var start: Array[Dictionary] = []
		var dir := Vector2i.RIGHT
		for turn in 5:
			var rect: Rect2i = Defs.machine_footprint(type, Vector2i(40, 40), dir)
			var ports: Array[Dictionary] = Defs.resolve_ports(Defs.machine_port_specs(type), rect, dir)
			if turn == 0:
				start = ports
			if turn == 4:
				_assert(ports == start, "%s: 네 번 돌리면 포트가 제자리다" % name)
				break
			for port: Dictionary in ports:
				var side: String = String(port["side"])
				_assert(port["dir"] == Defs.side_dir(side, dir),
					"%s %s: %s 면은 %s 쪽을 향한다" % [name, dir, side, Defs.side_dir(side, dir)])
				if side == Defs.SIDE_FRONT and String(port["kind"]) == Defs.PORT_OUTPUT:
					_assert(port["dir"] == dir, "%s %s: 출력은 앞" % [name, dir])
				if side == Defs.SIDE_BACK:
					_assert(port["dir"] == -dir, "%s %s: 뒤는 반대쪽" % [name, dir])
			dir = _turn(dir)
