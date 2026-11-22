extends "res://tests/framework/test_case.gd"

## Step 47: the kettle says when it cannot take a press -- before the press, and after it.
## Two blind players (fresh AI agents, screen only) lost presses to a full glass and said so:
## "about half my holds were silently swallowed, with no message saying full" (the 20-minute
## store: 19 of 72 presses refused) and "presses ignored right after a batch, nothing on screen
## to say the kettle wasn't ready" (the 44-machine factory). The ring looked ready, and Step 44's
## cue lasted 1.6 s from the press, so a 1.8 s hold looked at after letting go never showed it.
## - while a lot waits in the glass (or the kettle cools), the ring is dimmed: any still shows it
## - when the kettle can take a press again, the ring lights up (a white flash) at full colour
## - a refused hold's cue stays up while the finger is down and 2 s after it lifts
## - none of this redraws a polygon: the ring's own layer is tinted (R-01)

const Main := preload("res://app/main.tscn")
const Actor := preload("res://variants/factory/actor.gd")   # (like test_factory: see test_cargo46)
var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	app.save_prefix = "test."
	PopSaveStore.clear("test.factory.v1")
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame


func _open() -> Node:
	app.open("factory")
	app.clock.set_pause("dev", true)
	await tree.process_frame
	return app.frame.play


func _mouse(v: Node, at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	v._gui_input(e)


func _frames(n: int, ms: int = 100) -> void:
	for i in n:
		app.dev_advance(ms)
		await tree.process_frame


func _wait_glass(v: Node) -> void:
	# The bin full (it drains a pack every few seconds), so the glass's lot cannot pour.
	app.dev_fill_bin()
	app.rules.glass = {"id": 777777, "recipe": "plain", "quality": 90, "portions": 4}
	app.rules.stats["made_portions"] = int(app.rules.stats["made_portions"]) + 4
	await tree.process_frame


func _empty_glass() -> void:
	if not (app.rules.glass as Dictionary).is_empty():
		app.rules.glass = {}
		app.rules.stats["made_portions"] = int(app.rules.stats["made_portions"]) - 4


func test_a_waiting_glass_dims_the_ring_and_a_ready_kettle_lights_it() -> void:
	var v: Node = await _open()
	await _frames(2)
	assert_false(bool(v.ring_waiting), "a fresh kettle is ready")
	assert_eq(v.ring_layer.modulate, Color.WHITE, "its ring at full colour")
	var r0 := int(v.redraws.get("ring", 0))
	await _wait_glass(v)
	await _frames(3)
	assert_true(bool(v.ring_waiting), "a lot waits in the glass: the kettle cannot take a press")
	assert_eq(v.ring_layer.modulate, v.RING_WAIT_TINT, "and the ring is dimmed")
	await _frames(20)
	assert_true(int(v.redraws.get("ring", 0)) - r0 <= 2, "dimmed by a tint, not redrawn each frame (%d)" % (int(v.redraws.get("ring", 0)) - r0))
	var f0 := int(v.ring_ready_flashes)
	_empty_glass()
	await _frames(2)
	assert_false(bool(v.ring_waiting), "the glass poured: ready again")
	assert_eq(v.ring_layer.modulate, Color.WHITE, "the ring back to full colour")
	assert_eq(int(v.ring_ready_flashes), f0 + 1, "lit up once (a flash)")
	var dbg: Dictionary = v.debug_state() if v.has_method("debug_state") else {}
	if not dbg.is_empty():
		assert_true(dbg.has("ring_waiting"), "the state tells the tests")


func test_a_refused_hold_shows_why_after_the_finger_lifts() -> void:
	var v: Node = await _open()
	await _wait_glass(v)
	await _frames(2)
	# A blind player's hold: 1.8 s down, then a look 0.4 s after the lift.
	_mouse(v, v.machine_centre(), true)
	await _frames(18)
	assert_true(v.full_cue.visible, "the cue is up while the finger is still down (1.8 s)")
	_mouse(v, v.machine_centre(), false)
	await _frames(4)
	assert_true(v.full_cue.visible, "and 0.4 s after it lifts: the still shows why")
	assert_false(bool(app.rules.heating), "refused: no heat")
	assert_true(bool(v.ring_waiting), "the ring stays dimmed while the glass waits")
	await _frames(17)
	assert_false(v.full_cue.visible, "gone 2 s after the lift")
	_empty_glass()
