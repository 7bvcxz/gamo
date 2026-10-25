extends SceneTree

## The views' per-frame work on the large demo island (Settings > large
## island demo), counted rather than timed -- a shared or busy machine makes
## frame times noise, while these counts are the same on every machine:
##
##   godot --headless --path momonium --script res://tools/bench/render_bench.gd [-- --check]
##
## For the whole island in view, zoomed in on a corner, and zoomed far out:
## how many nodes still run per-frame code, how many building rings and Momo
## bodies are redrawn in one second at 60 fps, and how many Momo limbs pose.
## "before" is the same island as Step 40 drew it: every ring and every Momo
## redrawn and posed every frame. --check compares with budgets.json.

const FPS := 60
const STAGES := ["fit", "close", "far"]

var _main: Node
var _stage := -1
var _left := 0
var _rings := 0
var _bodies := 0
var _results := {}
var _check := false


func _init() -> void:
	_check = OS.get_cmdline_user_args().has("--check")
	Engine.set_meta("momonium_no_save", true)
	Engine.set_meta("momonium_demo", "large")
	Engine.max_fps = FPS
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	process_frame.connect(_tick)


func _tick() -> void:
	if _stage < 0:
		# One frame in: the scene is ready; count every redraw from here.
		for v: BuildingView in (_main.get("building_views") as BuildingViews).views.values():
			v.ring.draw.connect(func() -> void: _rings += 1)
		for a: MomoActor in (_main.get("momo_views") as MomoViews).actors.values():
			a.draw.connect(func() -> void: _bodies += 1)
		_begin(0)
		return
	_left -= 1
	if _left > 0:
		return
	var momos: MomoViews = _main.get("momo_views")
	var posing := 0
	for a: MomoActor in momos.actors.values():
		if a.rig.is_processing():
			posing += 1 if a.rig.lod_step <= 1 else 0
	_results[STAGES[_stage]] = {"processing": _processing(_main), "rings": _rings, "bodies": _bodies,
		"buildings_awake": (_main.get("building_views") as BuildingViews).active_count(), "momos_awake": momos.awake_count(), "momos_full_rate": posing}
	_stage += 1
	if _stage >= STAGES.size():
		_report()
		return
	_begin(_stage)


func _begin(stage: int) -> void:
	_stage = stage
	var cams: CameraController = _main.get("cameras")
	var size := cams.viewport_size()
	cams.frame_island()
	match STAGES[stage]:
		"close":
			for i in 12:
				cams.zoom_at(1.5, size * 0.5)
		"far":
			for i in 8:
				cams.zoom_at(0.6, size * 0.5)
	# Settle a few frames (culling follows the camera), then count a second.
	_left = FPS + 3
	await process_frame
	await process_frame
	await process_frame
	_rings = 0
	_bodies = 0


func _processing(n: Node) -> int:
	var c := 1 if n.is_processing() else 0
	for ch: Node in n.get_children():
		c += _processing(ch)
	return c


func _report() -> void:
	process_frame.disconnect(_tick)
	var views: BuildingViews = _main.get("building_views")
	var momos: MomoViews = _main.get("momo_views")
	var nb := views.views.size()
	var nm := momos.actors.size()
	print("render: large demo, %d buildings, %d Momo, one second at %d fps" % [nb, nm, FPS])
	print("render: before        rings %5d/s  Momo bodies %5d/s  (every one, every frame)" % [nb * FPS, nm * FPS])
	for k: String in STAGES:
		var r: Dictionary = _results[k]
		print("render: %-6s  rings %5d/s  Momo bodies %5d/s  buildings awake %3d/%d  Momo awake %2d/%d (full rate %d)  nodes processing %d" % [
			k, r["rings"], r["bodies"], r["buildings_awake"], nb, r["momos_awake"], nm, r["momos_full_rate"], r["processing"]])
	var bad := 0
	if _check:
		var b: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://tools/bench/budgets.json")) as Dictionary).get("render", {})
		for k: String in STAGES:
			var limit: Dictionary = b.get(k, {})
			for key: String in limit:
				if int(_results[k][key]) > int(limit[key]):
					print("render: FAIL %s %s %d > budget %d" % [k, key, _results[k][key], limit[key]])
					bad += 1
		print("render: budget %s" % ("OK" if bad == 0 else "FAILED"))
	quit(bad)
