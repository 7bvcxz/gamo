extends SceneTree

## World generation places every node once, of one type, and never writes a
## node over another (Factory Interaction Pass 01) -- over two hundred worlds.
##
## `put_ore` counts every node it replaces; after `setup` the count must be
## zero. Every node's four cells are one type (`ore_errors`), the pinned copper
## and iron patches are there and of their kind, and the same seed makes the
## same nodes of the same types twice.

var failures := 0

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _finish(name: String) -> void:
	if failures == 0:
		print("PASS %s" % name)
	else:
		print("FAIL %s (%d)" % [name, failures])
	quit(failures)

func _seams() -> Array[int]:
	var out: Array[int] = []
	for id: int in Defs.item_ids():
		if Defs.ore_output(id) >= 0:
			out.append(id)
	return out

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var overwritten := 0
	var broken := 0
	var copper_short := 0
	var iron_short := 0
	var stray := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(81000 + index)
		overwritten += sim.ore_overwrites
		broken += sim.ore_errors().size()
		var copper := 0
		var iron := 0
		for origin: Vector2i in sim.ore_nodes:
			var type: int = int(sim.ore_nodes[origin])
			if not Defs.ORE_TIERS.has(type):
				stray += 1
			var d: float = sim.ore_tiles_from_core(origin)
			if type == Defs.ITEM_COPPER and d >= Defs.FIRST_COPPER_BAND.x and d <= Defs.FIRST_COPPER_BAND.y:
				copper += 1
			if type == Defs.ITEM_IRON and d >= Defs.FIRST_IRON_BAND.x and d <= Defs.FIRST_IRON_BAND.y:
				iron += 1
		if copper < Defs.FIRST_COPPER_SIZE:
			copper_short += 1
		if iron < Defs.FIRST_IRON_SIZE:
			iron_short += 1
		if index < 20:
			var again := Sim.new()
			again.setup(81000 + index)
			if again.ore_nodes != sim.ore_nodes:
				_assert(false, "시드 %d: 같은 시드가 같은 노드를 만든다" % (81000 + index))
			again.free()
		sim.free()
	_assert(overwritten == 0, "200회차 생성에서 노드 위에 다른 노드를 쓴 일이 없다 (%d건)" % overwritten)
	_assert(broken == 0, "모든 노드의 네 칸이 한 종류다 (%d건)" % broken)
	_assert(stray == 0, "생성되는 노드는 광맥 사다리의 재료뿐이다 (%d건)" % stray)
	_assert(copper_short == 0, "첫 구리 띠에 구리 노드가 %d개 이상 (%d회 부족)" % [Defs.FIRST_COPPER_SIZE, copper_short])
	_assert(iron_short == 0, "첫 철 띠에 철 노드가 %d개 이상 (%d회 부족)" % [Defs.FIRST_IRON_SIZE, iron_short])
	_finish("test_ore_generation_does_not_overwrite_type")
