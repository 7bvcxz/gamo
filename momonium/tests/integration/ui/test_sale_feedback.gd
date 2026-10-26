extends "res://tests/framework/test_case.gd"

## The player can see the economy work: what the island's work earned in the
## last minute ("+$N/min"), and a "+$N" the moment a harvest is picked and
## sold (Step 50: no waiting for dawn).

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var hud: Hud


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	hud = main.get("hud")
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _harvest_by_hand(farm: int) -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	for i in bs.stages(bs.get_building(farm)).size():
		var b := bs.get_building(farm)
		if b["state"] != BuildingSystem.IDLE:
			sim.advance_ms(bs.remaining_ms(b))
		sim.execute({"type": "building.tap", "id": farm})
		sim.advance_ms(bs.remaining_ms(b))


func test_the_rate_line_shows_the_last_minute() -> void:
	hud.refresh(true)
	assert_false(hud.production_label.visible, "nothing earned yet: no line")
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(0, 0))
	_harvest_by_hand(farm)
	_harvest_by_hand(farm)
	hud.refresh()
	var price := (sim.system(&"economy") as EconomySystem).unit_price("crop")
	assert_true(hud.production_label.visible, "money earned: the line appears")
	assert_eq(hud.production_label.text, "+$%d/min" % (2 * price), "two harvests in the last minute")
	# Placed by its width once the text arrives: inside the screen (Step 45 blind playtest: "1 c…").
	await tree.process_frame
	var right := hud.production_label.position.x + hud.production_label.size.x
	assert_true(right <= hud.size.x + 0.5, "the line ends inside the screen (%.0f of %.0f)" % [right, hud.size.x])
	assert_true(hud.production_label.position.x >= 0.0, "and starts inside it")
	sim.advance_ms(61000)
	hud.refresh()
	assert_false(hud.production_label.visible, "a quiet minute: the line goes")


func test_a_harvest_pops_its_money_at_once() -> void:
	var farm := (sim.system(&"buildings") as BuildingSystem).place_ready("farm", Vector2i(0, 0), "harvest")
	var before := hud.get_child_count()
	var money := (sim.system(&"economy") as EconomySystem).money
	_harvest_by_hand(farm)
	hud.refresh()
	var price := (sim.system(&"economy") as EconomySystem).unit_price("crop")
	assert_eq(hud._money_label.text, str(money + price), "paid the moment it was picked")
	# Feedback gathers for a moment (Step 47) so a burst pops once.
	hud.flush_feedback()
	var pops := hud.get_children().filter(func(n: Node) -> bool: return n is Label and (n as Label).text == "+$%d" % price)
	assert_eq(pops.size(), 1, "a single '+$%d' rises from the money pill" % price)
	assert_true(hud.get_child_count() > before, "added on top of the HUD")
	var fx: FeedbackFx = main.get("feedback_fx")
	assert_true(fx.shown.any(func(e: Dictionary) -> bool: return String(e["kind"]) == "money" and String(e["text"]) == "+$%d" % price), "and over the farm itself (%s)" % [fx.shown])
