extends "res://tests/framework/test_case.gd"

## Buying the sea where it is: a mouse hovering a sea tile beside the island
## sees the block and its price, a click buys it at once and it rises; a
## finger previews with the first tap and buys with the second; not enough
## money says so and buys nothing; only tiles side by side with the island;
## panning and brushing never buy.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var cams: CameraController
var proj: IsoProjection
var vp: Viewport
var buyer: LandBuyer
var preview: LandPreview
var world: WorldSystem
var economy: EconomySystem


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	cams = main.get("cameras")
	proj = main.get("projection")
	vp = main.get_viewport()
	buyer = main.get("land_buyer")
	preview = main.get("land_preview")
	world = sim.system(&"world")
	economy = sim.system(&"economy")
	LocaleService.apply("en")
	# Mouse events right after a touch are ignored as emulation: start clean.
	(main.get("router") as InputRouter).set("_last_touch_ms", -100000)


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _at(c: Vector2i) -> Vector2:
	return cams.world_to_screen(proj.cell_center(c))


func _hover(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	vp.push_input(m, true)


func _click(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.position = p
		b.pressed = pressed
		vp.push_input(b, true)


func _finger(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		vp.push_input(t, true)


## The k-th land purchase's price, from the data.
func _price(k: int) -> int:
	return (sim.system(&"land") as LandSystem).cost_of(k)


func test_hover_shows_the_block_and_its_price() -> void:
	economy.earn(100, "test")
	_hover(_at(Vector2i(2, 0)))
	assert_eq(preview.focus, Vector2i(2, 0), "the sea tile beside the island is previewed")
	assert_eq(preview.price_text(), "$%d" % _price(0), "with its price")
	assert_true(preview.affordable, "gold: it can be bought")
	_hover(_at(Vector2i(0, 0)))
	assert_eq(preview.focus, LandPreview.NONE, "over the island: nothing")
	assert_eq(world.owned_count(), 4, "hovering buys nothing")


func test_click_buys_at_once_and_the_land_rises() -> void:
	economy.earn(100, "test")
	_hover(_at(Vector2i(2, 0)))
	_click(_at(Vector2i(2, 0)))
	assert_true(world.is_owned(Vector2i(2, 0)), "bought with one click")
	assert_eq(economy.money, 110 - _price(0), "the real price")
	assert_eq((sim.system(&"land") as LandSystem).next_cost(), _price(1), "the next costs more")
	assert_eq(preview.focus, LandPreview.NONE, "the preview goes")
	assert_true(main.find_child("LandRise", true, false) != null, "and the new land rises out of the sea")


func test_a_finger_taps_twice() -> void:
	economy.earn(100, "test")
	_finger(_at(Vector2i(0, 2)))
	assert_false(world.is_owned(Vector2i(0, 2)), "the first tap buys nothing")
	assert_eq(buyer.pending, Vector2i(0, 2), "it previews")
	assert_eq(preview.hint, "Tap again to buy", "and says what a second tap does")
	_finger(_at(Vector2i(2, 1)))
	assert_eq(buyer.pending, Vector2i(2, 1), "another tile: the preview moves, still nothing bought")
	assert_eq(world.owned_count(), 4, "")
	_finger(_at(Vector2i(2, 1)))
	assert_true(world.is_owned(Vector2i(2, 1)), "the second tap on the same tile buys it")
	assert_eq(economy.money, 110 - _price(0), "for its price")
	_finger(_at(Vector2i(0, 2)))
	_finger(_at(Vector2i(0, 0)))
	assert_eq(buyer.pending, LandPreview.NONE, "a tap on the island forgets the preview")
	assert_eq(preview.focus, LandPreview.NONE, "and takes the block away")
	_finger(_at(Vector2i(0, 2)))
	_finger(_at(Vector2i(6, 6)))
	assert_eq(preview.focus, LandPreview.NONE, "so does a tap on the open sea")
	_finger(_at(Vector2i(0, 2)))
	assert_false(world.is_owned(Vector2i(0, 2)), "so the next tap there only previews again")


func test_not_enough_money() -> void:
	_hover(_at(Vector2i(2, 0)))
	assert_false(preview.affordable, "$10 for a $50 tile: shown red")
	assert_eq(preview.hint, "Not enough money", "with the reason")
	_click(_at(Vector2i(2, 0)))
	assert_false(world.is_owned(Vector2i(2, 0)), "the click buys nothing")
	assert_eq(buyer.last_result["reason"], "err.not_enough_money", "and is refused")
	assert_eq(economy.money, 10, "nothing taken")


func test_only_side_by_side() -> void:
	economy.earn(500, "test")
	_hover(_at(Vector2i(2, 2)))
	assert_eq(preview.focus, LandPreview.NONE, "corner to corner is not next to the island")
	_click(_at(Vector2i(2, 2)))
	assert_false(world.is_owned(Vector2i(2, 2)), "and cannot be bought")
	_click(_at(Vector2i(5, 0)))
	assert_false(world.is_owned(Vector2i(5, 0)), "neither can the open sea")
	assert_eq(world.owned_count(), 4, "no tile apart from the island, ever")


func test_panning_and_brushing_never_buy() -> void:
	economy.earn(500, "test")
	var from := _at(Vector2i(2, 0))
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.position = from
	b.pressed = true
	vp.push_input(b, true)
	for i in range(1, 8):
		var m := InputEventMouseMotion.new()
		m.position = from + Vector2(12 * i, 4 * i)
		vp.push_input(m, true)
	b = b.duplicate()
	b.pressed = false
	vp.push_input(b, true)
	assert_eq(world.owned_count(), 4, "a pan that started on the sea buys nothing")
	(main.get("selection") as SelectionController).select_momo(1)
	(main.get("watch_editor") as WatchEditor).begin_edit()
	_hover(_at(Vector2i(2, 0)))
	assert_eq(preview.focus, LandPreview.NONE, "editing a Momo's tiles: no land preview")
	_click(_at(Vector2i(2, 0)))
	assert_eq(world.owned_count(), 4, "and a click on the sea ends editing, buying nothing")
	assert_false((main.get("watch_editor") as WatchEditor).active, "")
