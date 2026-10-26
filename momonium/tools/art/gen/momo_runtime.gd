extends Node2D

## Step 51: the runtime rig (MomoRig on the sprite sheet) in every view, walk
## frame, job and mood, magnified on a grass swatch, with labels -- the
## "live" column of the sheet's contact sheet. Capture with
##   tools/capture.gd -- --scene res://tools/art/gen/momo_runtime.tscn --size 720x1280
## Each rig is a real MomoRig posed by the same calls the island makes.

const ZOOM := 1.9
## [label, state, facing, time, work pose, mood pose]
const POSES := [
	["front idle", "idle", Vector2(0.4, 1), 0.4, "", ""], ["front blink", "idle", Vector2(0.4, 1), -1.0, "", ""],
	["left walk", "walk", Vector2(-0.6, 1), 0.05, "", ""], ["right walk", "walk", Vector2(0.6, 1), 0.2, "", ""],
	["back idle", "idle", Vector2(0.3, -1), 0.4, "", ""], ["back walk", "walk", Vector2(-0.3, -1), 0.05, "", ""],
	["side right", "walk", Vector2(1, 0.1), 0.05, "", ""], ["side left", "walk", Vector2(-1, 0.1), 0.3, "", ""],
	["harvest", "work", Vector2(-1, -0.4), 0.4, "harvest", ""], ["water", "work", Vector2(1, 0.3), 0.4, "water", ""],
	["dig", "work", Vector2(1, 0.3), 0.4, "dig", ""], ["study", "work", Vector2(1, 0.3), 0.4, "study", ""],
	["work (back)", "work", Vector2(-1, -0.4), 0.4, "", ""], ["sit", "sit", Vector2(1, 0.5), 0.4, "", ""],
	["sleep", "sleep", Vector2(1, 0.5), 0.4, "", ""], ["happy", "idle", Vector2(1, 0.5), 0.4, "", "happy"],
	["confused", "idle", Vector2(1, 0.5), 0.4, "", "confused"], ["waiting", "idle", Vector2(1, 0.5), 0.4, "", "waiting"],
	["carry", "work", Vector2(1, 0.3), 0.4, "carry", ""],
]


func _ready() -> void:
	var font := ThemeDB.fallback_font
	for i in POSES.size():
		var p: Array = POSES[i]
		var col := i % 4
		var row := i / 4
		var at := Vector2(95 + col * 177, 210 + row * 230)
		var swatch := ColorRect.new()
		swatch.color = Color("#9ccf5a")
		swatch.position = at + Vector2(-80, -8)
		swatch.size = Vector2(160, 40)
		add_child(swatch)
		var rig := MomoRig.new()
		rig.setup(null, 7)
		rig.set_state(String(p[1]))
		rig.face(p[2])
		rig.work_pose = String(p[4])
		rig.mood_pose = String(p[5])
		rig.position = at
		add_child(rig)
		# After entering the tree: a node with _process starts processing
		# when it does, and a blink would end before the picture.
		rig.set_process(false)
		rig.scale = Vector2(rig.scale.x * ZOOM, ZOOM)
		if float(p[3]) < 0.0:
			rig.time = 0.0
			rig.set("_next_blink", 0.0)
			rig.tick(0.01)
		else:
			rig.tick(float(p[3]))
		var label := Label.new()
		label.text = String(p[0])
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("#23324a"))
		label.position = at + Vector2(-70, 36)
		add_child(label)
