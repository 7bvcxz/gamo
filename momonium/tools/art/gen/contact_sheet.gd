extends SceneTree

## Step 46: the art contact sheet -- one row per subject, three columns:
## concept reference | the game before | the game after. Each image is fitted
## into its cell (letterboxed); rows are separated by a thin rule.
##   godot --headless --path momonium --script res://tools/art/gen/contact_sheet.gd -- \
##     --out /abs/sheet.jpg --width 400 --row 711 ref.png old.png new.png --row 300 ...


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var out := ""
	var cell_w := 400
	var rows: Array = []
	var i := 0
	while i < raw.size():
		match raw[i]:
			"--out": out = raw[i + 1]; i += 2
			"--width": cell_w = int(raw[i + 1]); i += 2
			"--row":
				rows.append([int(raw[i + 1]), raw[i + 2], raw[i + 3], raw[i + 4]])
				i += 5
			_: i += 1
	var gap := 8
	var total_h := gap
	for r: Array in rows:
		total_h += int(r[0]) + gap
	var sheet := Image.create(cell_w * 3 + gap * 4, total_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#1d2633"))
	var y := gap
	for r: Array in rows:
		var h := int(r[0])
		for c in 3:
			var img := Image.load_from_file(r[c + 1])
			img.convert(Image.FORMAT_RGBA8)
			var s := minf(float(cell_w) / img.get_width(), float(h) / img.get_height())
			img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
			var x0 := gap + c * (cell_w + gap)
			sheet.fill_rect(Rect2i(x0, y, cell_w, h), Color("#2a3546"))
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x0 + (cell_w - img.get_width()) / 2, y + (h - img.get_height()) / 2))
		y += h + gap
	sheet.convert(Image.FORMAT_RGB8)
	if out.ends_with(".jpg"):
		sheet.save_jpg(out, 0.86)
	else:
		sheet.save_png(out)
	print("contact_sheet: %s %dx%d" % [out, sheet.get_width(), sheet.get_height()])
	quit()
