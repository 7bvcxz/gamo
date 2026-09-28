extends SceneTree

## One post, one seam; many posts, many seams, working at once.
##
## A field of seven nodes ORE_PITCH apart carries seven posts side by side, and
## seven cats work them in parallel: each post mines its own node and nothing
## else, each cat stands at its own post, and seven posts together produce
## seven times what one does.

var failures := 0

const SITE := Vector2i(36, 12)
const FIELD := 7
## Four kinds in turn, so a post handing out its neighbour's ore would show.
const KINDS: Array[int] = [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON, Defs.ITEM_CRYSTAL]
const SECONDS := 240.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Each kind digs at its own pace, so each post is measured against a lone
	# post on the same kind of seam.
	var alone: Dictionary = {}
	for kind: int in KINDS:
		alone[kind] = float(_produce(1, kind)["total"])
		_assert(float(alone[kind]) > 0.0, "%s 채굴기 하나가 광석을 낸다 (%.0f개)"
			% [Defs.ITEM_NAMES[kind], alone[kind]])
	var field: Dictionary = _produce(FIELD)
	var per_post: Dictionary = field["per_post"]
	_assert(per_post.size() == FIELD, "일곱 채굴기가 모두 낸다 (%d)" % per_post.size())
	var behind := 0
	var expected := 0.0
	for index in FIELD:
		var kind: int = KINDS[index % KINDS.size()]
		expected += float(alone[kind])
	for seam: Vector2i in per_post:
		var kind: int = int(field["kinds"][seam])
		if float(per_post[seam]) < float(alone[kind]) - 1.0:
			behind += 1
			print("    %s: %d vs %.0f alone" % [seam, per_post[seam], alone[kind]])
	_assert(behind == 0, "나란히 선 채굴기 모두가 혼자일 때만큼 낸다 (%d개 뒤처짐)" % behind)
	_assert(float(field["total"]) >= expected - float(FIELD),
		"일곱이 함께 낸 양이 각자 혼자 낸 양의 합이다 (%.0f vs %.0f)" % [field["total"], expected])
	_assert(int(field["wrong"]) == 0, "어느 채굴기도 이웃 광맥의 광석을 내지 않는다 (%d개)" % int(field["wrong"]))
	if failures == 0:
		print("PASS test_mining_post_targets_one_ore")
	else:
		print("FAIL test_mining_post_targets_one_ore (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## Builds `count` posts along a row of seams and staffs each; returns what came
## out of each post's output cell, emptied every tick the way a belt would.
func _produce(count: int, only: int = -1) -> Dictionary:
	var sim := Sim.new()
	sim.setup(4242)
	sim.unlocked[Defs.M_MINER] = true
	for item: int in KINDS:
		sim.stock[item] = 500
	sim.cats.clear()
	var origin: Vector2i = sim.core_cell + SITE
	var area := Rect2i(origin - Vector2i(6, 8), Vector2i(Defs.ORE_PITCH * FIELD + 12, 18))
	for cell: Vector2i in Grid.cells_in(area):
		sim.erase_ore_at(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for key: Vector2i in props.keys():
			if sim.prop_rect(key).intersects(area):
				props.erase(key)
	var seams: Array[Vector2i] = []
	for index in count:
		var seam: Vector2i = origin + Vector2i(index * Defs.ORE_PITCH, 0)
		sim.put_ore(seam, only if only >= 0 else KINDS[index % KINDS.size()])
		seams.append(seam)
	var outputs: Dictionary = {}
	for seam: Vector2i in seams:
		if not sim.build(Defs.M_MINER, seam, Vector2i.DOWN):
			_assert(false, "%s 에 채굴기가 선다: %s" % [seam, sim.can_build(Defs.M_MINER, seam, Vector2i.DOWN)])
			continue
		outputs[sim.output_cell(sim.machine_at(seam))] = seam
	if count > 1:
		_assert(outputs.size() == count, "채굴기 %d개가 나란히 선다" % count)
		# Seven four-by-fours, edge to edge, and no cell claimed twice.
		var claimed: Dictionary = {}
		var twice := 0
		for seam: Vector2i in seams:
			for cell: Vector2i in Grid.cells_in(sim.machine_rect(sim.machine_at(seam))):
				if claimed.has(cell):
					twice += 1
				claimed[cell] = seam
		_assert(twice == 0, "어느 칸도 두 채굴기에 속하지 않는다")
	# One cat to each, put down through the post's far corner rather than the
	# seam: any cell of a post means that post.
	sim.grant_cats(count)
	for index in count:
		var seam: Vector2i = seams[index]
		var corner: Vector2i = sim.machine_rect(sim.machine_at(seam)).end - Vector2i.ONE
		sim.carried_cat = sim.cats[index]
		_assert(sim.place_cat(corner), "고양이를 %s 채굴기에 둔다" % seam)
		_assert(sim.cats[index].assigned == seam, "그 고양이는 그 광맥의 채굴기에 배정된다")
	if count > 1:
		# A second cat on a staffed post is refused.
		sim.grant_cats(1)
		sim.carried_cat = sim.cats[count]
		_assert(not sim.place_cat(seams[0]), "이미 고양이가 있는 채굴기에는 둘째를 둘 수 없다")
		sim.drop_cat(Grid.centre(seams[0] + Vector2i(0, -6)))
		sim.cats.remove_at(count)
		# Each cat stands on its own post (World Visual Pass 01).
		var spots: Dictionary = {}
		for cat: Sim.Cat in sim.cats:
			var rect: Rect2i = sim.machine_rect(sim.machine_at(cat.assigned))
			var feet: Vector2 = cat.pos + Vector2(0.0, Defs.CAT_FOOT_DROP)
			_assert(Grid.rect_px(rect).has_point(feet), "고양이는 제 채굴기 위에 선다")
			spots[sim.cell_of(cat.pos)] = true
		_assert(spots.size() == count, "일곱 마리가 일곱 자리에 선다 (%d)" % spots.size())
	var per_post: Dictionary = {}
	var kinds: Dictionary = {}
	for seam: Vector2i in seams:
		kinds[seam] = sim.ore_type_at(seam)
	var wrong := 0
	var total := 0.0
	var step := 0.1
	for _tick in int(SECONDS / step):
		sim.tick(step)
		for cell: Vector2i in sim.ground.keys():
			if not outputs.has(cell):
				continue
			var seam: Vector2i = outputs[cell]
			if int(sim.ground[cell]) != sim.ore_type_at(seam):
				wrong += 1
			per_post[seam] = int(per_post.get(seam, 0)) + 1
			total += 1.0
			sim.ground.erase(cell)
	sim.free()
	return {"total": total, "per_post": per_post, "wrong": wrong, "kinds": kinds}
