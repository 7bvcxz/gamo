extends SceneTree

## Step 66: the keyed work poses (assets/src/png/momo_work/*.webp, Momo with
## the tool of each job) -> one packed atlas and its map, beside the 5x5 sheet
## (assets/momo/momo_work.png/.json, design/MOMO_TOOLS.md).
##
## Every frame is the same Momo at the same size as the sheet's: a pose with a
## tool raised over the head or a body that bends cannot be fitted by its
## height. Two measures, both matched to the front standing anchor:
##   eyes  the two solid dark blobs, sized by area (a tilted head keeps it);
##         a paw or a tool beside the head never changes it
##   head  the widest row of cream fur in the head band, the ears beside it --
##         which a raised paw next to the head widens (chop: +30%)
## The eyes fit every frame; their scale is calibrated by the median frame's
## head (the model draws the eyes a little smaller than the anchor's), and
## where the head agrees within 8% the two are averaged. `adjust` corrects
## by eye what neither can see.
## Step 67: frames with the same `strip` were drawn in one picture at one
## size -- they share one scale, so a swing does not pulse with the
## measuring's noise; each still stands on its own feet. A strip's scale is
## the geometric mean of its frames' median by-eye and median by-head
## scales: a closed eye (the strike) or a paw beside the head (the wind-up)
## spoils one frame's measure, not the strip's, and a model that draws one
## job's eyes small (the pickaxe, 12%) no longer decides the size alone.
## `texel_scale` stores the atlas at that share of the sheet's density
## (`stand_height` texels from feet to fur curl): the runtime draws each
## frame at its texture's stand height, so the size on the island is the
## same and the atlas is smaller.
## The feet are the lowest cream pixels; each frame keeps its own pivot (the
## point between the feet), so a frame packs into the atlas trimmed, and the
## renderer stands every one of them on the same ground point.
##
##   godot --headless --path momonium --script res://tools/art/gen/build_momo_work.gd -- \
##     [--frames res://assets/src/png/momo_work/frames.json] [--out res://assets/momo/momo_work]

const HEAD_BAND := Vector2(0.18, 0.45)
## Transparent texels around every frame in the atlas, so mipmaps of one
## frame never bleed into the next.
const PAD := 6


