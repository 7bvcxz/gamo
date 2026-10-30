class_name MomoCalibration
extends Node2D

## Step 76: the Momo calibration gallery (design/MOMO_ANCHORS.md). The real
## MomoRig stands on a real island tile with its root -- the node's origin,
## where the simulation puts a Momo -- fixed on the tile's centre, and plays
## any animation the rig has, frame by frame. A red cross marks the root; the
## measured feet (white), torso (blue) and eyes (violet) of the frame on show
## come from the map (MomoSheet.marks). A drawing that stands on its root
## keeps its feet on the cross through every frame and every change.
##
## Run the scene (scenes/dev/momo_calibration.tscn):
##   Left / Right   previous / next frame (pauses)    Up / Down  animation
##   Space          play / pause                       M          markers
##   O              onion skin: every frame of the animation at once, faded
##   F              face left (the mirror) / right     Z / X      zoom in / out
## Capture it as a contact sheet (tools/capture.gd, MOMO_CAL=work or states):
## one row per animation, its frames in play order, each on its own tile,
## and the onion skin last.
##   MOMO_CAL=work xvfb-run -a godot --path momonium --script res://tools/capture.gd -- \
##     --scene res://scenes/dev/momo_calibration.tscn --size 1180x2440 --out /abs/work.png
## It sets frames through the rig's own clock and reads the maps as files, so
## the same scene shows any build's rig and maps as they are (Step 76's
## before and after).

## [label, state, facing, work pose, mood pose]
const STATES := [
	["idle front", "idle", Vector2(0.5, 1), "", ""], ["idle back (waiting at work)", "idle", Vector2(-1, -0.4), "", ""],
	["idle side", "idle", Vector2(1, 0), "", ""], ["walk front", "walk", Vector2(0.5, 1), "", ""],
	["walk back", "walk", Vector2(0.3, -1), "", ""], ["walk side", "walk", Vector2(1, 0), "", ""],
	["sit", "sit", Vector2(0.5, 1), "", ""], ["sleep", "sleep", Vector2(0.5, 1), "", ""],
	["happy", "idle", Vector2(0.5, 1), "", "happy"], ["waiting", "idle", Vector2(0.5, 1), "", "waiting"],
	["confused", "idle", Vector2(0.5, 1), "", "confused"], ["carry", "work", Vector2(0.5, 1), "carry", ""],
	["work, no job pose", "work", Vector2(-1, -0.4), "", ""],
]
const JOBS: PackedStringArray = ["sow", "water", "harvest", "dig", "chop", "replant", "study", "hammer", "stoke", "write"]
const TILE := Color("#8cc45a")
const TILE_EDGE := Color("#5e9a3c")

var sheet: MomoSheet
var maps := {}
var specs: Array = []
var index := 0
var frame := 0
var playing := true
var marks_on := true
var onion := false
var facing_left := true
var zoom := 3.0
var rig: MomoRig
var ghosts: Array[MomoRig] = []
var label: Label
var camera: Camera2D
var _proj: IsoProjection
var _sim: Simulation
var _cell_px := Vector2(128, 64)
var _overlay: _Overlay


func _ready() -> void:
	# One pixel to a pixel (the project's stretch is for the game's HUD).
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	sheet = MomoSheet.shared()
	for path: String in [MomoSheet.MAP, MomoSheet.WORK_MAP]:
		if FileAccess.file_exists(path):
			var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			for e: Dictionary in m.get("cells", []) + m.get("frames", []):
				maps[String(e["name"])] = e
	for s: Array in STATES:
		specs.append(s)
	for job: String in JOBS:
		if sheet.animations.has("work_" + job):
			specs.append([job, "work", Vector2(-1, -0.4), job, ""])
	_sim = Simulation.new_game()
	_proj = IsoProjection.from_data(_sim.data)
	var c0 := _proj.cell_corners(Vector2i.ZERO)
	_cell_px = Vector2(absf(c0[1].x - c0[3].x), absf(c0[2].y - c0[0].y))
	var mode := OS.get_environment("MOMO_CAL")
	if mode in ["work", "states"]:
		_contact_sheet(mode)
		return
	var island := IslandRenderer.new()
	add_child(island)
	island.setup(_sim, _proj)
	rig = MomoRig.new()
	rig.setup(null, 7)
	rig.position = _proj.cell_center(Vector2i.ZERO)
	add_child(rig)
	_overlay = _Overlay.new()
	_overlay.gallery = self
	add_child(_overlay)
	camera = Camera2D.new()
	camera.position = rig.position + Vector2(0, -30)
	add_child(camera)
	var hud := CanvasLayer.new()
	add_child(hud)
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_color_override("font_color", Color("#1d2a3a"))
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	hud.add_child(label)
	_show()


