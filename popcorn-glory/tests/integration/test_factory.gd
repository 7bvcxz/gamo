extends "res://tests/framework/test_case.gd"

## Step 16: the three-floor factory scene (#factory) -- layout on several
## screens, cooking only on the bottom floor, floors' details by tap and keys,
## and the layers redrawing only while something moves (QUALITY_GATES R-01).

const Main := preload("res://app/main.tscn")
var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	app.save_prefix = "test."
	PopSaveStore.clear("test.factory.v1")   # Step 22: the factory is saved; tests start clean
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame


func _view() -> Node:
	return app.frame.play


func _mouse(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	_view()._gui_input(e)


func _layout_ok(label: String) -> void:
	var v := _view()
	var full := Rect2(Vector2.ZERO, v.size)
	var floors := [v.floor_rect(0), v.floor_rect(1), v.floor_rect(2)]
	for i in 3:
		assert_true(full.encloses(floors[i]), "%s: floor %d inside the view" % [label, i])
		if i > 0:
			assert_false(floors[i].intersects(floors[i - 1]), "%s: floors %d and %d do not overlap" % [label, i - 1, i])
	var ring: Rect2 = v.extra_rects()["ring"]
	assert_true(floors[2].grow(2).encloses(ring), "%s: the ring is inside the kitchen %s %s" % [label, ring, floors[2]])
	if v.is_wide():
		assert_true(ring.size.y >= floors[2].size.y * 0.6, "%s: on landscape the ring fills most of the kitchen's height" % label)
	else:
		assert_true(ring.size.x >= v.scene_rect().size.x * 0.4, "%s: the ring is at least 40%% of the width (G-03)" % label)
	for i in 3:
		v.toggle_floor(i)
		assert_false(v.detail_rect().intersects(ring) and i == 2, "%s: the kitchen's detail never covers the ring" % label)
	v.toggle_floor(-1)


func test_the_floors_fit_and_never_cover_the_ring_on_every_screen() -> void:
	app.open("factory")
	await tree.process_frame
	# Canvas sizes as the stretch (canvas_items, expand, 720x1280) makes them: phones
	# 9:16 and 9:19.5, a 3:4 tablet, landscape 16:10 and 16:9.
	for sz: Vector2i in [Vector2i(720, 1280), Vector2i(720, 1558), Vector2i(960, 1280), Vector2i(2048, 1280), Vector2i(2276, 1280)]:
		app.frame.size = Vector2(sz)
		app.frame._layout()
		await tree.process_frame
		_layout_ok("%dx%d" % [sz.x, sz.y])
		if sz.x > sz.y:
			assert_true(app.frame.is_wide_layout(), "landscape is wide")
			assert_true(_view().scene_rect().size.x <= _view().size.x * 0.61, "floors on the left")
			assert_true(app.frame.upgrade_button.position.x >= app.frame.size.x * 0.6, "the card in the right column")


func test_cooking_only_on_the_bottom_floor_and_floors_open_details() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var mid: Rect2 = v.floor_rect(1)
	_mouse(mid.get_center(), true)
	_mouse(mid.get_center(), false)
	assert_eq(int(app.rules.presses), 0, "a tap on the packing floor does not cook")
	assert_eq(int(v.selected), 1, "it opens the packing floor's detail")
	_mouse(mid.get_center(), true)
	_mouse(mid.get_center(), false)
	assert_eq(int(v.selected), -1, "a second tap closes it")
	var c: Vector2 = v.machine_centre()
	_mouse(c, true)
	app.dev_advance(app.rules.window_start() + 60)
	_mouse(c, false)
	assert_eq(int(app.rules.presses), 1, "the kettle cooks")
	assert_eq(int(app.rules.outcomes["perfect"]), 1, "B's hold into the gold")
	assert_eq(app.rules.money, 0, "the pop pays nothing (Step 17: money only from a sale)")
	assert_eq(int(app.rules.stats["lots"]), 1, "it made a lot")
	for k: int in [KEY_2, KEY_3, KEY_1]:
		var e := InputEventKey.new()
		e.keycode = k
		e.pressed = true
		v._unhandled_key_input(e)
	assert_eq(int(v.selected), 2, "keys 2, 3, 1: the kitchen's detail last")
	_mouse(v.badge_rect(0).get_center(), true)
	_mouse(v.badge_rect(0).get_center(), false)
	assert_eq(int(v.selected), 0, "the shop's badge opens the shop")


func test_the_layers_redraw_only_while_something_moves() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	app.rules.queue.clear()               # a quiet shop: nothing moves but what the hand starts
	app.rules.next_arrival_ms = 1 << 40
	var c: Vector2 = v.machine_centre()
	_mouse(c, true)
	app.dev_advance(200)
	assert_true(bool(v._needs_redraw()), "heating redraws")
	app.dev_advance(app.rules.window_start())
	_mouse(c, false)
	app.dev_advance(8000)                 # the lot lifts and is packed (events: a redraw each)
	v.last_input_ms = app.clock.now_ms   # (the app records input this way; the test sends to the view)
	# Pieces, the gain and the release mark fade on real frame time (MARK_S = 3 s).
	await tree.create_timer(3.3).timeout
	assert_false(bool(v._needs_redraw()), "idle after a cook: no redraw (heating %s fx %d gains %d flash %.2f mark %.1f hint %s squash %.3f jump %.2f once %s)" % [
		app.rules.state()["heating"], v.fx.alive, v._gains.size(), v._flash, v._mark_age, v._hint_visible(), v._squash, v._jump, v._redraw_once])
	app.dev_advance(21000)   # past 20 s idle: the hint's burst
	await tree.process_frame   # (process_frame fires before the nodes' _process: two frames)
	await tree.process_frame
	assert_true(v.hint_node.visible, "the idle hint shows")
	assert_false(bool(v._needs_redraw()), "and redraws nothing (Step 21: its dot moves by position, R-01)")
	var p0: Vector2 = v.hint_dot.position
	await tree.create_timer(0.3).timeout
	assert_true(v.hint_dot.position != p0, "the dot runs round the ring")
	app.dev_advance(7000)
	await tree.process_frame
	await tree.process_frame
	assert_false(v.hint_node.visible, "and hides after its burst")


func test_an_untouched_factory_hints_without_redrawing() -> void:
	# The newcomer's case that grew memory in 0.19.0: nobody touches it.
	app.open("factory")
	await tree.process_frame
	var v := _view()
	app.rules.queue.clear()
	app.rules.next_arrival_ms = 1 << 40
	app.dev_advance(21000)
	await tree.create_timer(3.3).timeout
	await tree.process_frame
	assert_true(v.hint_node.visible, "after 8 s the hint shows")
	assert_true(v.hint_finger.visible, "with the resting finger (after 20 s untouched)")
	assert_false(bool(v._needs_redraw()), "and the ring's layers are not redrawn every frame")


func test_the_stand_is_unchanged() -> void:
	app.open("stand")
	await tree.process_frame
	assert_true(bool(_view()._needs_redraw()), "the stand still redraws every frame as before")
	assert_false(app.frame.wide, "and is not wide")


## Step 18: the pictures follow the model's goods one by one (QUALITY_GATES G-13):
## every lot that rides the lift starts and ends once, every pack that goes to
## the shelf or to a customer starts once and ends once (at the sale), customers
## have one actor each, nothing lingers, a restart clears every journey.
func test_every_good_is_followed_once_from_start_to_end() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var c: Vector2 = v.machine_centre()
	for i in 5:
		_mouse(c, true)
		app.dev_advance(app.rules.window_start() + 60)
		_mouse(c, false)
		for k in 12:
			app.dev_advance(250)
			await tree.process_frame
	await tree.create_timer(1.0).timeout    # bags reach the shelf on real frame time
	app.dev_advance(30000)
	await tree.create_timer(1.0).timeout
	var starts := {}
	var ends := {}
	for e: Dictionary in v.cargo_log:
		if String(e["kind"]) == "fill":
			continue   # the packing station's own record (Step 20, its own test)
		var key := "%s:%d" % [e["kind"], e["id"]]
		if String(e["what"]) == "start" or String(e["what"]) == "serve":
			starts[key] = int(starts.get(key, 0)) + 1
		elif String(e["what"]) == "end":
			ends[key] = int(ends.get(key, 0)) + 1
	assert_true(starts.size() >= 5, "goods were followed (%d)" % starts.size())
	for key: String in starts.keys():
		assert_true(int(starts[key]) <= 2, "%s started at most twice (to the shelf, then to a customer)" % key)
		assert_eq(int(ends.get(key, 0)), int(starts[key]), "%s: every journey that started ended once" % key)
	var lots_lifted := 0
	for e: Dictionary in v.cargo_log:
		if String(e["kind"]) == "lot" and String(e["what"]) == "start":
			lots_lifted += 1
	assert_eq(lots_lifted, int(app.rules.stats["lots"]) - (0 if app.rules.glass.is_empty() else 1), "one lift journey per lot that left the glass")
	assert_eq(v.cargo.size(), int(app.rules.lift.size()) + (0 if app.rules.serving.is_empty() else 1), "no good lingers: only what is still moving in the model")
	assert_eq(v.customers.size(), app.rules.queue.size() + (0 if app.rules.serving.is_empty() else 1), "one actor per customer in the shop")
	app.restart()
	await tree.process_frame
	assert_eq(_view().cargo.size(), 0, "a restart clears the journeys")
	assert_eq(_view().cargo_log.size(), 0, "and their record")


func test_reduced_motion_moves_in_clear_steps() -> void:
	var a: Node2D = preload("res://variants/factory/actor.gd").new()
	a.start(PackedVector2Array([Vector2(0, 0), Vector2(0, 100), Vector2(100, 100)]), 1.0, true)
	var seen := {}
	for i in 50:
		a.step(0.021)
		seen[str(a.position.round())] = true
	for p: String in seen.keys():
		assert_true(p in ["(0.0, 0.0)", "(0.0, 100.0)", "(100.0, 100.0)"], "only waypoints, no glide (%s)" % p)
	assert_true(a.done, "it arrives")
	a.free()


# -- Step 20: the packing station on screen -----------------------------------

func _frames(n: int, ms: int) -> void:
	for k in n:
		app.dev_advance(ms)
		await tree.process_frame


func test_the_station_fills_one_puff_per_portion_seals_and_the_same_bag_leaves() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	app.rules.queue.clear()
	app.rules.next_arrival_ms = 1 << 40
	var c: Vector2 = v.machine_centre()
	_mouse(c, true)
	app.dev_advance(app.rules.window_start() + 60)
	_mouse(c, false)
	await tree.process_frame
	assert_eq(v.nozzles.size(), 1, "tier 0: one scoop")
	var bag: Node2D = null
	var pid := -1
	for k in 40:
		await _frames(1, 50)
		if not v.filling.is_empty():
			pid = int(v.filling.keys()[0])
			bag = v.filling[pid]["bag"]
			break
	assert_true(bag != null, "a pack in the model has an open bag on screen")
	assert_true(bag.open, "open while it is filled")
	assert_eq(int(v.filling[pid]["size"]), int(app.rules.pack_size()), "it will hold the pack's real portions")
	var landed_seen := {}
	var sealed_before_shelf := false
	for k in 120:
		await _frames(1, 30)
		if v.filling.has(pid):
			landed_seen[int(v.filling[pid]["landed"])] = true
			if bool(v.filling[pid]["sealed"]):
				sealed_before_shelf = true
				assert_eq(int(v.filling[pid]["landed"]), int(app.rules.pack_size()), "sealed only when every portion has fallen in")
		else:
			break
	assert_true(landed_seen.has(1), "the portions fall one at a time (1 of 2 seen)")
	assert_true(sealed_before_shelf, "the nozzle seals it before it leaves")
	assert_false(v.filling.has(pid), "shelved: no longer filling")
	if v.cargo.has(pid):
		assert_true(v.cargo[pid] == bag, "the same bag slides to the shelf (no second bag)")
	await tree.create_timer(0.8).timeout
	await _frames(40, 250)
	var starts := 0
	var ends := 0
	for e: Dictionary in v.cargo_log:
		if String(e["kind"]) == "fill":
			if String(e["what"]) == "start":
				starts += 1
			else:
				ends += 1
	assert_eq(starts, int(app.rules.stats["packed"]) + app.rules.packing.size(), "one fill per real pack")
	assert_eq(ends, int(app.rules.stats["packed"]), "every finished pack ended its fill once")
	assert_eq(v.filling.size(), app.rules.packing.size(), "on screen exactly the packs in progress")


func test_the_middle_floor_card_sells_the_station_and_the_status_shows_backpressure() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var f = app.rules
	f.queue.clear()
	f.next_arrival_ms = 1 << 40
	await tree.process_frame
	assert_eq(String(v._status), "starved", "nothing to pack: the starved icon")
	assert_eq(String(app.frame.upgrade_button.art_key), "", "the card sells the kettle")
	v.toggle_floor(1)
	await tree.process_frame
	assert_eq(String(app.frame.upgrade_button.art_key), "", "before its first sealed pack the station is not for sale (Step 24)")
	f.stats["packed"] = 1
	await tree.process_frame
	assert_eq(String(app.frame.upgrade_button.art_key), "packer", "the middle floor's card sells the station")
	var tiers: Array = f.economy.table("factory")["packer"]
	assert_eq(int(app.frame.upgrade_button.price), int(tiers[1]["cost"]), "at the next tier's price")
	assert_eq(int(app.frame.upgrade_button.gain_now), int(round(f.packs_per_min(0))), "packs a minute now")
	assert_eq(int(app.frame.upgrade_button.gain_next), int(round(f.packs_per_min(1))), "and next")
	app.buy()
	assert_eq(int(f.packer_tier), 0, "no money: nothing bought")
	var both := int(tiers[1]["cost"]) + int(tiers[2]["cost"])
	f.money = both + 20
	app.buy()
	assert_eq(int(f.packer_tier), 1, "bought tier 1")
	assert_eq(int(f.level), 0, "not the kettle")
	app.buy()
	assert_eq(int(f.packer_tier), 2, "tier 2")
	assert_eq(int(f.money), 20, "paid each price once")
	await tree.process_frame
	assert_eq(v.nozzles.size(), 2, "two heads on screen")
	f.bin.append({"id": f._new_id(), "recipe": "plain", "quality": 100, "portions": 24})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 24
	await _frames(60, 600)
	assert_eq(String(f.packer_state()), "blocked", "the shelf filled")
	assert_eq(String(v._status), "blocked", "and the station shows it")
	v.toggle_floor(2)
	await tree.process_frame
	assert_eq(String(app.frame.upgrade_button.art_key), "", "the kitchen's card sells the kettle again")
	f.money = 30
	app.buy()
	assert_eq(int(f.level), 1, "a kettle level bought from the kitchen")
	assert_eq(int(f.packer_tier), 2, "the station untouched")
	assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "nothing made or lost")


