extends RefCounted

## The large island demo with the performance readout on (Step 41).


func setup(main: Node) -> void:
	var settings: SettingsStore = main.get("settings")
	settings.persistent = false
	settings.set_value("perf_overlay", true)
	main.call("apply_options")
	var cams: CameraController = main.get("cameras")
	if OS.get_environment("MOMONIUM_CAPTURE_STEP") == "close":
		for i in 6:
			cams.zoom_at(1.5, cams.viewport_size() * 0.5)
