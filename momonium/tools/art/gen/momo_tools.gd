extends Node2D

## Steps 66-67: Momo at every job, drawn by the real MomoRig from the work
## atlas -- the gallery of design/MOMO_TOOLS.md. One row per job: the front
## standing Momo (faded, the size every frame must keep: the head and the
## feet line up), then the job's frames in the order they play, facing left
## as Momo does at work, on a grass swatch.
##   tools/capture.gd -- --scene res://tools/art/gen/momo_tools.tscn --size 1000x1500
## `MOMO_TOOLS_ZOOM` sets the magnification (1.0 = the island at zoom 1).

## [label, work pose, stage actions]
const JOBS := [
	["sow", "sow", "farm: sow"], ["water", "water", "farm: water"], ["harvest", "harvest", "farm: harvest"],
	["dig", "dig", "mine: dig"], ["chop", "chop", "lumberyard: chop"], ["replant", "replant", "lumberyard: replant"],
	["study", "study", "lab: study"], ["hammer", "hammer", "smelter, car factory"], ["stoke", "stoke", "steam engine: stoke"],
	["write", "write", "game studio"],
]


func _ready() -> void:
	var zoom := float(OS.get_environment("MOMO_TOOLS_ZOOM")) if OS.get_environment("MOMO_TOOLS_ZOOM") != "" else 1.2
	var font := ThemeDB.fallback_font
	var paper := ColorRect.new()
	paper.color = Color("#f4efe4")
	paper.size = Vector2(6000, 6000)
	add_child(paper)
	var sheet := MomoSheet.shared()
	var cw := 190.0 * zoom / 1.4
	var ch := 145.0 * zoom / 1.4
	for i in JOBS.size():
		var job: Array = JOBS[i]
		var anim := "work_" + String(job[1])
		var frames: Array = sheet.frames(anim)
		var y := ch * 0.95 + i * ch
		var swatch := ColorRect.new()
		swatch.color = Color("#9ccf5a")
		swatch.position = Vector2(20, y - 8)
		swatch.size = Vector2(cw * (frames.size() + 1) + 10, 30 * zoom / 1.4)
		add_child(swatch)
		for k in frames.size() + 1:
			var rig := MomoRig.new()
			rig.setup(null, 7)
			rig.set_state("idle" if k == 0 else "work")
			rig.face(Vector2(0.4, 1) if k == 0 else Vector2(-1, -0.4))
			rig.work_pose = String(job[1])
			rig.position = Vector2(20 + cw * (k + 0.5), y)
			add_child(rig)
			rig.set_process(false)
			rig.scale = Vector2(rig.scale.x * zoom, zoom)
			rig.tick(0.0)
			if k > 0:
				# The middle of frame k-1 of the loop.
				var timed: Array = sheet.animations[anim].get("durations", [])
				var t := 0.0
				for n in k - 1:
					t += float(timed[n])
				rig.set("_loop_t", t + float(timed[k - 1]) * 0.5)
				rig.tick(0.0)
			else:
				rig.modulate = Color(1, 1, 1, 0.55)
		var label := Label.new()
		label.text = "%s  (%s)" % [job[0], job[2]]
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", maxi(11, int(15 * zoom / 1.4)))
		label.add_theme_color_override("font_color", Color("#23324a"))
		label.position = Vector2(24, y + 22 * zoom / 1.4)
		add_child(label)