# -- Step 21: the shop on screen ----------------------------------------------

func test_faces_follow_patience_the_sale_and_leaving() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var f = app.rules
	await tree.process_frame
	await tree.process_frame
	var first := int(f.queue[0]["id"])
	assert_eq(String(v.customers[first].mood), "wait", "a new customer is calm")
	app.dev_advance(42000)   # past two thirds of the patience (60 s)
	await tree.process_frame
	await tree.process_frame
	assert_eq(String(v.customers[first].mood), "impatient", "below a third of the patience: impatient")
	f.shelf.append({"id": f._new_id(), "recipe": "plain", "size": 2, "quality": 100})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 2
	var actor: Node2D = v.customers[first]
	await _frames(40, 100)
	assert_eq(String(actor.mood), "happy", "served: happy, carrying the bag")
	assert_true(actor.carrying, "with the bag")
	# The others, with no more stock, leave sad.
	var left_sad := false
	for k in 80:
		var before: Array = v.leaving.duplicate()
		await _frames(1, 1000)
		for c: Node2D in v.leaving:
			if not before.has(c) and c.mood == "sad":
				left_sad = true
	assert_true(left_sad, "someone who waited too long walks out sad")


func test_the_bell_swings_before_the_next_customer_and_the_queue_fits() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var f = app.rules
	var soon := int(f.next_arrival_ms) - int(f.flow_ms)
	app.dev_advance(maxi(0, soon - 4000))
	await tree.process_frame
	await tree.process_frame
	assert_false(v.bell_swinging(), "4 s before: still")
	app.dev_advance(3000)
	await tree.process_frame
	await tree.create_timer(0.1).timeout
	assert_true(v.bell_swinging(), "in the last 1.5 s: it swings")
	var top: Rect2 = v.floor_rect(0)
	# Every sign tier's shop: its lanes and its full queue fit without people on each other.
	for tier in (f.economy.table("factory")["sign"] as Array).size():
		f.sign_tier = tier
		var cap := int(f.queue_cap())
		var spots: Array = []
		for k in int(f.lanes()):
			spots.append(v._handoff_spot(k))
		for i in cap:
			spots.append(v._queue_spot(i))
		for i in spots.size():
			var p: Vector2 = spots[i]
			assert_true(top.has_point(p) and p.x + v._head_px() * 1.05 <= top.end.x, "tier %d: place %d inside the shop" % [tier, i])
			assert_true(p.x - v._head_px() * 1.05 >= v.counter_rect().position.x, "tier %d: place %d on the counter's span" % [tier, i])
			for j in i:
				var q: Vector2 = spots[j]
				var apart: bool = absf(p.x - q.x) >= v._head_px() * 2.1 or absf(p.y - q.y) >= v._head_px() * 1.2
				assert_true(apart, "tier %d: places %d and %d do not overlap" % [tier, j, i])
	f.sign_tier = 0
	assert_true(v.bell_node.position.distance_to(v.news_rect().get_center()) > v.news_rect().size.x * 0.6, "the bell clear of the news paper")


