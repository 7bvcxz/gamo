extends "res://tests/framework/test_case.gd"

## E+ (Steps 97-98) in the Lab's frame: for E's three minutes the same line
## as E delivery for delivery (the same TycoonLine, E's ten levels, the same
## purchases, the same coins; Step 98 adds twenty levels after them),
## drawn big -- the line takes the play area's shape (straight down on a
## phone, an L on a nearly square one, straight across on a wide screen), stays
## between the counter and the button, and draws a product at least 1.8 times
## as big as E does. A delivery pays once and only a delivery pays; an upgrade
## is measured once its goods reach the crate (deliveries a minute before ->
## after); a paused line does not move.

const MainScene := preload("res://lab/main.tscn")

var app: LabApp


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	tree.root.size = Vector2i(720, 1280)
	tree.paused = false
	await tree.process_frame


func _open(id: String) -> LabExperiment:
	app.open(id)
	# Play time only by the test's steps, from the first frame on (two real
	# frames of different lengths would start E and E+ differently).
	app.host.set_process(false)
	await tree.process_frame
	await tree.process_frame
	return app.host.experiment


func test_the_same_line_as_e_delivery_for_delivery() -> void:
	# E's three minutes: E+ keeps E's first ten levels (Step 98 adds the rest).
	var results: Array[Dictionary] = []
	for id: String in ["tycoon", "tycoon-plus"]:
		var e := await _open(id)
		for i in 360:
			app.host.step(0.5)
			if bool(e.action_info().get("affordable", false)):
				app.host.press_action()
		var st := e.state()
		results.append({"coins": st["coins"], "earned": st["earned"], "level": st["level"], "delivered": st["delivered"], "spawned": st["spawned"], "on_belt": st["on_belt"]})
		app.back()
		await tree.process_frame
	assert_eq(results[1], results[0], "E+ makes what E makes: %s" % str(results[0]))
	assert_true(int(results[0]["level"]) >= 7, "three minutes in, well up the line (Lv%d)" % int(results[0]["level"]))


func test_a_delivery_pays_once_and_only_deliveries_pay() -> void:
	var e := await _open("tycoon-plus")
	app.host.step(6.0)
	assert_eq(int(e.state()["delivered"]), 0, "nothing has reached the crate yet")
	assert_eq(int(e.state()["coins"]), 0, "so nothing is paid")
	assert_eq(int(e.get("deliveries_shown")), 0, "and nothing is shown as paid")
	for i in 120:
		app.host.step(0.5)
	var st := e.state()
	assert_true(int(st["delivered"]) > 10, "deliveries came (%d)" % int(st["delivered"]))
	assert_eq(int(st["earned"]), int(st["delivered"]) * int(st["value"]), "every coin is a delivery")
	assert_true(bool(st["unique_deliveries"]), "no item delivered twice")
	assert_true(int(e.get("deliveries_shown")) <= int(st["delivered"]), "never more '+n' than deliveries")


func test_the_line_takes_the_screens_shape_and_stays_in_the_play_area() -> void:
	for spec: Array in [[Vector2i(720, 1280), "down"], [Vector2i(720, 1558), "down"], [Vector2i(900, 1000), "turn"], [Vector2i(1600, 1000), "right"]]:
		tree.root.size = spec[0]
		await tree.process_frame
		var e := await _open("tycoon-plus")
		for lv: int in [0, 5, 10]:
			e.dev("level", lv)
			e.set("_zoom_t", 1.0)
			e.call("_frame", false)
			await tree.process_frame
			var st := e.state()
			assert_eq(String(st["orientation"]), String(spec[1]), "%s: %s" % [str(spec[0]), spec[1]])
			var lr: Array = st["line_rect"]
			var pa: Array = st["play_rect"]
			var line := Rect2(lr[0], lr[1], lr[2], lr[3])
			var area := Rect2(pa[0], pa[1], pa[2], pa[3]).grow(2.0)
			assert_true(area.encloses(line), "%s Lv%d: the line %s is in the play area %s" % [str(spec[0]), lv, line, area])
			var button := app.host.action_button.get_global_rect()
			var counter := app.host.resource_box.get_global_rect()
			assert_false(line.intersects(button), "%s Lv%d: clear of the button" % [str(spec[0]), lv])
			assert_false(line.intersects(counter), "%s Lv%d: clear of the counter" % [str(spec[0]), lv])
		app.back()
		await tree.process_frame


func test_a_product_is_drawn_much_bigger_than_in_e() -> void:
	var sizes := {}
	for id: String in ["tycoon", "tycoon-plus"]:
		var e := await _open(id)
		for lv: int in [0, 10]:
			e.dev("level", lv)
			e.set("_zoom_t", 1.0)
			if id == "tycoon-plus":
				e.call("_frame", false)
			await tree.process_frame
			var world: Node2D = e.get("world")
			var product := LabAtlas.texture(String(TycoonLevels.row(lv)["product"]))
			sizes["%s%d" % [id, lv]] = product.region.size.y * 0.36 * world.scale.y if id == "tycoon" else float(e.state()["item_px"])
		app.back()
		await tree.process_frame
	for lv: int in [0, 10]:
		assert_true(float(sizes["tycoon-plus%d" % lv]) >= 1.8 * float(sizes["tycoon%d" % lv]),
			"Lv%d: a product %.0f px in E+, %.0f px in E" % [lv, float(sizes["tycoon-plus%d" % lv]), float(sizes["tycoon%d" % lv])])


