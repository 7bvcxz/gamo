extends SceneTree

## Saves across Grid v2.
##
## `fixtures/save_v11.cfg` is a real save written by 1.0.42 -- the last schema-11
## build -- with a small factory in it: two miners on the starter seams with cats
## on them, belt lines that turn, a generator with stone in its drum, a splitter
## in front of a manufacturer, and a block of ice and a kit set down right
## against the core, where the bigger base now stands.
##
## Loading it must: keep the file (a copy, byte for byte, never overwritten),
## bring the run back rather than a new game, put every machine where it was or
## refund it in full, move what the base now covers instead of deleting it, keep
## the belt line into the base carrying, and say what happened. And a v12 save
## must come back exactly as it went.

const FIXTURE := "res://tests/fixtures/save_v11.cfg"

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
	_remove_backups()
	_test_migrates_a_v11_run()
	_test_v12_round_trip()
	_test_older_schemas_are_kept()
	_remove_backups()
	main.clear_save()
	if failures == 0:
		print("PASS test_save_load_grid_v2")
	else:
		print("FAIL test_save_load_grid_v2 (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _remove_backups() -> void:
	for slot in main.SAVE_SLOTS:
		for schema in [9, 10, 11]:
			if FileAccess.file_exists(main.backup_path(slot, schema)):
				DirAccess.remove_absolute(main.backup_path(slot, schema))

func _fixture_state() -> Dictionary:
	var config := ConfigFile.new()
	config.load(FIXTURE)
	return config.get_value("motorio", "state", {})

func _test_migrates_a_v11_run() -> void:
	var original: PackedByteArray = _bytes(FIXTURE)
	_assert(original.size() > 0, "v11 세이브 고정 파일이 있다")
	var before: Dictionary = _fixture_state()
	var old_sim: Dictionary = before["sim"]
	_write(main.slot_path(0), original)
	var sim: Sim = main.sim

	# The picker lists it rather than showing an empty slot.
	var card: Dictionary = main.slot_cards()[0]
	_assert(bool(card["exists"]), "슬롯 목록에 v11 세이브가 보인다")
	_assert(int(card["stones"]) == int(old_sim["stones_in"]), "열석 수도 그대로 읽힌다")

	_assert(main.load_game(0), "v11 세이브를 불러오면 새 게임이 아니라 그 회차가 돌아온다")
	_assert(not main.migration_report.is_empty(), "옮긴 기록이 남는다")
	# The file: copied aside first, byte for byte.
	var backup: String = main.backup_path(0, 11)
	_assert(FileAccess.file_exists(backup), "원본은 _v11.bak.cfg 로 먼저 복사된다")
	_assert(_bytes(backup) == original, "복사본은 원본과 바이트까지 같다")
	_assert(_bytes(main.slot_path(0)) == original, "불러오기만으로는 원본 슬롯도 건드리지 않는다")

	# The run: progress, stock and cats are what they were.
	_assert(sim.stones_in == int(old_sim["stones_in"]), "열석 진행이 그대로다 (%d)" % sim.stones_in)
	_assert(sim.cats.size() == (old_sim["cats"] as Array).size(), "고양이 수가 그대로다")
	_assert(sim.has_gun and sim.has_pickaxe, "도구가 그대로다")
	var old_stock: Dictionary = old_sim["stock"]
	var poorer := 0
	for key: String in old_stock:
		if int(sim.stock.get(int(key), 0)) < int(old_stock[key]):
			poorer += 1
	_assert(poorer == 0, "어느 재고도 줄지 않았다 — 거둔 설비는 재료로 돌아왔다")

	# The world: the fire's middle did not move, and the base is eight by eight.
	_assert(sim.core_cell == Vector2i(int(old_sim["core_x"]), int(old_sim["core_y"])) * Grid.SCALE,
		"기지 앵커는 옛 칸의 두 배다")
	_assert(sim.core_centre() == Grid.tile_centre(Vector2i(int(old_sim["core_x"]), int(old_sim["core_y"]))),
		"불의 가운데는 옛 코어 칸의 가운데 그대로다")

	# Every footprint on its own ground.
	var rects: Array[Rect2i] = []
	for anchor: Vector2i in sim.machines:
		rects.append(sim.machine_rect(sim.machines[anchor]))
	var overlaps := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				overlaps += 1
		if rects[i] != sim.base_rect() and rects[i].intersects(sim.shelter_rect()):
			overlaps += 1
	_assert(overlaps == 0, "어떤 발자국도 서로·숙소와 겹치지 않는다 (%d)" % overlaps)
	sim.shelter_placed = false
	_assert(sim.shelter_problems(sim.shelter_cell).is_empty(), "숙소는 설 수 있는 자리에 있다")
	sim.shelter_placed = true
	_assert((main.migration_report["moved"] as Array).has("숙소"),
		"옛 자리가 커진 기지와 겹친 숙소는 옮겼다고 말한다")

	# The whole machines kept their tile.
	var generator: Sim.Machine = sim.machine_at(Vector2i(8, -3) * Grid.SCALE)
	_assert(generator != null and generator.type == Defs.M_GENERATOR
		and sim.machine_rect(generator) == Grid.tile_rect(Vector2i(8, -3)),
		"발전기는 옛 칸의 네 칸을 그대로 차지한다")
	if generator != null:
		_assert(int(generator.buffer.get(Defs.ITEM_HEATSTONE, 0)) == 3, "드럼 속 열석 3개도 그대로")
	var plant: Sim.Machine = sim.machine_at(Vector2i(-4, -6) * Grid.SCALE)
	_assert(plant != null and plant.type == Defs.M_MANUFACTURER, "제조기도 제자리다")
	var splitter: Sim.Machine = sim.machine_at(Vector2i(-4, -5) * Grid.SCALE)
	_assert(splitter != null and splitter.type == Defs.M_SPLITTER, "분배기도 제자리다")

	# Nothing lost that the base now covers: moved, not deleted.
	var old_frozen: int = (old_sim["frozen"] as Array).size()
	_assert(sim.frozen_cats.size() == old_frozen, "얼어붙은 고양이 수가 그대로다 (%d)" % sim.frozen_cats.size())
	var under := 0
	for origin: Vector2i in sim.frozen_cats:
		if sim.prop_rect(origin).intersects(sim.base_rect()):
			under += 1
	_assert(under == 0, "기지 밑에 깔린 얼음은 없다 — 옆으로 옮겼다")
	var kept_thaw := false
	for origin: Vector2i in sim.frozen_cats:
		if is_equal_approx(float(sim.frozen_cats[origin]), 0.4):
			kept_thaw = true
	_assert(kept_thaw, "그 얼음의 녹은 정도(0.4)도 그대로다")
	_assert(sim.drops.size() == (old_sim["drops"] as Array).size(), "눈 위의 물건 수가 그대로다")
	for cell: Vector2i in sim.drops:
		_assert(not sim.base_rect().has_point(cell), "물건 %s 는 기지 밖에 있다" % cell)

	# Miners: on a seam of the new world, with their cats, or refunded.
	var posts := 0
	for anchor: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[anchor]
		if not Defs.machine_mines(machine.type):
			continue
		posts += 1
		_assert(sim.has_ore(anchor), "남은 채굴기 %s 는 광맥 위에 있다" % anchor)
	var staffed := 0
	for cat: Sim.Cat in sim.cats:
		if cat.has_job():
			staffed += 1
			_assert(sim._is_post(cat.assigned), "배정된 고양이의 자리는 실제 일자리다")
	_assert(posts + int(main.migration_report["refunded"]) >= 2, "옛 채굴기 둘은 옮겨졌거나 환불됐다")
	_assert(staffed >= posts, "옮겨진 채굴기마다 제 고양이가 돌아간다 (%d/%d)" % [staffed, posts])

	# The belt line that turns and runs into the base still carries.
	var start: Vector2i = Vector2i(3, 3) * Grid.SCALE
	_assert(sim.machine_at(start) != null and sim.machine_at(start).type == Defs.M_BELT,
		"꺾이는 벨트 줄의 첫 칸이 있다")
	var delivered_before: int = int(sim.delivered.get(Defs.ITEM_COPPER, 0))
	sim._push_into(start, Defs.ITEM_COPPER)
	for _tick in 1200:
		sim.tick(0.05)
		if int(sim.delivered.get(Defs.ITEM_COPPER, 0)) > delivered_before:
			break
	_assert(int(sim.delivered.get(Defs.ITEM_COPPER, 0)) > delivered_before,
		"그 줄에 올린 구리가 꺾여서 기지에 닿는다")

	# She is not standing inside anything, and she was told.
	var r: float = Defs.PLAYER_RADIUS
	var low: Vector2i = Grid.cell_at(main.player.position - Vector2(r, r))
	var high: Vector2i = Grid.cell_at(main.player.position + Vector2(r, r))
	var stuck := 0
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if sim.blocks_player(Vector2i(x, y)):
				stuck += 1
	_assert(stuck == 0, "그녀는 커진 기지 안에 갇히지 않는다")
	var told := false
	for entry: Dictionary in main.messages:
		if String(entry["text"]).begins_with("새 격자로 옮"):
			told = true
	_assert(told, "무엇이 일어났는지 한 줄로 말한다: '%s'"
		% SaveMigration_describe(main.migration_report))

	# Saving writes a 12 over the slot; the 11 stays where it was copied.
	_assert(main.save_game(false, 0), "새 스키마로 저장한다")
	var config := ConfigFile.new()
	config.load(main.slot_path(0))
	_assert(int(config.get_value("motorio", "schema", -1)) == main.SAVE_SCHEMA, "슬롯은 이제 12다")
	_assert(_bytes(backup) == original, "v11 복사본은 저장 뒤에도 그대로다")
	# And reads back as itself, with nothing to migrate.
	var anchors: Array = sim.machines.keys()
	anchors.sort()
	_assert(main.load_game(0), "다시 불러온다")
	_assert(main.migration_report.is_empty(), "두 번째에는 옮길 것이 없다")
	var again: Array = sim.machines.keys()
	again.sort()
	_assert(again == anchors, "설비가 같은 자리로 돌아온다")
	main.clear_save()
	_assert(FileAccess.file_exists(backup), "새 게임을 시작해도 v11 복사본은 지우지 않는다")

func SaveMigration_describe(report: Dictionary) -> String:
	return main.SaveMigration.describe(report)

## A v12 world with multi-cell machines goes out and comes back exactly.
func _test_v12_round_trip() -> void:
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	var sim: Sim = main.sim
	sim.unlocked[Defs.M_MINER] = true
	sim.unlocked[Defs.M_BELT] = true
	sim.unlocked[Defs.M_GENERATOR] = true
	for item: int in [Defs.ITEM_CRYSTAL, Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_ENERGY_CORE]:
		sim.stock[item] = 500
	var seam: Vector2i = sim.core_cell + Sim.STARTER_PATCH[1]
	sim.build(Defs.M_MINER, seam, Vector2i.UP)
	var mouth: Vector2i = sim.output_cell(sim.machine_at(seam))
	sim.build(Defs.M_BELT, mouth, Vector2i.UP)
	sim.build(Defs.M_BELT, mouth + Vector2i.UP, Vector2i.UP)
	var pad: Vector2i = sim.free_anchor_near(sim.core_cell + Vector2i(14, -6), Vector2i(2, 2))
	sim.build(Defs.M_GENERATOR, pad, Vector2i.RIGHT)
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[-1]
	sim.place_cat(seam)
	var shape: Dictionary = {}
	for anchor: Vector2i in sim.machines:
		shape[anchor] = [sim.machines[anchor].type, sim.machines[anchor].dir,
			sim.machine_rect(sim.machines[anchor])]
	var assigned: Vector2i = sim.cats[-1].assigned
	var hut: Vector2i = sim.shelter_cell
	_assert(main.save_game(false, 0), "v12 로 저장한다")
	sim.machines.clear()
	sim.cats.clear()
	_assert(main.load_game(0), "v12 를 불러온다")
	_assert(main.migration_report.is_empty(), "v12 는 옮기지 않는다")
	var same := sim.machines.size() == shape.size()
	for anchor: Vector2i in shape:
		var machine: Sim.Machine = sim.machines.get(anchor, null)
		if machine == null or [machine.type, machine.dir, sim.machine_rect(machine)] != shape[anchor]:
			same = false
	_assert(same, "설비 %d개가 같은 앵커·방향·발자국으로 돌아온다" % shape.size())
	_assert(sim.machine_at(seam + Vector2i(1, 1)) == sim.machine_at(seam),
		"발자국의 다른 칸도 같은 채굴기를 가리킨다")
	_assert(not sim.cats.is_empty() and sim.cats[-1].assigned == assigned, "고양이의 자리도 그대로다")
	_assert(sim.shelter_cell == hut, "숙소 앵커도 그대로다")
	main.clear_save()

## A save older than the migration still becomes a new game, as it always did --
## but the file is copied aside first and never deleted.
func _test_older_schemas_are_kept() -> void:
	var text: String = FileAccess.get_file_as_string(FIXTURE).replace("schema=11", "schema=10")
	var file := FileAccess.open(main.slot_path(1), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var original: PackedByteArray = _bytes(main.slot_path(1))
	_assert(not main.load_game(1), "v10 세이브는 새 게임으로 시작한다 (전과 같다)")
	_assert(FileAccess.file_exists(main.backup_path(1, 10)), "하지만 먼저 복사해 둔다")
	_assert(_bytes(main.backup_path(1, 10)) == original, "바이트까지 같게")
	_assert(FileAccess.file_exists(main.slot_path(1)), "슬롯 파일도 지우지 않는다")
	main.clear_save()
	_assert(FileAccess.file_exists(main.backup_path(1, 10)), "새 게임을 시작해도 복사본은 남는다")
