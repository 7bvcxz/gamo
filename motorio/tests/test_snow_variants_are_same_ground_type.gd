extends SceneTree

## Four faces, one ground (World Visual Pass 01).
##
## The snow floor is four variants of one tile (`assets/tiles/snow_4.png`),
## picked per cell from its coordinates. Every one of them is the ground type
## SNOW: nothing in the game -- walking, building, the cold, the path grid --
## can tell one variant from another, and the choice is the same every time the
## same world is drawn.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_the_atlas()
	_test_every_variant_is_snow()
	_test_nothing_in_the_game_can_tell()
	if failures == 0:
		print("PASS test_snow_variants_are_same_ground_type")
	else:
		print("FAIL test_snow_variants_are_same_ground_type (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_the_atlas() -> void:
	_assert(GroundLayer.TILE_ATLAS.resource_path.ends_with("snow_4.png"), "바닥은 눈 타일 아틀라스다")
	_assert(GroundLayer.TILE_VARIANTS == 4, "변형은 넷이다 (snow_01~04)")
	_assert(GroundLayer.SNOW_VARIANTS.size() == GroundLayer.TILE_VARIANTS, "변형마다 이름이 있다")

func _test_every_variant_is_snow() -> void:
	var seen: Dictionary = {}
	var not_snow := 0
	var changed := 0
	for y in range(-60, 60):
		for x in range(-60, 60):
			var cell := Vector2i(x, y)
			var variant: int = GroundLayer.tile_variant(cell)
			seen[variant] = true
			if GroundLayer.ground_type(cell) != GroundLayer.GROUND_SNOW:
				not_snow += 1
			if GroundLayer.tile_variant(cell) != variant:
				changed += 1
	_assert(seen.size() == GroundLayer.TILE_VARIANTS, "네 변형이 모두 쓰인다 (%d)" % seen.size())
	_assert(not_snow == 0, "어느 칸의 어느 변형도 지면 종류는 SNOW 다 (%d)" % not_snow)
	_assert(changed == 0, "같은 칸은 언제나 같은 변형이다")

func _test_nothing_in_the_game_can_tell() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.clear_ore()
	sim.unlocked[Defs.M_BELT] = true
	sim.stock[Defs.ITEM_COPPER] = 500
	# One cell of each variant on open ground near the fire.
	var picked: Dictionary = {}
	for y in range(6, 30):
		for x in range(12, 40):
			var cell: Vector2i = sim.core_cell + Vector2i(x, y)
			var variant: int = GroundLayer.tile_variant(cell)
			if picked.has(variant) or sim.is_structure(cell) or sim.has_rock(cell) \
					or sim.machine_at(cell) != null or sim.frozen_key(cell) != Sim.NONE \
					or sim.debris_key(cell) != Sim.NONE:
				continue
			picked[variant] = cell
	_assert(picked.size() == GroundLayer.TILE_VARIANTS, "변형마다 빈 땅 칸이 있다")
	var answers: Dictionary = {}
	for variant: int in picked:
		var cell: Vector2i = picked[variant]
		answers[[sim.blocks_player(cell), sim.can_build(Defs.M_BELT, cell) == "",
			sim.has_ore(cell), sim.can_hand_mine(cell)]] = true
	_assert(answers.size() == 1, "걷기·짓기·광맥·캐기가 변형과 상관없이 같다 (%d가지 답)" % answers.size())
	sim.free()
