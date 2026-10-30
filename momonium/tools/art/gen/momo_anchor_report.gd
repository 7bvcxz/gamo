extends SceneTree

## Step 76: how still Momo stands, measured -- for every animation of the
## sheet and the work atlas, each anchoring method's jitter, and the drawn
## pivots' distance from the measured root (design/MOMO_ANCHORS.md).
##
## Methods (the root each puts on the node's origin):
##   shipped  the pivot the map ships (what the game draws)
##   feet     midway between the two feet (the lowest body row if not two)
##   torso    the torso, at one point for the whole animation
##   box      the bounding box's centre, at one point for the whole animation
##   hybrid   MomoAnchor.roots: the feet, the planted foot when one lifts,
##            the torso over the feet's place when they are hidden
## Jitter, in island pixels at zoom 1, between consecutive frames of a loop:
##   slide  how far the steadier foot moves (both frames two-footed)
##   torso  how far the torso moves      head  how far the eyes move
##   float  how far the ground contact rises or sinks off the root's line
##   off    how far the method's root is from the hybrid root (for
##          `shipped`: how far off the game's pivot is)
##
##   godot --headless --path momonium --script res://tools/art/gen/momo_anchor_report.gd -- \
##     [--work res://assets/momo/momo_work] [--sheet res://assets/momo/momo_sheet] \
##     [--out /abs/dir] [--label 0.76]
## Writes <out>/anchors.json (every frame's measures and roots, every
## method's jitter) and <out>/methods.png (each animation's frames stacked
## on each method's root, a cross on it), and prints the table.

const Anchor := preload("res://tools/art/gen/momo_anchor.gd")
const METHODS: PackedStringArray = ["shipped", "feet", "torso", "box", "hybrid"]
## Island pixels from feet to fur curl (MomoRig.HEIGHT).
const HEIGHT := 72.0


func _init() -> void:
	var args := {"work": "res://assets/momo/momo_work", "sheet": "res://assets/momo/momo_sheet", "out": "", "label": ""}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var frames := load_frames(String(args["work"]), String(args["sheet"]))
	var anims: Dictionary = frames["animations"]
	var report := {"label": args["label"], "animations": {}, "frames": {}}
	var totals := {}
	print("%-14s %-8s %6s %6s %6s %6s %6s" % ["animation", "method", "slide", "torso", "head", "float", "off"])
	for anim: String in anims:
		var names: Array = anims[anim]
		var ms: Array = []
		for n: String in names:
			var f: Dictionary = frames["frames"][n]
			ms.append(Anchor.measure(f["img"], float(f["h"])))
		var specs: Array = names.map(func(n: String) -> Dictionary: return (frames["frames"][n] as Dictionary).get("spec", {}))
		if anim.begins_with("walk_"):
			# A walk keeps the head where the view's standing pose has it.
			var idle := "%s_idle" % anim.trim_prefix("walk_")
			var im: Dictionary = Anchor.measure(frames["frames"][idle]["img"], float(frames["frames"][idle]["h"]))
			var ir: Vector2 = Anchor.roots([im], float(frames["frames"][idle]["h"]), [frames["frames"][idle].get("spec", {})])[0]["root"]
			specs = names.map(func(_n: String) -> Dictionary: return {"head": ir.x - float(im["head_x"])})
		var hyb: Array = Anchor.roots(ms, float((frames["frames"][names[0]] as Dictionary)["h"]), specs)
		var by_method := {}
		for method: String in METHODS:
			by_method[method] = method_roots(method, names, ms, hyb, frames["frames"])
		var row := {}
		for method: String in METHODS:
			var j := jitter(names, ms, specs, by_method[method], hyb, frames["frames"])
			row[method] = j
			if not totals.has(method):
				totals[method] = {"slide": [], "torso": [], "head": [], "float": [], "off": []}
			for k: String in j:
				(totals[method][k] as Array).append(float(j[k]))
			print("%-14s %-8s %6.1f %6.1f %6.1f %6.1f %6.1f" % [anim, method, j["slide"], j["torso"], j["head"], j["float"], j["off"]])
		report["animations"][anim] = row
		for i in names.size():
			var f: Dictionary = frames["frames"][names[i]]
			var m: Dictionary = ms[i]
			var k := HEIGHT / float(f["h"])
			report["frames"][names[i]] = {"pivot": _v(f["pivot"]), "root": _v(hyb[i]["root"]), "method": hyb[i]["method"],
				"off_px": snappedf(((f["pivot"] as Vector2) - (hyb[i]["root"] as Vector2)).length() * k, 0.01),
				"feet": (m["feet"] as Array).size(), "torso": _v(m["torso"]), "eyes": _v(m["eyes"]), "box": [m["box"].position.x, m["box"].position.y, m["box"].size.x, m["box"].size.y]}
		report["animations"][anim]["_roots"] = {}
		for method: String in METHODS:
			report["animations"][anim]["_roots"][method] = (by_method[method] as Array).map(func(v: Vector2) -> Array: return _v(v))
	print("")
	print("%-23s %6s %6s %6s %6s %6s   (max over animations; mean in brackets)" % ["method", "slide", "torso", "head", "float", "off"])
	var summary := {}
	for method: String in METHODS:
		var line := "%-23s" % method
		summary[method] = {}
		for k: String in ["slide", "torso", "head", "float", "off"]:
			var l: Array = totals[method][k]
			var mx := 0.0
			var sum := 0.0
			for v: float in l:
				mx = maxf(mx, v)
				sum += v
			summary[method][k] = {"max": snappedf(mx, 0.01), "mean": snappedf(sum / maxi(l.size(), 1), 0.01)}
			line += " %6.1f" % mx
		print(line + "   " + " ".join(["slide", "torso", "head", "float", "off"].map(func(k: String) -> String: return "%.1f" % summary[method][k]["mean"])))
	report["summary"] = summary
	var out := String(args["out"])
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		var f := FileAccess.open(out.path_join("anchors.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  ", false) + "\n")
		f.close()
		methods_sheet(frames, report).save_png(out.path_join("methods.png"))
		print("momo_anchor_report: %s/anchors.json, methods.png" % out)
	quit()


