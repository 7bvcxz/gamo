extends SceneTree

## Step 67: a generated 2x2 animation sheet (four frames of one job on chroma
## green, read top-left, top-right, bottom-left, bottom-right) -> four keyed
## frames, `<out>_0.webp` .. `<out>_3.webp`. Every opaque piece goes to the
## quarter its centre is in -- the water drops, the wood chips, the seeds
## belong to the frame they fly in, not to the biggest blob -- and specks
## under `--min` px are dropped. Each frame is cropped to its pieces with
## `--margin` px; the four keep the generated scale (one picture, one size),
## which build_momo_work.gd keeps too (`strip`).
##
##   godot --headless --path momonium --script res://tools/art/gen/split_frames.gd -- \
##     --in /abs/dig4.png --out res://assets/src/png/momo_work/dig [--min 24] [--margin 4]

const KeyOutput := preload("res://tools/art/gen/key_output.gd")


func _init() -> void:
	var args := {"min": "24", "margin": "4"}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var img := Image.load_from_file(String(args["in"]))
	img.convert(Image.FORMAT_RGBA8)
	KeyOutput.key(img)
	var w := img.get_width()
	var h := img.get_height()
	var boxes: Array[Rect2i] = []
	boxes.resize(4)
	var found := [false, false, false, false]
	var dropped := 0
	var seen := PackedByteArray()
	seen.resize(w * h)
	for start in w * h:
		if seen[start] == 1 or img.get_pixel(start % w, start / w).a < 0.5:
			continue
		var pixels: Array[int] = []
		var stack: Array[int] = [start]
		seen[start] = 1
		var sum := Vector2.ZERO
		while not stack.is_empty():
			var i: int = stack.pop_back()
			pixels.append(i)
			var x := i % w
			var y := i / w
			sum += Vector2(x, y)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx := x + d.x
				var yy := y + d.y
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				var j := yy * w + xx
				if seen[j] == 0 and img.get_pixel(xx, yy).a >= 0.5:
					seen[j] = 1
					stack.append(j)
		if pixels.size() < int(args["min"]):
			dropped += 1
			for i: int in pixels:
				img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))
			continue
		var c := sum / pixels.size()
		var q := (1 if c.x >= w / 2.0 else 0) + (2 if c.y >= h / 2.0 else 0)
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		for i: int in pixels:
			lo = Vector2i(mini(lo.x, i % w), mini(lo.y, i / w))
			hi = Vector2i(maxi(hi.x, i % w), maxi(hi.y, i / w))
		var r := Rect2i(lo, hi - lo + Vector2i.ONE)
		boxes[q] = boxes[q].merge(r) if found[q] else r
		found[q] = true
	for q in 4:
		if not found[q]:
			push_error("split_frames: frame %d is empty" % q)
			quit(1)
			return
		var r := boxes[q].grow(int(args["margin"])).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		# Only this quarter's pieces: clear what belongs to the others.
		var cut := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		for y in r.size.y:
			for x in r.size.x:
				var px := img.get_pixel(r.position.x + x, r.position.y + y)
				if px.a <= 0.0:
					continue
				var owner := -1
				for k in 4:
					if found[k] and boxes[k].has_point(Vector2i(r.position.x + x, r.position.y + y)):
						owner = k if owner < 0 or k == q else owner
				if owner == q:
					cut.set_pixel(x, y, px)
		var path := ProjectSettings.globalize_path("%s_%d.webp" % [args["out"], q])
		cut.save_webp(path, false)
		print("split_frames: %s_%d %dx%d" % [String(args["out"]).get_file(), q, r.size.x, r.size.y])
	print("split_frames: %d specks dropped" % dropped)
	quit()
