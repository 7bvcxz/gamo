extends SceneTree

## Step 41: the sprite audit. Renders with the real renderer (Xvfb; the headless dummy has no
## pixels) and measures what the eye would complain about:
##   motion   every cast member (two looks) through every motion (idle, walk, queue, receive,
##            delight, leave), frame by frame at runtime size: the foot point (the middle of
##            the lowest opaque rows) against the person standing still, the outline's height,
##            and the jump of the centre between frames. A foot that slides or a centre that
##            jumps is jitter or a teleport.
##   halo     the atlas's edge pixels: a half-transparent edge much lighter than the opaque
##            pixels it touches is a white fringe.
##   scale    the factory played at three screens (44 machines, sign 8): the largest screen
##            size each atlas sprite was drawn at, in its own texels (above 1.25 it is soft).
##   crowd    in the same runs: the most people in the shop at once and how close two standing
##            people's feet come (under a head apart they stand on each other).
##   icons    art/icons.gd's set rendered alone: each icon's silhouette against every other
##            (their overlap after centring, IoU) and their mean colours.
##
##   xvfb-run -a -s "-screen 0 1400x1600x24" godot --path popcorn-glory --audio-driver Dummy \
##     --script res://tools/sprite_audit.gd -- --out <dir>
## Writes <dir>/audit.json and contact strips (<dir>/motion_<who>.png, icons.png); exits 1 if a
## check fails.

const Actor := preload("res://variants/factory/actor.gd")
const WHO := ["classic", "student", "rush", "kid", "elder"]
const MOTIONS := ["idle", "walk", "queue", "receive", "delight", "leave"]
const HEAD := 21.8
const FRAMES := 36
const DT := 1.0 / 30.0
var _out := ""
var _fail: Array = []


