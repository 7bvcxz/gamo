extends "res://tests/framework/test_case.gd"

## Momo at work (Step 66, design/MOMO_TOOLS.md): a packed atlas of Momo with
## the tool of each job, beside the 5x5 sheet. Every stage the island has
## maps to a pose; every frame is in the atlas, trimmed, apart from the
## others, a different drawing, stood on its own pivot between the feet, at
## the sheet's scale; the import is drawn small like the sheet's. Built by
## tools/art/gen/build_momo_work.gd from assets/src/png/momo_work/.

const ATLAS := "res://assets/momo/momo_work.png"
const MAP := "res://assets/momo/momo_work.json"
const Build := preload("res://tools/art/gen/build_momo_work.gd")

## The jobs the owner named (#66) and the pose that shows each.
const NAMED := {"dig": "dig", "smelt": "hammer", "assemble": "hammer", "water": "water", "chop": "chop", "harvest": "harvest", "study": "study"}

var map: Dictionary
var img: Image


func before_each() -> void:
	if img != null:
		return
	map = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	img = Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	img.convert(Image.FORMAT_RGBA8)


func _rect(f: Dictionary) -> Rect2i:
	var r: Array = f["rect"]
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


func _frame(name: String) -> Dictionary:
	for f: Dictionary in map["frames"]:
		if String(f["name"]) == name:
			return f
	return {}


func test_every_stage_on_the_island_has_a_pose_with_its_tool() -> void:
	var actions: Dictionary = map["actions"]
	var seen := 0
	var data := GameData.load_default()
	var types: Dictionary = data.table("buildings")["types"]
	for type: String in types:
		var t := data.building_type(type)
		for st: Dictionary in (t.get("cycle", {}) as Dictionary).get("stages", []):
			var action := String(st.get("action", st.get("id", "")))
			seen += 1
			assert_true(actions.has(action), "%s: %s has a pose" % [type, action])
			var anim := "work_" + String(actions.get(action, ""))
			assert_true((map["animations"] as Dictionary).has(anim), "%s: %s plays %s" % [type, action, anim])
			for cell: String in (map["animations"] as Dictionary).get(anim, {}).get("cells", []):
				assert_false(_frame(cell).is_empty(), "%s is in the atlas" % cell)
	assert_true(seen >= 13, "every stage of every building (%d)" % seen)
	for action: String in NAMED:
		assert_eq(String(actions.get(action, "")), String(NAMED[action]), "%s shows the %s" % [action, NAMED[action]])


func test_frames_are_in_the_atlas_apart_and_trimmed() -> void:
	var frames: Array = map["frames"]
	assert_true(frames.size() >= 10, "ten jobs")
	var rects: Array[Rect2i] = []
	for f: Dictionary in frames:
		var r := _rect(f)
		assert_true(Rect2i(Vector2i.ZERO, img.get_size()).encloses(r), "%s inside the atlas" % f["name"])
		for other: Rect2i in rects:
			assert_false(r.grow(2).intersects(other), "%s apart from the others (mipmaps do not bleed)" % f["name"])
		rects.append(r)
		var used := img.get_region(r).get_used_rect()
		assert_eq(used.size, r.size, "%s trimmed to its drawing" % f["name"])
	var seen := {}
	for f: Dictionary in frames:
		var h := hash(img.get_region(_rect(f)).get_data())
		assert_false(seen.has(h), "%s is its own drawing" % f["name"])
		seen[h] = true


func test_each_frame_stands_on_its_pivot_at_the_sheet_scale() -> void:
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/momo/momo_sheet.json"))
	assert_eq(float(map["stand_height"]), float(sheet["stand_height"]), "the sheet's texel scale")
	# The front standing cell's eyes, in sheet texels: the size to keep.
	var sheet_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/momo/momo_sheet.png"))
	sheet_img.convert(Image.FORMAT_RGBA8)
	var front := sheet_img.get_region(Rect2i(0, 0, int(sheet["cell"][0]), int(sheet["cell"][1])))
	var anchor_eye := float(Build.eyes(front)[0])
	for f: Dictionary in map["frames"]:
		var cut := img.get_region(_rect(f))
		var pv := Vector2(f["pivot"][0], f["pivot"][1])
		var feet := Build.feet_point(cut)
		assert_near(pv.y, feet.y, 1.0, "%s: the pivot on the lowest of the feet" % f["name"])
		assert_near(pv.x, feet.x, 1.0, "%s: between the feet" % f["name"])
		assert_true(cut.get_height() <= float(map["stand_height"]) * 1.4, "%s: a tool raised, never a giant (%d)" % [f["name"], cut.get_height()])
		var e := Build.eyes(cut)
		assert_false(e.is_empty(), "%s: Momo's face" % f["name"])
		if not e.is_empty():
			assert_between(float(e[0]) / anchor_eye, 0.8, 1.15, "%s: the same Momo, the same size (eyes %.1f vs %.1f)" % [f["name"], e[0], anchor_eye])


func test_the_runtime_reads_it_and_draws_it_small() -> void:
	var tex: Texture2D = load(ATLAS)
	assert_true(tex != null, "the atlas imports")
	var imp := ConfigFile.new()
	assert_eq(imp.load(ATLAS + ".import"), OK, "")
	assert_eq(bool(imp.get_value("params", "mipmaps/generate", false)), true, "mipmaps, like the sheet")
	var sheet := MomoSheet.shared()
	assert_eq(sheet.work_frames.size(), (map["frames"] as Array).size(), "every frame read")
	assert_eq(sheet.texture_of("dig_0"), sheet.work_texture, "a work frame comes from the atlas")
	assert_eq(sheet.texture_of("front_idle"), sheet.texture, "a sheet cell from the sheet")
	assert_eq(sheet.region("dig_0"), Rect2(_rect(_frame("dig_0"))), "its rect")
	assert_eq(sheet.pivot_of("front_idle"), sheet.pivot, "a sheet cell keeps the sheet's pivot")
	assert_eq(sheet.work_animation("smelt"), "hammer", "an action to its pose")
	assert_eq(sheet.work_animation("nothing"), "", "an unknown action: none")
	# The atlas is small: a quarter of a 2048 square at most.
	assert_true(img.get_width() * img.get_height() <= 1024 * 1024, "%dx%d" % [img.get_width(), img.get_height()])
