extends SceneTree

## Step 51: a generated pose (one character on chroma green) -> a transparent
## source cropped to the character, for the Momo sheet.
##
## The key is key_output.gd's (flood fill from the border through key-green,
## pure key anywhere, edges unmixed). Then whatever is not part of the
## character goes: connected pieces smaller than `--keep` of the largest one
## (a stray drop, a speck the model left on the green). Saved as lossless WebP
## with `--margin` px around the drawing.
##
##   godot --headless --path momonium --script res://tools/art/gen/key_sprite.gd -- \
##     --in /abs/front_idle.png --out res://assets/src/png/momo/front_idle.webp [--keep 0.01] [--margin 4] [--max 512]

const Key := preload("res://tools/art/gen/key_output.gd")


func _init() -> void:
	var args := {}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var img := Image.load_from_file(String(args["in"]))
	img.convert(Image.FORMAT_RGBA8)
	Key.key(img)
	var kept := keep_character(img, float(args.get("keep", "0.01")))
	var box := opaque_box(img)
	var margin := int(args.get("margin", "4"))
	var r := box.grow(margin).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var cut := img.get_region(r)
	# Sources are kept at most `--max` px tall (the sheet's cells are 256):
	# the full-size originals stay on the TopView board under their file ids.
	var max_h := int(args.get("max", "512"))
	if cut.get_height() > max_h:
		var k := float(max_h) / cut.get_height()
		cut.resize(maxi(1, roundi(cut.get_width() * k)), max_h, Image.INTERPOLATE_LANCZOS)
	var out := String(args["out"])
	var path := ProjectSettings.globalize_path(out) if out.begins_with("res://") else out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	cut.save_webp(path, false)
	print("key_sprite: %s -> %s %dx%d (pieces kept %d of %d)" % [String(args["in"]).get_file(), out, cut.get_width(), cut.get_height(), kept.x, kept.y])
	quit()


## Clears every opaque piece smaller than `keep` x the largest; returns
## (pieces kept, pieces found).
static func keep_character(img: Image, keep: float) -> Vector2i:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	var sizes: Array[int] = [0]
	for start in w * h:
		if label[start] != 0 or img.get_pixel(start % w, start / w).a <= 0.1:
			continue
		var id := sizes.size()
		var n := 0
		var stack: Array[int] = [start]
		label[start] = id
		while not stack.is_empty():
			var i: int = stack.pop_back()
			n += 1
			var x := i % w
			var y := i / w
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
				if j >= 0 and label[j] == 0 and img.get_pixel(j % w, j / w).a > 0.1:
					label[j] = id
					stack.append(j)
		sizes.append(n)
	var largest := 0
	for s: int in sizes:
		largest = maxi(largest, s)
	var kept := 0
	for id in range(1, sizes.size()):
		if sizes[id] >= int(largest * keep):
			kept += 1
	for i in w * h:
		if label[i] != 0 and sizes[label[i]] < int(largest * keep):
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))
	return Vector2i(kept, sizes.size() - 1)


static func opaque_box(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.1:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)
