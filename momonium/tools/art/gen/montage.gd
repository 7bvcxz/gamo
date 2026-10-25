extends SceneTree
## Tiles images into one sheet: -- --out sheet.png --cols N --cell 256 img1 img2 ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out := ""
	var cols := 4
	var cell := 256
	var files: Array[String] = []
	var i := 0
	while i < a.size():
		match a[i]:
			"--out": out = a[i + 1]; i += 2
			"--cols": cols = int(a[i + 1]); i += 2
			"--cell": cell = int(a[i + 1]); i += 2
			_: files.append(a[i]); i += 1
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.92, 0.92, 0.9))
	for k in files.size():
		var img := Image.load_from_file(files[k])
		img.convert(Image.FORMAT_RGBA8)
		var s := minf(float(cell) / img.get_width(), float(cell) / img.get_height())
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((k % cols) * cell + (cell - img.get_width()) / 2, (k / cols) * cell + (cell - img.get_height()) / 2)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(out)
	print("montage ", out)
	quit()
