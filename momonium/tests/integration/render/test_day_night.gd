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


func test_sky_fills_the_top_two_fifths() -> void:
	await tree.process_frame
	var sky: SkyRenderer = main.get("sky")
	var size := sky.get_viewport_rect().size
	assert_near(sky.size.y / size.y, 0.4, 0.001, "sky is the top 2/5")
	assert_near(sky.size.x, size.x, 0.001, "full width")
	assert_near((main.get("ocean") as OceanRenderer).HORIZON_FRACTION, 0.4, 0.0001, "the sea starts where the sky ends")


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


func test_paused_clock_freezes_the_sky() -> void:
	sim.time_scale = 0.0
	await tree.process_frame
	var mat := (main.get("sky") as SkyRenderer).material as ShaderMaterial
	var drift: float = mat.get_shader_parameter("cloud_drift")
	for i in 5:
		await tree.process_frame
	assert_eq(mat.get_shader_parameter("cloud_drift"), drift, "no simulated time, no cloud drift")
	sim.time_scale = 1.0


func test_sky_reads_simulated_not_frame_time() -> void:
	var mat := (main.get("sky") as SkyRenderer).material as ShaderMaterial
	sim.advance_ms(60000)
	dn.apply()
	assert_near(float(mat.get_shader_parameter("cloud_drift")), sim.now_ms() / 1000.0 * 0.012, 0.0001, "cloud position is a function of sim time")
