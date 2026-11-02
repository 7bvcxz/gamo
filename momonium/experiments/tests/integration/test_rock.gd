extends "res://tests/framework/test_case.gd"

## Experiment C in the Lab's frame with real input: one finger on the rock is
## one hit, a tap on the water or on the frame's button is not, the rock
## breaks exactly once at zero and pays exactly once, a tap while the next
## rock rises does nothing, the pickaxe level changes every later hit.

const MainScene := preload("res://lab/main.tscn")
const H := preload("res://tests/integration/lab_helpers.gd")

var app: LabApp
var host: LabHost
var rock: LabExperiment


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame
	app.open("rock")
	await tree.process_frame
	await tree.process_frame
	host = app.host
	rock = host.experiment


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func _s() -> Dictionary:
	return rock.state()


func _rock_centre() -> Vector2:
	var r: Array = _s()["rock_rect"]
	return Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5)


func test_it_is_playable() -> void:
	assert_true(LabRegistry.playable("rock"), "the tile says PLAY")
	assert_eq(int(_s()["hp"]), 50, "the first rock")
	assert_true(bool(_s()["goal_visible"]), "the Giant Crystal stands on the far islet")


func test_one_finger_one_hit() -> void:
	await H.touch(tree, _rock_centre())
	assert_eq(int(_s()["hp"]), 49, "one touch: one hit")
	assert_eq(int(host.session.counts.get("hit", 0)), 1, "recorded once")
	await H.click(tree, _rock_centre())
	assert_eq(int(_s()["hp"]), 48, "one click: one hit")
	assert_eq(int(_s()["taps"]), 2, "two taps")


func test_the_water_and_the_frame_are_not_the_rock() -> void:
	await H.touch(tree, Vector2(60, 900))
	assert_eq(int(_s()["hp"]), 50, "a tap on the water hits nothing")
	assert_eq(int(host.session.counts.get("tap_miss", 0)), 1, "it is recorded as a miss")
	await H.touch(tree, H.centre(host.action_button))
	assert_eq(int(_s()["hp"]), 50, "the frame's button never reaches the rock")
	assert_eq(int(host.session.counts.get("button_refused", 0)), 1, "it was the button's (it cannot pay yet)")
	await H.touch(tree, H.centre(host.restart_button) + Vector2(0, 0))
	assert_eq(host.runs, 2, "Restart is Restart")


func test_a_rock_breaks_once_and_pays_once() -> void:
	rock.dev("hits", 49)
	assert_eq(int(_s()["hp"]), 1, "one left")
	assert_eq(int(_s()["coins"]), 0, "nothing paid yet")
	rock.dev("hits", 1)
	var s := _s()
	assert_eq(int(s["breaks"]), 1, "broken once")
	assert_eq(int(s["coins"]), 25, "paid once")
	assert_eq(int(s["rock"]), 1, "the next rock")
	assert_eq(int(s["hp"]), 80, "at full health")
	assert_true(bool(s["rising"]), "rising out of the ground")
	# Taps while it rises do nothing at all.
	await H.touch(tree, _rock_centre())
	await H.touch(tree, _rock_centre())
	s = _s()
	assert_eq(int(s["hp"]), 80, "no damage while it rises")
	assert_eq(int(s["coins"]), 25, "no second payout")
	assert_eq(int(host.session.counts.get("tap_wait", 0)) + int(host.session.counts.get("tap_miss", 0)), 2, "both recorded as non-hits")
	var names: Array = host.session.milestones.map(func(m: Dictionary) -> String: return String(m["name"]))
	assert_eq(names, ["break"], "one break milestone")
	host.step(0.6)
	await H.touch(tree, _rock_centre())
	assert_eq(int(_s()["hp"]), 79, "risen: hit again")
	assert_true(int(_s()["first_break_ms"]) >= 0, "the first break's time is kept")


func test_the_pickaxe_upgrade() -> void:
	rock.dev("hits", 50)
	host.step(0.6)
	await H.touch(tree, H.centre(host.action_button))
	var s := _s()
	assert_eq(int(s["pick"]), 1, "Pickaxe Power bought")
	assert_eq(int(s["coins"]), 5, "25 - 20")
	assert_eq(int(s["damage"]), 2, "two a hit")
	await H.touch(tree, _rock_centre())
	assert_eq(int(_s()["hp"]), 78, "the next hit does 2")
	assert_eq(host.session.upgrades.size(), 1, "recorded")
	assert_eq(int(host.session.upgrades[0]["damage"]), 2, "with its damage")


func test_the_same_taps_give_the_same_game() -> void:
	host.set_process(false)
	var a := _play()
	host.restart()
	rock = host.experiment
	var b := _play()
	assert_eq(a, b, "deterministic")


func _play() -> Array:
	for i in 12:
		rock.dev("hits", 25)
		host.step(0.6)
		host.press_action()
	var s := _s()
	return [int(s["rock"]), int(s["hp"]), int(s["pick"]), int(s["coins"]), int(s["breaks"]), int(s["damage_total"])]


func test_reduced_motion_keeps_the_numbers() -> void:
	app.back()
	await tree.process_frame
	app.reduced_motion = true
	app.open("rock")
	await tree.process_frame
	host = app.host
	rock = host.experiment
	rock.dev("hits", 50)
	var s := _s()
	assert_eq(int(s["breaks"]), 1, "it still breaks")
	assert_false(bool(s["rising"]), "the next rock is simply there")
	assert_true((rock.get("bits").get("items") as Array).is_empty(), "no flying pieces")
