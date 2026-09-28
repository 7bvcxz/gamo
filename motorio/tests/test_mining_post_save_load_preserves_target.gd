extends SceneTree

## A run saved before ore nodes (schema 12) comes back with every post on the
## node it worked, putting out what it put out (World Visual Pass 01).
##
## `fixtures/save_v12.cfg` was written by 1.0.43, the last schema-12 build: a
## heat stone post on the middle starter seam feeding a belt into the base, a
## copper post, an iron Mk.2, a generator and three cats at work. In 1.0.43 a
## post was four cells by four with its seam at (1, 1); now it is two by two
## exactly over its node, whose origin is where the seam was. So loading must:
## keep the file (copied aside, byte for byte), keep every post on its node with
## the same material, keep its cat, and keep the belt line carrying -- the post's
## front edge moved a cell in, and the cell between it and the old belt is
## bridged rather than left as a gap that drops everything on the snow.

const FIXTURE := "res://tests/fixtures/save_v12.cfg"

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	_test_v12_posts()
	main.clear_save()
	var backup: String = main.backup_path(0, 12)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	main.free()
	if failures == 0:
		print("PASS test_mining_post_save_load_preserves_target")
	else:
		print("FAIL test_mining_post_save_load_preserves_target (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_v12_posts() -> void:
	var original: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE)
	_assert(not original.is_empty(), "v12 고정 세이브를 읽는다")
	var file := FileAccess.open(main.slot_path(0), FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	_assert(main.load_game(), "v12 세이브가 새 게임이 아니라 그 회차로 열린다")
	var backup: String = main.backup_path(0, 12)
	_assert(FileAccess.get_file_as_bytes(backup) == original, "원본은 바이트 그대로 따로 보관된다")
	var sim: Sim = main.sim
	var core: Vector2i = sim.core_cell
	# What the v12 world had under each post (read off 1.0.43 when the fixture
	# was written).
	var expected: Dictionary = {
		core + Vector2i(1, 8): [Defs.M_MINER, Defs.ITEM_HEATSTONE],
		Vector2i(-19, -12): [Defs.M_MINER, Defs.ITEM_COPPER],
		Vector2i(41, 2): [Defs.M_MINER_MK2, Defs.ITEM_IRON],
	}
	for node: Vector2i in expected:
		var type: int = int(expected[node][0])
		var kind: int = int(expected[node][1])
		var post: Sim.Machine = sim.machines.get(node, null)
		var name: String = "%s(%s)" % [Defs.MACHINE_NAMES[type], Defs.ITEM_NAMES[kind]]
		_assert(post != null and post.type == type, "%s 가 제자리에 있다" % name)
		if post == null:
			continue
		_assert(post.ore_node == node and sim.ore_origin_at(node) == node,
			"%s 의 목표 노드가 그 광맥이다" % name)
		_assert(sim.ore_type_at(node) == kind, "%s 밑은 여전히 %s 다" % [name, Defs.ITEM_NAMES[kind]])
		_assert(sim.machine_rect(post) == Sim.ore_rect(node), "%s 는 이제 노드 위 2×2 다" % name)
		var staffed := false
		for cat: Sim.Cat in sim.cats:
			if cat.assigned == node:
				staffed = true
		_assert(staffed, "%s 의 고양이가 그대로 배정되어 있다" % name)
		for cat: Sim.Cat in sim.cats:
			if cat.assigned == node and cat.state == Defs.CAT_WORKING:
				_assert(Grid.rect_px(sim.machine_rect(post)).has_point(cat.pos + Vector2(0.0, Defs.CAT_FOOT_DROP)),
					"%s 의 고양이는 이제 채굴기 위에서 일한다" % name)
	# The line into the base still carries: heat stone reaches the fire.
	var bridge: Sim.Machine = sim.machine_at(core + Vector2i(1, 7))
	_assert(bridge != null and bridge.type == Defs.M_BELT and bridge.dir == Vector2i.UP,
		"채굴기 출구와 옛 벨트 사이 한 칸이 벨트로 이어진다")
	var before: int = int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) + sim.stones_in
	main.player.position = sim.core_centre() + Vector2(-80.0, 0.0)
	var copper_out: Dictionary = {}
	var copper: Sim.Machine = sim.machines.get(Vector2i(-19, -12), null)
	for step in int(45.0 * 30.0):
		main.player.warmth = 100.0
		main._process_play(1.0 / 30.0)
		if copper != null:
			var at: Vector2i = sim.output_cell(copper)
			if sim.ground.has(at):
				copper_out[int(sim.ground[at])] = true
				sim.ground.erase(at)
				sim.ground_stack.erase(at)
	var after: int = int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) + sim.stones_in
	_assert(after > before, "벨트로 열석이 기지에 닿는다 (%d -> %d)" % [before, after])
	_assert(copper_out.keys() == [Defs.ITEM_COPPER] or copper_out.is_empty(),
		"구리 채굴기는 구리 말고 아무것도 내지 않는다 (%s)" % str(copper_out.keys()))
