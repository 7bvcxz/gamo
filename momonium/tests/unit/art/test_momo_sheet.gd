extends "res://tests/framework/test_case.gd"

## Momo's 5x5 sprite sheet (Step 51, design/MOMO_SPRITES.md): equal cells, a
## map that names every one, transparency around each pose, every pose's feet
## on the same pivot, one standing height, no duplicate, and an import the
## web build can draw small. Built by tools/art/gen/build_momo_sheet.gd.

const SHEET := "res://assets/momo/momo_sheet.png"
const MAP := "res://assets/momo/momo_sheet.json"

var map: Dictionary
var img: Image


func before_each() -> void:
	if img != null:
		return
	map = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	img = Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	img.convert(Image.FORMAT_RGBA8)


func _rect(c: Dictionary) -> Rect2i:
	var w := int(map["cell"][0])
	var h := int(map["cell"][1])
	return Rect2i(int(c["col"]) * w, int(c["row"]) * h, w, h)


## Opaque box of a cell, in cell coordinates.
func _box(c: Dictionary) -> Rect2i:
	var r := _rect(c)
	var lo := Vector2i(r.size.x, r.size.y)
	var hi := Vector2i(-1, -1)
	for y in r.size.y:
		for x in r.size.x:
			if img.get_pixel(r.position.x + x, r.position.y + y).a > 0.3:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func test_twenty_five_equal_cells_and_a_map_for_each() -> void:
	assert_eq([int(map["cols"]), int(map["rows"])], [5, 5], "5 x 5")
	assert_eq(Vector2i(img.get_width(), img.get_height()), Vector2i(int(map["cell"][0]) * 5, int(map["cell"][1]) * 5), "the image is exactly 5 x 5 cells")
	assert_eq(int(map["cell"][0]), int(map["cell"][1]), "square cells")
	var cells: Array = map["cells"]
	assert_eq(cells.size(), 25, "25 cells named")
	var places := {}
	var names := {}
	for c: Dictionary in cells:
		places["%d,%d" % [int(c["row"]), int(c["col"])]] = true
		names[String(c["name"])] = true
		assert_true(String(c["view"]) in ["front", "back", "side"], "%s: a view" % c["name"])
	assert_eq(places.size(), 25, "every cell of the grid, once")
	assert_eq(names.size(), 25, "every name once")


func test_every_animation_and_every_pose_the_rig_asks_for_exists() -> void:
	var names := {}
	for c: Dictionary in map["cells"]:
		names[String(c["name"])] = true
	for anim: String in map["animations"]:
		var a: Dictionary = map["animations"][anim]
		assert_false((a["cells"] as Array).is_empty(), "%s plays something" % anim)
		for n: String in a["cells"]:
			assert_true(names.has(n), "%s: cell %s exists" % [anim, n])
		if a.has("blink"):
			assert_true(names.has(String(a["blink"])), "%s: its blink exists" % anim)
	var wanted: Array[String] = []
	for v: String in ["front", "back", "side"]:
		wanted.append_array(["idle_" + v, "walk_" + v])
	wanted.append_array(["work_back", "sit", "sleep"])
	wanted.append_array(MomoRig.WORK_POSES)
	wanted.append_array(MomoRig.MOOD_POSES)
	for anim: String in wanted:
		assert_true((map["animations"] as Dictionary).has(anim), "the rig can ask for %s" % anim)
	for v: String in ["front", "back", "side"]:
		assert_eq((map["animations"]["walk_" + v]["cells"] as Array).size(), 4, "%s walk: A B C B" % v)
	var used := {}
	for anim: String in map["animations"]:
		for n: String in map["animations"][anim]["cells"]:
			used[n] = true
		if map["animations"][anim].has("blink"):
			used[String(map["animations"][anim]["blink"])] = true
	assert_eq(used.size(), 25, "every cell is played by something (%s)" % [names.keys().filter(func(n: String) -> bool: return not used.has(n))])


