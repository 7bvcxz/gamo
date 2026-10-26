class_name AwayView
extends VBoxContainer

## "Welcome back": what the island did while the game was closed, from the
## catch-up's own report (Step 49) -- every number is what the simulation
## ran, nothing estimated:
##   - how long the player was away (the wall clock), and how much of it the
##     island counted (up to the offline ceiling) -- both, when they differ;
##   - money earned, EXP, crops, what else was made, the jobs done and by how
##     many Momo, research finished, letters;
##   - and, when nothing happened in a long absence, a quiet word instead of a
##     table of zeros.
## A small card with Momo and a few sparkles (none with effects off), closed
## with the corner button, a tap outside or Escape. Also says when the save
## had to be recovered or could not be used.

## Items listed by name besides crops: the most made first, at most this many.
const MAX_ITEMS := 3
const SPARKLE_SECONDS := 1.4

var sim: Simulation
var lib: SpriteLibrary
var notice: Label
var head: HBoxContainer
var counted_label: Label
var rows: VBoxContainer
var quiet: Label
var face: TextureRect
var report: Dictionary = {}
var load_status := ""
var _sparkle := -1.0


func setup(p_sim: Simulation, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	lib = p_lib
	name = "AwayView"
	add_theme_constant_override("separation", 8)
	head = HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 12)
	face = PanelViews.icon(lib, "momo_front", 72.0)
	face.name = "Face"
	face.draw.connect(_draw_sparkles)
	head.add_child(face)
	counted_label = PanelViews.label("", 16, true)
	counted_label.name = "Counted"
	counted_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	counted_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counted_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(counted_label)
	add_child(head)
	notice = PanelViews.label("", 16)
	notice.name = "Notice"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.theme_type_variation = &"GoldLabel"
	add_child(notice)
	rows = VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 4)
	add_child(rows)
	quiet = PanelViews.label("", 16, true)
	quiet.name = "Quiet"
	quiet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(quiet)
	set_process(false)


func show_report(p_report: Dictionary, p_status: String) -> void:
	report = p_report
	load_status = p_status
	refresh()
	if FxPrefs.enabled and not report.is_empty() and OfflineProgress.something_happened(report):
		_sparkle = 0.0
		set_process(true)


static func long_duration(ms: int) -> String:
	var s := ms / 1000
	if s >= 3600:
		return TranslationServer.translate("time.hm").format({"h": s / 3600, "m": (s % 3600) / 60})
	return BuildingDetailView.duration(s)


## Whether only part of the time away was counted (the offline ceiling, or
## the clock that went back), so the card must say both times.
func partly_counted() -> bool:
	return bool(report.get("capped_time", false)) or bool(report.get("capped_events", false)) or bool(report.get("clock_went_back", false))


## [label, value, icon] for each thing the island did; tests and the E2E
## bridge read label and value.
func lines() -> Array[Array]:
	var out: Array[Array] = []
	if report.is_empty():
		return out
	out.append([tr("away.time"), long_duration(int(report["away_ms"])), ""])
	if partly_counted():
		out.append([tr("away.capped").format({"t": long_duration(int(report["counted_ms"]))}), "", ""])
	if int(report.get("income", 0)) > 0:
		out.append([tr("away.income"), "+$" + FxPrefs.compact(int(report["income"])), "icon_coin"])
	if int(report.get("exp", 0)) > 0:
		out.append([tr("away.exp"), "+" + FxPrefs.compact(int(report["exp"])), "icon_star"])
	if int(report.get("crops", 0)) > 0:
		out.append([tr("away.crops"), "+" + FxPrefs.compact(int(report["crops"])), "ui_sprout"])
	var items: Dictionary = report.get("items", {})
	var made: Array = items.keys().filter(func(k: String) -> bool: return k != "crop" and int(items[k]) > 0)
	made.sort_custom(func(a: String, b: String) -> bool: return int(items[a]) > int(items[b]) or (int(items[a]) == int(items[b]) and a < b))
	for item: String in made.slice(0, MAX_ITEMS):
		var def := sim.data.item(item)
		out.append([tr(String(def.get("name", item))), "+" + FxPrefs.compact(int(items[item])), String(def.get("icon", ""))])
	if int(report.get("jobs", 0)) > 0:
		var who := int(report.get("workers", 0))
		var value := str(int(report["jobs"]))
		if who > 0:
			value = tr("away.jobs_by").format({"n": FxPrefs.compact(int(report["jobs"])), "m": who})
		out.append([tr("panel.records.tasks"), value, "ui_build"])
	var research: ResearchSystem = sim.system(&"research")
	for id: String in report.get("research", []):
		out.append([tr("away.research"), tr(String(research.node(id).get("name", id))), "ui_flask"])
	if int(report.get("letters", 0)) > 0:
		out.append([tr("away.letters"), str(int(report["letters"])), "ui_mail"])
	return out


func refresh() -> void:
	var notes := {"backup": "save.backup", "corrupt": "save.corrupt", "too_new": "save.too_new"}
	notice.text = tr(notes[load_status]) if notes.has(load_status) else ""
	notice.visible = notice.text != ""
	PanelViews.clear(rows)
	var all := lines()
	# The first line (how long) goes in the head beside Momo; the rest below.
	head.visible = not report.is_empty()
	if head.visible:
		var away := long_duration(int(report["away_ms"]))
		if partly_counted():
			counted_label.text = tr("away.counted_part").format({"away": away, "t": long_duration(int(report["counted_ms"]))})
		elif OfflineProgress.something_happened(report):
			counted_label.text = tr("away.counted_all").format({"away": away})
		else:
			counted_label.text = tr("away.counted_only").format({"away": away})
	for line: Array in all.slice(2 if partly_counted() else 1):
		var r := PanelViews.row(String(line[0]), String(line[1]))
		if String(line[2]) != "" and lib != null and lib.has(String(line[2])):
			var icon := PanelViews.icon(lib, String(line[2]), 24.0)
			r.add_child(icon)
			r.move_child(icon, 0)
		rows.add_child(r)
	var happened := OfflineProgress.something_happened(report) if not report.is_empty() else true
	quiet.text = tr("away.quiet") if not happened else ""
	quiet.visible = quiet.text != ""


func _process(delta: float) -> void:
	_sparkle += delta
	face.queue_redraw()
	if _sparkle >= SPARKLE_SECONDS:
		_sparkle = -1.0
		set_process(false)


## A few small stars around Momo: a restrained hello, once.
func _draw_sparkles() -> void:
	if _sparkle < 0.0:
		return
	var k := _sparkle / SPARKLE_SECONDS
	var c := face.size * 0.5
	for i in 5:
		var a := TAU * i / 5.0 + 0.6
		var r := 30.0 + k * 10.0
		var p := c + Vector2(cos(a), sin(a) * 0.8) * r
		var s := 4.0 * sin(clampf(k * PI * (1.0 + i * 0.12), 0.0, PI))
		var col := Color(1.0, 0.88, 0.45, 1.0 - k)
		face.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 2.0, true)
		face.draw_line(p - Vector2(0, s), p + Vector2(0, s), col, 2.0, true)
