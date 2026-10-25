class_name DayNight
extends Node

## Ties the sky, the sea and the world's light to the simulation clock.
##
## Every frame it reads the day's progress from sim.clock -- never a frame
## counter -- turns it into a look with SkyPalette, and hands that to the sky
## shader, the ocean shader and the world's CanvasModulate. Pausing the clock
## freezes the sky; speeding it up runs the day faster; a loaded save shows the
## sky of its saved moment.

var sim: Simulation
var palette: SkyPalette
var cycle: DayCycle
var sky: SkyRenderer
var ocean: OceanRenderer
var ambient: CanvasModulate
var current: Dictionary = {}


func setup(p_sim: Simulation, p_sky: SkyRenderer, p_ocean: OceanRenderer, p_ambient: CanvasModulate) -> void:
	sim = p_sim
	sky = p_sky
	ocean = p_ocean
	ambient = p_ambient
	palette = SkyPalette.new(sim.data)
	cycle = DayCycle.new(sim.data)
	apply()


func _process(_delta: float) -> void:
	apply()


func apply() -> void:
	var progress := sim.clock.day_progress()
	var look := palette.at(progress)
	current = look
	var sky_colors: Array = look["sky"]
	var sea: Array = look["sea"]
	sky.set_param(&"top_color", sky_colors[0])
	sky.set_param(&"mid_color", sky_colors[1])
	sky.set_param(&"horizon_color", sky_colors[2])
	sky.set_param(&"cloud_color", look["cloud"])
	sky.set_param(&"cloud_shade", look["cloud_shade"])
	sky.set_param(&"stars", look["stars"])
	# Clouds drift with simulated time so they pause and fast-forward with it.
	var t := sim.now_ms() / 1000.0
	sky.set_param(&"cloud_drift", t * 0.012)
	sky.set_param(&"twinkle_time", t)
	var sun_h := palette.sun_elevation(progress)
	var moon_h := palette.moon_elevation(progress)
	# uv.y = 0 top, 1 horizon; the body sits a little below the horizon when down.
	sky.set_param(&"sun_uv", Vector2(lerpf(0.12, 0.88, palette.sun_across(progress)), 1.08 - 0.82 * maxf(sun_h, -0.2)))
	sky.set_param(&"moon_uv", Vector2(lerpf(0.15, 0.85, palette.moon_across(progress)), 1.1 - 0.75 * maxf(moon_h, -0.2)))
	var sun_tint: Color = (look["glint"] as Color).lerp(Color(1.0, 0.98, 0.86), clampf(sun_h, 0.0, 1.0))
	sky.set_param(&"sun_color", sun_tint)
	ocean.set_palette(sea[2], sea[1], sea[3], sea[0], look["glint"])
	# The reflection follows whichever body is up.
	var body_x := lerpf(0.12, 0.88, palette.sun_across(progress)) if sun_h > 0.0 else lerpf(0.15, 0.85, palette.moon_across(progress))
	ocean.sun_screen_fraction = Vector2(body_x, 0.3)
	ocean.sun_strength = float(look["glint_strength"]) * (0.4 + 0.6 * clampf(maxf(sun_h, moon_h), 0.0, 1.0))
	ambient.color = look["ambient"]


## E2E/debug: the current phase name and a few resolved colours.
func describe() -> Dictionary:
	var sky_colors: Array = current.get("sky", [Color.BLACK, Color.BLACK, Color.BLACK])
	return {"phase": String(cycle.phase(sim.clock)), "day": sim.clock.day_number(),
		"progress": sim.clock.day_progress(), "sky_top": (sky_colors[0] as Color).to_html(false),
		"ambient": (current.get("ambient", Color.WHITE) as Color).to_html(false)}
