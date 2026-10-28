extends "res://tests/framework/test_case.gd"

## Step 71: the research panel on a deep tree. A new island shows two
## disciplines and a handful of cards; the tabs and the cards come with the
## level; a late player reaches the eighth tier, the tree scrolls on its own
## to it while the details stay where they are; and every line fits the
## panel -- at most three cards, none overlapping, none off the edge.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var frame: PanelFrame
var prog: ProgressionSystem


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	with_starter_momo(sim)
	await tree.process_frame
	frame = main.get("research_frame")
	prog = sim.system(&"progression")
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _to_level(n: int) -> void:
	while prog.level < n:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")


func _views() -> Array:
	return main.get("research_views")


func _shown_tabs() -> Array:
	return frame.tabs.filter(func(t: Dictionary) -> bool: return (t["button"] as Button).visible).map(func(t: Dictionary) -> String: return (t["button"] as Button).text)


func _shown_cards() -> int:
	var n := 0
	for v: ResearchView in _views():
		v.refresh()
		for id: String in v.cards:
			n += 1 if (v.cards[id] as Button).visible else 0
	return n


func test_tabs_and_cards_come_with_the_level() -> void:
	main.call("open_research")
	await tree.process_frame
	assert_eq(_shown_tabs(), ["Farm", "Lab", "Points"], "a new island: two disciplines")
	assert_between(_shown_cards(), 2, 3, "two or three cards")
	var before := _shown_cards()
	_to_level(2)
	await tree.process_frame
	assert_eq(_shown_tabs(), ["Farm", "Lumber", "Mine", "Lab", "General", "Points"], "Lv 2: what Lv 3 opens shows too, power (Lv 4) still to come")
	assert_true(_shown_cards() > before, "more cards (%d -> %d)" % [before, _shown_cards()])
	var farm: ResearchView = _views()[0]
	assert_true(farm.more_later().has("watering_efficiency"), "a stub under watering: its next tier (Lv 4) is still hidden (%s)" % [farm.more_later()])
	_to_level(3)
	await tree.process_frame
	assert_eq(_shown_tabs().size(), 7, "Lv 3: every tab (power opens at Lv 4)")


func test_a_late_player_reaches_tier_8_and_the_details_stay() -> void:
	_to_level(11)
	main.call("open_research", "combine_harvester")
	for i in 3:
		await tree.process_frame
	var farm: ResearchView = _views()[0]
	var card: Button = farm.cards["combine_harvester"]
	assert_true(card.visible, "the farm's eighth tier is on the screen")
	assert_eq(farm.selected, "combine_harvester", "and picked")
	assert_true(farm.tree.custom_minimum_size.y > farm.tree_scroll.size.y, "the tree is taller than its view: it scrolls (%.0f > %.0f)" % [farm.tree.custom_minimum_size.y, farm.tree_scroll.size.y])
	await tree.process_frame
	var view_rect := farm.tree_scroll.get_global_rect()
	assert_true(view_rect.grow(1.0).encloses(card.get_global_rect()), "scrolled to it (%s in %s)" % [card.get_global_rect(), view_rect])
	var detail_y := farm.detail.get_global_rect().position.y
	farm.tree_scroll.scroll_vertical = 0
	await tree.process_frame
	assert_near(farm.detail.get_global_rect().position.y, detail_y, 0.5, "the details do not scroll with the tree")
	assert_eq(farm.detail_name.text, "Combine harvester", "they show the chosen topic")
	var outer: ScrollContainer = frame.scroll
	assert_true(outer.get_v_scroll_bar().max_value <= outer.size.y + 1.0, "the panel itself needs no scrolling")


func test_every_line_fits_the_panel() -> void:
	_to_level(11)
	main.call("open_research")
	await tree.process_frame
	for i in _views().size():
		frame.show_tab(i)
		await tree.process_frame
		var v: ResearchView = _views()[i]
		var shown: Array = v.cards.keys().filter(func(id: String) -> bool: return (v.cards[id] as Button).visible)
		assert_true(shown.size() >= 8, "%s: the tree at Lv 11 (%d cards)" % [v.industry, shown.size()])
		var rows := {}
		for id: String in shown:
			var c: Button = v.cards[id]
			assert_true(c.position.x >= -0.5 and c.position.x + c.size.x <= v.tree.size.x + 0.5, "%s: %s inside the tree's width" % [v.industry, id])
			assert_true(c.size.x >= 90.0, "%s: %s readable (%.0f wide)" % [v.industry, id, c.size.x])
			rows[int(c.position.y)] = int(rows.get(int(c.position.y), 0)) + 1
			for other: String in shown:
				if other != id:
					assert_false(c.get_rect().intersects((v.cards[other] as Button).get_rect()), "%s: %s and %s apart" % [v.industry, id, other])
		for y: int in rows:
			assert_true(int(rows[y]) <= 3, "%s: three cards a line at most (%d at y %d)" % [v.industry, int(rows[y]), y])