func test_an_upgrade_is_measured_once_it_reaches_the_crate() -> void:
	var e := await _open("tycoon-plus")
	for i in 60:
		app.host.step(0.5)
	var before := float(e.state()["deliveries_per_min"])
	assert_near(before, 60.0 * TycoonPlusLevels.capacity(0), 0.6, "a steady line reads its real rate, not a window's count (%.1f)" % before)
	e.dev("coins", 12)
	app.host.press_action()
	assert_true(bool(e.state()["measuring"]), "measuring what the Bigger Hopper does")
	# The goods already on the belt arrive first; then the first one made
	# after the upgrade; then fifteen seconds of the new line.
	for i in 30:
		app.host.step(0.5)
	assert_true(bool(e.state()["measuring"]) or not _outputs().is_empty(), "still watching or told")
	for i in 30:
		app.host.step(0.5)
	var out := _outputs()
	assert_eq(out.size(), 1, "one measurement")
	assert_eq(String(out[0]["upgrade"]), "Bigger Hopper", "of that upgrade")
	assert_true(float(out[0]["after_per_min"]) > float(out[0]["before_per_min"]),
		"a faster hopper is told as faster: %s -> %s" % [str(out[0]["before_per_min"]), str(out[0]["after_per_min"])])
	assert_near(float(out[0]["after_per_min"]), 60.0 * TycoonPlusLevels.capacity(1), 1.0, "what the line can now make")
	assert_false(bool(e.state()["measuring"]), "done")


func test_an_upgrade_that_makes_no_more_is_not_measured() -> void:
	var e := await _open("tycoon-plus")
	e.dev("level", 12)
	for i in 40:
		app.host.step(0.5)
	var before := _outputs().size()
	e.dev("coins", TycoonPlusLevels.cost(13))
	app.host.press_action()
	assert_eq(int(e.state()["level"]), 13, "the Paint Arch")
	assert_false(bool(e.state()["measuring"]), "paint changes the goods, not how many: nothing to measure")
	for i in 80:
		app.host.step(0.5)
	assert_eq(_outputs().size(), before, "and nothing told")


func _outputs() -> Array:
	return app.host.session.milestones.filter(func(m: Dictionary) -> bool: return String(m["name"]) == "output")


func test_a_paused_line_does_not_move() -> void:
	var e := await _open("tycoon-plus")
	app.host.set_process(true)
	for i in 40:
		app.host.step(0.5)
	var line: TycoonLine = e.get("line")
	var before := JSON.stringify(line.items)
	var delivered := line.delivered
	app.host.set_pause("hidden", true)
	for i in 30:
		await tree.process_frame
	assert_eq(JSON.stringify(line.items), before, "the items stay where they were")
	assert_eq(line.delivered, delivered, "and nothing is delivered")
	app.host.set_pause("hidden", false)


func test_thirty_minutes_bring_eras_buildings_and_a_branch() -> void:
	var e := await _open("tycoon-plus")
	e.dev("level", 30)
	var st := e.state()
	assert_eq(st["eras"], ["Express Era", "Golden Era", "Festival Era", "Grand Era"], "four eras celebrated")
	assert_eq((st["decor"] as Array).size(), 5, "five buildings beside the line")
	assert_true(bool(st["branch"]), "two crates")
	assert_true(bool(st["painted"]) and bool(st["wrapped"]), "painted and wrapped goods")
	assert_eq(int(st["lanes"]), 6, "six lanes")
	var eras := app.host.session.milestones.filter(func(m: Dictionary) -> bool: return String(m["name"]) == "era")
	assert_eq(eras.size(), 4, "each era recorded")
	# By name (Step 100: a "name" in the detail lost to the milestone's own).
	assert_eq(eras.map(func(m: Dictionary) -> String: return String(m.get("era", ""))), ["Express Era", "Golden Era", "Festival Era", "Grand Era"], "with its name")


func test_the_next_change_shows_where_it_will_be() -> void:
	var e := await _open("tycoon-plus")
	var shown := {}
	for lv in range(11, 30):
		e.dev("level", lv)
		shown[String(e.state()["ghost"])] = true
	for kind: String in ["decor", "lane", "branch", "arch", "helper"]:
		assert_true(shown.has(kind), "a %s ghost before its upgrade" % kind)


func test_the_grand_alternative_buys_a_bundle() -> void:
	app.route["alt"] = "grand"
	var e := await _open("tycoon-plus")
	assert_eq(int(e.call("target")), 3, "the first press buys up to level 3")
	e.dev("coins", 72)
	app.host.press_action()
	assert_eq(int(e.state()["level"]), 3, "three levels at once")
	assert_eq(int(e.state()["coins"]), 0, "for 12 + 24 + 36")
	assert_eq(int(app.host.session.upgrades.size()), 1, "one purchase")
	assert_eq(app.host.session.variant, "grand", "the run says which")
	app.route["alt"] = ""
