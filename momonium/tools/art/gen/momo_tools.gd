extends Node2D

## Step 66: Momo at every job with its tool, drawn by the real MomoRig from
## the work atlas -- the gallery of design/MOMO_TOOLS.md. Each job stands
## beside the front standing Momo at the same scale (the head and the feet
## must line up), facing left as Momo does at work, on a grass swatch.
##   tools/capture.gd -- --scene res://tools/art/gen/momo_tools.tscn --size 900x1280
## `MOMO_TOOLS_ZOOM` sets the magnification (1.0 = the island at zoom 1).

## [label, work pose, stage actions]
const JOBS := [
	["sow", "sow", "farm: sow"], ["water", "water", "farm: water"], ["harvest", "harvest", "farm: harvest"],
	["dig", "dig", "mine: dig"], ["chop", "chop", "lumberyard: chop"], ["replant", "replant", "lumberyard: replant"],
	["study", "study", "lab: study"], ["hammer", "hammer", "smelter, car factory"], ["stoke", "stoke", "steam engine: stoke"],
	["write", "write", "game studio"],
]


func _ready() -> void:
	var zoom := float(OS.get_environment("MOMO_TOOLS_ZOOM")) if OS.get_environment("MOMO_TOOLS_ZOOM") != "" else 1.9
	var font := ThemeDB.fallback_font
	var paper := ColorRect.new()
	paper.color = Color("#f4efe4")
	paper.size = Vector2(4000, 4000)
	add_child(paper)
	var cw := 290.0 * zoom / 1.9
	var ch := 250.0 * zoom / 1.9
	for i in JOBS.size():
		var job: Array = JOBS[i]
		var at := Vector2(cw * 0.62 + (i % 3) * cw, ch * 0.9 + (i / 3) * ch)
		var swatch := ColorRect.new()
		swatch.color = Color("#9ccf5a")
		swatch.position = at + Vector2(-cw * 0.46, -8)
		swatch.size = Vector2(cw * 0.92, 40 * zoom / 1.9)
		add_child(swatch)
		for k in 2:
			var rig := MomoRig.new()
			rig.setup(null, 7)
			rig.set_state("idle" if k == 0 else "work")
			rig.face(Vector2(0.4, 1) if k == 0 else Vector2(-1, -0.4))
			rig.work_pose = String(job[1])
			rig.position = at + Vector2(-cw * 0.26 if k == 0 else cw * 0.12, 0)
			add_child(rig)
			rig.set_process(false)
			rig.scale = Vector2(rig.scale.x * zoom, zoom)
			rig.tick(0.4)
			if k == 0:
				rig.modulate = Color(1, 1, 1, 0.55)
		var label := Label.new()
		label.text = "%s  (%s)" % [job[0], job[2]]
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", maxi(11, int(16 * zoom / 1.9)))
		label.add_theme_color_override("font_color", Color("#23324a"))
		label.position = at + Vector2(-cw * 0.46, 34 * zoom / 1.9)
		add_child(label)
