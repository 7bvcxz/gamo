extends SceneTree

## Step 62: the loading screen's Momo -- the game's own front-standing Momo
## (assets/src/png/momo_front.png) at `--height` pixels, as WebP, written as
## a data URI between the markers in web/shell.html (the splash needs no
## request of its own, so it shows at the first paint).
##
##   godot --headless --path momonium --script res://tools/web/splash_art.gd -- [--height 132]

const SRC := "res://assets/src/png/momo_front.png"
const SHELL := "res://web/shell.html"
const BEGIN := "/*momo:begin*/"
const END := "/*momo:end*/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var height := 132
	var i := args.find("--height")
	if i >= 0 and i + 1 < args.size():
		height = int(args[i + 1])
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null or img.is_empty():
		push_error("no source image")
		quit(1)
		return
	var used := img.get_used_rect()
	img = img.get_region(used)
	img.resize(int(round(img.get_width() * float(height) / img.get_height())), height, Image.INTERPOLATE_LANCZOS)
	var bytes := img.save_webp_to_buffer(true, 0.85)
	var uri := "data:image/webp;base64," + Marshalls.raw_to_base64(bytes)
	var path := ProjectSettings.globalize_path(SHELL)
	var html := FileAccess.get_file_as_string(path)
	var a := html.find(BEGIN)
	var b := html.find(END)
	if a < 0 or b < a:
		push_error("markers missing in shell.html")
		quit(1)
		return
	html = html.substr(0, a + BEGIN.length()) + "url(" + uri + ")" + html.substr(b)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(html)
	f.close()
	print("splash_art: %dx%d, %d bytes (%d as base64)" % [img.get_width(), img.get_height(), bytes.size(), uri.length()])
	quit(0)
