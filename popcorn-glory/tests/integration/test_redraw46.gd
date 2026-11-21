extends "res://tests/framework/test_case.gd"

## Step 46: what may redraw every frame (QUALITY_GATES R-01, G-30). On the web each redrawn
## polygon is GL ids the engine never gives back (Emscripten's GL.getNewId), so the page's
## heap grows with every redraw of a polygon. At 44 machines 0.46.0 made ~830-1200 ids a frame
## (~20 MB a minute): the kettle redrew every frame (two fills fought), the upgrade card bobbed
## by redrawing, the ring was redrawn with every effect, a count's change redrew the whole shop
## and packing floor, and the kitchen's card redrew with the goods. These hold the fixes.

const Main := preload("res://app/main.tscn")
const PLAN := [["M07", "kitchen"], ["bagger", "packing"], ["S03", "shop"], ["M01", "kitchen"], ["M07", "kitchen"],
	["S05", "shop"], ["M07", "kitchen"], ["P07", "packing"], ["M13", "kitchen"], ["M07", "kitchen"], ["bagger", "packing"], ["S08", "shop"]]
var app: PopApp
var _face_draws := 0
var _face_cb := Callable()


func before_each() -> void:
	app = Main.instantiate()
	app.save_prefix = "test."
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	var face: Node2D = app.frame.upgrade_button.get_node_or_null("Face")
	if face != null and _face_cb.is_valid() and face.draw.is_connected(_face_cb):
		face.draw.disconnect(_face_cb)
	_face_cb = Callable()
	app.queue_free()
	await tree.process_frame


func _view() -> Node:
	return app.frame.play


func _count(frames: int) -> Dictionary:
	var v := _view()
	var face: Node2D = app.frame.upgrade_button.get_node("Face")
	if not _face_cb.is_valid():
		_face_cb = func() -> void: _face_draws += 1
		face.draw.connect(_face_cb)
	var r0: Dictionary = (v.redraws as Dictionary).duplicate()
	var k0 := int(v.machine_node.redraws)
	_face_draws = 0
	for i in frames:
		await tree.process_frame
	var out := {"kettle": int(v.machine_node.redraws) - k0, "face": _face_draws}
	for key: String in ["ring", "scenery", "goods", "detail", "floors"]:
		out[key] = int((v.redraws as Dictionary).get(key, 0)) - int(r0.get(key, 0))
	return out


func test_an_idle_factory_redraws_nothing_every_frame() -> void:
	app.open("factory")
	for i in 10:
		await tree.process_frame
	var c := await _count(40)
	print("  idle, 40 frames: ", c)
	assert_true(int(c["kettle"]) <= 1, "the kettle is not redrawn each frame (%d)" % int(c["kettle"]))
	assert_true(int(c["ring"]) <= 1, "nor the ring (%d)" % int(c["ring"]))
	assert_true(int(c["face"]) <= 4, "nor the upgrade card: only when its offer changes (%d of 40 frames)" % int(c["face"]))
	assert_eq(int(c["scenery"]), 0, "nor the shop's and packing floor's still parts")


func test_a_running_factory_redraws_the_goods_not_the_scenery_and_bakes_its_pieces() -> void:
	app.open("factory")
	await tree.process_frame
	app.dev_money(1000000000)
	assert_true(bool(app.dev_build(PLAN, 6, 3)["ok"]), "a twelve-machine factory")
	for i in 20:
		app.dev_advance(250)
		await tree.process_frame
	var v := _view()
	var rich: bool = app.rules.money > 0
	var c := await _count(60)
	print("  12 machines, 60 frames: ", c, " bin ", app.rules.bin_portions(), " shelf ", (app.rules.get("shelf") as Array).size())
	assert_true(int(c["kettle"]) <= 2, "the kettle is not redrawn each frame (%d)" % int(c["kettle"]))
	assert_true(int(c["ring"]) <= 2, "nor the ring (%d)" % int(c["ring"]))
	assert_eq(int(c["scenery"]), 0, "the still parts stay as they are while the goods move")
	assert_true(rich, "the wallet")
	# The goods' pieces are baked pictures (a quad each), not polygons: a full bin, a few frames
	# for its pictures to bake (3 process frames), then nothing pends and every piece is a quad.
	app.dev_fill_bin()
	for i in 8:
		await tree.process_frame
	print("  full bin ", app.rules.bin_portions(), ": pending ", v._goods_pending, ", pictures ", (v._goods_list as Array).size())
	assert_false(bool(v._goods_pending), "no piece waits for its picture")
	assert_true((v._goods_list as Array).size() >= mini(int(app.rules.bin_portions()), int(app.rules.state()["bin_cap"])), "every portion in the bin drawn as a picture")
