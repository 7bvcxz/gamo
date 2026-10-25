extends RefCounted

## The performance readout with Settings open over it (Step 44).


func setup(main: Node) -> void:
	var settings: SettingsStore = main.get("settings")
	settings.persistent = false
	settings.set_value("perf_overlay", true)
	main.call("apply_options")
	(main.get("settings_frame") as PanelFrame).open()