# -- Step 22: the factory is saved, a seeded session is not, a hidden tab stops it

func test_the_factory_resumes_where_it_was() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var c: Vector2 = v.machine_centre()
	for i in 2:
		_mouse(c, true)
		app.dev_advance(app.rules.window_start() + 60)
		_mouse(c, false)
		app.dev_advance(2600)
	var a = app.rules
	assert_true(bool(app.save_now()), "the factory saves")
	var want := {"money": a.money, "flow": a.flow_ms, "made": a.stats["made_portions"], "shelf": a.shelf.size(), "bin": a.bin_portions(),
		"queue": a.queue.map(func(q: Dictionary) -> int: return int(q["id"])), "next": a.next_arrival_ms, "lots": a.stats["lots"]}
	var app2: Node = Main.instantiate()
	app2.save_prefix = "test."
	tree.root.add_child(app2)
	await tree.process_frame
	app2.open("factory")
	await tree.process_frame
	var b = app2.rules
	var got := {"money": b.money, "flow": b.flow_ms, "made": b.stats["made_portions"], "shelf": b.shelf.size(), "bin": b.bin_portions(),
		"queue": b.queue.map(func(q: Dictionary) -> int: return int(q["id"])), "next": b.next_arrival_ms, "lots": b.stats["lots"]}
	# (one frame of play may have passed in the new app: compare what a frame cannot change)
	for k: String in ["money", "made", "lots", "queue", "next"]:
		assert_eq(got[k], want[k], "resumed: %s" % k)
	assert_true(int(got["flow"]) >= int(want["flow"]) and int(got["flow"]) < int(want["flow"]) + 200, "resumed: the flow's clock")
	assert_eq(int(b.portions_everywhere()), int(b.stats["made_portions"]), "every portion where it was")
	app2.queue_free()
	await tree.process_frame


