extends RefCounted
# Local input metrics (no server, no analytics SDK). Distances are in viewport
# pixels and in "normalized units" (pixels / the shorter viewport side), never in
# millimetres: nothing here is calibrated to a physical screen.
#
# raw input      = every press (finger or mouse), whatever it landed on
# gameplay       = presses that began on the field and ended without cancel
# accepted       = gameplay gestures the rules took as an action
# upgrade taps   = presses that began and ended on an upgrade button

var gestures_raw: int = 0
var gestures_field: int = 0
var accepted: int = 0
var upgrade_taps: int = 0
var upgrade_buys: int = 0
var button_taps: int = 0
var cancelled: int = 0
var travel_px: float = 0.0
var travel_norm: float = 0.0
var down_time: float = 0.0
var field_down_time: float = 0.0
var first_action_t: float = -1.0
var first_buy_t: float = -1.0
var view: Vector2 = Vector2.ZERO
var dpr: float = 1.0
var minutes: Array = []   # per minute: {g, acc, down, buys, earned0}


func reset() -> void:
	gestures_raw = 0
	gestures_field = 0
	accepted = 0
	upgrade_taps = 0
	upgrade_buys = 0
	button_taps = 0
	cancelled = 0
	travel_px = 0.0
	travel_norm = 0.0
	down_time = 0.0
	field_down_time = 0.0
	first_action_t = -1.0
	first_buy_t = -1.0
	minutes.clear()


func _bucket(t: float, earned_now: float) -> Dictionary:
	var m: int = int(t / 60.0)
	while minutes.size() <= m:
		minutes.append({"g": 0, "acc": 0, "down": 0.0, "buys": 0, "earned0": earned_now})
	return minutes[m]


# One finished press. kind: "field", "upgrade", "button".
func press(t: float, earned_now: float, kind: String, down_s: float, px: float, norm: float, was_cancelled: bool, took: bool) -> void:
	gestures_raw += 1
	down_time += down_s
	travel_px += px
	travel_norm += norm
	var b: Dictionary = _bucket(t, earned_now)
	b["g"] += 1
	b["down"] += down_s
	if was_cancelled:
		cancelled += 1
		return
	match kind:
		"field":
			gestures_field += 1
			field_down_time += down_s
			if took:
				accepted += 1
				b["acc"] += 1
				if first_action_t < 0.0:
					first_action_t = t
		"upgrade":
			upgrade_taps += 1
			if took:
				upgrade_buys += 1
				b["buys"] += 1
				if first_buy_t < 0.0:
					first_buy_t = t
		_:
			button_taps += 1


func input_fraction(t: float, live_down: float) -> float:
	return (down_time + live_down) / maxf(t, 0.001)


func per_minute(count: int, t: float) -> float:
	return float(count) / maxf(t / 60.0, 1.0 / 60.0)


func summary(t: float, live_down: float, earned: float, game: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("elapsed_s=%.1f" % t)
	lines.append("viewport=%dx%d dpr=%.2f" % [int(view.x), int(view.y), dpr])
	lines.append("raw_presses=%d (%.1f/min) field_gestures=%d accepted=%d upgrade_taps=%d buys=%d other_taps=%d cancelled=%d" % [gestures_raw, per_minute(gestures_raw, t), gestures_field, accepted, upgrade_taps, upgrade_buys, button_taps, cancelled])
	lines.append("travel_px=%.0f travel_norm=%.2f touch_down_s=%.2f active_input_fraction=%.3f" % [travel_px, travel_norm, down_time + live_down, input_fraction(t, live_down)])
	lines.append("first_action_s=%.2f first_buy_s=%.2f earned=%.1f earned_per_min=%.1f" % [first_action_t, first_buy_t, earned, earned / maxf(t / 60.0, 1.0 / 60.0)])
	for k in game:
		lines.append("%s=%s" % [k, str(game[k])])
	for i in minutes.size():
		var b: Dictionary = minutes[i]
		var nxt: float = float(minutes[i + 1]["earned0"]) if i + 1 < minutes.size() else earned
		lines.append("minute%d: presses=%d accepted=%d buys=%d down_s=%.2f earned=%.1f" % [i + 1, b["g"], b["acc"], b["buys"], b["down"], nxt - float(b["earned0"])])
	return "\n".join(lines)
