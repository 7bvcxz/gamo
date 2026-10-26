class_name PerfOverlay
extends Label

## A small readout of how hard the game is working (Settings > show
## performance): frames per second, the time a frame and the simulation take,
## how many buildings and Momo are animating of all there are (the rest are
## out of sight), draw calls and memory. Measured continuously but written
## twice a second, so watching costs next to nothing.

const REFRESH_SECONDS := 0.5

var building_views: BuildingViews
var momo_views: MomoViews
## Milliseconds the simulation took this frame (set by the composition root).
var sim_ms := 0.0
var _sim_sum := 0.0
var _frames := 0
var _left := 0.0
## The last numbers shown (the browser bridge reads them).
var numbers: Dictionary = {}


func setup(p_buildings: BuildingViews, p_momos: MomoViews) -> void:
	name = "PerfOverlay"
	building_views = p_buildings
	momo_views = p_momos
	add_theme_font_size_override("font_size", 15)
	add_theme_color_override("font_color", Color("#eaf6ff"))
	# A dark plate, so it reads over sea and grass alike.
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.04, 0.11, 0.2, 0.78)
	plate.set_corner_radius_all(8)
	plate.content_margin_left = 8.0
	plate.content_margin_right = 8.0
	plate.content_margin_top = 4.0
	plate.content_margin_bottom = 4.0
	add_theme_stylebox_override("normal", plate)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func show_overlay(on: bool) -> void:
	visible = on
	set_process(on)
	_left = 0.0


func _process(delta: float) -> void:
	_sim_sum += sim_ms
	_frames += 1
	_left -= delta
	if _left > 0.0:
		return
	_left = REFRESH_SECONDS
	numbers = measure()
	_sim_sum = 0.0
	_frames = 0
	text = "%d fps · %.1f ms · sim %.2f ms\n%s %d/%d · Momo %d/%d · %d draws · %.0f MB" % [
		numbers["fps"], numbers["frame_ms"], numbers["sim_ms"], tr("perf.buildings"),
		numbers["buildings_awake"], numbers["buildings"], numbers["momos_awake"], numbers["momos"],
		numbers["draw_calls"], numbers["memory_mb"]]


func measure() -> Dictionary:
	var awake := 0
	if building_views != null:
		awake = building_views.active_count()
	return {
		"fps": int(Engine.get_frames_per_second()),
		"frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"sim_ms": _sim_sum / maxi(_frames, 1),
		"buildings": building_views.views.size() if building_views != null else 0,
		"buildings_awake": awake,
		"momos": momo_views.actors.size() if momo_views != null else 0,
		"momos_awake": momo_views.awake_count() if momo_views != null else 0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	}
