extends "res://tests/framework/test_case.gd"

## The player can see the economy work: crops waiting in the store and what
## they will fetch, and a "+$N" when the day's sale lands.

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


func test_store_line_shows_crops_and_their_value() -> void:
	hud.refresh(true)
	assert_false(hud.production_label.visible, "nothing in store: no line")
	(sim.system(&"inventory") as InventorySystem).add("crop", 2)
	hud.refresh()
	assert_true(hud.production_label.visible, "crops in store: the line appears")
	assert_eq(hud.production_label.text, "2 crops · +$10", "two batches worth $10 tomorrow")


func test_sale_pops_the_amount_by_the_money() -> void:
	(sim.system(&"inventory") as InventorySystem).add("crop", 1)
	var before := hud.get_child_count()
	sim.advance_to(sim.clock.next_day_start_ms())
	hud.refresh()
	assert_eq(hud._money_label.text, "15", "$10 + $5")
	var pops := hud.get_children().filter(func(n: Node) -> bool: return n is Label and (n as Label).text == "+$5")
	assert_eq(pops.size(), 1, "a single '+$5' rises from the money pill")
	assert_true(hud.get_child_count() > before, "added on top of the HUD")
	assert_false(hud.production_label.visible, "and the store line is gone with the crops")
