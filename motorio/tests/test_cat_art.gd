extends SceneTree

## What the world layer draws over the ground: the food count, and the animals.
##
## None of this can be judged from a screenshot at the size the game draws it --
## a cat standing three pixels off the centre of its tile and a cat standing on
## it look the same at 44 pixels -- so the decisions are asked as questions here
## rather than looked for by eye.

const MachineLayerScript := preload("res://scripts/MachineLayer.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_food_count()
	_test_tool_belongs_to_the_machine()
	_test_working_cat_stands_on_the_middle()
	_test_kit_art()
	if failures == 0:
		print("CAT_ART: PASS")
	else:
		print("CAT_ART: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _layer(sim: Sim) -> Node2D:
	var layer: Node2D = MachineLayerScript.new()
	layer.sim = sim
	return layer

# --- The number belongs to the bin --------------------------------------------

func _test_food_count() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.carried_kit = Defs.KIT_BASE
	sim.place_base(sim.core_cell)
	var layer: Node2D = _layer(sim)
	_assert(not sim.food_placed, "새 게임에는 사료 상자가 없다")
	# It was drawn anyway. The bin stopped being placed at the start in 0.20.74
	# and the count did not stop with it, so a bare 200 floated in the snow with
	# nothing under it to say what it counted.
	_assert(not layer.shows_food_count(), "그래서 개수도 그리지 않는다")
	sim.food_placed = true
	_assert(layer.shows_food_count(), "상자를 세우면 그때 개수가 붙는다")
	layer.free()
	sim.free()

# --- The drill belongs to the machine -----------------------------------------

func _test_tool_belongs_to_the_machine() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) == Defs.ITEM_HEATSTONE:
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "광맥을 찾았다")
	sim.grant_cats(2)
	var bare: Sim.Cat = sim.cats[0]

	# On open ore the cat digs with its paws. Both cases are CAT_WORKING, and the
	# drawing side asking the state alone put a drill in the paws of a cat that
	# does not have one -- which hid the whole reason to build the machine.
	sim.carried_cat = bare
	_assert(sim.place_cat(seam), "맨 광맥에 고양이를 놓는다")
	_assert(bare.state == Defs.CAT_WORKING, "고양이가 일한다")
	_assert(not sim.cat_has_tool(bare), "그런데 도구는 들지 않는다")

	# Build the miner under it and the drill appears, because the drill is the
	# machine's.
	_assert(sim.build(Defs.M_MINER, seam, Vector2i.UP), "그 자리에 채굴기를 세운다")
	_assert(sim.cat_has_tool(bare), "이제 도구를 든다")

	# And nothing else in the game gets one.
	var idle: Sim.Cat = sim.cats[1]
	_assert(not sim.cat_has_tool(idle), "노는 고양이는 들지 않는다")
	idle.state = Defs.CAT_HAUL_TO_BASE
	_assert(not sim.cat_has_tool(idle), "나르는 고양이도 들지 않는다")
	_assert(not sim.cat_has_tool(null), "고양이가 없으면 물어도 안전하다")
	sim.free()

# --- Feet on the middle, not the torso ----------------------------------------

func _test_working_cat_stands_on_the_middle() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	var seam := Vector2i(9999, 9999)
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) == Defs.ITEM_HEATSTONE:
			seam = cell
			break
	sim.grant_cats(1)
	var cat: Sim.Cat = sim.cats[0]
	sim.carried_cat = cat
	_assert(sim.place_cat(seam), "광맥에 고양이를 놓는다")

	# A cat's position is its torso; the drawing puts its feet CAT_FOOT_DROP below
	# it. Placed at the middle of the tile, the animal stands a third of a tile
	# south of the thing it is working -- 19 pixels on screen at full zoom.
	var feet: Vector2 = cat.pos + Vector2(0.0, Defs.CAT_FOOT_DROP)
	var middle: Vector2 = sim.cell_centre(seam)
	_assert(feet.distance_to(middle) < 0.01,
		"발이 칸 한가운데를 딛는다: %.1fpx 어긋남" % feet.distance_to(middle))

	# And it stays there after walking back, or a cat carried in would sit right
	# once and drop ten pixels the first time it came home from lunch.
	cat.state = Defs.CAT_TO_MINER
	cat.pos = sim.cell_centre(seam) + Vector2(0.0, 60.0)
	cat.path.clear()
	cat.path_goal = Vector2(9999.0, 9999.0)
	var guard := 0
	while cat.state != Defs.CAT_WORKING and guard < 600:
		sim.tick(0.05)
		guard += 1
	_assert(cat.state == Defs.CAT_WORKING, "걸어와서 다시 일한다")
	var walked: Vector2 = cat.pos + Vector2(0.0, Defs.CAT_FOOT_DROP)
	_assert(walked.distance_to(middle) < 0.01,
		"걸어온 뒤에도 같은 자리다: %.1fpx 어긋남" % walked.distance_to(middle))
	sim.free()

# --- The case, and what comes out of it ----------------------------------------

func _test_kit_art() -> void:
	# Three pictures, and each one a real texture rather than a preload that
	# resolved to null: a missing sheet draws nothing at all, which on a snowfield
	# looks exactly like a crate that has not spawned yet.
	for art: Texture2D in [MachineLayerScript.KIT_ART, MachineLayerScript.KIT_BASE_ART,
			MachineLayerScript.KIT_SHELTER_ART]:
		_assert(art != null and art.get_width() > 0, "키트 그림이 실제로 있다")
	# One tile. The crate is a one-by-one thing standing in the snow and the game
	# reads it against the grid.
	_assert(is_equal_approx(MachineLayerScript.KIT_DRAW, float(Defs.TILE)),
		"닫힌 케이스가 정확히 한 칸이다: %.0f / %d" % [MachineLayerScript.KIT_DRAW, Defs.TILE])
	_assert(MachineLayerScript.KIT_OPEN_DRAW < MachineLayerScript.KIT_DRAW,
		"품에 안은 것은 그보다 작다 — 그녀를 가리면 안 된다")
	# And what she carries says which one it is. Both used to be the same drawn
	# rectangle, so the opening never showed her holding the fire or the hut.
	_assert(MachineLayerScript.kit_art(Defs.KIT_BASE) == MachineLayerScript.KIT_BASE_ART,
		"기지 키트를 들면 기지 키트가 보인다")
	_assert(MachineLayerScript.kit_art(Defs.KIT_SHELTER) == MachineLayerScript.KIT_SHELTER_ART,
		"거처 키트를 들면 거처 키트가 보인다")
	_assert(MachineLayerScript.kit_art(Defs.KIT_BASE)
		!= MachineLayerScript.kit_art(Defs.KIT_SHELTER), "둘은 다른 그림이다")
