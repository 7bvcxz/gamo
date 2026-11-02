extends SceneTree

## Puts the six experiments' pictures side by side for the comparison page:
## a column per experiment (A, C, F first), a row per moment (5 s, 1:00, 3:00),
## labelled, rendered in a real window (Xvfb) and saved as one image.
##
##   xvfb-run -a godot --path momonium/experiments --script res://tools/compare_grid.gd -- <dir of id_tag.png> <out.png>

const ORDER := ["island", "rock", "tree", "evolution", "harvest", "tycoon"]
const TAGS := [["0", "5 s"], ["1m", "1:00"], ["3m", "3:00"]]
const CELL := Vector2(270, 480)

var _frames := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src := args[0]
	var w := int(CELL.x * ORDER.size() + 10 * (ORDER.size() + 1) + 70)
	var h := int(CELL.y * TAGS.size() + 10 * (TAGS.size() + 1) + 60)
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var bg := ColorRect.new()
	bg.color = Color("#e8f4fb")
	bg.size = Vector2(w, h)
	root.add_child(bg)
	var font: Font = load("res://shared/fonts/ui_ko.otf")
	for c in ORDER.size():
		var e := LabRegistry.find(ORDER[c])
		var head := Label.new()
		head.text = "%s · %s" % [e["letter"], e["title"]]
		head.add_theme_font_override("font", font)
		head.add_theme_font_size_override("font_size", 24)
		head.add_theme_color_override("font_color", Color("#2b3a4a"))
		head.position = Vector2(70 + 10 + c * (CELL.x + 10), 14)
		root.add_child(head)
		for r in TAGS.size():
			var img := Image.load_from_file("%s/%s_%s.png" % [src, ORDER[c], TAGS[r][0]])
			var tex := TextureRect.new()
			tex.texture = ImageTexture.create_from_image(img)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex.position = Vector2(70 + 10 + c * (CELL.x + 10), 50 + 10 + r * (CELL.y + 10))
			tex.size = CELL
			root.add_child(tex)
	for r in TAGS.size():
		var tag := Label.new()
		tag.text = TAGS[r][1]
		tag.add_theme_font_override("font", font)
		tag.add_theme_font_size_override("font_size", 26)
		tag.add_theme_color_override("font_color", Color("#2b3a4a"))
		tag.position = Vector2(8, 50 + 10 + r * (CELL.y + 10) + CELL.y * 0.45)
		root.add_child(tag)
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames < 5:
		return
	process_frame.disconnect(_tick)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	quit()
