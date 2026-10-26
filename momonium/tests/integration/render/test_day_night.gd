extends "res://tests/framework/test_case.gd"

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var dn: DayNight


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	dn = main.get("day_night")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


## Step 56: no sky. The sea is the whole backdrop, edge to edge, and nothing
## of a sky -- no renderer, no shader, no cloud texture -- is left under it.
func test_the_sea_fills_the_whole_view_and_no_sky_is_left() -> void:
	await tree.process_frame
	var ocean: OceanRenderer = main.get("ocean")
	var size := ocean.get_viewport_rect().size
	assert_eq(ocean.position, Vector2.ZERO, "from the top-left corner")
	assert_eq(ocean.size, size, "to the bottom-right: the whole view")
	var back := main.get_node("Background")
	assert_eq(back.get_children().map(func(n: Node) -> String: return String(n.name)), ["Ocean"], "the backdrop is the sea alone")
	var mat := ocean.material as ShaderMaterial
	var names := (mat.shader.get_shader_uniform_list() as Array).map(func(u: Dictionary) -> String: return String(u["name"]))
	assert_false("horizon_y" in names, "the sea has no horizon to stop at")
	for gone: String in ["res://assets/shaders/sky.gdshader", "res://assets/textures/clouds.png", "res://src/render/sky_renderer.gd"]:
		assert_false(ResourceLoader.exists(gone), "%s is gone" % gone)
	# A resize: still edge to edge.
	var was := tree.root.size
	tree.root.size = Vector2i(1280, 800)
	await tree.process_frame
	await tree.process_frame
	assert_eq(ocean.size, ocean.get_viewport_rect().size, "a landscape window too")
	tree.root.size = was
	await tree.process_frame


## The day's colours reach the sea's shader -- fresh blue, warm, navy -- and
## the sun or moon is only a soft glow on the water, following its arc.
func test_the_sea_takes_the_time_of_day() -> void:
	var ocean: OceanRenderer = main.get("ocean")
	var mat := ocean.material as ShaderMaterial
	var at := func(p: float) -> Dictionary:
		sim.advance_to(maxi(int(p * sim.clock.day_ms), sim.now_ms()))
		dn.apply()
		return {"far": mat.get_shader_parameter("far_color"), "mid": mat.get_shader_parameter("mid_color"), "glow": ocean.sun_screen_fraction, "strength": ocean.sun_strength}
	var day: Dictionary = await at.call(0.3)
	var sunset: Dictionary = await at.call(0.62)
	var night: Dictionary = await at.call(0.86)
	assert_eq(dn.describe()["phase"], "night", "")
	var luma := func(c: Color) -> float: return c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	assert_true((day["mid"] as Color).b > (day["mid"] as Color).r + 0.4, "day: blue water")
	assert_true((sunset["far"] as Color).r > (sunset["far"] as Color).b, "sunset: warm light on it")
	assert_true(luma.call(night["mid"]) < luma.call(day["mid"]) - 0.2, "night: darker water")
	assert_true((day["glow"] as Vector2).x < (sunset["glow"] as Vector2).x, "the sun's glow moves across with the day")
	assert_true(float(night["strength"]) < float(sunset["strength"]), "the moon's is fainter than the low sun's")


func test_world_light_follows_the_clock() -> void:
	var ambient: CanvasModulate = main.get("ambient")
	sim.advance_to(int(0.3 * sim.clock.day_ms))
	dn.apply()
	var day := ambient.color
	sim.advance_to(int(0.86 * sim.clock.day_ms))
	dn.apply()
	var night := ambient.color
	assert_eq(day, Color.WHITE, "full light at midday")
	var luma := func(c: Color) -> float: return c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	assert_true(luma.call(night) < luma.call(day) - 0.3, "the island is darker at night")
	assert_true(night.b > night.r, "and moonlit blue, not grey")
	assert_eq(dn.describe()["phase"], "night", "and the phase says so")


func test_paused_clock_freezes_the_sea_look() -> void:
	var mat := (main.get("ocean") as OceanRenderer).material as ShaderMaterial
	sim.advance_to(int(0.6 * sim.clock.day_ms))
	sim.time_scale = 0.0
	await tree.process_frame
	var far: Color = mat.get_shader_parameter("far_color")
	for i in 5:
		await tree.process_frame
	assert_eq(mat.get_shader_parameter("far_color"), far, "no simulated time, no change of light")
	sim.time_scale = 1.0


func test_fast_forward_runs_the_day_on_the_water() -> void:
	var mat := (main.get("ocean") as OceanRenderer).material as ShaderMaterial
	sim.advance_to(int(0.55 * sim.clock.day_ms))
	dn.apply()
	var before: Color = mat.get_shader_parameter("far_color")
	# What a fast-forward does: simulated time jumps; the look is its function.
	sim.advance_ms(int(0.1 * sim.clock.day_ms))
	dn.apply()
	var after: Color = mat.get_shader_parameter("far_color")
	assert_eq(after, (DayPalette.new(sim.data).at(sim.clock.day_progress())["sea"] as Array)[0], "the look of the new moment")
	assert_true(after.r > before.r, "the light warmed towards sunset")
