extends "res://tests/framework/test_case.gd"

## C+ (Step 95) in the Lab's frame with real input. The feel is new -- the
## pickaxe on the rock on the frame of the tap, dents and chunks, the held
## breaking moment, pieces on the ground -- and the economy is C's exactly:
## the same hits and purchases on C and C+ end with the same coins, rocks
## and pickaxe. One press is one hit; a miss or a tap while the next rock
## rises pays nothing; a break pays once; `?alt=hold` repeats only while held.

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
	await _open("rock-plus", "")


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func _open(id: String, alt: String) -> void:
	app.route["alt"] = alt
	app.open(id)
	await tree.process_frame
	await tree.process_frame
	host = app.host
	rock = host.experiment


func _s() -> Dictionary:
	return rock.state()


func _rock_centre() -> Vector2:
	var r: Array = _s()["rock_rect"]
	return Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5)


func test_one_finger_one_hit_and_the_pickaxe_lands_on_that_frame() -> void:
	var sounds_before := int(app.audio.played.get("pick", 0))
	await H.touch(tree, _rock_centre())
	assert_eq(int(_s()["hits"]), 1, "one touch: one hit")
	assert_eq(int(_s()["hp"]), 49, "one hit of 1")
	assert_eq(int(host.session.counts.get("hit", 0)), 1, "recorded once")
	assert_eq(int(app.audio.played.get("pick", 0)) - sounds_before, 1, "one hit sound")
	assert_true(bool(_s()["touch"]), "a finger: the number rises clear of it")
	assert_eq(int(_s()["marks"]), 1, "a dent where it landed")
	await H.click(tree, _rock_centre())
	assert_eq(int(_s()["hits"]), 2, "one click: one hit")
	assert_false(bool(_s()["touch"]), "a mouse")
	# The hit itself (not a frame later): the tip is on the rock right away.
	rock.call("tap_at", rock.get_global_transform().affine_inverse() * _rock_centre())
	assert_true(bool(_s()["contact"]), "the pickaxe touches the rock on the frame of the tap")


func test_a_miss_and_a_tap_while_the_next_rises_pay_nothing() -> void:
	await H.touch(tree, Vector2(60, 900))
	assert_eq(int(_s()["hits"]), 0, "a tap on the water hits nothing")
	assert_eq(int(_s()["misses"]), 1, "it is a miss")
	assert_eq(int(_s()["coins"]), 0, "and pays nothing")
	rock.dev("hits", 49)
	var hp_before := int(_s()["hp"])
	assert_eq(hp_before, 1, "one hit left")
	rock.call("tap_at", rock.get_global_transform().affine_inverse() * _rock_centre())
	assert_eq(int(_s()["breaks"]), 1, "broken")
	assert_eq(int(_s()["coins"]), 25, "paid once, at the hit")
	assert_true(bool(_s()["breaking"]), "the breaking moment holds")
	for i in 5:
		rock.call("tap_at", rock.get_global_transform().affine_inverse() * _rock_centre())
	assert_eq(int(_s()["coins"]), 25, "taps in the breaking moment and the rise pay nothing")
	assert_eq(int(_s()["breaks"]), 1, "and break nothing")
	assert_eq(int(host.session.counts.get("tap_wait", 0)), 5, "they are recorded as waits")
	host.step(1.0)
	assert_false(bool(_s()["rising"]), "the next rock is up")
	assert_eq(int(_s()["hp"]), 80, "the Grey Stone, untouched")
	assert_eq(int(_s()["coins"]), 25, "still paid exactly once")


func test_two_chunks_then_the_break() -> void:
	# The first rock: 50 hits of 1, chunks at 17 (0.34) and 34 (0.68).
	rock.dev("hits", 16)
	assert_eq(int(_s()["stage"]), 0, "whole at 16/50")
	rock.dev("hits", 1)
	assert_eq(int(_s()["stage"]), 1, "a chunk off at a third")
	rock.dev("hits", 17)
	assert_eq(int(_s()["stage"]), 2, "another at two thirds")
	rock.dev("hits", 16)
	assert_eq(int(_s()["breaks"]), 1, "then it breaks")
	var chunk_ms := host.session.milestones.filter(func(m: Dictionary) -> bool: return String(m["name"]) == "chunk")
	assert_eq(chunk_ms.size(), 2, "two chunk moments recorded")
	assert_eq(int(_s()["chunks"]), 2, "two chunks")
	host.step(1.0)
	assert_eq(int(_s()["stage"]), 0, "the next rock is whole")
	assert_eq(int(_s()["marks"]), 0, "and unmarked")


