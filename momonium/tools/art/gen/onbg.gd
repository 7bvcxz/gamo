extends SceneTree
## Composites keyed sprites onto a grass-green and a dark strip: -- out.png a.png b.png ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	var imgs: Array[Image] = []
	for i in range(1, a.size()):
		var im := Image.load_from_file(a[i])
		im.convert(Image.FORMAT_RGBA8)
		imgs.append(im)
	var cell := 300
	var sheet := Image.create(cell * imgs.size(), cell * 2, false, Image.FORMAT_RGBA8)
	sheet.fill_rect(Rect2i(0, 0, sheet.get_width(), cell), Color(0.45, 0.68, 0.3))
	sheet.fill_rect(Rect2i(0, cell, sheet.get_width(), cell), Color(0.12, 0.1, 0.14))
	for k in imgs.size():
		var im := imgs[k]
		for row in 2:
			sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(k * cell + (cell - im.get_width()) / 2, row * cell + (cell - im.get_height()) / 2))
	sheet.save_png(out)
	quit()
