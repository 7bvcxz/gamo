extends SceneTree

const ManifestJson := preload("res://tools/art/gen/manifest_json.gd")

## Step 52: after a redraw keyed into a frame with headroom (render_input.gd
## --headroom), the sprite's pivots move down by the headroom -- the ground
## did not move, the frame grew above it -- and `top` (where rings and labels
## sit) moves to the new drawing's real top.
##   godot --headless --path momonium --script res://tools/art/gen/repivot.gd -- <sprite> <headroom>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var name := a[0]
	var head := float(a[1])
	var path := "res://assets/sprites.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var spec: Dictionary = manifest["sprites"][name]
	var scale := float(spec.get("scale", 1.0))
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/src/" + String(spec["source"])))
	img.convert(Image.FORMAT_RGBA8)
	var top := img.get_height()
	for y in img.get_height():
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.5:
				top = y
				break
		if top < img.get_height():
			break
	for p: String in spec["pivots"]:
		var v: Array = spec["pivots"][p]
		v[1] = float(v[1]) + head
	spec["headroom"] = float(spec.get("headroom", 0.0)) + head
	if spec["pivots"].has("top"):
		spec["pivots"]["top"][1] = snappedf(top / scale, 0.1)
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_string(ManifestJson.dump(manifest) + "\n")
	f.close()
	print("repivot: %s +%.0f, pivots %s" % [name, head, spec["pivots"]])
	quit()

