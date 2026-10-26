extends SceneTree

## Step 55: rings drawn on a screenshot to point at what changed -- for the
## annotated before/after sheets.
##   godot --headless --path momonium --script res://tools/art/gen/rings.gd -- \
##     <in.png> <out.png> <radius> <#rrggbb> x,y [x,y ...] [crop:x,y,w,h]
## A last `crop:` argument cuts the result to that rectangle (after the rings).

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	var r := float(a[2])
	var col := Color(a[3])
	var crop := Rect2i()
	for k in range(4, a.size()):
		if a[k].begins_with("crop:"):
			var v: PackedStringArray = a[k].trim_prefix("crop:").split(",")
			crop = Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3]))
			continue
		var xy: PackedStringArray = a[k].split(",")
		var c := Vector2(float(xy[0]), float(xy[1]))
		for i in 720:
			var ang := TAU * i / 720.0
			for w in range(-3, 4):
				var p := c + Vector2.from_angle(ang) * (r + w)
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					img.set_pixelv(Vector2i(p), col)
	if crop.size != Vector2i.ZERO:
		img = img.get_region(crop)
	img.save_png(a[1])
	quit()
