extends SceneTree

## Measures where each work frame's head is (experiment B's hats sit on it):
## the topmost row with at least MIN_WIDTH opaque texels within HALF texels of
## the face's column (the eyes mark, or the torso's where a bent frame has
## none) -- a tool's handle crossing above is narrower than that. Writes
## lab/art/work_heads.json; tests/unit/test_wear.gd checks it is
## current.
##
##   godot --headless --path momonium/experiments --script res://tools/work_heads.gd

const OUT := "res://lab/art/work_heads.json"
const HALF := 22
const MIN_WIDTH := 12


static func measure() -> Dictionary:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://shared/momo/momo_work.png"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://shared/momo/momo_work.json"))
	var out := {}
	for f: Dictionary in data["frames"]:
		var r: Array = f["rect"]
		var face := float(f["eyes"][0]) if f.has("eyes") else float(f["torso"][0])
		var top := -1
		for y in int(r[3]):
			var n := 0
			for x in range(int(face) - HALF, int(face) + HALF + 1):
				if x < 0 or x >= int(r[2]):
					continue
				if img.get_pixel(int(r[0]) + x, int(r[1]) + y).a > 0.6:
					n += 1
			if n >= MIN_WIDTH:
				top = y
				break
		out[String(f["name"])] = [face, top]
	return out


func _init() -> void:
	var heads := measure()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"_doc": "tools/work_heads.gd: each momo_work frame's head top [x, y] in its rect's texels (the hats of experiment B sit on it).", "heads": heads}, "\t"))
	f.close()
	print("work_heads: %d frames" % heads.size())
	quit()
