extends SceneTree

## A grid of screenshots for the Step 50 report: one row per blind run, one
## column per moment (the screenshot the player saw nearest to it), shrunk
## and saved as one JPG -- the evidence of a round without a hundred files.
##
##   godot --headless --path momonium --script res://tools/balance_optimizer/grid.gd -- \
##     --out /abs/grid.jpg --cell 150 --times 10,60,150,300,450,590 RUN1 RUN2 RUN3


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var out := ""
	var cell_w := 150
	var times: Array[float] = [10.0, 60.0, 150.0, 300.0, 450.0, 590.0]
	var runs: Array[String] = []
	var i := 0
	while i < raw.size():
		match raw[i]:
			"--out": out = raw[i + 1]; i += 2
			"--cell": cell_w = int(raw[i + 1]); i += 2
			"--times":
				times.clear()
				for t: String in raw[i + 1].split(","):
					times.append(float(t))
				i += 2
			_:
				runs.append(raw[i]); i += 1
	var cell_h := int(round(cell_w * 1290.0 / 600.0))
	var gap := 6
	var sheet := Image.create(gap + times.size() * (cell_w + gap), gap + runs.size() * (cell_h + gap), false, Image.FORMAT_RGB8)
	sheet.fill(Color("#1d2633"))
	for r in runs.size():
		var shots := _shots(runs[r])
		for c in times.size():
			var file := _nearest(shots, times[c])
			if file == "":
				continue
			var img := Image.load_from_file(runs[r].path_join("player/shots").path_join(file))
			if img == null:
				continue
			img.convert(Image.FORMAT_RGB8)
			img.resize(cell_w, cell_h, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, cell_w, cell_h), Vector2i(gap + c * (cell_w + gap), gap + r * (cell_h + gap)))
	sheet.save_jpg(out, 0.8)
	print("grid: %s (%d runs x %d moments)" % [out, runs.size(), times.size()])
	quit(0)


## [[session seconds, shot file], ...] from the run's action log.
func _shots(run: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(run.path_join("controller/actions.jsonl"), FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var a: Variant = JSON.parse_string(line)
		if typeof(a) == TYPE_DICTIONARY and (a as Dictionary).has("shot"):
			out.append([float(a["t"]), String(a["shot"])])
	return out


func _nearest(shots: Array, t: float) -> String:
	var best := ""
	var d := INF
	for s: Array in shots:
		if absf(float(s[0]) - t) < d:
			d = absf(float(s[0]) - t)
			best = String(s[1])
	return best
