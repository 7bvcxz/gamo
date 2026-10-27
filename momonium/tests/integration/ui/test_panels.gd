extends "res://tests/framework/test_case.gd"

## The panels: one frame, tabs, dismissible by ✕, by the scrim and by the
## corner button; out of the way when closed; every value read from the
## simulation and following it while open; touch-sized controls.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var frame: PanelFrame
var detail: PanelFrame
var vp: Viewport


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	# The Momo these cases are about (Step 53: a new island has none).
	with_starter_momo(sim)
	await tree.process_frame
	frame = main.get("status_frame")
	detail = main.get("detail_frame")
	vp = main.get_viewport()
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _tap(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		vp.push_input(t, true)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = p
		m.pressed = pressed
		vp.push_input(m, true)


func test_closed_panels_leave_the_island_alone() -> void:
	assert_false(frame.visible, "nothing open at start")
	assert_false(detail.visible, "nothing open at start")
	assert_eq(frame.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a closed frame takes no input")
	var hud: Hud = main.get("hud")
	assert_true(frame.get_index() < hud.get_index(), "frames sit under the HUD")


func test_tabs_switch_and_every_control_is_touch_sized() -> void:
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	assert_eq(frame.tabs.size(), 6, "status, store, money, records, life, stats")
	for i in frame.tabs.size():
		var b: Button = frame.tabs[i]["button"]
		assert_true(b.size.y >= 48.0, "tab %d is tall enough (%.0f)" % [i, b.size.y])
		_tap(b.get_global_rect().get_center())
		assert_eq(frame.current, i, "tapping tab %d shows it" % i)
		assert_true((frame.tabs[i]["view"] as Control).visible, "its view is visible")
	assert_true(frame.close_button.size.x >= 48.0 and frame.close_button.size.y >= 48.0, "✕ is a finger's size")


func test_dismiss_by_close_scrim_and_corner_button() -> void:
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	_tap(frame.close_button.get_global_rect().get_center())
	assert_false(frame.visible, "✕ closes")
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	var outside := Vector2(frame.card_rect().position.x + 20.0, frame.card_rect().end.y + 60.0)
	_tap(outside)
	assert_false(frame.visible, "a tap on the island around the card closes it")
	main.call("_on_hud_action", &"status")
	main.call("_on_hud_action", &"hire")
	assert_false(frame.visible, "opening the hire card puts the panel away")
	main.call("_on_hud_action", &"status")
	main.call("_on_hud_action", &"shop")
	assert_false(frame.visible, "and so does the Premium Shop")


func test_store_follows_the_inventory_live() -> void:
	main.call("_on_hud_action", &"status")
	frame.show_tab(1)
	var inv: InventorySystem = sim.system(&"inventory")
	var view: InventoryView = main.get("inventory_view")
	assert_eq(view.rows.keys(), ["crop"], "only crops are known at the start")
	inv.count_made("crop", 3)
	view.refresh()
	assert_false((view.rows["crop"]["bar"] as Bar).visible, "crops never fill the store: no stack bar")
	assert_true((view.rows["crop"]["note"] as Label).text.begins_with("Sold as picked"), "they are sold as they are picked (%s)" % (view.rows["crop"]["note"] as Label).text)
	assert_true((view.rows["crop"]["note"] as Label).text.contains("Made 3"), "and what was grown")
	inv.add("wood", 2, "yield:lumberyard")
	assert_true(view.rows.has("wood"), "a new item appears when the island first has it")
	assert_eq((view.rows["wood"]["count"] as Label).text, "2 / 50", "count follows at once")
	assert_near((view.rows["wood"]["bar"] as Bar).value, 2.0 / 50.0, 0.001, "and the bar")


func test_money_tab_is_the_ledger() -> void:
	var eco: EconomySystem = sim.system(&"economy")
	eco.earn(100, "sale")
	eco.spend(30, "hire")
	eco.spend(10, "build:farm")
	main.call("_on_hud_action", &"status")
	frame.show_tab(2)
	var view: EconomyView = main.get("economy_view")
	assert_eq(view.money_label.text, PanelViews.money(eco.money), "money now")
	var cats := {}
	for r: Node in view.today_box.get_children():
		cats[String(r.name)] = (r.get_node("Value") as Label).text
	assert_eq(cats, {"Cat_build": "-$10", "Cat_hire": "-$30", "Cat_sale": "+$100"}, "one row per category, signed")
	sim.advance_to(sim.clock.next_day_start_ms() + 10)
	assert_eq(view.days.days.size(), 1, "a closed day becomes a bar")
	assert_eq((view.totals_box.get_node("TotalIn/Value") as Label).text, PanelViews.money(eco.lifetime_income()), "lifetime income")


func test_records_count_the_island() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	main.call("_on_hud_action", &"status")
	frame.show_tab(3)
	var view: StatsView = main.get("stats_view")
	var n := view.numbers()
	assert_eq(n["buildings"], 1, "one building")
	assert_eq(n["momo"], 1, "one Momo")
	assert_eq(n["momo_working"], 1, "at work")
	assert_eq(n["land"], (sim.system(&"world") as WorldSystem).owned_count(), "island size")
	assert_eq((view.get_node("Row_momo/Value") as Label).text, "1 · 1 working", "shown")


func test_building_details_from_the_name() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	(main.get("selection") as SelectionController).select_building(farm)
	await tree.process_frame
	var ctx: ContextPanel = main.get("panel")
	assert_true(ctx.title.text.ends_with("›"), "the name shows it opens (%s)" % ctx.title.text)
	assert_true(ctx.title.size.y >= 44.0, "and is a finger's height")
	_tap(ctx.title.get_global_rect().get_center())
	assert_true(detail.visible, "tapping the name opens the details")
	var view: BuildingDetailView = main.get("detail_view")
	assert_eq(detail.title_label.text, "Farm", "titled with the building")
	assert_eq(view.state_label.text, "Next: Sow", "what comes next")
	var stages: Array = sim.data.building_type("farm")["cycle"]["stages"]
	var wait := float(stages[1]["cooldown"])
	var work := (float(stages[0]["seconds"]) + float(stages[1]["seconds"]) + float(stages[2]["seconds"])) * work_scale(sim)
	var momo_x := sim.data.get_float("balance", "momo.work_time_multiplier", 4.0)
	assert_eq((view.cycle_you.get_node("Value") as Label).text, BuildingDetailView.duration(work + wait), "a cycle by hand: the work + the wait")
	assert_eq((view.cycle_momo.get_node("Value") as Label).text, BuildingDetailView.duration(work * momo_x + wait), "by Momo: its work + the same wait")
	assert_eq(BuildingDetailView.duration(70.0), "1 min 10 s", "(shown as minutes and seconds)")
	assert_eq(view.workers_box.get_child(0).get_meta("who"), "empty", "an empty worker spot")
	sim.execute({"type": "building.tap", "id": farm})
	assert_eq(view.workers_box.get_child(0).get_meta("who"), "you", "you, while you sow")
	assert_eq(view.state_label.text, "Sow · %s left" % BuildingDetailView.duration(float(stages[0]["seconds"]) * work_scale(sim)), "and the time left")
	sim.advance_ms(int(float(stages[0]["seconds"]) * work_scale(sim) * 1000.0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	view.refresh()
	assert_eq(view.workers_box.get_child(0).get_meta("who"), "momo:1", "the assigned Momo fills the spot")
	assert_eq((view.workers_box.get_child(0).find_child("Status", true, false) as Label).text, "On the way", "walking over")
	sim.advance_ms(int((sim.system(&"momo") as MomoSystem).get_momo(1)["end"]) - sim.now_ms() + 10)
	view.refresh()
	assert_eq((view.workers_box.get_child(0).find_child("Status", true, false) as Label).text, "Working", "and working")
	sim.advance_ms(int(round(float(stages[1]["seconds"]) * work_scale(sim) * momo_x * 1000.0)))
	assert_eq(view.state_label.text, "Harvest in %d s" % int(wait), "then the crop ripens before the harvest")
	assert_eq((view.done_row.get_node("Value") as Label).text, "2", "two jobs done")


func test_only_one_panel_at_a_time() -> void:
	var buildings: BuildingSystem = sim.system(&"buildings")
	var farm := buildings.place_instant("farm", Vector2i(1, 0))
	main.call("open_details", farm)
	assert_true(detail.visible, "details open")
	main.call("_on_hud_action", &"status")
	assert_false(detail.visible, "Status replaces the details")
	assert_true(frame.visible, "Status open")
	main.call("open_details", farm)
	assert_false(frame.visible, "and the other way round")


func test_details_close_when_the_building_goes() -> void:
	(sim.system(&"economy") as EconomySystem).earn(100, "test")
	var id: int = sim.execute({"type": "building.place", "building": "farm", "anchor": [1, 0]})["id"]
	main.call("open_details", id)
	assert_true(detail.visible, "details of a building under construction")
	assert_eq((main.get("detail_view") as BuildingDetailView).state_label.text, "Building · %s left" % BuildingDetailView.duration(float(sim.data.building_type("farm")["build_seconds"])), "counting down")
	sim.execute({"type": "building.cancel", "id": id})
	assert_false(detail.visible, "cancelled: the details close instead of showing a ghost")


func test_escape_closes() -> void:
	main.call("_on_hud_action", &"status")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	vp.push_input(esc)
	assert_false(frame.visible, "Escape closes the panel")


func test_panels_follow_the_language() -> void:
	main.call("_on_hud_action", &"status")
	frame.show_tab(2)
	LocaleService.apply("ko")
	await tree.process_frame
	assert_eq((frame.tabs[2]["button"] as Button).text, "경제", "tabs relabel")
	frame.refresh()
	assert_eq(((main.get("economy_view") as EconomyView).today_box.get_child(0) as Label).text, "아직 없음", "bodies too")
	LocaleService.apply("en")
