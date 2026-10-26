extends SceneTree

## Step 46: cuts a generated prop sheet (props on chroma green) into one
## transparent png per prop, in reading order (rows top to bottom, then left
## to right), each trimmed with a small margin and scaled to `--height` px for
## the tallest. Names come from `--names a,b,c`.
##
##   godot --headless --path momonium --script res://tools/art/gen/split_props.gd -- \
##     --in /abs/sheet.png --names bush,bush_flowers,... --out res://assets/src/png/ [--px 0.25]
## Step 52: `--rows 4 --prefix "" --square 128` cuts an icon sheet instead:
## names used as they are, each icon centred in a square of that many px;
## `--cols 4` treats the sheet as a strict grid (pieces in a cell are one icon).

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
	var rows := float(args.get("rows", "2"))
	if args.has("cols"):
		# A strict grid: every blob joins the others in its cell (a watering
		# can's drops, a seed bag's seeds are pieces of one icon).
		var cols := float(args["cols"])
		var cells := {}
		for r in boxes:
			var c := r.get_center()
			var key := Vector2i(int(c.x / (img.get_width() / cols)), int(c.y / (img.get_height() / rows)))
			cells[key] = (cells[key] as Rect2i).merge(r) if cells.has(key) else r
		boxes.assign(cells.values())
	var prefix := String(args.get("prefix", "prop_"))
	var square := int(args.get("square", "0"))
	boxes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		var ra := int((a.position.y + a.size.y / 2) / (img.get_height() / rows))
		var rb := int((b.position.y + b.size.y / 2) / (img.get_height() / rows))
		return ra < rb or (ra == rb and a.position.x < b.position.x))
	if boxes.size() != names.size():
		push_error("split_props: found %d props, expected %d" % [boxes.size(), names.size()])
		quit(1)
		return
	var px := float(args.get("px", "0.5"))
	for i in boxes.size():
		var r := boxes[i].grow(4).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var cut := img.get_region(r)
		if square > 0:
			var k := square * 0.94 / maxf(cut.get_width(), cut.get_height())
			cut.resize(maxi(1, roundi(cut.get_width() * k)), maxi(1, roundi(cut.get_height() * k)), Image.INTERPOLATE_LANCZOS)
			var sq := Image.create(square, square, false, Image.FORMAT_RGBA8)
			sq.blit_rect(cut, Rect2i(Vector2i.ZERO, cut.get_size()), (Vector2i(square, square) - cut.get_size()) / 2)
			cut = sq
		else:
			cut.resize(maxi(1, roundi(cut.get_width() * px)), maxi(1, roundi(cut.get_height() * px)), Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(String(args["out"]).path_join("%s%s.png" % [prefix, names[i]]))
		cut.save_png(path)
		print("split_props: %s%s %dx%d" % [prefix, names[i], cut.get_width(), cut.get_height()])
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
