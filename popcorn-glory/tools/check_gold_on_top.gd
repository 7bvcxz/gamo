extends SceneTree

## Step 14 render check (needs a renderer: xvfb-run ... godot --path popcorn-glory --script
## res://tools/check_gold_on_top.gd). Burst pieces are put exactly on the middle of the gold
## arc; with the crescendo mode the gold is stroked again over them and must stay gold, while
## without it (the control, B as it was) the same pieces cover it. Exit code = failures.

const MainScene := preload("res://app/main.tscn")

var _fail := 0


func _init() -> void:
	root.size = Vector2i(720, 1280)
	DisplayServer.window_set_size(Vector2i(720, 1280))
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _gold_fraction(img: Image, r: Rect2) -> float:
	var n := 0
	var gold := 0
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			var c := img.get_pixel(x, y)
			n += 1
			if c.r > 0.88 and c.g > 0.66 and c.g < 0.85 and c.b < 0.36:
				gold += 1
	return float(gold) / maxf(1.0, float(n))


func _measure(burst: bool) -> float:
	var app: Node = MainScene.instantiate()
	app.set("save_prefix", "check.")
	root.add_child(app)
	await process_frame
	app.set("burst", burst)   # after _ready, which sets it from the address
	app.call("open", "stand")
	for i in 3:
		await process_frame
	var view: Node = _find(app)
	var r: Rect2 = view.call("gold_mid_rect")
	var centre := r.get_center()
	var fx = view.get("fx")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Cream pieces with dark outlines, standing still on the gold.
	fx.call("burst", centre, 40, 1.2, rng, Color(1, 0.97, 0.88), 0.01, 0.0001, 1.6, 5.0)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var t: Transform2D = view.get_global_transform_with_canvas()
	var sr := Rect2(t * r.position, t.basis_xform(r.size))
	var f := _gold_fraction(img, sr.grow(-2))
	if OS.get_environment("GOLD_DEBUG") != "":
		img.save_png(OS.get_environment("GOLD_DEBUG") + ("_on.png" if burst else "_off.png"))
		print("rect view ", r, " screen ", sr, " image ", img.get_size())
	app.queue_free()
	await process_frame
	PopSaveStore.clear("check.stand.v1")
	return f


func _find(n: Node) -> Node:
	for c in n.get_children():
		if c.has_method("gold_mid_rect"):
			return c
		var x := _find(c)
		if x != null:
			return x
	return null


func _run() -> void:
	var off := await _measure(false)
	var on := await _measure(true)
	print("gold on the arc under burst pieces: without the mode %.2f, with the crescendo mode %.2f" % [off, on])
	if on < 0.5:
		print("FAIL: with the crescendo mode the gold must stay gold under the pieces")
		_fail += 1
	if off > on - 0.2:
		print("FAIL: the control did not cover the gold -- the check would not see a regression")
		_fail += 1
	print("PASS" if _fail == 0 else "FAILED")
	quit(_fail)
