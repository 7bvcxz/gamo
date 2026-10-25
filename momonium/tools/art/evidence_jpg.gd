extends SceneTree

## Shrinks evidence screenshots for committing: every PNG in a directory
## becomes a half-size JPG (quality 0.82) and the PNG is removed.
##
##   godot --headless --path momonium --script res://tools/art/evidence_jpg.gd -- <dir>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <directory>")
		quit(1)
		return
	var dir := String(args[0])
	var n := 0
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".png"):
			continue
		var img := Image.load_from_file(dir.path_join(file))
		if img == null:
			continue
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		img.save_jpg(dir.path_join(file.get_basename() + ".jpg"), 0.82)
		DirAccess.remove_absolute(dir.path_join(file))
		n += 1
	print("evidence_jpg: %d images" % n)
	quit(0)
