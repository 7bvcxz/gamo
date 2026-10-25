class_name FxPrefs
extends RefCounted

## How much the game celebrates (Step 47), set from Settings: effects on or
## off, and reduced motion (no rising, bouncing or flying -- fades only). One
## place every view asks, so the setting reaches all of them at once. Values
## alone change, never the game: the numbers still update with effects off.

static var enabled := true
static var reduced_motion := false


static func apply(settings: SettingsStore) -> void:
	enabled = bool(settings.get_value("effects"))
	reduced_motion = bool(settings.get_value("reduce_motion"))


## Whether things may move (rise, bounce, fly) as well as appear.
static func moving() -> bool:
	return enabled and not reduced_motion


static func reset() -> void:
	enabled = true
	reduced_motion = false


## A number short enough to read at a glance: 950, 12.3K, 4.5M, 1.2B.
static func compact(n: float) -> String:
	var a := absf(n)
	var sign_text := "-" if n < 0.0 else ""
	if a < 10000.0:
		return sign_text + str(int(round(a)))
	for unit: Array in [[1e9, "B"], [1e6, "M"], [1e3, "K"]]:
		if a >= float(unit[0]):
			var v := a / float(unit[0])
			var text := ("%.1f" % v) if v < 100.0 else str(int(v))
			return sign_text + text.trim_suffix(".0") + String(unit[1])
	return sign_text + str(int(round(a)))
