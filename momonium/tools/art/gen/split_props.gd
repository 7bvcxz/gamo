extends SceneTree

## Step 46: cuts a generated prop sheet (props on chroma green) into one
## transparent png per prop, in reading order (rows top to bottom, then left
## to right), each trimmed with a small margin and scaled to `--height` px for
## the tallest. Names come from `--names a,b,c`.
##
##   godot --headless --path momonium --script res://tools/art/gen/split_props.gd -- \
##     --in /abs/sheet.png --names bush,bush_flowers,... --out res://assets/src/png/ [--px 0.25]

const KeyOutput := preload("res://tools/art/gen/key_output.gd")


func _init() -> void:
	var args := {}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var img := Image.load_from_file(args["in"])
	img.convert(Image.FORMAT_RGBA8)
	KeyOutput.key(img)
	var names: PackedStringArray = String(args["names"]).split(",")
	var boxes := _components(img, 400)
	boxes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		var ra := int((a.position.y + a.size.y / 2) / (img.get_height() / 2.0))
		var rb := int((b.position.y + b.size.y / 2) / (img.get_height() / 2.0))
		return ra < rb or (ra == rb and a.position.x < b.position.x))
	if boxes.size() != names.size():
		push_error("split_props: found %d props, expected %d" % [boxes.size(), names.size()])
		quit(1)
		return
	var px := float(args.get("px", "0.5"))
	for i in boxes.size():
		var r := boxes[i].grow(4).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var cut := img.get_region(r)
		cut.resize(maxi(1, roundi(cut.get_width() * px)), maxi(1, roundi(cut.get_height() * px)), Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(String(args["out"]).path_join("prop_%s.png" % names[i]))
		cut.save_png(path)
		print("split_props: prop_%s %dx%d" % [names[i], cut.get_width(), cut.get_height()])
	quit()


## Bounding boxes of the opaque blobs larger than `min_px` pixels.
static func _components(img: Image, min_px: int) -> Array[Rect2i]:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var out: Array[Rect2i] = []
	for start in w * h:
		if seen[start] == 1 or img.get_pixel(start % w, start / w).a < 0.5:
			continue
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		var count := 0
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % w
			var y := i / w
			count += 1
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			# 8-connected with a 2 px reach, so a flower's petals stay one prop.
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var xx := x + dx
					var yy := y + dy
					if xx < 0 or yy < 0 or xx >= w or yy >= h:
						continue
					var j := yy * w + xx
					if seen[j] == 0 and img.get_pixel(xx, yy).a >= 0.5:
						seen[j] = 1
						stack.append(j)
		if count >= min_px:
			out.append(Rect2i(lo, hi - lo + Vector2i.ONE))
	return out
