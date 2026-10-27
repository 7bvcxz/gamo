extends "res://tests/framework/test_case.gd"

## Step 59: hiring and the Premium Shop are two buttons. Hire stands at the
## right edge a little below the middle, carries the "a hire would put a
## Momo to work" dot and opens the hire card, paid in the game's money. The
## shopping bag at the bottom-left (where Hire was) opens the Premium Shop:
## real-money products, all 'Coming soon' with no storefront -- it never
## hires and never spends the game's money.

const MainScene := preload("res://scenes/main.tscn")

var holder: SubViewport
var main: Node
var sim: Simulation
var hud: Hud
var vp: Viewport


## A screen of `size` for layout (a SubViewport); taps are made on the game
## window itself (720x1280, the portrait baseline) -- `size` left out.
func _open(size: Vector2i = Vector2i.ZERO) -> void:
	main = MainScene.instantiate()
	if size == Vector2i.ZERO:
		tree.root.add_child(main)
		vp = main.get_viewport()
	else:
		holder = SubViewport.new()
		holder.size = size
		tree.root.add_child(holder)
		holder.add_child(main)
		vp = holder
	await tree.process_frame
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	hud = main.get("hud")
	LocaleService.apply("en")
	await tree.process_frame


func after_each() -> void:
	LocaleService.apply("en")
	if holder != null:
		holder.queue_free()
		holder = null
	elif main != null and is_instance_valid(main):
		main.queue_free()
	main = null
	await tree.process_frame


## A finger (`touch`) or a mouse click -- one of the two, as a phone or a
## desktop sends it (both at once, a test artifact, presses a card twice).
func _tap(p: Vector2, touch: bool) -> void:
	for pressed: bool in [true, false]:
		if touch:
			var t := InputEventScreenTouch.new()
			t.position = p
			t.pressed = pressed
			vp.push_input(t, true)
		else:
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.position = p
			m.pressed = pressed
			vp.push_input(m, true)


func _tap_control(c: Control, touch: bool = true) -> void:
	_tap(c.get_global_rect().get_center(), touch)
	await tree.process_frame


func test_hire_stands_at_the_right_a_little_below_the_middle() -> void:
	for size: Vector2i in [Vector2i(720, 1280), Vector2i(720, 1558), Vector2i(720, 960), Vector2i(576, 768), Vector2i(2048, 1280), Vector2i(1575, 985), Vector2i(1260, 788)]:
		await _open(size)
		var r := hud.hire_button.get_rect()
		var h := float(size.y)
		assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(r), "%s: on screen %s" % [size, r])
		assert_true(r.end.x > size.x - 100, "%s: at the right edge" % size)
		assert_true(r.position.y >= hud.side_buttons[-1].get_rect().end.y + Hud.GAP - 0.5, "%s: below Research, Mailbox and Status" % size)
		assert_between(r.get_center().y, h * 0.4, h * 0.62, "%s: around the middle (%.0f of %.0f)" % [size, r.get_center().y, h])
		if size.y > size.x:
			assert_true(r.get_center().y >= h * 0.5, "%s: a little below the middle in portrait" % size)
		for other: Rect2 in hud.occupied_rects():
			if other != r:
				assert_false(other.intersects(r), "%s: clear of %s" % [size, other])
		assert_false(hud.corner_buttons.has(hud.hire_button), "%s: no longer a bottom-left button" % size)
		assert_eq(hud.corner_buttons.map(func(b: HudButton) -> StringName: return b.action), [&"settings", &"shop"], "%s: Settings and the Shop at the bottom-left" % size)
		await after_each()


func test_the_hiring_dot_is_on_hire_never_on_the_shop() -> void:
	await _open(Vector2i(720, 1280))
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("farm", Vector2i(1, 0))
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	hud.refresh(true)
	assert_true(hud.hire_button.badge, "work nobody looks after and a hire affordable: a dot on Hire")
	assert_false((hud.buttons[&"shop"] as HudButton).badge, "never on the Premium Shop")


func test_hire_opens_the_hire_card_and_pays_game_money() -> void:
	await _open()
	var economy: EconomySystem = sim.system(&"economy")
	var momos: MomoSystem = sim.system(&"momo")
	economy.earn(500, "test")
	assert_eq(momos.ids().size(), 0, "a new island has no Momo (Step 53)")
	await _tap_control(hud.hire_button)
	var menu: HireMenu = main.get("hire_menu")
	assert_true(menu.visible, "the hire card opens")
	assert_eq(menu.cards.keys(), ["momo"], "hiring a Momo, nothing else")
	var mr := menu.get_rect()
	assert_true(mr.end.x <= hud.hire_button.get_rect().position.x, "beside Hire, to its left")
	assert_true(Rect2(Vector2.ZERO, hud.size).encloses(mr), "inside the screen")
	var cost := momos.hire_cost()
	var money := economy.money
	await _tap_control(menu.cards["momo"])
	assert_eq(momos.ids().size(), 1, "a Momo hired")
	assert_eq(economy.money, money - cost, "for the game's money: $%d" % cost)
	assert_eq(int(momos.get_momo(momos.ids()[0])["assigned"]), 0, "and unassigned until placed")
	assert_false(menu.visible, "the card closes")


