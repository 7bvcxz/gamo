extends SceneTree

## Step 46: sprites side by side on a light ground, for before/after sheets:
## an .svg path is rasterised at `--scale`, a .png used as it is.
##   godot --headless --path momonium --script res://tools/art/gen/sprite_grid.gd -- \
##     --out /abs/grid.png --cols 3 --cell 300 [--scale 2] a.svg b.png ...


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var out := ""
	var cols := 3
	var cell := 300
	var scale := 2.0
	var files: Array[String] = []
	var i := 0
	while i < raw.size():
		match raw[i]:
			"--out": out = raw[i + 1]; i += 2
			"--cols": cols = int(raw[i + 1]); i += 2
			"--cell": cell = int(raw[i + 1]); i += 2
			"--scale": scale = float(raw[i + 1]); i += 2
			_: files.append(raw[i]); i += 1
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#e8f1f6"))
	for k in files.size():
		var img := Image.new()
		if files[k].ends_with(".svg"):
			img.load_svg_from_string(FileAccess.get_file_as_string(files[k]), scale)
		else:
			img = Image.load_from_file(files[k])
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(img.get_used_rect())
		var s := minf(1.0, minf(cell * 0.92 / img.get_width(), cell * 0.92 / img.get_height()))
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((k % cols) * cell + (cell - img.get_width()) / 2, (k / cols) * cell + cell - img.get_height() - int(cell * 0.04))
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(out)
	quit()
