extends Node2D

## Composition root. Builds the Simulation, then the views that show it, and
## hands each view the simulation it reads -- nothing is reached through a
## global. Owns the frame loop: real time in, simulated time out.

var sim: Simulation
var bridge := WebBridge.new()
var _version_label: Label


func _ready() -> void:
	sim = Simulation.new_game()
	add_child(Backdrop.new())
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	_version_label = Label.new()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0")
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_version_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(_version_label)
	get_viewport().size_changed.connect(_layout)
	_layout()
	bridge.attach(sim, _version_label.text.trim_prefix("v"))
	bridge.register_query("save_roundtrip", _save_roundtrip)


func _process(delta: float) -> void:
	sim.advance_seconds(delta)


func _layout() -> void:
	_version_label.position = get_viewport_rect().size - Vector2(84, 28)


## E2E: proves the platform's user:// (IndexedDB on the web) can hold a save and
## give the same world back. Writes to its own file, never the player's save.
func _save_roundtrip(_arg: Variant) -> Dictionary:
	var path := "user://e2e_roundtrip.json"
	var err := SaveService.write(sim, path)
	var restored := Simulation.from_save(SaveService.read(path))
	var same := JSON.stringify(restored.snapshot()) == JSON.stringify(sim.snapshot())
	DirAccess.remove_absolute(path)
	return {"write": err, "equal": same, "now_ms": restored.now_ms()}