func test_the_shop_opens_the_premium_shop_and_never_hires_or_charges() -> void:
	await _open()
	var economy: EconomySystem = sim.system(&"economy")
	var momos: MomoSystem = sim.system(&"momo")
	economy.earn(500, "test")
	var money := economy.money
	await _tap_control(hud.buttons[&"shop"], false)
	var frame: PanelFrame = main.get("shop_frame")
	var view: PremiumShopView = main.get("shop_view")
	assert_true(frame.visible, "the Premium Shop opens")
	assert_false((main.get("hire_menu") as HireMenu).visible, "not the hire card")
	assert_eq(frame.title_label.text, "Shop", "titled Shop")
	assert_eq(view.cards.keys(), ["accelerator"], "the catalog's products")
	var c: Dictionary = view.cards["accelerator"]
	assert_eq((c["name"] as Label).text, "Accelerator", "by name")
	assert_true((c["buy"] as Button).disabled, "it cannot be bought")
	assert_eq((c["buy"] as Button).text, "Coming soon", "and says so")
	assert_false((c["price"] as Label).visible, "no price without a storefront")
	assert_eq((c["steps"] as Array).map(func(b: Button) -> String: return b.text), ["×2", "×4", "×8", "×16", "×32"], "the steps it would climb")
	assert_true(view.note.visible, "a line says purchases are not open")
	assert_true(view.restore_button.disabled, "nothing to restore")
	view.purchase_requested.emit("accelerator")
	assert_false(bool((main.get("shop_last") as Dictionary)["result"]["ok"]), "a Buy tap (were it possible) is refused")
	assert_eq(economy.money, money, "the game's money untouched")
	assert_eq(momos.ids().size(), 0, "no Momo hired")
	assert_true(frame.card_rect().end.x <= hud.hire_button.get_rect().position.x, "the card leaves Hire free")


func test_one_thing_open_at_a_time() -> void:
	await _open(Vector2i(720, 1280))
	var menu: HireMenu = main.get("hire_menu")
	var frame: PanelFrame = main.get("shop_frame")
	main.call("_on_hud_action", &"hire")
	assert_true(menu.visible, "hire card open")
	main.call("_on_hud_action", &"shop")
	assert_true(frame.visible and not menu.visible, "the shop puts the hire card away")
	main.call("_on_hud_action", &"hire")
	assert_true(menu.visible and not frame.visible, "and Hire puts the shop away")
	main.call("_on_hud_action", &"hire")
	assert_false(menu.visible, "Hire again closes its card")
	main.call("_on_hud_action", &"shop")
	main.call("_on_hud_action", &"status")
	assert_false(frame.visible, "Status puts the shop away")
	main.call("_on_hud_action", &"shop")
	main.call("_on_hud_action", &"shop")
	assert_false(frame.visible, "the shop again closes it")


func test_names_in_every_language_and_for_screen_readers() -> void:
	await _open(Vector2i(720, 1280))
	var want := {"en": ["Hire", "Shop", "Coming soon"], "ko": ["고용", "상점", "준비 중"], "ja": ["雇用", "ショップ", "準備中"], "zh_CN": ["雇佣", "商店", "即将推出"]}
	var view: PremiumShopView = main.get("shop_view")
	for lang: String in want:
		LocaleService.apply(lang)
		await tree.process_frame
		assert_eq(hud.hire_button._label.text, want[lang][0], "%s: Hire" % lang)
		assert_eq((hud.buttons[&"shop"] as HudButton)._label.text, want[lang][1], "%s: Shop" % lang)
		assert_eq((view.cards["accelerator"]["buy"] as Button).text, want[lang][2], "%s: Coming soon" % lang)
		assert_eq(hud.hire_button.accessibility_name, want[lang][0], "%s: a screen reader hears Hire" % lang)
		assert_eq((hud.buttons[&"shop"] as HudButton).accessibility_name, want[lang][1], "%s: and Shop" % lang)


func test_a_selected_building_keeps_its_bin_and_check_clear_of_hire() -> void:
	for size: Vector2i in [Vector2i(720, 1280), Vector2i(1575, 985), Vector2i(1260, 788)]:
		await _open(size)
		var id := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
		(main.get("selection") as SelectionController).select_building(id)
		await tree.process_frame
		var panel: ContextPanel = main.get("panel")
		var hire := hud.hire_button.get_rect()
		for b: Control in [panel.trash_button, panel.confirm_button]:
			assert_false(b.get_rect().intersects(hire), "%s: %s clear of Hire" % [size, b.name])
		for card: Control in panel.cards:
			assert_false(card.get_rect().intersects(hire), "%s: the stage cards clear of Hire" % size)
		await after_each()
