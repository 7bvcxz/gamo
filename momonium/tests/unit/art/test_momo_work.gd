extends "res://tests/framework/test_case.gd"

## Momo at work (Steps 66-67, design/MOMO_TOOLS.md): a packed atlas of Momo
## with the tool of each job, beside the 5x5 sheet. Every stage the island
## has maps to a job; every job plays at least four visibly different frames
## with a time for each; every frame is in the atlas, trimmed, apart from the
## others, stood on its own pivot between the feet, at the sheet's size; the
## import is drawn small like the sheet's. Built by
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
	assert_true(frames.size() >= 40, "ten jobs, four frames each")
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
	var texel := float(map.get("texel_scale", 1.0))
	assert_between(texel, 0.75, 1.0, "close to the sheet's density (a hi-DPI phone at full zoom)")
	assert_near(float(map["stand_height"]), float(sheet["stand_height"]) * texel, 0.01, "the stand height the runtime draws by")
	# The front standing cell's eyes, in sheet texels: the size to keep.
	var sheet_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/momo/momo_sheet.png"))
	sheet_img.convert(Image.FORMAT_RGBA8)
	var front := sheet_img.get_region(Rect2i(0, 0, int(sheet["cell"][0]), int(sheet["cell"][1])))
	var anchor_eye := float(Build.eyes(front)[0]) * texel
	var faces := {}
	for f: Dictionary in map["frames"]:
		var cut := img.get_region(_rect(f))
		var pv := Vector2(f["pivot"][0], f["pivot"][1])
		var feet := Build.feet_point(cut)
		assert_near(pv.y, feet.y, 1.0, "%s: the pivot on the lowest of the feet" % f["name"])
		assert_near(pv.x, feet.x, 1.0, "%s: between the feet" % f["name"])
		assert_true(cut.get_height() <= float(map["stand_height"]) * 1.4, "%s: a tool raised, never a giant (%d)" % [f["name"], cut.get_height()])
		# A strike squeezes the eyes shut: those frames show no eyes to
		# measure, and every job has frames that do (below).
		var e := Build.eyes(cut)
		if not e.is_empty():
			var job := String(f["name"]).rsplit("_", true, 1)[0]
			faces[job] = int(faces.get(job, 0)) + 1
			assert_between(float(e[0]) / anchor_eye, 0.8, 1.15, "%s: the same Momo, the same size (eyes %.1f vs %.1f)" % [f["name"], e[0], anchor_eye])
	for anim: String in map["animations"]:
		var job := anim.trim_prefix("work_")
		assert_true(int(faces.get(job, 0)) >= 2, "%s: its face measured in two frames at least (%d)" % [job, int(faces.get(job, 0))])


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
	# The atlas stays about the sheet's size (1280 square): 40 frames at 0.8
	# of its density, packed.
	assert_true(img.get_width() * img.get_height() <= 1536 * 1280, "%dx%d" % [img.get_width(), img.get_height()])
	assert_eq(sheet.stand_height_of("dig_0"), float(map["stand_height"]), "a work frame is drawn by the atlas's density")
	assert_eq(sheet.stand_height_of("front_idle"), sheet.stand_height, "a sheet cell by the sheet's")


## Step 67: every job is a loop of at least four frames, each its own
## drawing -- not one picture repeated or played back and forth -- and each
## visibly different from every other: stood on the same feet, a good share
## of their drawn pixels change between any two (the outline alone would
## call writing one picture: only the pencil, the lines and the face move).
func test_every_job_plays_four_different_frames() -> void:
	for anim: String in map["animations"]:
		var a: Dictionary = map["animations"][anim]
		var cells: Array = a["cells"]
		assert_true(cells.size() >= 4, "%s: at least four frames (%d)" % [anim, cells.size()])
		var names := {}
		for c: String in cells:
			names[c] = true
		assert_eq(names.size(), cells.size(), "%s: no frame repeated (not A-B-A-B)" % anim)
		var timed: Array = a.get("durations", [])
		assert_eq(timed.size(), cells.size(), "%s: a time for every frame" % anim)
		for d: Variant in timed:
			assert_between(float(d), 0.05, 1.0, "%s: a frame between 0.05 and 1 s" % anim)
		assert_true(float(a.get("rest", 0.0)) >= 0.0, "%s: a pause after each pass" % anim)
		for i in cells.size():
			for j in range(i + 1, cells.size()):
				var changed := _changed(_frame(cells[i]), _frame(cells[j]))
				assert_true(changed > 0.12, "%s: %s and %s are different drawings (%.0f%% of the pixels change)" % [anim, cells[i], cells[j], changed * 100.0])


## The share of the drawn pixels (either frame) whose colour changes
## clearly between two frames, feet on feet.
func _changed(a: Dictionary, b: Dictionary) -> float:
	var ra := _rect(a)
	var rb := _rect(b)
	var pa := Vector2(a["pivot"][0], a["pivot"][1])
	var pb := Vector2(b["pivot"][0], b["pivot"][1])
	var changed := 0
	var any := 0
	var lo := Vector2i(floori(minf(-pa.x, -pb.x)), floori(minf(-pa.y, -pb.y)))
	var hi := Vector2i(ceili(maxf(ra.size.x - pa.x, rb.size.x - pb.x)), ceili(maxf(ra.size.y - pa.y, rb.size.y - pb.y)))
	for y in range(lo.y, hi.y, 2):
		for x in range(lo.x, hi.x, 2):
			var ca := _px(ra, Vector2i(roundi(x + pa.x), roundi(y + pa.y)))
			var cb := _px(rb, Vector2i(roundi(x + pb.x), roundi(y + pb.y)))
			if ca.a < 0.5 and cb.a < 0.5:
				continue
			any += 1
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) + absf(ca.a - cb.a) > 0.35:
				changed += 1
	return float(changed) / maxf(any, 1.0)


func _px(r: Rect2i, p: Vector2i) -> Color:
	if p.x < 0 or p.y < 0 or p.x >= r.size.x or p.y >= r.size.y:
		return Color(0, 0, 0, 0)
	return img.get_pixel(r.position.x + p.x, r.position.y + p.y)
