class_name Settings
extends RefCounted

## The player's two comfort settings, with no words on screen (icons in the
## HUD's lower left): the volume (3 steps: full, half, off) and reduced motion
## (no screen flash, no shake). Stored in user://windup_settings.json, apart
## from the save, so starting over keeps them. `?sound=off`, `?motion=reduce`
## and the system's prefers-reduced-motion set them for a visit.

const PATH := "user://windup_settings.json"
const VOLUMES: Array[float] = [1.0, 0.5, 0.0]

var volume_step: int = 0
var reduced_motion: bool = false
var path: String = PATH


func volume() -> float:
	return VOLUMES[clampi(volume_step, 0, VOLUMES.size() - 1)]


func cycle_volume() -> void:
	volume_step = (volume_step + 1) % VOLUMES.size()


func load_saved() -> void:
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var d: Variant = json.data
	if d is Dictionary:
		volume_step = clampi(int((d as Dictionary).get("volume_step", 0)), 0, VOLUMES.size() - 1)
		reduced_motion = bool((d as Dictionary).get("reduced_motion", false))


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"volume_step": volume_step, "reduced_motion": reduced_motion}))


## Applies the volume to the Master bus.
func apply_audio() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	var v := volume()
	AudioServer.set_bus_mute(bus, v <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