func _unhandled_input(event: InputEvent) -> void:
	if rig == null or not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_RIGHT:
			playing = false
			frame = (frame + 1) % _count()
		KEY_LEFT:
			playing = false
			frame = (frame - 1 + _count()) % _count()
		KEY_DOWN:
			index = (index + 1) % specs.size()
			frame = 0
		KEY_UP:
			index = (index - 1 + specs.size()) % specs.size()
			frame = 0
		KEY_SPACE:
			playing = not playing
		KEY_M:
			marks_on = not marks_on
		KEY_O:
			onion = not onion
		KEY_F:
			facing_left = not facing_left
		KEY_Z:
			zoom = minf(zoom * 1.25, 8.0)
		KEY_X:
			zoom = maxf(zoom / 1.25, 1.0)
	_show()


func _process(delta: float) -> void:
	if rig == null:
		return
	camera.zoom = Vector2(zoom, zoom)
	if playing:
		rig.tick(delta)
	_label()
	_overlay.queue_redraw()


## The frames of `spec`'s animation in play order, each once (a blink last).
func frames_of(spec: Array, probe: MomoRig) -> Array:
	_dress(probe, spec)
	var anim := probe.animation()
	var out: Array = []
	for n: Variant in sheet.frames(anim):
		if not out.has(n):
			out.append(n)
	var blink := String(sheet.animations.get(anim, {}).get("blink", ""))
	if blink != "":
		out.append(blink)
	return out


func _count() -> int:
	return maxi(1, frames_of(specs[index], rig).size())


func _dress(r: MomoRig, spec: Array) -> void:
	r.set_state(String(spec[1]))
	r.work_pose = String(spec[3])
	r.mood_pose = String(spec[4])
	var f: Vector2 = spec[2]
	if f.x != 0.0:
		f.x = -absf(f.x) if facing_left else absf(f.x)
	r.face(f)


## Holds `r` at frame `i` of `spec`'s animation, through the rig's own clock
## (the `tick` the island runs): a job's loop at the middle of that frame, a
## walk at that step, a blink held shut.
func hold(r: MomoRig, spec: Array, i: int) -> void:
	var once := frames_of(spec, r)
	var anim := r.animation()
	var cells := sheet.frames(anim)
	var timed: Array = sheet.animations.get(anim, {}).get("durations", [])
	i = clampi(i, 0, once.size() - 1)
	if cells.size() > 1 and timed.size() == cells.size():
		var t := 0.0
		for n in i:
			t += float(timed[n])
		r.set("_loop_anim", anim)
		r.set("_loop_t", t + float(timed[i]) * 0.5)
	elif cells.size() > 1:
		r.time = (cells.find(once[i]) + 0.5) / maxf(sheet.fps(anim) * r.walk_speed, 0.001)
	var blink := cells.size() == 1 and i == 1
	r.blinking = blink
	r.set("_blink_until", r.time + 1.0)
	r.set("_next_blink", r.time + 10.0)
	r.tick(0.0)


func _show() -> void:
	for g in ghosts:
		g.queue_free()
	ghosts.clear()
	if onion:
		var n := frames_of(specs[index], rig).size()
		for i in n:
			var g := MomoRig.new()
			g.setup(null, 7)
			g.position = rig.position
			g.modulate = Color(1, 1, 1, 0.3)
			add_child(g)
			# After add_child: entering the tree turns processing back on.
			g.set_process(false)
			hold(g, specs[index], i)
			ghosts.append(g)
	hold(rig, specs[index], frame)
	_label()
	_overlay.queue_redraw()


func _label() -> void:
	var once := frames_of(specs[index], rig)
	var cell := rig.cell_name()
	var method := String((maps.get(cell, {}) as Dictionary).get("root", "?"))
	label.text = "%s   frame %d/%d  %s   root: %s%s\n←/→ frame  ↑/↓ animation  Space %s  M marks  O onion  F flip  Z/X zoom" % [
		specs[index][0], once.find(cell) + 1, once.size(), cell, method,
		"" if method in ["feet", "head", "?"] else " (authored)", "pause" if playing else "play"]


## A point of the frame `r` shows (from its rect's top-left) in `r`'s
## parent's space -- through the body's offset, scale and bob, and the rig's
## mirror: where the drawing puts it on the island.
static func to_parent(r: MomoRig, p: Vector2) -> Vector2:
	return r.transform * (r.body.position + r.body.scale * (p + r.body.offset))


static func cross(ci: CanvasItem, at: Vector2, size: float, width: float) -> void:
	ci.draw_line(at - Vector2(size, 0), at + Vector2(size, 0), Color(0.9, 0.1, 0.1), width)
	ci.draw_line(at - Vector2(0, size), at + Vector2(0, size), Color(0.9, 0.1, 0.1), width)