func test_the_economy_is_c_exactly() -> void:
	# The same hits and purchases on C and C+: the same coins, rocks, pickaxe.
	var results: Array[Dictionary] = []
	for id: String in ["rock", "rock-plus"]:
		app.back()
		await tree.process_frame
		await _open(id, "")
		for round in 60:
			rock.dev("hits", 12)
			while host.experiment.action_info().get("affordable", false):
				host.press_action()
		var st := _s()
		results.append({"coins": st["coins"], "earned": st["earned"], "pick": st["pick"], "rock": st["rock"], "breaks": st["breaks"],
			"damage_total": st["damage_total"], "hits": st["hits"]})
	assert_eq(results[1], results[0], "C+ pays what C pays: %s" % str(results[0]))
	assert_true(int(results[0]["breaks"]) >= 6, "several rocks broken on the way (%d)" % int(results[0]["breaks"]))


func test_marks_and_bits_stay_bounded() -> void:
	rock.dev("pick", 10)
	for i in 300:
		rock.dev("hits", 1)
		if i % 20 == 0:
			await tree.process_frame
	assert_true(int(_s()["marks"]) <= RockPlusView.MAX_MARKS, "dents capped (%d)" % int(_s()["marks"]))
	assert_true(int(_s()["bits"]) <= RockPlusFeel.MAX_BITS, "flying bits capped (%d)" % int(_s()["bits"]))
	assert_true(int(_s()["breaks"]) >= 10, "a strong pickaxe broke many rocks (%d)" % int(_s()["breaks"]))


func test_two_hits_in_one_moment_are_one_sound() -> void:
	var at := rock.get_global_transform().affine_inverse() * _rock_centre()
	rock.call("tap_at", at)
	rock.call("tap_at", at)
	assert_eq(int(_s()["hits"]), 2, "two hits")
	assert_eq(int(_s()["hit_sounds"]), 1, "one sound")


func test_the_pickaxe_milestones() -> void:
	rock.dev("coins", 2000)
	var tiers: Array[String] = []
	for i in 5:
		host.press_action()
		var u: Dictionary = host.session.upgrades.back()
		tiers.append("%d:%s:%s" % [int(u["level"]), String(u["tier"]), str(u["milestone"])])
	assert_eq(tiers, ["1:Wooden Pickaxe:false", "2:Wooden Pickaxe:false", "3:Copper Pickaxe:true", "4:Copper Pickaxe:false", "5:Steel Pickaxe:true"] as Array[String],
		"Copper at 3 and Steel at 5 are new pickaxes; the others a stronger one")
	assert_eq(int(app.audio.played.get("promote", 0)), 2, "a milestone sounds like one")


func test_hold_repeats_only_in_the_hold_experiment_and_only_while_held() -> void:
	for alt: String in ["", "hold"]:
		app.back()
		await tree.process_frame
		await _open("rock-plus", alt)
		host.time_scale = 0.0
		var at: Vector2 = tree.root.get_final_transform() * _rock_centre()
		var t := InputEventScreenTouch.new()
		t.position = at
		t.pressed = true
		Input.parse_input_event(t)
		await tree.process_frame
		await tree.process_frame
		host.step(2.0)
		var held := int(_s()["hits"])
		t = InputEventScreenTouch.new()
		t.position = at
		t.pressed = false
		Input.parse_input_event(t)
		await tree.process_frame
		await tree.process_frame
		host.step(2.0)
		if alt == "hold":
			assert_eq(held, 1 + 4, "the press, then one every 0.45 s for 2 s")
			assert_eq(int(_s()["hold_hits"]), 4, "recorded as hold hits")
			assert_eq(int(_s()["hits"]), held, "nothing after the release")
			assert_eq(host.session.variant, "hold", "the run says which experiment")
		else:
			assert_eq(held, 1, "without the experiment a held press is one hit")
			assert_eq(int(_s()["hold_hits"]), 0, "no repeats")


func test_reduced_motion_keeps_the_information_and_drops_the_flying() -> void:
	app.back()
	await tree.process_frame
	app.reduced_motion = true
	await _open("rock-plus", "")
	rock.dev("hits", 50)
	assert_eq(int(_s()["breaks"]), 1, "broken")
	assert_false(bool(_s()["breaking"]), "no held moment")
	assert_eq(int(_s()["bits"]), 0, "nothing flies")
	assert_eq(int(_s()["coins"]), 25, "paid")
	assert_eq(int(_s()["chunks"]), 2, "the chunks still count (the rock still shows them)")