static func _v(v: Vector2) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]


## Every frame of the sheet and the atlas: {frames: name -> {img, pivot, h},
## animations: name -> [frame names, each once, in play order]}. The sheet's
## stationary poses are grouped as the rig switches between them (a mood or
## a rest from standing), so a jump between them counts.
static func load_frames(work: String, sheet: String) -> Dictionary:
	var out := {"frames": {}, "animations": {}}
	var smap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sheet + ".json"))
	var simg := Image.load_from_file(ProjectSettings.globalize_path(sheet + ".png"))
	simg.convert(Image.FORMAT_RGBA8)
	var cell := Vector2i(int(smap["cell"][0]), int(smap["cell"][1]))
	# The authored roots of the sources (a point in source pixels is left
	# out: the report measures the built pictures).
	var cell_specs := _specs("res://assets/src/png/momo/cells.json", "cells")
	var frame_specs := _specs("res://assets/src/png/momo_work/frames.json", "frames")
	for c: Dictionary in smap["cells"]:
		var pv: Array = c.get("pivot", smap["pivot"])
		out["frames"][c["name"]] = {"img": simg.get_region(Rect2i(Vector2i(int(c["col"]) * cell.x, int(c["row"]) * cell.y), cell)),
			"pivot": Vector2(float(pv[0]), float(pv[1])), "h": float(smap["stand_height"]), "spec": _spec(cell_specs.get(c["name"], {}))}
	for a: String in smap["animations"]:
		var cells: Array = smap["animations"][a]["cells"]
		if cells.size() > 1:
			var once: Array = []
			for c: String in cells:
				if not once.has(c):
					once.append(c)
			out["animations"][a] = once
	out["animations"]["stand_front"] = ["front_idle", "front_blink", "happy", "confused", "waiting", "carry", "sit"]
	if FileAccess.file_exists(work + ".json"):
		var wmap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(work + ".json"))
		var wimg := Image.load_from_file(ProjectSettings.globalize_path(work + ".png"))
		wimg.convert(Image.FORMAT_RGBA8)
		for f: Dictionary in wmap["frames"]:
			var r: Array = f["rect"]
			out["frames"][f["name"]] = {"img": wimg.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))),
				"pivot": Vector2(float(f["pivot"][0]), float(f["pivot"][1])), "h": float(wmap["stand_height"]), "spec": _spec(frame_specs.get(f["name"], {}))}
		for a: String in wmap["animations"]:
			out["animations"][a] = (wmap["animations"][a]["cells"] as Array).duplicate()
	return out


