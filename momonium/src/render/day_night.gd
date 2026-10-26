class_name DayNight
extends Node

## Ties the sea and the world's light to the simulation clock.
##
## Every frame it reads the day's progress from sim.clock -- never a frame
## counter -- turns it into a look with DayPalette, and hands that to the
## ocean shader and the world's CanvasModulate. Pausing the clock freezes the
## look; speeding it up runs the day faster; a loaded save shows the look of
## its saved moment. Step 56: there is no sky. The day is in the water -- its
## colours, and a faint glow where the sun or moon is mirrored.

## The reflection's height on the screen (a fraction): over the upper water,
## where the sky used to be.
const GLOW_Y := 0.24

var sim: Simulation
var palette: DayPalette
var cycle: DayCycle
var ocean: OceanRenderer
var ambient: CanvasModulate
var current: Dictionary = {}


func setup(p_sim: Simulation, p_ocean: OceanRenderer, p_ambient: CanvasModulate) -> void:
	sim = p_sim
	ocean = p_ocean
	ambient = p_ambient
	palette = DayPalette.new(sim.data)
	cycle = DayCycle.new(sim.data)
	apply()


func _process(_delta: float) -> void:
	apply()


func apply() -> void:
	var progress := sim.clock.day_progress()
	var look := palette.at(progress)
	current = look
	var sea: Array = look["sea"]
	ocean.set_palette(sea[2], sea[1], sea[3], sea[0], look["glint"])
	var sun_h := palette.sun_elevation(progress)
	var moon_h := palette.moon_elevation(progress)
	# The reflection follows whichever body is up.
	var body_x := lerpf(0.12, 0.88, palette.sun_across(progress)) if sun_h > 0.0 else lerpf(0.15, 0.85, palette.moon_across(progress))
	ocean.sun_screen_fraction = Vector2(body_x, GLOW_Y)
	ocean.sun_strength = float(look["glint_strength"]) * (0.4 + 0.6 * clampf(maxf(sun_h, moon_h), 0.0, 1.0))
	ambient.color = look["ambient"]
	BuildingView.ambient = look["ambient"]


## E2E/debug: the current phase name and the sea's resolved colours.
func describe() -> Dictionary:
	var sea: Array = current.get("sea", [Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK])
	return {"phase": String(cycle.phase(sim.clock)), "day": sim.clock.day_number(),
		"progress": sim.clock.day_progress(), "sea_far": (sea[0] as Color).to_html(false),
		"sea_mid": (sea[1] as Color).to_html(false), "sea_deep": (sea[2] as Color).to_html(false),
		"ambient": (current.get("ambient", Color.WHITE) as Color).to_html(false),
		"glow": [ocean.sun_screen_fraction.x, ocean.sun_screen_fraction.y], "glow_strength": ocean.sun_strength}