func _init() -> void:
	var args := {"frames": "res://assets/src/png/momo_work/frames.json", "out": "res://assets/momo/momo_work"}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(args["frames"])))
	var stand := float(cfg["stand_height"])
	var dir := String(args["frames"]).get_base_dir()
	var anchor := Image.load_from_file(ProjectSettings.globalize_path(String(cfg["anchor"])))
	anchor.convert(Image.FORMAT_RGBA8)
	# The anchor stands upright: its height is the sheet's stand height.
	var texel := float(cfg.get("texel_scale", 1.0))
	stand *= texel
	var anchor_k := stand / float(cream_box(anchor).size.y)
	var target_head := head_width(anchor) * anchor_k
	var target_eye := float(eyes(anchor)[0]) * anchor_k
	var width := int(cfg.get("atlas_width", 1024))
	var sources: Array = []
	var ratios: Array[float] = []
	for f: Dictionary in cfg["frames"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir.path_join(String(f["src"]))))
		img.convert(Image.FORMAT_RGBA8)
		var e := eyes(img)
		var by_head := target_head / head_width(img)
		var by_eye := target_eye / float(e[0]) if not e.is_empty() else 0.0
		if by_eye > 0.0:
			ratios.append(by_head / by_eye)
		sources.append({"f": f, "img": img, "head": by_head, "eye": by_eye})
	ratios.sort()
	var k := ratios[ratios.size() / 2] if not ratios.is_empty() else 1.0
	var scales: Array[float] = []
	for src: Dictionary in sources:
		var by_head: float = src["head"]
		var by_eye: float = float(src["eye"]) * k
		var s0 := by_head
		if by_eye > 0.0:
			s0 = sqrt(by_eye * by_head) if absf(by_head / by_eye - 1.0) < 0.08 else by_eye
		scales.append(s0)
	var by_strip := {}
	for i in sources.size():
		var strip := String((sources[i]["f"] as Dictionary).get("strip", ""))
		if strip == "":
			continue
		if not by_strip.has(strip):
			by_strip[strip] = {"eye": [], "head": []}
		(by_strip[strip]["head"] as Array).append(float(sources[i]["head"]))
		if float(sources[i]["eye"]) > 0.0:
			(by_strip[strip]["eye"] as Array).append(float(sources[i]["eye"]) * k)
	var strips := {}
	for strip: String in by_strip:
		var head := _median(by_strip[strip]["head"])
		var eye := _median(by_strip[strip]["eye"])
		strips[strip] = sqrt(head * eye) if eye > 0.0 else head
		print("strip %-10s head %.4f eye %.4f -> %.4f" % [strip, head, eye, strips[strip]])
	var placed: Array = []
	print("eye calibration %.3f" % k)
	print("%-16s %7s %7s %7s %9s" % ["frame", "scale", "head", "eye", "size"])
	for n in sources.size():
		var src: Dictionary = sources[n]
		var f: Dictionary = src["f"]
		var img: Image = src["img"]
		var by_head: float = src["head"]
		var by_eye: float = float(src["eye"]) * k
		var s: float = scales[n]
		if f.has("strip"):
			s = float(strips[String(f["strip"])])
		s *= float(f.get("adjust", 1.0))
		var w2 := maxi(1, roundi(img.get_width() * s))
		var h2 := maxi(1, roundi(img.get_height() * s))
		img.resize(w2, h2, Image.INTERPOLATE_LANCZOS)
		var box := opaque_box(img)
		var cut := img.get_region(box)
		var feet := feet_point(img) - Vector2(box.position)
		placed.append({"name": f["name"], "img": cut, "pivot": feet})
		print("%-16s %7.4f %7.4f %7.4f %4dx%-4d" % [f["name"], s, by_head, by_eye, cut.get_width(), cut.get_height()])
	# Shelf packing, tallest first.
	var order := range(placed.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (placed[a]["img"] as Image).get_height() > (placed[b]["img"] as Image).get_height())
	var x := PAD
	var y := PAD
	var shelf := 0
	for i: int in order:
		var im: Image = placed[i]["img"]
		if x + im.get_width() + PAD > width:
			x = PAD
			y += shelf + PAD * 2
			shelf = 0
		placed[i]["at"] = Vector2i(x, y)
		x += im.get_width() + PAD * 2
		shelf = maxi(shelf, im.get_height())
	var height := y + shelf + PAD
	height = (height + 3) / 4 * 4
	var atlas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var frames: Array = []
	for p: Dictionary in placed:
		var im: Image = p["img"]
		var at: Vector2i = p["at"]
		atlas.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), at)
		var pv: Vector2 = p["pivot"]
		frames.append({"name": p["name"], "rect": [at.x, at.y, im.get_width(), im.get_height()], "pivot": [snappedf(pv.x, 0.5), snappedf(pv.y, 0.5)]})
	var base := String(args["out"])
	atlas.save_png(ProjectSettings.globalize_path(base + ".png"))
	var meta := {
		"_doc": "Momo at work (Steps 66-67, design/MOMO_TOOLS.md): a packed atlas beside the 5x5 sheet. Each frame is a trimmed rect with its own pivot (the point between the feet, from the rect's top-left); `stand_height` texels from feet to fur curl (`texel_scale` of the sheet's density -- the runtime draws by it, the same size on the island). `animations` name the frames a job plays at `fps`; `actions` map each building stage's action (data/buildings.json) to its animation. Built by tools/art/gen/build_momo_work.gd from assets/src/png/momo_work/.",
		"stand_height": stand, "texel_scale": texel, "frames": frames, "animations": cfg["animations"], "actions": cfg["actions"],
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(base + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "  ", false) + "\n")
	file.close()
	print("build_momo_work: %s.png %dx%d, %d frames" % [base, width, height, frames.size()])
	quit()


## Momo's fur and overalls: light, warm and unsaturated (r >= b). Steel is
## blue-grey (b > r), wood and wicker are saturated, outlines are dark.
static func is_cream(c: Color) -> bool:
	return c.a > 0.5 and c.r8 > 200 and c.g8 > 180 and c.b8 > 150 and c.r8 >= c.b8 and c.r8 - c.b8 < 70


