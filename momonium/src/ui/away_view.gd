class_name AwayView
extends VBoxContainer

## "Welcome back": what the island did while the game was closed, from the
## catch-up's report -- time away (and if only part of it was counted), crops
## grown, money earned, jobs done, research finished, letters. Also says when
## the save had to be recovered or could not be used.

var sim: Simulation
var notice: Label
var rows: VBoxContainer
var report: Dictionary = {}
var load_status := ""


func setup(p_sim: Simulation, lib: SpriteLibrary) -> void:
	sim = p_sim
	name = "AwayView"
	add_theme_constant_override("separation", 8)
	var face := PanelViews.icon(lib, "momo_front", 72.0)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(face)
	notice = PanelViews.label("", 16)
	notice.name = "Notice"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_color_override("font_color", Color("#ffe27a"))
	add_child(notice)
	rows = VBoxContainer.new()
	rows.name = "Rows"
	add_child(rows)


func show_report(p_report: Dictionary, p_status: String) -> void:
	report = p_report
	load_status = p_status
	refresh()


static func long_duration(ms: int) -> String:
	var s := ms / 1000
	if s >= 3600:
		return TranslationServer.translate("time.hm").format({"h": s / 3600, "m": (s % 3600) / 60})
	return BuildingDetailView.duration(s)


func lines() -> Array[Array]:
	var out: Array[Array] = []
	if report.is_empty():
		return out
	out.append([tr("away.time"), long_duration(int(report["away_ms"]))])
	if bool(report.get("capped_time", false)) or bool(report.get("capped_events", false)):
		out.append([tr("away.capped").format({"t": long_duration(int(report["counted_ms"]))}), ""])
	if int(report.get("crops", 0)) > 0:
		out.append([tr("away.crops"), "+%d" % int(report["crops"])])
	if int(report.get("income", 0)) > 0:
		out.append([tr("away.income"), "+" + PanelViews.money(int(report["income"]))])
	if int(report.get("jobs", 0)) > 0:
		out.append([tr("panel.records.tasks"), str(int(report["jobs"]))])
	var research: ResearchSystem = sim.system(&"research")
	for id: String in report.get("research", []):
		out.append([tr("away.research"), tr(String(research.node(id).get("name", id)))])
	if int(report.get("letters", 0)) > 0:
		out.append([tr("away.letters"), str(int(report["letters"]))])
	return out


func refresh() -> void:
	var notes := {"backup": "save.backup", "corrupt": "save.corrupt", "too_new": "save.too_new"}
	notice.text = tr(notes[load_status]) if notes.has(load_status) else ""
	notice.visible = notice.text != ""
	PanelViews.clear(rows)
	for line: Array in lines():
		var r := PanelViews.row(String(line[0]), String(line[1]))
		rows.add_child(r)