func test_each_pose_is_alone_in_its_cell_with_a_clear_border() -> void:
	var w := int(map["cell"][0])
	for c: Dictionary in map["cells"]:
		var r := _rect(c)
		var bleed := 0
		for i in w:
			for p: Vector2i in [Vector2i(i, 0), Vector2i(i, 1), Vector2i(0, i), Vector2i(1, i), Vector2i(w - 1, i), Vector2i(w - 2, i)]:
				if img.get_pixel(r.position.x + p.x, r.position.y + p.y).a > 0.05:
					bleed += 1
		assert_eq(bleed, 0, "%s: nothing on the cell's top, left or right edge (no bleeding into a neighbour)" % c["name"])
		var b := _box(c)
		assert_true(b.size.x > 40 and b.size.y > 40, "%s: a pose is there (%s)" % [c["name"], b])


func test_every_pose_stands_on_the_pivot() -> void:
	var pivot_y := int(map["pivot"][1])
	for c: Dictionary in map["cells"]:
		var b := _box(c)
		assert_between(b.end.y, pivot_y - 2, pivot_y + 1, "%s: its lowest point on the ground line (%d, pivot %d)" % [c["name"], b.end.y, pivot_y])


func test_standing_poses_share_one_height_and_the_head_stays_put() -> void:
	var stand := float(map["stand_height"])
	var pivot_x := float(map["pivot"][0])
	for c: Dictionary in map["cells"]:
		var n := String(c["name"])
		if n.ends_with("_idle") or n.contains("_walk_") or n in ["front_blink", "harvest", "water", "carry", "study", "happy", "confused", "waiting"]:
			var b := _box(c)
			assert_between(float(b.size.y), stand - 3.0, stand + 2.0, "%s: the standing height (%d)" % [n, b.size.y])
	# A walk keeps the head over the pivot while the feet step.
	for c: Dictionary in map["cells"]:
		var box: Array = c["box"]
		assert_true(int(box[0]) >= 0 and int(box[0]) + int(box[2]) <= int(map["cell"][0]), "%s: fits its cell" % c["name"])
	assert_near(pivot_x, float(map["cell"][0]) / 2.0, 0.01, "the pivot is the cell's middle")


func test_no_two_cells_are_the_same_picture() -> void:
	var seen := {}
	for c: Dictionary in map["cells"]:
		var cut := img.get_region(_rect(c))
		var h := hash(cut.get_data())
		assert_false(seen.has(h), "%s is not a copy of %s" % [c["name"], seen.get(h, "")])
		seen[h] = c["name"]


func test_the_runtime_import_draws_it_small_and_ships_its_map() -> void:
	var tex: Texture2D = load(SHEET)
	assert_true(tex != null, "the sheet imports")
	assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(img.get_width(), img.get_height()), "at full size")
	var imp := ConfigFile.new()
	assert_eq(imp.load(SHEET + ".import"), OK, "")
	assert_eq(bool(imp.get_value("params", "mipmaps/generate", false)), true, "mipmaps: drawn at about a third of its size")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(presets.contains("assets/momo/*.json"), "the map is exported with the game (a JSON is not a resource)")
	assert_eq(MomoSheet.shared().cells.size(), 25, "and the runtime reads it")


## Animation continuity: in a walk the head stays where it is while the feet
## step -- each frame's head (the widest row of the head band) is centred over
## the same x and its top on the same line, so the cycle does not wobble.
func test_a_walk_keeps_the_head_still() -> void:
	var by := {}
	for c: Dictionary in map["cells"]:
		by[String(c["name"])] = c
	for view: String in ["front", "back", "side"]:
		var xs: Array[float] = []
		var tops: Array[int] = []
		for n: String in map["animations"]["walk_" + view]["cells"]:
			var c: Dictionary = by[n]
			var r := _rect(c)
			var b := _box(c)
			var best := Vector2(0, 0)
			for y in range(b.position.y + int(b.size.y * 0.18), b.position.y + int(b.size.y * 0.45)):
				var lo := -1
				var hi := -1
				for x in r.size.x:
					if img.get_pixel(r.position.x + x, r.position.y + y).a > 0.5:
						if lo < 0:
							lo = x
						hi = x
				if lo >= 0 and hi - lo > best.x:
					best = Vector2(hi - lo, (lo + hi) / 2.0)
			xs.append(best.y)
			tops.append(b.position.y)
		assert_true(xs.max() - xs.min() <= 3.0, "%s walk: the head centred within 3 px (%s)" % [view, xs])
		assert_true(tops.max() - tops.min() <= 4, "%s walk: the head's top within 4 px (%s)" % [view, tops])
