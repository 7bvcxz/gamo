extends SceneTree

## Where a cat works a post is on the post, and it is data (World Visual Pass 01).
##
## Each rig's row in `Defs.MACHINES` carries `work_anchor`: where the working
## cat's feet stand, in cells from the footprint's top-left. It lies inside the
## footprint for every rig, in every direction; `Sim.work_point` reads it and
## nothing hardcodes it; and on a bare node the cat digs standing on the node.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_the_data()
	_test_every_rig_every_way()
	_test_bare_node()
	if failures == 0:
		print("PASS test_cat_work_anchor_is_inside_post")
	else:
		print("FAIL test_cat_work_anchor_is_inside_post (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_the_data() -> void:
	for type: int in Defs.MINER_MACHINES:
		var row: Dictionary = Defs.machine(type)
		_assert(row.has("work_anchor"), "%s 의 표에 work_anchor 가 있다" % Defs.MACHINE_NAMES[type])
		var anchor: Vector2 = Defs.machine_work_anchor(type)
		var size := Vector2(Defs.machine_size(type))
		_assert(anchor.x > 0.0 and anchor.y > 0.0 and anchor.x < size.x and anchor.y < size.y,
			"%s 의 work_anchor %s 는 발자국 %s 안이다" % [Defs.MACHINE_NAMES[type], anchor, size])

func _test_every_rig_every_way() -> void:
	for type: int in Defs.MINER_MACHINES:
		for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var sim := Sim.new()
			sim.setup(4242)
			sim.clear_ore()
			var node: Vector2i = sim.core_cell + Vector2i(30, 10)
			sim.put_ore(node, Defs.ITEM_HEATSTONE)
			var post := Sim.Machine.new()
			post.type = type
			post.cell = node
			post.dir = dir
			sim.add_machine(post)
			var rect := Grid.rect_px(sim.machine_rect(post))
			var feet: Vector2 = sim.work_point(node)
			var label: String = "%s %s" % [Defs.MACHINE_NAMES[type], dir]
			_assert(rect.grow(-1.0).has_point(feet), "%s: 발은 채굴기 위 %s (발자국 %s)" % [label, feet, rect])
			_assert(sim.post_stand(node) == feet - Vector2(0.0, Defs.CAT_FOOT_DROP),
				"%s: 서는 점은 발에서 몸통 높이만큼 위다" % label)
			_assert(sim.work_point(node + Vector2i(1, 1)) == feet, "%s: 어느 칸으로 물어도 같은 자리다" % label)
			# From the table, not written in: the point moves with the row.
			var expected: Vector2 = rect.position + Defs.machine_work_anchor(type) * float(Grid.CELL)
			_assert(feet.is_equal_approx(expected), "%s: 표의 work_anchor 에서 나온 자리다" % label)
			sim.free()

func _test_bare_node() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.clear_ore()
	var node: Vector2i = sim.core_cell + Vector2i(30, 10)
	sim.put_ore(node, Defs.ITEM_COPPER)
	var feet: Vector2 = sim.work_point(node)
	_assert(Grid.rect_px(Sim.ore_rect(node)).grow(-1.0).has_point(feet), "맨 노드에서는 노드 위에 서서 판다")
	_assert(sim.work_point(node + Vector2i(1, 0)) == feet, "노드의 어느 칸으로 물어도 같은 자리다")
	sim.free()
