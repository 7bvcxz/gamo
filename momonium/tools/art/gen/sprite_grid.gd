extends SceneTree

## Step 46: sprites side by side on a light ground, for before/after sheets:
## an .svg path is rasterised at `--scale`, a .png used as it is.
##   godot --headless --path momonium --script res://tools/art/gen/sprite_grid.gd -- \
##     --out /abs/grid.png --cols 3 --cell 300 [--scale 2] a.svg b.png ...
## Step 52: `--bg #00ff00 --fit 0.6 --center` lays icons out as an image-edit
## input -- each centred in its cell at `fit` of it, on the key green.


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var out := ""
	var cols := 3
	var cell := 300
	var scale := 2.0
	var files: Array[String] = []
	var bg := Color("#e8f1f6")
	var fit := 0.92
	var center := false
	var i := 0
	while i < raw.size():
		match raw[i]:
			"--out": out = raw[i + 1]; i += 2
			"--cols": cols = int(raw[i + 1]); i += 2
			"--cell": cell = int(raw[i + 1]); i += 2
			"--scale": scale = float(raw[i + 1]); i += 2
			"--bg": bg = Color(raw[i + 1]); i += 2
			"--fit": fit = float(raw[i + 1]); i += 2
			"--center": center = true; i += 1
			_: files.append(raw[i]); i += 1
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(bg)
	for k in files.size():
		var img := Image.new()
		if files[k].ends_with(".svg"):
			img.load_svg_from_string(FileAccess.get_file_as_string(files[k]), scale)
		else:
			img = Image.load_from_file(files[k])
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(img.get_used_rect())
		var s := minf(cell * fit / img.get_width(), cell * fit / img.get_height())
		if not center:
			s = minf(1.0, s)
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((k % cols) * cell + (cell - img.get_width()) / 2, (k / cols) * cell + cell - img.get_height() - int(cell * 0.04))
		if center:
			at.y = (k / cols) * cell + (cell - img.get_height()) / 2
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(out)
	quit()