func test_a_seeded_session_is_fresh_and_never_saved() -> void:
	app.seed = 4242
	app.open("factory")
	await tree.process_frame
	var f = app.rules
	var ref = preload("res://variants/factory/factory_rules.gd").new(null, 4242)
	assert_eq(int(f.next_arrival_ms), int(ref.next_arrival_ms), "the seed draws its own second customer")
	assert_false(bool(app.save_now()), "a measured session is not saved")
	app.seed = -1


func test_a_hidden_tab_stops_the_factory() -> void:
	app.open("factory")
	await tree.process_frame
	app.clock.set_pause("hidden", true)
	var f = app.rules
	var flow := int(f.flow_ms)
	var arrivals: int = f.arrival_log.size()
	await tree.create_timer(0.6).timeout
	assert_eq(int(f.flow_ms), flow, "no flow while hidden")
	assert_eq(f.arrival_log.size(), arrivals, "no customer arrives while hidden")
	app.clock.set_pause("hidden", false)
	await tree.create_timer(0.3).timeout
	assert_true(int(f.flow_ms) > flow, "it continues when shown")


# -- Step 23: orders and the bottleneck on screen -----------------------------

func test_bubbles_show_each_order_and_the_cue_follows_the_bottleneck() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var f = app.rules
	f.packer_tier = 2
	app.dev_advance(60000)
	await tree.process_frame
	await tree.process_frame
	for c: Dictionary in f.queue:
		var a: Node2D = v.customers[int(c["id"])]
		assert_eq(int(a.order_size), int(c["order"]["size"]), "customer %d's bubble shows their order" % int(c["id"]))
	assert_eq(String(f.bottleneck()), "production", "people wait, no popcorn")
	assert_true(v.cue_node.visible and String(v._cue) == "production", "the kitchen is outlined")
	f.queue.clear()
	f.next_arrival_ms = 1 << 40
	f.bin.append({"id": f._new_id(), "recipe": "plain", "quality": 100, "portions": 24})
	f.stats["made_portions"] = int(f.stats["made_portions"]) + 24
	await _frames(60, 1000)
	assert_eq(String(f.bottleneck()), "demand", "packs wait, nobody comes")
	assert_eq(String(v._cue), "demand", "the shop is outlined")
	v._hover = 1
	await tree.process_frame
	await tree.process_frame
	assert_true(String(v._stats_key).begins_with("1|"), "hovering the middle badge shows its numbers")