static func _specs(path: String, key: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for e: Dictionary in cfg[key]:
		if e.has("root"):
			out[String(e["name"])] = e["root"]
	return out


static func _spec(spec: Dictionary) -> Dictionary:
	var s := spec.duplicate()
	s.erase("at")
	return s


## Each frame's root under `method`, in its own pixels.
static func method_roots(method: String, names: Array, ms: Array, hyb: Array, frames: Dictionary) -> Array:
	var out: Array = []
	var torso_off: Array = [[], []]
	var box_off: Array = [[], []]
	for i in names.size():
		var r: Vector2 = hyb[i]["root"]
		var t: Vector2 = ms[i]["torso"]
		var b: Vector2 = Rect2(ms[i]["box"] as Rect2i).get_center()
		(torso_off[0] as Array).append(r.x - t.x)
		(torso_off[1] as Array).append(r.y - t.y)
		(box_off[0] as Array).append(r.x - b.x)
		(box_off[1] as Array).append(r.y - b.y)
	for i in names.size():
		var m: Dictionary = ms[i]
		match method:
			"shipped":
				out.append(frames[names[i]]["pivot"])
			"feet":
				var c: Array = m["contacts"]
				if c.size() == 2:
					out.append(Anchor._between(c))
				else:
					out.append(Vector2(float(m["bottom_x"]), float(m["bottom"])))
			"torso":
				out.append((m["torso"] as Vector2) + Vector2(Anchor.median(torso_off[0]), Anchor.median(torso_off[1])))
			"box":
				out.append(Rect2(m["box"] as Rect2i).get_center() + Vector2(Anchor.median(box_off[0]), Anchor.median(box_off[1])))
			_:
				out.append(hyb[i]["root"])
	return out


## The jitter of one animation under one method's roots (see the top), in
## island pixels at zoom 1. Consecutive pairs wrap around a loop.
static func jitter(names: Array, ms: Array, specs: Array, roots: Array, hyb: Array, frames: Dictionary) -> Dictionary:
	var out := {"slide": 0.0, "torso": 0.0, "head": 0.0, "float": 0.0, "off": 0.0}
	var n := names.size()
	for i in n:
		var k := HEIGHT / float(frames[names[i]]["h"])
		out["off"] = maxf(out["off"], ((roots[i] as Vector2) - (hyb[i]["root"] as Vector2)).length() * k)
		if n < 2:
			continue
		var j := (i + 1) % n
		var kj := HEIGHT / float(frames[names[j]]["h"])
		var a: Dictionary = ms[i]
		var b: Dictionary = ms[j]
		var ra: Vector2 = roots[i]
		var rb: Vector2 = roots[j]
		var fa: Array = a["contacts"]
		var fb: Array = b["contacts"]
		if fa.size() == 2 and fb.size() == 2:
			var best := INF
			for s in 2:
				var d := ((fb[s] as Vector2) - rb) * kj - ((fa[s] as Vector2) - ra) * k
				best = minf(best, d.length())
			out["slide"] = maxf(out["slide"], best)
		out["torso"] = maxf(out["torso"], (((b["torso"] as Vector2) - rb) * kj - ((a["torso"] as Vector2) - ra) * k).length())
		if (a["eyes"] as Vector2).x >= 0.0 and (b["eyes"] as Vector2).x >= 0.0:
			out["head"] = maxf(out["head"], (((b["eyes"] as Vector2) - rb) * kj - ((a["eyes"] as Vector2) - ra) * k).length())
		out["float"] = maxf(out["float"], absf((_ground(b, specs[j]) - rb.y) * kj - (_ground(a, specs[i]) - ra.y) * k))
	return out


## Where a drawing meets the ground: its planted feet's line, or the body's
## lowest row where the feet are hidden or off the ground (an authored torso
## or box root).
static func _ground(m: Dictionary, spec: Dictionary) -> float:
	return float(m["bottom"]) if spec.has("torso") or spec.has("box") else float(m["ground"])


## Every animation (rows) under every method (columns): its frames stacked
## on the method's root at one size, faded, a red cross on the root -- a
## still Momo is one sharp figure, a jumping one a smear.
static func methods_sheet(frames: Dictionary, report: Dictionary) -> Image:
	var cw := 240
	var ch := 210
	var anims: Dictionary = report["animations"]
	var img := Image.create(150 + cw * METHODS.size(), 30 + ch * anims.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.93, 0.94, 0.9))
	var row := 0
	for anim: String in anims:
		var names: Array = (frames["animations"] as Dictionary)[anim]
		for col in METHODS.size():
			var roots: Array = anims[anim]["_roots"][METHODS[col]]
			var origin := Vector2i(150 + col * cw, 30 + row * ch)
			var ground := origin + Vector2i(cw / 2, ch - 22)
			for x in range(origin.x + 8, origin.x + cw - 8):
				img.set_pixel(x, ground.y, Color(0.45, 0.6, 0.4))
			for i in names.size():
				var f: Dictionary = frames["frames"][names[i]]
				var src: Image = (f["img"] as Image).duplicate()
				var s := 120.0 / float(f["h"])
				src.resize(maxi(1, roundi(src.get_width() * s)), maxi(1, roundi(src.get_height() * s)), Image.INTERPOLATE_BILINEAR)
				for y in src.get_height():
					for x in src.get_width():
						var c := src.get_pixel(x, y)
						c.a *= 0.38
						src.set_pixel(x, y, c)
				var r := Vector2(float(roots[i][0]), float(roots[i][1])) * s
				var at := ground - Vector2i(roundi(r.x), roundi(r.y))
				var clip := Rect2i(origin, Vector2i(cw, ch)).intersection(Rect2i(at, src.get_size()))
				if clip.size.x > 0 and clip.size.y > 0:
					img.blend_rect(src, Rect2i(clip.position - at, clip.size), clip.position)
			for d in range(-7, 8):
				for t in [-1, 0, 1]:
					for q: Vector2i in [ground + Vector2i(d, t), ground + Vector2i(t, d)]:
						img.set_pixelv(q, Color(0.85, 0.1, 0.1))
		row += 1
	return img
