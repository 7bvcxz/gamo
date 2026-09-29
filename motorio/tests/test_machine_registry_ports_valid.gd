extends SceneTree

## Every machine row says where it takes in and puts out, and what it says makes
## sense (Factory Interaction Pass 01): real kinds and sides, a post that takes
## nothing and pours at one place, a generator with no output, a splitter with one
## way in and two out, and -- resolved on a real footprint in every direction --
## ports that sit on the edge, meet a cell outside it, and never share a cell
## between an input and an output.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rows()
	_test_resolved()
	if failures == 0:
		print("PASS test_machine_registry_ports_valid")
	else:
		print("FAIL test_machine_registry_ports_valid (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

func _test_rows() -> void:
	for row: Dictionary in Defs.MACHINES:
		var type: int = int(row["id"])
		var name: String = Defs.machine_name(type)
		var specs: Array = Defs.machine_port_specs(type)
		_assert(not specs.is_empty(), "%s 행에 포트가 있다" % name)
		var ins := 0
		var outs := 0
		for spec: Dictionary in specs:
			var kind: String = String(spec.get("kind", ""))
			_assert(kind in [Defs.PORT_INPUT, Defs.PORT_OUTPUT], "%s: 종류가 입력 또는 출력 (%s)" % [name, kind])
			_assert(String(spec.get("side", "")) in Defs.SIDES, "%s: 면이 앞·뒤·왼·오른쪽 중 하나" % name)
			if kind == Defs.PORT_INPUT:
				ins += 1
			else:
				outs += 1
		if Defs.machine_mines(type):
			_assert(ins == 0 and outs == 1, "%s: 입력 없음, 출력 하나 (%d/%d)" % [name, ins, outs])
		elif type == Defs.M_GENERATOR:
			_assert(ins > 0 and outs == 0, "발전기: 입력만 있다")
		elif type == Defs.M_SPLITTER:
			_assert(ins == 1 and outs == 2, "분배기: 하나 들어와 둘로 나간다")
		elif type == Defs.M_CORE:
			_assert(ins == 4 and outs == 0, "기지: 사방이 반입구다")
		else:
			_assert(ins >= 1 and outs == 1, "%s: 입력이 있고 출력은 하나" % name)

func _test_resolved() -> void:
	var bad_edge := 0
	var bad_outside := 0
	var shared := 0
	var checked := 0
	for row: Dictionary in Defs.MACHINES:
		var type: int = int(row["id"])
		for dir: Vector2i in DIRS:
			var rect: Rect2i = Defs.machine_footprint(type, Vector2i(40, 40), dir)
			var ports: Array[Dictionary] = Defs.resolve_ports(Defs.machine_port_specs(type), rect, dir)
			var inside_in: Dictionary = {}
			for port: Dictionary in ports:
				checked += 1
				var inside: Vector2i = port["inside"]
				var outside: Vector2i = port["outside"]
				if not rect.has_point(inside) or rect.grow(-1).has_point(inside):
					bad_edge += 1
				if rect.has_point(outside) or Grid.steps(inside, outside) != 1 \
						or inside + (port["dir"] as Vector2i) != outside:
					bad_outside += 1
				if String(port["kind"]) == Defs.PORT_INPUT:
					inside_in[[inside, outside]] = true
			for port: Dictionary in ports:
				if String(port["kind"]) == Defs.PORT_OUTPUT and inside_in.has([port["inside"], port["outside"]]):
					shared += 1
	_assert(checked > 0, "포트 칸 %d개를 봤다" % checked)
	_assert(bad_edge == 0, "모든 포트가 발자국 가장자리 칸에 있다 (%d건)" % bad_edge)
	_assert(bad_outside == 0, "모든 포트가 발자국 바로 바깥 칸과 맞닿는다 (%d건)" % bad_outside)
	_assert(shared == 0, "입력과 출력이 같은 자리를 쓰지 않는다 (%d건)" % shared)
