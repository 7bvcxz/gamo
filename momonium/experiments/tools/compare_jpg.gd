extends SceneTree

## The comparison pictures as JPEG: each id_tag.png at 360x640 and grid.png
## as it is.  godot --headless --script res://tools/compare_jpg.gd -- <src> <out>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var d := DirAccess.open(args[0])
	for f: String in d.get_files():
		if not f.ends_with(".png"):
			continue
		var img := Image.load_from_file(args[0].path_join(f))
		img.convert(Image.FORMAT_RGB8)
		if f != "grid.png":
			img.resize(360, 640, Image.INTERPOLATE_LANCZOS)
		img.save_jpg(args[1].path_join(f.get_basename() + ".jpg"), 0.82)
	quit()
