extends SceneTree

## A mining post stands on a seam: its ORE_ANCHOR cell -- (1,1) of the four by
## four -- must be a seam, and no other cell of it may be one.
##
## Checked on the rules (`can_build`), on the build, and on the hand: aiming the
## gun at any cell near a seam puts the post's anchor on the seam itself, never
## a cell off it.

var failures := 0

const SITE := Vector2i(36, 0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rules()
	_test_every_seam_cell_kind()
	await _test_aimed()
	if failures == 0:
		print("PASS test_mining_post_requires_valid_ore_anchor")
	else:
		print("FAIL test_mining_post_requires_valid_ore_anchor (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	sim.unlocked[Defs.M_MINER] = true
	sim.unlocked[Defs.M_MINER_MK2] = true
	sim.unlocked[Defs.M_BELT] = true
	for item: int in [Defs.ITEM_CRYSTAL, Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 500
	return sim

func _clear(sim: Sim, rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.ore.erase(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)

func _test_rules() -> void:
	var sim := _sim()
	var seam: Vector2i = sim.core_cell + SITE
	_clear(sim, Rect2i(seam - Vector2i(8, 8), Vector2i(17, 17)))
	# Bare ground: refused, and the reason names the seam.
	_assert(sim.can_build(Defs.M_MINER, seam) == "광맥 위에만 설치할 수 있습니다",
		"맨땅에는 채굴기를 지을 수 없다")
	_assert(not sim.build(Defs.M_MINER, seam, Vector2i.RIGHT), "짓기도 거부된다")
	sim.ore[seam] = Defs.ITEM_CRYSTAL
	_assert(sim.can_build(Defs.M_MINER, seam) == "", "광맥 위에는 지을 수 있다")
	# A seam off the anchor but inside the footprint: the post would mine one
	# and bury the other.
	var rect: Rect2i = Defs.machine_footprint(Defs.M_MINER, seam)
	var buried := 0
	for covered: Vector2i in Grid.cells_in(rect):
		if covered == seam:
			continue
		sim.ore[covered] = Defs.ITEM_COPPER
		if sim.can_build(Defs.M_MINER, seam) == "다른 광맥이 겹칩니다":
			buried += 1
		sim.ore.erase(covered)
	_assert(buried == 15, "나머지 15칸 중 어디에 광맥이 있어도 거부된다 (%d)" % buried)
	# The anchor is the seam, whichever cell of the footprint the post is aimed
	# through: a cell of the footprint that is not the seam is not an anchor.
	for covered: Vector2i in Grid.cells_in(rect):
		if covered == seam:
			continue
		if sim.can_build(Defs.M_MINER, covered) == "":
			_assert(false, "광맥이 아닌 칸 %s 을 앵커로 지을 수 있다" % covered)
			break
	# Built, the post and the seam are one: the post's anchor is the seam.
	_assert(sim.build(Defs.M_MINER, seam, Vector2i.RIGHT), "짓는다")
	var post: Sim.Machine = sim.machine_at(seam)
	_assert(post.cell == seam, "채굴기의 앵커 칸은 광맥이다")
	_assert(sim.machine_rect(post).position + Vector2i(1, 1) == seam, "발자국의 (1,1)")
	# Not a belt: a seam is not a floor to lay one on.
	var other: Vector2i = seam + Vector2i(0, 10)
	sim.ore[other] = Defs.ITEM_CRYSTAL
	_assert(sim.can_build(Defs.M_BELT, other) == "광맥 위에는 설치할 수 없습니다",
		"광맥 위에 벨트는 놓지 못한다")
	sim.free()

## Every kind of seam takes a post, and every kind of mining machine asks it.
func _test_every_seam_cell_kind() -> void:
	var sim := _sim()
	var seam: Vector2i = sim.core_cell + SITE + Vector2i(0, 20)
	_clear(sim, Rect2i(seam - Vector2i(8, 8), Vector2i(17, 17)))
	for type: int in [Defs.M_MINER, Defs.M_MINER_MK2]:
		for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON, Defs.ITEM_CRYSTAL]:
			sim.ore[seam] = item
			_assert(sim.footprint_problems(type, seam).is_empty(),
				"%s 는 %s 광맥을 앵커로 받는다" % [Defs.MACHINE_NAMES[type], Defs.ITEM_NAMES[item]])
		sim.ore.erase(seam)
		_assert(sim.footprint_problems(type, seam).get(seam, "") == "광맥 위에만 설치할 수 있습니다",
			"%s 도 맨땅은 거부한다" % Defs.MACHINE_NAMES[type])
	sim.free()

## From the hand: facing a seam from anywhere she can reach it, the gun's anchor
## is the seam.
func _test_aimed() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var sim: Sim = main.sim
	sim.has_gun = true
	sim.unlocked[Defs.M_MINER] = true
	for item: int in [Defs.ITEM_CRYSTAL, Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 500
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	main.selected_index = Defs.BUILDABLE.find(Defs.M_MINER)
	var seam: Vector2i = sim.core_cell + SITE
	_clear(sim, Rect2i(seam - Vector2i(10, 10), Vector2i(21, 21)))
	sim.ore[seam] = Defs.ITEM_CRYSTAL
	var rect: Rect2i = Defs.machine_footprint(Defs.M_MINER, seam)
	var aimed := 0
	var tried := 0
	# From each side, and up to twelve pixels off the seam's line: her reach is a
	# tile wide, as the old front cell was, so anywhere in that band aims at it.
	var middle: Vector2 = Grid.centre(seam)
	var span: Rect2 = Grid.rect_px(rect)
	var stands: Array = [
		[Vector2(middle.x, span.end.y + 9.0), Vector2i.UP],
		[Vector2(middle.x + 12.0, span.end.y + 9.0), Vector2i.UP],
		[Vector2(middle.x - 12.0, span.end.y + 9.0), Vector2i.UP],
		[Vector2(middle.x, span.position.y - 9.0), Vector2i.DOWN],
		[Vector2(span.position.x - 9.0, middle.y), Vector2i.RIGHT],
		[Vector2(span.position.x - 9.0, middle.y + 12.0), Vector2i.RIGHT],
		[Vector2(span.end.x + 9.0, middle.y - 12.0), Vector2i.LEFT],
	]
	for stand: Array in stands:
		main.player.position = stand[0]
		main.player.facing = stand[1]
		tried += 1
		if main.build_anchor(Defs.M_MINER) == seam:
			aimed += 1
		else:
			print("    %s facing %s aims at %s" % [stand[0], stand[1], main.build_anchor(Defs.M_MINER)])
	_assert(aimed == tried, "사방 어디서 겨눠도 앵커는 광맥 칸이다 (%d/%d)" % [aimed, tried])
	# Past her reach the gun does not slide the post over onto the seam, and it
	# does not put one down off it either: the ghost is red.
	main.player.position = Vector2(middle.x + 20.0, span.end.y + 9.0)
	main.player.facing = Vector2i.UP
	var off: Vector2i = main.build_anchor(Defs.M_MINER)
	_assert(off != seam, "손이 닿지 않는 줄의 광맥은 겨누지 않는다")
	_assert(sim.can_build(Defs.M_MINER, off, main.build_dir, main.body_cells()) != "",
		"그리고 그 자리는 거부된다 — 광맥 밖에 채굴기가 서지 않는다")
	main.queue_free()
	await process_frame