func _init() -> void:
	Engine.max_fps = 60
	var raw := OS.get_cmdline_user_args()
	for i in raw.size():
		if raw[i] == "--out" and i + 1 < raw.size():
			_out = raw[i + 1]
	if _out == "":
		push_error("sprite_audit: --out <dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _vp(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _grab(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


## The opaque pixels' box, centre and foot point (the middle of the lowest 3 opaque rows).
func _shape(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var x1 := -1
	var y0 := h
	var y1 := -1
	var sx := 0.0
	var sy := 0.0
	var n := 0
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
				sx += x
				sy += y
				n += 1
	if n == 0:
		return {"n": 0}
	var fx := 0.0
	var fn := 0
	for y in range(maxi(0, y1 - 2), y1 + 1):
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				fx += x
				fn += 1
	return {"n": n, "box": [x0, y0, x1 - x0 + 1, y1 - y0 + 1], "c": [sx / n, sy / n], "foot": [fx / maxi(1, fn), float(y1 + 1)]}


func _audit_motion() -> Dictionary:
	var size := Vector2i(int(HEAD * 6), int(HEAD * 6.2))
	var foot := Vector2(size.x * 0.5, size.y - 4)
	var out := {}
	for who: String in WHO:
		var strip := Image.create(size.x * 8, size.y * MOTIONS.size(), false, Image.FORMAT_RGBA8)
		strip.fill(Color(1.0, 0.95, 0.85))
		for look_i in 2:
			for mi in MOTIONS.size():
				var motion := String(MOTIONS[mi])
				var vp := _vp(size)
				var a: Node2D = Actor.new()
				a.kind = Actor.CUSTOMER
				a.model_id = 300 + look_i * 17 + WHO.find(who)
				a.who = who
				a.look = PopCastArt.look_for(a.model_id, who)
				a.size_px = HEAD
				a.position = foot
				a.mood = {"queue": "impatient", "delight": "delight", "leave": "thanks"}.get(motion, "wait")
				vp.add_child(a)
				var rest := _shape(await _grab(vp))
				var worst_foot := 0.0
				var worst_jump := 0.0
				var hmin := 9.0
				var hmax := 0.0
				var last_c := Vector2(rest["c"][0], rest["c"][1])
				if motion in ["receive", "delight"]:
					a.react(motion)
				for f in FRAMES:
					var moved := HEAD * 10.0 * DT if motion in ["walk", "leave"] else 0.0
					a._pose(DT, moved)
					var img := await _grab(vp)
					var sh := _shape(img)
					if int(sh.get("n", 0)) == 0:
						_fail.append("%s %s: nothing drawn" % [who, motion])
						continue
					var fp := Vector2(sh["foot"][0], sh["foot"][1])
					worst_foot = maxf(worst_foot, fp.distance_to(Vector2(rest["foot"][0], rest["foot"][1])))
					var c := Vector2(sh["c"][0], sh["c"][1])
					worst_jump = maxf(worst_jump, c.distance_to(last_c))
					last_c = c
					var hr := float(sh["box"][3]) / float(rest["box"][3])
					hmin = minf(hmin, hr)
					hmax = maxf(hmax, hr)
					if look_i == 0 and f % 4 == 0 and f / 4 < 8:
						strip.blit_rect(img, Rect2i(Vector2i.ZERO, size), Vector2i((f / 4) * size.x, mi * size.y))
				var key := "%s/%d/%s" % [who, look_i, motion]
				out[key] = {"foot_slide_px": snappedf(worst_foot, 0.01), "centre_jump_px": snappedf(worst_jump, 0.01), "height": [snappedf(hmin, 0.001), snappedf(hmax, 0.001)]}
				if worst_foot > maxf(2.5, HEAD * 0.12):
					_fail.append("%s: the foot slides %.1f px" % [key, worst_foot])
				if worst_jump > HEAD * 0.25:
					_fail.append("%s: the centre jumps %.1f px in a frame" % [key, worst_jump])
				if hmin < 0.85 or hmax > 1.25:
					_fail.append("%s: the height changes %s" % [key, [hmin, hmax]])
				vp.queue_free()
		_blend_onto(strip)
		strip.save_png(_out.path_join("motion_%s.png" % who))
	return out


## The strips were blitted with alpha; put them on the shop's cream so they can be looked at.
func _blend_onto(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 1.0:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.85).lerp(Color(c.r, c.g, c.b), c.a))


func _audit_halo() -> Dictionary:
	var out := {}
	if not PopAtlas.ready():
		_fail.append("halo: no atlas")
		return out
	var img: Image = PopAtlas.texture().get_image()
	if img.is_compressed():
		img.decompress()
	for name: String in ["coin", "piece_a", "piece_b", "piece_c", "smoke", "sparkle", "kernel"]:
		var r := PopAtlas.region(name)
		var edge := 0
		var lighter := 0.0
		for y in range(int(r.position.y) + 1, int(r.end.y) - 1):
			for x in range(int(r.position.x) + 1, int(r.end.x) - 1):
				var c := img.get_pixel(x, y)
				if c.a <= 0.05 or c.a >= 0.6:
					continue
				var best := -1.0
				var ref := Color()
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := img.get_pixel(x + d.x, y + d.y)
					if q.a > best:
						best = q.a
						ref = q
				if best < 0.9:
					continue
				edge += 1
				lighter += maxf(0.0, c.get_luminance() - ref.get_luminance())
		var mean := lighter / maxf(1.0, float(edge))
		out[name] = {"edge_px": edge, "lighter_than_inside": snappedf(mean, 0.001)}
		if mean > 0.25:
			_fail.append("halo: %s's edge is %.2f lighter than its inside (a white fringe)" % [name, mean])
	return out


func _audit_runs() -> Dictionary:
	var out := {}
	PopAtlas.audit = true
	for sz: Vector2i in [Vector2i(720, 1280), Vector2i(390, 844), Vector2i(1280, 800)]:
		PopAtlas.peak.clear()
		root.size = sz
		DisplayServer.window_set_size(sz)
		var app: Node = load("res://app/main.tscn").instantiate()
		app.set("save_prefix", "audit.")
		PopSaveStore.clear("audit.factory.v1")
		root.add_child(app)
		for i in 3:
			await process_frame
		app.open("factory")
		for i in 3:
			await process_frame
		var rr = app.rules
		rr.sign_tier = 6
		rr.packer_tier = 3
		rr.level = maxi(int(rr.level), 6)
		rr.money += 1 << 24
		for row: Array in preload("res://tests/unit/test_factory_rules.gd").FORTY_PLAN:
			var fl := String(row[1])
			if rr.floor_full(fl) and int(rr.line_cost(fl)) >= 0:
				app.on_command("buy_line", {"type": "buy_line", "floor": fl})
			app.on_command("build", {"type": "build", "machine": row[0], "floor": fl})
		rr.sign_tier = 8
		var most := 0
		var closest := 1e9
		var v: Node = app.frame.play
		for f in 1500:   # 25 s at 60 fps, the game at its own speed
			await process_frame
			if f % 6 != 0:
				continue
			var people: Array = v.cast_debug()["people"]
			most = maxi(most, people.size())
			var standing := people.filter(func(p: Dictionary) -> bool: return not bool(p["moving"]) and float(p["alpha"]) > 0.99)
			for i in standing.size():
				for j in i:
					var a: Dictionary = standing[i]
					var b: Dictionary = standing[j]
					if absf(float(a["y"]) - float(b["y"])) < 2.0:
						closest = minf(closest, absf(float(a["x"]) - float(b["x"])))
		var hp := float(v._head_px())
		var key := "%dx%d" % [sz.x, sz.y]
		out[key] = {"atlas_peak_scale": PopAtlas.peak.duplicate(), "people_most": most, "closest_feet_heads": snappedf(closest / hp, 0.01) if closest < 1e8 else -1.0, "head_px": hp}
		for name: String in PopAtlas.peak:
			if float(PopAtlas.peak[name]) > 1.25:
				_fail.append("%s: %s drawn at %.2fx its texels (soft)" % [key, name, float(PopAtlas.peak[name])])
		if closest < hp * 1.0:
			_fail.append("%s: two people stand %.1f heads apart (on each other)" % [key, closest / hp])
		var img := root.get_texture().get_image()
		img.save_png(_out.path_join("rush_%s.png" % key))
		if app.get("audio") != null:
			app.audio.stop_all()
		app.queue_free()
		for i in 3:
			await process_frame
	PopAtlas.audit = false
	return out


func _audit_icons() -> Dictionary:
	var n := PopIcons.NAMES.size()
	var cell := 64
	var masks := []
	var cols := []
	var sheet := Image.create(cell * n, cell, false, Image.FORMAT_RGBA8)
	for i in n:
		var vp := _vp(Vector2i(cell, cell))
		var node := Node2D.new()
		var nm := String(PopIcons.NAMES[i])
		node.draw.connect(func() -> void: PopIcons.draw(node, nm, Vector2(cell * 0.5, cell * 0.5), cell * 0.75))
		vp.add_child(node)
		var img := await _grab(vp)
		sheet.blit_rect(img, Rect2i(0, 0, cell, cell), Vector2i(i * cell, 0))
		var sh := _shape(img)
		var m := PackedByteArray()
		m.resize(cell * cell)
		var acc := Vector3.ZERO
		var k := 0
		var c0 := Vector2(sh["c"][0], sh["c"][1]) if int(sh.get("n", 0)) > 0 else Vector2(cell * 0.5, cell * 0.5)
		var shift := Vector2i(roundi(cell * 0.5 - c0.x), roundi(cell * 0.5 - c0.y))
		for y in cell:
			for x in cell:
				var px := img.get_pixel(x, y)
				if px.a > 0.5:
					acc += Vector3(px.r, px.g, px.b)
					k += 1
					var q := Vector2i(x, y) + shift
					if q.x >= 0 and q.y >= 0 and q.x < cell and q.y < cell:
						m[q.y * cell + q.x] = 1
		masks.append(m)
		cols.append(acc / maxf(1.0, float(k)))
		vp.queue_free()
	_blend_onto(sheet)
	sheet.save_png(_out.path_join("icons.png"))
	var worst := 0.0
	var pair := ""
	var table := {}
	for i in n:
		for j in i:
			var inter := 0
			var uni := 0
			var a: PackedByteArray = masks[i]
			var b: PackedByteArray = masks[j]
			for q in a.size():
				if a[q] == 1 and b[q] == 1:
					inter += 1
				if a[q] == 1 or b[q] == 1:
					uni += 1
			var iou := float(inter) / maxf(1.0, float(uni))
			table["%s~%s" % [PopIcons.NAMES[j], PopIcons.NAMES[i]]] = snappedf(iou, 0.001)
			if iou > worst:
				worst = iou
				pair = "%s~%s" % [PopIcons.NAMES[j], PopIcons.NAMES[i]]
	if worst > 0.8:
		_fail.append("icons: %s have nearly the same outline (IoU %.2f)" % [pair, worst])
	var mean := {}
	for i in n:
		var c: Vector3 = cols[i]
		mean[PopIcons.NAMES[i]] = [snappedf(c.x, 0.01), snappedf(c.y, 0.01), snappedf(c.z, 0.01)]
	return {"worst_iou": snappedf(worst, 0.001), "worst_pair": pair, "iou": table, "mean_colour": mean}


func _run() -> void:
	var report := {}
	report["motion"] = await _audit_motion()
	report["halo"] = _audit_halo()
	report["icons"] = await _audit_icons()
	report["runs"] = await _audit_runs()
	report["failures"] = _fail
	var f := FileAccess.open(_out.path_join("audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("sprite_audit: %d failures" % _fail.size())
	for m: String in _fail:
		print("  ", m)
	for i in 3:
		await process_frame
	await create_timer(0.25).timeout
	quit(0 if _fail.is_empty() else 1)
