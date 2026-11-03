extends SceneTree

## How big E's and E+'s production line is on screen (Step 97), measured the
## same way for both at the same levels and window sizes:
##   item_px     how tall a product is drawn, in canvas pixels
##   path_px     how long the belt the eye follows is, hopper end to crate end
##   box         the line's bounding box (hopper, belts, machine, crate) as a
##               share of the play area between the counter and the button
## Each run also saves a picture (--shots dir). E's numbers come from its own
## nodes (its `at`, its sprites, its world scale) without changing it.
##
##   xvfb-run -a godot --path momonium/experiments --audio-driver Dummy --script res://tools/e_frame.gd -- \
##     --size 720x1280 [--shots /abs/dir] [--json /abs/out.json]

const LEVELS: Array[int] = [0, 3, 5, 7, 10]

var _args := {}


func _init() -> void:
	Engine.max_fps = 60
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var v: String = raw[i + 1] if i + 1 < raw.size() and not raw[i + 1].begins_with("--") else ""
		_args[raw[i].trim_prefix("--")] = v
		i += 2 if v != "" else 1
	var parts: PackedStringArray = String(_args.get("size", "720x1280")).split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	root.size = size
	DisplayServer.window_set_size(size)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var app: LabApp = (load("res://lab/main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await _frames(3)
	var rows: Array = []
	for id: String in ["tycoon", "tycoon-plus"]:
		for lv: int in LEVELS:
			app.open(id)
			await _frames(3)
			var e := app.host.experiment
			e.dev("level", lv)
			app.host.step(15.0)
			# Long enough for E+'s camera to settle and the upgrades' words
			# (all bought at once here) to fade before the picture.
			await _frames(150)
			var m := _measure(id, e)
			m["id"] = id
			m["level"] = lv
			rows.append(m)
			print("%s lv%d: item %.0f px, path %.0f px, box %.2f" % [id, lv, m["item_px"], m["path_px"], m["box"]])
			if _args.has("shots"):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(String(_args["shots"]).path_join("%s_lv%d_%s.png" % [id, lv, _args.get("size", "720x1280")]))
			app.back()
			await _frames(2)
	if _args.has("json"):
		var f := FileAccess.open(String(_args["json"]), FileAccess.WRITE)
		f.store_string(JSON.stringify({"size": _args.get("size", "720x1280"), "rows": rows}, "  "))
		f.close()
	app.queue_free()
	await _frames(3)
	quit()


static func _measure(id: String, e: Node) -> Dictionary:
	var world: Node2D = e.get("world")
	var island: Node2D = e.get("island")
	var k := world.scale.x
	var line: TycoonLine = e.get("line")
	var product := LabAtlas.texture(String(TycoonLevels.row(int(e.get("level")))["product"]))
	var xf := island.get_global_transform()
	var path := 0.0
	var prev := Vector2.ZERO
	var box := Rect2()
	var first := true
	var x := 0.0
	while x <= TycoonLine.LENGTH + 0.001:
		var p: Vector2 = xf * (e.call("at", x, 0) if id == "tycoon" else e.call("at", x, 0.0))
		if not first:
			path += p.distance_to(prev)
		prev = p
		x += 0.1
		first = false
	for lane in line.lanes:
		for t: float in [0.0, TycoonLine.MACHINE_AT, TycoonLine.LENGTH]:
			var p: Vector2 = xf * (e.call("at", t, lane) if id == "tycoon" else e.call("at", t, float(lane)))
			box = Rect2(p, Vector2.ZERO) if box.size == Vector2.ZERO and box.position == Vector2.ZERO else box.expand(p)
	for s: Sprite2D in [e.get("machine"), e.get("hopper"), e.get("crate")]:
		var size := s.texture.get_size() * s.scale
		var r := Rect2(s.get_global_transform() * (s.offset), size * world.scale)
		box = box.merge(r)
	var item := 0.0
	if id == "tycoon":
		item = product.region.size.y * 0.36 * k
	else:
		item = float(e.call("item_gap")) * k
	var area := Rect2(0, LabHost.TOP_UI + 64.0, (e as Control).size.x, (e as Control).size.y - LabHost.TOP_UI - 64.0 - LabHost.BOTTOM_UI)
	return {"item_px": snappedf(item, 0.1), "path_px": snappedf(path, 1.0), "box": snappedf(box.size.x * box.size.y / (area.size.x * area.size.y), 0.01),
		"zoom": snappedf(k, 0.01), "lanes": line.lanes}
