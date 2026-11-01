extends SceneTree

## Step 83 (design/HANDS83.md): the player's tools, for the hands drawn over a
## building the player is working. The ten painted tools of Step 66
## (assets/src/png/tools/, the sheet Momo's tool poses were made from) are
## scaled to one height and packed in a row into assets/hands/hand_tools.png;
## assets/hands/hand_tools.json gives each its region, its grip (where the
## glove holds it -- the pivot it turns about) and its tip (where the work
## lands: the spout, the blade, the mouth of the pouch), in atlas pixels.
## Grips and tips are measured on the source drawings (a 25 px grid).
##
##   godot --headless --path momonium --script res://tools/art/gen/build_hand_tools.gd

const SRC := "res://assets/src/png/tools/"
const OUT := "res://assets/hands/hand_tools"
const HEIGHT := 128
const PAD := 4
## tool -> [grip, tip] in source pixels.
const POINTS := {
	"watering_can": [Vector2(22, 40), Vector2(206, 62)],
	"seed_pouch": [Vector2(80, 58), Vector2(78, 22)],
	"basket": [Vector2(95, 14), Vector2(95, 120)],
	"pickaxe": [Vector2(42, 172), Vector2(172, 103)],
	"axe": [Vector2(37, 168), Vector2(160, 110)],
	"trowel": [Vector2(36, 114), Vector2(120, 190)],
	"flask": [Vector2(70, 52), Vector2(70, 18)],
	"hammer": [Vector2(37, 170), Vector2(120, 95)],
	"logs": [Vector2(110, 32), Vector2(100, 150)],
	"notebook": [Vector2(152, 48), Vector2(107, 107)],
}


func _init() -> void:
	var images := {}
	var width := PAD
	for tool: String in POINTS:
		var im := Image.load_from_file(ProjectSettings.globalize_path(SRC + "tool_" + tool + ".png"))
		im.convert(Image.FORMAT_RGBA8)
		images[tool] = im
		width += int(round(im.get_width() * float(HEIGHT) / im.get_height())) + PAD
	var atlas := Image.create(width, HEIGHT + PAD * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var meta := {"_doc": "Step 83: the player's tools (tools/art/gen/build_hand_tools.gd). region [x, y, w, h], grip and tip in atlas pixels; height the drawn height of every tool.", "height": HEIGHT, "tools": {}}
	var x := PAD
	for tool: String in POINTS:
		var im: Image = images[tool]
		var k := float(HEIGHT) / im.get_height()
		var w := int(round(im.get_width() * k))
		var scaled := im.duplicate() as Image
		scaled.resize(w, HEIGHT, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i(x, PAD))
		var grip: Vector2 = POINTS[tool][0] * k
		var tip: Vector2 = POINTS[tool][1] * k
		meta["tools"][tool] = {"region": [x, PAD, w, HEIGHT], "grip": [snappedf(grip.x, 0.1), snappedf(grip.y, 0.1)], "tip": [snappedf(tip.x, 0.1), snappedf(tip.y, 0.1)]}
		x += w + PAD
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/hands"))
	atlas.save_png(ProjectSettings.globalize_path(OUT + ".png"))
	var f := FileAccess.open(OUT + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t") + "\n")
	f.close()
	print("hand tools: %d tools, %dx%d" % [POINTS.size(), atlas.get_width(), atlas.get_height()])
	quit()