static func cream_box(img: Image) -> Rect2i:
	var lo := Vector2i(img.get_width(), img.get_height())
	var hi := Vector2i(-1, -1)
	for yy in img.get_height():
		for xx in img.get_width():
			if is_cream(img.get_pixel(xx, yy)):
				lo = Vector2i(mini(lo.x, xx), mini(lo.y, yy))
				hi = Vector2i(maxi(hi.x, xx), maxi(hi.y, yy))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## The widest span of cream in the head band of the cream's own height --
## the head with the ears hanging beside it, whatever the paws lift above.
static func head_width(img: Image) -> float:
	var b := cream_box(img)
	var best := 1.0
	for yy in range(b.position.y + int(b.size.y * HEAD_BAND.x), b.position.y + int(b.size.y * HEAD_BAND.y)):
		var lo := -1
		var hi := -1
		for xx in range(b.position.x, b.end.x):
			if is_cream(img.get_pixel(xx, yy)):
				if lo < 0:
					lo = xx
				hi = xx
		if lo >= 0:
			best = maxf(best, hi - lo + 1)
	return best


## Between the feet: the centre of the cream in the lowest 6% of the cream,
## on the bottom edge of the lowest cream row.
static func feet_point(img: Image) -> Vector2:
	var b := cream_box(img)
	var y0 := b.end.y - maxi(2, int(b.size.y * 0.06))
	var sx := 0.0
	var n := 0
	for yy in range(y0, b.end.y):
		for xx in range(b.position.x, b.end.x):
			if is_cream(img.get_pixel(xx, yy)):
				sx += xx + 0.5
				n += 1
	return Vector2(sx / maxi(n, 1), b.end.y)


## Momo's two eyes: the two largest solid dark blobs (the outline is a thin
## line, a blob is filled), side by side, the head maybe tilted. Returns
## [eye size, spacing] in px -- the size is the square root of an eye's
## area, which a tilted head does not change -- or [] when two are not found.
static func eyes(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var blobs: Array = []
	for start in w * h:
		if seen[start] == 1:
			continue
		var c := img.get_pixel(start % w, start / w)
		if not _dark(c):
			continue
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		var n := 0
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % w
			var y := i / w
			n += 1
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx := x + d.x
				var yy := y + d.y
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				var j := yy * w + xx
				if seen[j] == 0 and _dark(img.get_pixel(xx, yy)):
					seen[j] = 1
					stack.append(j)
		var size := hi - lo + Vector2i.ONE
		var fill := float(n) / float(size.x * size.y)
		var aspect := float(size.y) / float(size.x)
		if n >= 60 and fill > 0.5 and aspect > 0.8 and aspect < 2.2:
			blobs.append({"n": n, "size": size, "c": (Vector2(lo) + Vector2(hi)) / 2.0})
	blobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["n"]) > int(b["n"]))
	for i in blobs.size():
		for j in range(i + 1, mini(blobs.size(), 6)):
			var a: Dictionary = blobs[i]
			var b: Dictionary = blobs[j]
			var dy := absf((a["c"] as Vector2).y - (b["c"] as Vector2).y)
			var dx := absf((a["c"] as Vector2).x - (b["c"] as Vector2).x)
			var ha := float((a["size"] as Vector2i).y)
			var hb := float((b["size"] as Vector2i).y)
			if dy < maxf(ha, hb) * 1.2 and dx > maxf(ha, hb) * 0.7 and absf(ha - hb) < maxf(ha, hb) * 0.4:
				return [sqrt((float(a["n"]) + float(b["n"])) / 2.0), Vector2(dx, dy).length()]
	return []


static func _dark(c: Color) -> bool:
	return c.a > 0.5 and c.get_luminance() < 0.22


static func _median(list: Array) -> float:
	if list.is_empty():
		return 0.0
	var l := list.duplicate()
	l.sort()
	return float(l[(l.size() - 1) / 2]) if l.size() % 2 == 1 else (float(l[l.size() / 2 - 1]) + float(l[l.size() / 2])) / 2.0


static func opaque_box(img: Image) -> Rect2i:
	var r := img.get_used_rect()
	return r if r.size.x > 0 else Rect2i(0, 0, 1, 1)
