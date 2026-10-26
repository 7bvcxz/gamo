extends "res://tests/framework/test_case.gd"

## Step 46 art pass: the painted assets are working game assets -- props that
## dress the island but never stand on a building, painted sprites that keep
## the frame their pivots were measured in, Momo's portrait composed from the
## rig's parts, and panels that stay clear of the HUD. (The painted sky went in
## Step 56: there is no sky.)

const MainScene := preload("res://scenes/main.tscn")
const WindowLights := preload("res://tools/art/gen/window_lights.gd")

var main: Node
var sim: Simulation
var world: WorldSystem
var props: IslandProps
var proj: IsoProjection


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	world = sim.system(&"world")
	props = main.get("island_props")
	proj = main.get("projection")
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _prop_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for s: Sprite2D in props.sprites():
		if is_instance_valid(s) and not s.is_queued_for_deletion():
			out.append(proj.cell_at(s.position))
	return out


func test_props_dress_the_island_on_free_land_only() -> void:
	for x in range(-1, 4):
		for y in range(-1, 4):
			world.add_land(Vector2i(x, y))
	await tree.process_frame
	await tree.process_frame
	assert_true(props.count() >= 8, "a 5x5 island is dressed (%d props)" % props.count())
	for c: Vector2i in _prop_cells():
		assert_true(world.is_owned(c), "prop on owned land %s" % c)
		assert_false(world.is_occupied(c), "prop on a free cell %s" % c)
	var bs: BuildingSystem = sim.system(&"buildings")
	# Build on every cell that has a prop: they must all make way.
	var dressed := _prop_cells()
	for c: Vector2i in dressed:
		if not world.is_occupied(c):
			bs.place_instant("farm", c)
	await tree.process_frame
	await tree.process_frame
	for c: Vector2i in _prop_cells():
		assert_false(world.is_occupied(c), "no prop left under a building (%s)" % c)


func test_props_are_stable_and_change_nothing() -> void:
	var before: Dictionary = world.save_state()
	var open: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0)]
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(5, -3), Vector2i(-7, 2)]:
		assert_eq(IslandProps.props_for(cell, open), IslandProps.props_for(cell, open), "props of %s are deterministic" % cell)
	props.rebuild()
	await tree.process_frame
	assert_eq(world.save_state(), before, "dressing the island changes nothing in the world")
	for s: Sprite2D in props.sprites():
		assert_false(s.is_processing(), "props run no per-frame code")


func test_trees_stand_on_far_edges_and_props_stay_in_their_cell() -> void:
	var sides: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
	var trees := 0
	for x in range(-20, 20):
		for y in range(-20, 20):
			var cell := Vector2i(x, y)
			var open: Array[Vector2i] = []
			for d: Vector2i in sides:
				if (x * 31 + y * 17 + d.x * 7 + d.y * 3) % 3 == 0:
					open.append(d)
			for p: Array in IslandProps.props_for(cell, open):
				var local: Vector2 = p[1] - Vector2(cell)
				assert_true(local.x > 0.0 and local.x < 1.0 and local.y > 0.0 and local.y < 1.0, "prop inside its cell")
				if (IslandProps.TREES + IslandProps.FAR_GOODS).any(func(t: Array) -> bool: return t[0] == p[0]):
					trees += 1
					assert_true(local.x < 0.3 or local.y < 0.3, "a tree or a crate stands on a far edge, behind the island (%s)" % p[0])
				if open.is_empty():
					assert_true(p[0] in ["prop_flowers", "prop_grass"], "inside the island only small flowers and grass")
	assert_true(trees > 0, "some far edges grow a tree")


func test_painted_sprites_keep_the_frame_of_their_pivots() -> void:
	# A painted png replaces an SVG drawn in a frame the pivots were measured
	# in: it must be exactly that frame at the sprite's scale -- plus, for a
	# Step 52 redraw that rose higher, its `headroom` on top.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	var checked := 0
	for name: String in manifest["sprites"]:
		var spec: Dictionary = manifest["sprites"][name]
		var src := String(spec["source"])
		var svg := "res://assets/src/svg/%s.svg" % src.get_file().get_basename()
		if not src.ends_with(".png") or not FileAccess.file_exists(svg) or name.ends_with("_lit"):
			continue
		var m := RegEx.create_from_string("viewBox=\"[\\d.\\-]+[ ,]+[\\d.\\-]+[ ,]+([\\d.]+)[ ,]+([\\d.]+)\"").search(FileAccess.get_file_as_string(svg))
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/src/" + src))
		var want := Vector2(float(m.get_string(1)), float(m.get_string(2)) + float(spec.get("headroom", 0.0))) * float(spec.get("scale", 1.0))
		assert_true(absf(img.get_width() - want.x) <= 1.0 and absf(img.get_height() - want.y) <= 1.0, "%s is its frame %s (got %dx%d)" % [name, want, img.get_width(), img.get_height()])
		checked += 1
	assert_true(checked >= 20, "the painted buildings and crops are checked (%d)" % checked)


