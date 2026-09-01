extends SceneTree

## The item registry: one table, and the lists that used to be written beside it.
##
## `Defs.ITEMS` replaced five parallel arrays indexed by item number. The arrays
## are still there and every caller reads them unchanged -- they are built from
## the table now, which is the whole point of the change: a factory game adds
## materials by the dozen, and five lists that must stay the same length in the
## same order is five chances to be wrong per material.
##
## So this file guards two different things. Most of it guards the table (no two
## rows sharing a number or a key, retired numbers never handed to a new
## material). The rest guards the *translation* -- that what the player reads and
## the order they read it in came through the refactor unchanged, which is the
## only claim "nothing changed for the player" can be made of.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_table_is_wellformed()
	_test_reserved_ids()
	_test_every_item_is_reachable()
	_test_derived_lists_are_unchanged()
	_test_atlas_matches_the_ground_layer()
	await _test_save_round_trip()
	if failures == 0:
		print("PASS test_items")
	else:
		print("FAIL test_items (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- The table ----------------------------------------------------------------

func _test_table_is_wellformed() -> void:
	var ids: Dictionary = {}
	var keys: Dictionary = {}
	var kinds: Array[String] = [Defs.KIND_RAW, Defs.KIND_INTERMEDIATE, Defs.KIND_SPECIAL]
	var duplicate_id := ""
	var duplicate_key := ""
	var bad_kind := ""
	var missing_field := ""
	for row: Dictionary in Defs.ITEMS:
		for field: String in ["id", "key", "kind", "name", "short", "color",
				"atlas", "counter", "ore_tier", "retired", "desc"]:
			if not row.has(field) and missing_field == "":
				missing_field = "%s: %s" % [row.get("key", "?"), field]
		var id: int = int(row["id"])
		var key: String = String(row["key"])
		if ids.has(id) and duplicate_id == "":
			duplicate_id = "%d (%s, %s)" % [id, ids[id], key]
		if keys.has(key) and duplicate_key == "":
			duplicate_key = key
		if not kinds.has(String(row["kind"])) and bad_kind == "":
			bad_kind = "%s: %s" % [key, row["kind"]]
		ids[id] = key
		keys[key] = id

	_assert(missing_field == "", "모든 행이 모든 항목을 갖는다 (%s)" % missing_field)
	# The two failures this table can have that nothing else would catch. A
	# duplicate number means two materials share a save slot; a duplicate key
	# means a recipe written later points at whichever row was read last.
	_assert(duplicate_id == "", "번호가 겹치지 않는다 (%s)" % duplicate_id)
	_assert(duplicate_key == "", "key 가 겹치지 않는다 (%s)" % duplicate_key)
	_assert(bad_kind == "", "kind 는 raw/intermediate/special 뿐이다 (%s)" % bad_kind)

	# Keys are what code refers to, so they have to look like code. The display
	# name is Korean and allowed to change; this is the half that is not.
	var bad_shape := ""
	for row: Dictionary in Defs.ITEMS:
		var key: String = String(row["key"])
		if key.is_empty() or key != key.to_lower() or key.contains(" "):
			bad_shape = key
	_assert(bad_shape == "", "key 는 소문자에 공백이 없다 (%s)" % bad_shape)

	# Two rows claiming one seat in the panel would leave the order up to the
	# sort's stability rather than to the table.
	var seats: Dictionary = {}
	var clash := ""
	for row: Dictionary in Defs.ITEMS:
		for field: String in ["counter", "ore_tier"]:
			var seat: int = int(row[field])
			if seat < 0:
				continue
			var taken: String = "%s:%d" % [field, seat]
			if seats.has(taken):
				clash = "%s <- %s, %s" % [taken, seats[taken], row["key"]]
			seats[taken] = String(row["key"])
	_assert(clash == "", "counter/ore_tier 자리를 두 행이 다투지 않는다 (%s)" % clash)

# --- Numbers that can never come back -----------------------------------------

## A save writes materials by number. Handing a retired number to a new material
## would not fail anywhere -- it would quietly turn one run's heat stone into
## another run's rubble, in a file written weeks ago and opened once.
func _test_reserved_ids() -> void:
	var reserved: Dictionary = {0: "crystal", 3: "stone"}
	for id: int in reserved:
		var row: Dictionary = Defs.item(id)
		_assert(not row.is_empty(), "%d 번은 표에 남아 있다" % id)
		_assert(String(row.get("key", "")) == String(reserved[id]),
			"%d 번은 여전히 %s 다 (%s)" % [id, reserved[id], row.get("key", "-")])
		_assert(Defs.item_retired(id), "%d 번은 retired 로 표시돼 있다" % id)
	# And they are out of the world rather than out of the table: nothing
	# produces them, which is what retired means.
	_assert(not Defs.ORE_TIERS.has(Defs.ITEM_STONE), "돌은 광맥 사다리에 없다")
	_assert(not Defs.ORE_TIERS.has(Defs.ITEM_CRYSTAL), "수정도 광맥 사다리에 없다")
	# Crystal still shows on the panel and stone does not, and the reason is not
	# symmetry: a run saved before 1.0.27 is holding crystal, and a material she
	# owns that the panel does not show is a material she has lost.
	_assert(Defs.COUNTED_ITEMS.has(Defs.ITEM_CRYSTAL), "수정은 아직 세어 준다")
	_assert(not Defs.COUNTED_ITEMS.has(Defs.ITEM_STONE), "돌은 세지 않는다")

# --- Every material answers ----------------------------------------------------

func _test_every_item_is_reachable() -> void:
	var ids: Array[int] = Defs.item_ids()
	_assert(ids.size() == Defs.ITEMS.size(), "item_ids() 가 표 전체를 준다 (%d)" % ids.size())
	var unreachable := ""
	for id: int in ids:
		var row: Dictionary = Defs.item(id)
		var key: String = String(row.get("key", ""))
		if row.is_empty() or Defs.item_by_key(key) != row or not Defs.has_item(id):
			unreachable = "%d/%s" % [id, key]
		if Defs.item_name(id).is_empty() or Defs.item_short(id).is_empty():
			unreachable = "%d 이름 없음" % id
		if Defs.item_desc(id).is_empty():
			unreachable = "%d 설명 없음" % id
		# The arrays every caller still reads have to answer for the same number.
		if Defs.ITEM_NAMES[id] != Defs.item_name(id):
			unreachable = "%d ITEM_NAMES 불일치" % id
		if Defs.ITEM_SHORT[id] != Defs.item_short(id):
			unreachable = "%d ITEM_SHORT 불일치" % id
		if Defs.ITEM_COLORS[id] != Defs.item_color(id):
			unreachable = "%d ITEM_COLORS 불일치" % id
	_assert(unreachable == "", "모든 항목이 번호로도 key 로도 조회된다 (%s)" % unreachable)

	# A number nothing claims answers rather than crashes: an old save can be
	# holding one, and the arrays are sized to the largest id so a retired number
	# in the middle stays a hole instead of shifting the rest down.
	_assert(Defs.item(9999).is_empty(), "없는 번호는 빈 행을 준다")
	_assert(Defs.item_name(9999) == "", "없는 번호의 이름은 빈 문자열이다")
	_assert(Defs.item_by_key("nothing_by_this_name").is_empty(), "없는 key 도 마찬가지")

	_assert(Defs.items_of_kind(Defs.KIND_SPECIAL) == [Defs.ITEM_ENERGY_CORE],
		"special 은 에너지 코어 하나다")
	# 1.0.34: the day this stopped being empty is the day the tech tree started.
	_assert(Defs.items_of_kind(Defs.KIND_INTERMEDIATE) == [Defs.ITEM_IRON_PLATE],
		"중간재는 철판 하나다")

# --- Nothing changed for the player -------------------------------------------

## Pinned by hand, on purpose. This is the one file that can say the refactor was
## invisible, and it can only say it by holding the values from before it.
func _test_derived_lists_are_unchanged() -> void:
	# The five the registry migration moved, plus the two 1.0.34 added. Numbers
	# 0 and 3 are retired and still hold their places, which is the property this
	# list exists to show.
	var names: Array[String] = ["수정조각", "구리광석", "열석", "돌", "에너지 코어",
		"철광석", "철판"]
	var shorts: Array[String] = ["수정", "구리", "열석", "돌", "에너지 코어", "철", "철판"]
	var colors: Array[Color] = [Color8(127, 212, 232), Color8(252, 104, 46),
		Color8(255, 122, 48), Color8(150, 152, 158), Color8(186, 148, 255),
		Color8(150, 176, 205), Color8(206, 216, 226)]
	_assert(Defs.ITEM_NAMES == names, "표시 이름이 그대로다 (%s)" % str(Defs.ITEM_NAMES))
	_assert(Defs.ITEM_SHORT == shorts, "약칭이 그대로다 (%s)" % str(Defs.ITEM_SHORT))
	_assert(Defs.ITEM_COLORS == colors, "색이 그대로다")

	# Order, not membership. The panel reads top to bottom and the wreck pays out
	# of the ladder by index, so both of these are behaviour.
	var counted: Array[int] = [Defs.ITEM_HEATSTONE, Defs.ITEM_CRYSTAL,
		Defs.ITEM_COPPER, Defs.ITEM_ENERGY_CORE, Defs.ITEM_IRON, Defs.ITEM_IRON_PLATE]
	_assert(Defs.COUNTED_ITEMS == counted,
		"자원 패널 순서가 그대로다 (%s)" % str(Defs.COUNTED_ITEMS))
	var tiers: Array[int] = [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON]
	_assert(Defs.ORE_TIERS == tiers, "광맥 사다리가 그대로다 (%s)" % str(Defs.ORE_TIERS))

# --- The seam sheets ----------------------------------------------------------

## Promoting an ore used to mean editing three places: the item constant, a
## preload, and the mapping. The table names the sheet now, so the two lists can
## be compared -- and an ore drawn nowhere is a hole in the floor that only shows
## up on a map where that ore happens to be near the camera.
func _test_atlas_matches_the_ground_layer() -> void:
	var mapped: Array = GroundLayer.ORE_ATLAS.keys()
	var declared: Array[int] = []
	for row: Dictionary in Defs.ITEMS:
		if not String(row["atlas"]).is_empty():
			declared.append(int(row["id"]))
	declared.sort()
	mapped.sort()
	_assert(declared == mapped,
		"시트를 선언한 자원과 그리는 자원이 같다 (표 %s / 레이어 %s)" % [str(declared), str(mapped)])
	var missing := ""
	for id: int in declared:
		if not FileAccess.file_exists("res://assets/tiles/%s" % Defs.item_atlas(id)):
			missing = Defs.item_atlas(id)
	_assert(missing == "", "선언한 시트 파일이 실재한다 (%s)" % missing)

# --- Saves written before this change -----------------------------------------

## The registry must not touch what a save holds. Materials go in by number and
## come back by number, including the two nothing produces any more.
func _test_save_round_trip() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()

	var sim = main.sim
	# One of everything, retired numbers included -- those are exactly the ones a
	# file written weeks ago is holding.
	var put: Dictionary = {}
	var amount: int = 3
	for id: int in Defs.item_ids():
		sim.stock[id] = amount
		put[id] = amount
		amount += 7
	main.save_game(false, 0)

	var reloaded := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(reloaded)
	await process_frame
	await process_frame
	_assert(reloaded.load_game(0), "저장한 회차를 다시 연다")
	var wrong := ""
	for id: int in put:
		if int(reloaded.sim.stock.get(id, -1)) != int(put[id]):
			wrong = "%d: %s != %d" % [id, str(reloaded.sim.stock.get(id, -1)), put[id]]
	_assert(wrong == "", "모든 자원이 개수 그대로 돌아온다 (%s)" % wrong)
	_assert(int(reloaded.sim.stock.get(Defs.ITEM_CRYSTAL, -1)) == int(put[Defs.ITEM_CRYSTAL]),
		"은퇴한 수정조각도 그대로 돌아온다")
	_assert(int(reloaded.sim.stock.get(Defs.ITEM_STONE, -1)) == int(put[Defs.ITEM_STONE]),
		"은퇴한 돌도 그대로 돌아온다")

	main.clear_save()
	main.free()
	reloaded.free()