## The measured marks of the frame `r` shows: feet (white), torso (blue),
## eyes (violet), `px` the size of a screen pixel.
static func marks(ci: CanvasItem, r: MomoRig, maps: Dictionary, px: float) -> void:
	var e: Dictionary = maps.get(r.cell_name(), {})
	for f: Array in e.get("feet", []):
		var p := to_parent(r, Vector2(float(f[0]), float(f[1])))
		ci.draw_circle(p, 3.5 * px, Color(0.1, 0.1, 0.1))
		ci.draw_circle(p, 2.4 * px, Color.WHITE)
	if e.has("torso"):
		ci.draw_circle(to_parent(r, Vector2(float(e["torso"][0]), float(e["torso"][1]))), 3.0 * px, Color(0.15, 0.35, 0.95))
	if e.has("eyes"):
		ci.draw_circle(to_parent(r, Vector2(float(e["eyes"][0]), float(e["eyes"][1]))), 3.0 * px, Color(0.6, 0.2, 0.85))


## The contact sheet: every animation of `mode` (the jobs, or the sheet's
## states) as a row of its frames, each on its own tile, the onion skin
## last, at 2x the island at zoom 1.
func _contact_sheet(mode: String) -> void:
	var rows: Array = specs.filter(func(s: Array) -> bool: return (String(s[1]) == "work" and String(s[3]) in JOBS) == (mode == "work"))
	var k := 2.0
	var cw := 200.0
	var ch := 236.0
	var paper := ColorRect.new()
	paper.color = Color("#f2efe6")
	paper.size = Vector2(4000, 6000)
	add_child(paper)
	var probe := MomoRig.new()
	probe.setup(null, 7)
	var title := Label.new()
	title.text = "Momo %s %s\nred cross: the root, where the simulation stands Momo -- white: feet, blue: torso, violet: eyes -- last column: every frame at once" % [
		"at work" if mode == "work" else "states", OS.get_environment("MOMO_CAL_LABEL")]
	title.position = Vector2(12, 6)
	title.add_theme_color_override("font_color", Color("#1d2a3a"))
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)
	for row in rows.size():
		var spec: Array = rows[row]
		var names := frames_of(spec, probe)
		var y := 56.0 + ch * (row + 0.8)
		var name_label := Label.new()
		name_label.text = String(spec[0])
		name_label.position = Vector2(12, y - ch * 0.42)
		name_label.add_theme_color_override("font_color", Color("#1d2a3a"))
		name_label.add_theme_font_size_override("font_size", 15)
		add_child(name_label)
		for col in names.size() + 1:
			var at := Vector2(150.0 + cw * (col + 0.5), y)
			var tile := _Tile.new()
			tile.size = _cell_px * k * 0.62
			tile.position = at
			add_child(tile)
			var all: Array = range(names.size()) if col == names.size() else [col]
			for i: int in all:
				var r := MomoRig.new()
				r.setup(null, 7)
				r.position = at
				add_child(r)
				# After add_child: entering the tree turns processing back on.
				r.set_process(false)
				hold(r, spec, i)
				# `face` set the mirror; the size goes on top of it.
				r.scale = Vector2(r.scale.x * k, k)
				if col == names.size():
					r.modulate = Color(1, 1, 1, 0.35)
					continue
				var cap := Label.new()
				var method := String((maps.get(r.cell_name(), {}) as Dictionary).get("root", ""))
				cap.text = r.cell_name() + ("  " + method if method != "" else "")
				cap.position = at + Vector2(-cw * 0.46, 18)
				cap.add_theme_color_override("font_color", Color("#55606e"))
				cap.add_theme_font_size_override("font_size", 11)
				add_child(cap)
				var m := _Marks.new()
				m.rig = r
				m.maps = maps
				add_child(m)
			var c := _Cross.new()
			c.position = at
			add_child(c)
	probe.free()


## The interactive view's marks and cross, over the island and the rig.
class _Overlay:
	extends Node2D
	var gallery: MomoCalibration

	func _ready() -> void:
		z_index = 10

	func _draw() -> void:
		var px := 1.0 / gallery.zoom
		if gallery.marks_on:
			MomoCalibration.marks(self, gallery.rig, gallery.maps, px)
		MomoCalibration.cross(self, gallery.rig.position, 10.0 * px, 2.0 * px)


## A flat island tile under a contact-sheet Momo.
class _Tile:
	extends Node2D
	var size := Vector2(80, 40)

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, -size.y / 2), Vector2(size.x / 2, 0), Vector2(0, size.y / 2), Vector2(-size.x / 2, 0)])
		draw_colored_polygon(pts, MomoCalibration.TILE)
		pts.append(pts[0])
		draw_polyline(pts, MomoCalibration.TILE_EDGE, 1.5, true)


class _Cross:
	extends Node2D

	func _ready() -> void:
		z_index = 10

	func _draw() -> void:
		MomoCalibration.cross(self, Vector2.ZERO, 9.0, 2.0)


class _Marks:
	extends Node2D
	var rig: MomoRig
	var maps: Dictionary

	func _ready() -> void:
		z_index = 9

	func _draw() -> void:
		MomoCalibration.marks(self, rig, maps, 1.0)
