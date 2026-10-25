extends SceneTree

## Step 46: draws every pivot of the named sprites onto their painted source
## (red cross) and tiles them -- to see that a redrawn chimney top or rotor
## hub still sits where the code puts smoke and blades.
##   godot --headless --path momonium --script res://tools/art/gen/mark_pivots.gd -- /abs/out.png name ...


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	var cell := 360
	var sheet := Image.create(cell * (a.size() - 1), cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.85, 0.88, 0.9))
	for i in range(1, a.size()):
		var spec: Dictionary = manifest["sprites"][a[i]]
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/src/" + spec["source"]))
		img.convert(Image.FORMAT_RGBA8)
		var sc := float(spec.get("scale", 1.0))
		for pv: String in spec.get("pivots", {}):
			var p: Array = spec["pivots"][pv]
			var c := Vector2i(roundi(float(p[0]) * sc), roundi(float(p[1]) * sc))
			for d in range(-7, 8):
				for t in [-1, 0, 1]:
					for q: Vector2i in [c + Vector2i(d, t), c + Vector2i(t, d)]:
						if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
							img.set_pixelv(q, Color(1, 0, 0) if pv != "origin" else Color(0, 0, 1))
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i - 1) * cell + (cell - img.get_width()) / 2, (cell - img.get_height()) / 2))
	sheet.save_png(a[0])
	quit()