## Step 52: a building's lit windows are cut from its own drawing -- every lit
## texel lands, through the two origins, on a pane of the building (its glass,
## amber or highlight), so a shift of even one texel would show.
func test_lit_windows_lie_on_their_building() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	var checked := 0
	for name: String in manifest["sprites"]:
		if not name.ends_with("_lit"):
			continue
		var lit_spec: Dictionary = manifest["sprites"][name]
		var spec: Dictionary = manifest["sprites"][name.trim_suffix("_lit")]
		var k := float(spec.get("scale", 1.0))
		assert_eq(float(lit_spec.get("scale", 1.0)), k, "%s at its building's scale" % name)
		var lit := Image.load_from_file(ProjectSettings.globalize_path("res://assets/src/" + String(lit_spec["source"])))
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/src/" + String(spec["source"])))
		var o_lit: Array = lit_spec["pivots"]["origin"]
		var o: Array = spec["pivots"]["origin"]
		var shift := Vector2i(roundi((float(o[0]) - float(o_lit[0])) * k), roundi((float(o[1]) - float(o_lit[1])) * k))
		var total := 0
		var on := 0
		for y in range(0, lit.get_height(), 2):
			for x in range(0, lit.get_width(), 2):
				if lit.get_pixel(x, y).a < 0.5:
					continue
				total += 1
				var p := Vector2i(x, y) + shift
				if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
					continue
				var c := img.get_pixel(p.x, p.y)
				if WindowLights._is_glass(c) or WindowLights._is_amber(c) or (c.a > 0.9 and c.r > 0.85 and c.g > 0.88 and c.b > 0.88):
					on += 1
		assert_true(total > 0 and on == total, "%s lies on its building (%d of %d)" % [name, on, total])
		checked += 1
	assert_true(checked >= 8, "the houses have lit windows (%d)" % checked)


## Step 51: the panels' Momo is the island's Momo -- the portrait is cut from
## the sheet's front standing cell, pixel for pixel, in the frame the old
## drawing had (feet at 100, 210).
func test_momo_portrait_is_the_sheets_front_cell() -> void:
	var portrait := Image.load_from_file(ProjectSettings.globalize_path("res://assets/src/png/momo_front.png"))
	var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/momo/momo_sheet.png"))
	portrait.convert(Image.FORMAT_RGBA8)
	sheet.convert(Image.FORMAT_RGBA8)
	var map := MomoSheet.shared()
	var c: Dictionary = map.cells["front_idle"]
	var at := Vector2i(int(c["col"]) * map.cell.x + int(map.pivot.x) - 100, int(c["row"]) * map.cell.y + int(map.pivot.y) - 210)
	assert_eq(portrait.get_size(), Vector2i(200, 220), "the old frame")
	assert_eq(portrait.get_data(), sheet.get_region(Rect2i(at, Vector2i(200, 220))).get_data(), "the sheet's front cell (rebuild with tools/art/gen/build_momo_sheet.gd)")


func test_research_card_stays_clear_of_the_side_buttons() -> void:
	var research: PanelFrame = main.get("research_frame")
	research.open(0)
	await tree.process_frame
	await tree.process_frame
	var vp_w := main.get_viewport().get_visible_rect().size.x
	assert_true(research.card_rect().end.x <= vp_w - research.right_reserved + 1.0, "the research card (%s) leaves the HUD's side buttons free (%.0f)" % [research.card_rect(), vp_w - research.right_reserved])
	research.show_tab(research.tabs.size() - 1)
	await tree.process_frame
	await tree.process_frame
	var last: Button = research.tabs[research.tabs.size() - 1]["button"]
	var clip := research.tab_scroll.get_global_rect()
	assert_true(clip.grow(1.0).encloses(last.get_global_rect()), "the chosen tab is scrolled into view")


func test_status_tabs_all_fit_without_scrolling() -> void:
	# The Status panel's few tabs must all be visible at once (only Research,
	# with a tab per industry, needs to scroll).
	var status: PanelFrame = main.get("status_frame")
	status.open(0)
	await tree.process_frame
	await tree.process_frame
	var clip := status.tab_scroll.get_global_rect().grow(1.0)
	for t: Dictionary in status.tabs:
		assert_true(clip.encloses((t["button"] as Button).get_global_rect()), "Status tab %s is in view" % t["key"])