# -- Step 26: machines on screen ------------------------------------------------

func test_a_machine_place_is_chosen_built_paused_and_sold_from_the_screen() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var f = app.rules
	f.sign_tier = 3
	f.money = 5000
	await tree.process_frame
	var r: Rect2 = v.slot_rect("kitchen", 1)
	var presses := int(f.presses)
	_mouse(r.get_center(), true)
	_mouse(r.get_center(), false)
	await tree.process_frame
	assert_eq(int(f.presses), presses, "a tap on a machine place does not cook")
	assert_eq(String(v.sel_slot.get("floor", "")), "kitchen", "it chooses the place")
	await tree.process_frame
	assert_eq(String(app.frame.upgrade_button.art_key), "build_cooker", "the card sells a cooker for it")
	assert_eq(int(app.frame.upgrade_button.price), int(f.build_cost("cooker")), "at its price")
	var money := int(f.money)
	app.buy()
	assert_eq(f.machines.size(), 1, "built")
	assert_eq(int(f.machines[0]["slot"]), 1, "in the chosen place")
	assert_eq(int(f.money), money - int(f.machines[0]["paid"]), "paid")
	_mouse(r.get_center(), true)
	_mouse(r.get_center(), false)
	await tree.process_frame
	var id := int(f.machines[0]["id"])
	assert_eq(int(v.sel_machine), id, "a tap on the machine chooses it")
	await tree.process_frame
	assert_eq(String(app.frame.upgrade_button.art_key), "machine_up", "the card sells its next tier")
	var b: Dictionary = v._machine_buttons()
	_mouse((b["pause"] as Rect2).get_center(), true)
	_mouse((b["pause"] as Rect2).get_center(), false)
	assert_eq(String(f.machine(id)["state"]), "paused", "its pause button pauses it")
	_mouse((b["pause"] as Rect2).get_center(), true)
	_mouse((b["pause"] as Rect2).get_center(), false)
	assert_true(String(f.machine(id)["state"]) != "paused", "and resumes it")
	var g: Rect2 = v._group_rect(v.detail_rect())
	_mouse(g.get_center(), true)
	_mouse(g.get_center(), false)
	assert_true(f.machines.all(func(m: Dictionary) -> bool: return String(m["state"]) == "paused"), "the group button pauses the floor")
	_mouse(g.get_center(), true)
	_mouse(g.get_center(), false)
	app.dev_advance(3000)
	_mouse((b["sell"] as Rect2).get_center(), true)
	_mouse((b["sell"] as Rect2).get_center(), false)
	if f.machines.is_empty():
		assert_eq(int(v.sel_machine), -1, "sold: nothing chosen any more")
	else:
		assert_true(not (f.machines[0]["held"] as Dictionary).is_empty(), "or it waits to finish the lot it holds")
	assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "nothing made or lost")


func test_a_perfect_pop_with_a_cooker_chosen_tunes_it() -> void:
	app.open("factory")
	await tree.process_frame
	var v := _view()
	var f = app.rules
	f.sign_tier = 3
	f.money = 5000
	app.on_command("build", {"type": "build", "machine": "cooker", "slot": 0})
	var r: Rect2 = v.slot_rect("kitchen", 0)
	_mouse(r.get_center(), true)
	_mouse(r.get_center(), false)
	await tree.process_frame
	var c: Vector2 = v.machine_centre()
	_mouse(c, true)
	app.dev_advance(f.window_start() + 60)
	_mouse(c, false)
	assert_eq(int(f.machines[0]["assist"]), 3, "the hand tuned the chosen cooker's next 3 lots")
