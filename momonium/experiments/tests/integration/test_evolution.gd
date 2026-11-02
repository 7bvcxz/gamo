extends "res://tests/framework/test_case.gd"

## Experiment B in the Lab's frame: the Momo works by itself and every
## finished pass pays exactly once; Upgrade Momo changes its tool and motion
## or what it wears, each worn thing following the body frame by frame; the
## Momo keeps the game's size and its place; the same play gives the same Momo.

const MainScene := preload("res://lab/main.tscn")
const H := preload("res://tests/integration/lab_helpers.gd")

var app: LabApp
var host: LabHost
var evo: LabExperiment


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame
	app.open("evolution")
	await tree.process_frame
	await tree.process_frame
	host = app.host
	# Only the tests' steps move play time: a fresh run with no frame's delta.
	host.set_process(false)
	host.restart()
	evo = host.experiment


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func _s() -> Dictionary:
	return evo.state()


func test_a_pass_pays_once_when_it_ends() -> void:
	var c := float(_s()["cycle"])
	host.step(c - 0.05)
	assert_eq(int(_s()["coins"]), 0, "nothing before the pass ends")
	host.step(0.1)
	assert_eq(int(_s()["coins"]), 1, "one coin when it ends")
	assert_eq(int(_s()["passes"]), 1, "one pass")
	host.step(c * 10.0)
	assert_eq(int(_s()["passes"]), 11, "eleven passes")
	assert_eq(int(_s()["coins"]), 11, "eleven coins, never more")


func test_the_first_upgrade_brings_a_bag() -> void:
	assert_true(LabRegistry.playable("evolution"), "the tile says PLAY")
	assert_eq(String(_s()["pose"]), "work_sow", "sowing")
	assert_eq(_s()["teaser_wear"], ["bag"], "the bag waits as an outline")
	host.step(20.0)
	await H.touch(tree, H.centre(host.action_button))
	var s := _s()
	assert_eq(int(s["level"]), 1, "Upgrade Momo")
	assert_eq(s["wearing"], ["bag"], "it wears the bag")
	assert_true(bool(s["teaser_tool"]), "the next level's tool waits in a bubble")
	assert_eq(String(host.session.upgrades[0]["name"]), "Satchel", "recorded")


func test_a_new_tool_is_a_new_motion() -> void:
	evo.dev("level", 2)
	var s := _s()
	assert_eq(String(s["pose"]), "work_water", "the watering can")
	assert_eq(String(s["name"]), "Waterer", "named")
	var names: Array = host.session.milestones.map(func(m: Dictionary) -> String: return String(m["name"]))
	assert_eq(names, ["Waterer"], "a new tool is a milestone")
	evo.dev("level", 12)
	assert_eq(String(_s()["pose"]), "work_study", "the Scholar studies")
	assert_eq(_s()["wearing"], ["bag", "crown", "apron", "scarf", "medal"], "and wears the crown")


func test_what_it_wears_follows_the_body() -> void:
	evo.dev("level", 11)
	# Let the upgrade's little hop land first.
	await tree.create_timer(0.6).timeout
	var momo: LabMomo = evo.get("momo")
	var pose := String(_s()["pose"])
	var seconds := LabMomo.loop_seconds(pose)
	var offsets := {}
	for i in 24:
		momo.work_t = seconds * float(i) / 24.0
		momo.queue_redraw()
		await tree.process_frame
		var f := LabMomo.work_frame(String(LabMomo.frame_at(pose, momo.work_t)[0]))
		var s := LabMomo.HEIGHT * momo.size / float(LabMomo.work()["stand_height"])
		var pivot := Vector2(float(f["pivot"][0]), float(f["pivot"][1]))
		var head := (Vector2(float(f["head"][0]), float(f["head"][1])) - pivot) * s
		var torso := (Vector2(float(f["torso"][0]), float(f["torso"][1])) - pivot) * s
		var helmet: Vector2 = momo.worn_at["helmet"]
		var bag: Vector2 = momo.worn_at["bag"]
		assert_near((helmet - head).length(), 22.0 * s, 0.01, "frame %d: the helmet on the head" % i)
		assert_near((bag - torso).distance_to(Vector2(44.0 * s, 6.0 * s)), 0.0, 0.01, "frame %d: the bag at the side" % i)
		offsets[String(f["name"])] = true
	assert_eq(offsets.size(), 4, "all four frames of the motion were checked")


func test_the_momo_keeps_its_size_and_place() -> void:
	var first := _s()
	for to: int in [2, 6, 10, 12, 14]:
		evo.dev("level", to)
		var s := _s()
		assert_near(float(s["momo_height"]), float(first["momo_height"]), 0.01, "level %d: the same size" % to)
		assert_eq(s["foot"], first["foot"], "level %d: the same place" % to)
	var momo: LabMomo = evo.get("momo")
	assert_near(momo.size, 0.8, 0.0001, "the game's Momo size")


func test_the_same_play_gives_the_same_momo() -> void:
	host.restart()
	evo = host.experiment
	var a := _play()
	host.restart()
	evo = host.experiment
	var b := _play()
	assert_eq(a, b, "deterministic")


func _play() -> Array:
	for i in 600:
		host.step(0.25)
		if i % 11 == 0:
			host.press_action()
	var s := _s()
	return [int(s["level"]), int(s["coins"]), int(s["passes"]), snappedf(float(s["cycle_t"]), 0.0001), host.session.upgrades.map(func(u: Dictionary) -> int: return int(u["t_ms"]))]


func test_three_minutes_buying_at_once() -> void:
	var t := 0.0
	while t < 180.0:
		host.step(0.05)
		t += 0.05
		if int(_s()["coins"]) >= int(_s()["next_cost"]):
			host.press_action()
	var ups := EvolutionLevels.simulate(180.0)
	assert_eq(host.session.upgrades.size(), ups.size(), "as many upgrades as the table's simulation")
	for i in ups.size():
		assert_near(float(host.session.upgrades[i]["t_ms"]) / 1000.0, ups[i], 0.11, "upgrade %d when the table says" % (i + 1))
