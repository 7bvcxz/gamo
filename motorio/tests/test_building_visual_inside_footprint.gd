extends SceneTree

## Every building's picture stands on its own cells (World Visual Pass 01).
##
## The brief: the building body has to be inside its footprint -- the food bin
## and the old hut were not. For each building the game draws from a PNG, the
## opaque pixels of the source file, drawn at the size the game draws it
## (`MachineLayer.building_art`, the same table the drawing reads), lie inside
## the footprint the game blocks for it, and fill most of it: a picture far
## smaller than its building leaves a band of "building" nobody can see, which
## is the other half of the same complaint.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rows: Array[Dictionary] = MachineLayer.building_art()
	var names: Array = []
	for row: Dictionary in rows:
		names.append(String(row["name"]))
	for wanted: String in ["base", "shelter", "miner", "miner_mk2", "generator", "manufacturer",
			"assembler", "food_bin"]:
		_assert(names.has(wanted), "%s 가 표에 있다" % wanted)
	for row: Dictionary in rows:
		_check(row)
	if failures == 0:
		print("PASS test_building_visual_inside_footprint")
	else:
		print("FAIL test_building_visual_inside_footprint (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _check(row: Dictionary) -> void:
	var name: String = row["name"]
	var texture: Texture2D = row["texture"]
	var drawn: float = float(row["drawn"])
	var footprint: Vector2 = row["footprint"]
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
	_assert(image != null, "%s: 그림을 읽는다" % name)
	if image == null:
		return
	# Opaque means opaque: the soft edge of the key is not the building.
	var used := Rect2i()
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	used = Rect2i(low, high - low + Vector2i.ONE)
	var per_pixel: float = drawn / float(image.get_width())
	var opaque := Rect2(Vector2.ONE * -drawn * 0.5 + Vector2(used.position) * per_pixel,
		Vector2(used.size) * per_pixel)
	var cells := Rect2(-footprint * 0.5, footprint)
	_assert(cells.grow(0.01).encloses(opaque), "%s: 몸체가 발자국 안이다 (그림 %s, 발자국 %s)"
		% [name, opaque, cells])
	var larger: float = maxf(opaque.size.x / footprint.x, opaque.size.y / footprint.y)
	var smaller: float = minf(opaque.size.x / footprint.x, opaque.size.y / footprint.y)
	_assert(larger >= 0.88 and smaller >= 0.65, "%s: 발자국을 채운다 (긴 쪽 %.0f%%, 짧은 쪽 %.0f%%)"
		% [name, larger * 100.0, smaller * 100.0])
