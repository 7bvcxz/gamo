extends SceneTree

## The core and the hut are one tile each.
##
## They always were, in the only place it decides anything: the core is one
## machine blocking one cell and `is_structure` blocks exactly the cell the hut
## stands on. The pictures were 2.7 and 2.2 tiles across -- three times the size
## of the thing they stood for -- so they hung over the tiles their neighbours
## are built on and over the mouth a belt feeds.

const MachineLayerScript := preload("res://scripts/MachineLayer.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_one_tile()
	_test_the_sim_agrees()
	if failures == 0:
		print("BUILDINGS: PASS")
	else:
		print("BUILDINGS: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_one_tile() -> void:
	var tile := float(Defs.TILE)
	_assert(is_equal_approx(MachineLayerScript.CORE_DRAW, tile),
		"기지가 한 칸이다: %.0f / %.0f" % [MachineLayerScript.CORE_DRAW, tile])
	_assert(is_equal_approx(MachineLayerScript.SHELTER_DRAW, tile),
		"숙소가 한 칸이다: %.0f / %.0f" % [MachineLayerScript.SHELTER_DRAW, tile])
	# Both are drawn from real art rather than from shapes, and at twice the drawn
	# size so zooming in stays soft rather than blocky.
	for art: Texture2D in [MachineLayerScript.CORE_ART, MachineLayerScript.SHELTER_ART]:
		_assert(art != null and art.get_width() >= int(tile) * 2,
			"그림이 그리는 크기의 두 배 이상이다: %d" % art.get_width())

func _test_the_sim_agrees() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.carried_kit = Defs.KIT_BASE
	sim.place_base(sim.core_cell)
	sim.shelter_placed = true
	# One cell each, and the cell next door is walkable. This is what the drawing
	# now says too, which is the whole point of the change: a player who walks
	# around the picture was walking around nothing.
	_assert(sim.blocks_player(sim.core_cell), "기지 칸은 막힌다")
	_assert(sim.blocks_player(sim.shelter_cell), "숙소 칸도 막힌다")
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var beside: Vector2i = sim.core_cell + step
		if sim.machines.has(beside) or sim.ore.has(beside):
			continue
		_assert(not sim.blocks_player(beside),
			"기지 옆 %s 칸은 지나갈 수 있다" % str(step))
	sim.free()
