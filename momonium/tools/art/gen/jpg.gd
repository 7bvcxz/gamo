extends SceneTree

## Step 51: one image -> a full-size JPG for the design notes (evidence_jpg.gd
## halves; a contact sheet needs every pixel).
##   godot --headless --path momonium --script res://tools/art/gen/jpg.gd -- <in.png> <out.jpg> [quality]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(a[1], float(a[2]) if a.size() > 2 else 0.88)
	quit()
