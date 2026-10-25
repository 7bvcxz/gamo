extends SceneTree

## Step 46: how far a generated image drifted from its input -- bounding box
## and bottom tip (the ground pivot) of the non-key pixels in each.
##   godot --headless --path momonium --script res://tools/art/gen/align_report.gd -- in.png out.png ...pairs


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i + 1 < a.size():
		var bi := _box(a[i])
		var bo := _box(a[i + 1])
		print("%-22s in %s  out %s  d_pos %s d_size %s" % [a[i].get_file(), bi, bo, bo.position - bi.position, bo.size - bi.size])
		i += 2
	quit()


static func _box(path: String) -> Rect2i:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	var lo := Vector2i(100000, 100000)
	var hi := Vector2i(-1, -1)
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.g - maxf(c.r, c.b) > 0.5 and c.r < 0.5 and c.b < 0.5:
				continue
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo, hi - lo)
