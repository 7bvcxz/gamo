class_name PopPlayView
extends Control

## The play area of one experiment: the machine and what flies out of it.
## The whole area is the target (a newcomer who taps beside the machine still
## makes it pop). It turns input into commands for the app -- it never changes
## the rules itself -- and turns the rules' events into pictures.
##
## Hints, never words: the machine breathes; after HINT_RING_MS without input a
## ring pulses round it; after HINT_HAND_MS with no input at all, a finger taps
## it (AGENTS.md: more help only after someone has been stuck ~20 seconds).

signal command(kind: String, cmd: Dictionary)

const HINT_RING_MS := 8000
const HINT_HAND_MS := 20000

var rules: PopRules
var fx := PopFx.new()
var rng := RandomNumberGenerator.new()
var reduced_motion := false
## Set by the app each frame: active time and the time of the last input (-1: none).
var now_ms := 0
var last_input_ms := -1
var _t := 0.0
var _squash := 0.0
var _held := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	rng.seed = 1


func setup(p_rules: PopRules) -> void:
	rules = p_rules
	fx.clear()
	_squash = 0.0
	_held = false


## Bottom-centre of the machine and its stage-4 height, in this control's space.
func machine_base() -> Vector2:
	return Vector2(size.x / 2, size.y * 0.86)


## The stage-4 machine is this tall: it must leave room above for the
## popcorn to fly and fit the column's width with the awning.
func machine_size() -> float:
	return minf(size.y * 0.72, size.x * 0.78)


func machine_top() -> Vector2:
	var h := PopMachineArt.height_at(rules.level if rules else 0, machine_size())
	return machine_base() - Vector2(0, h * 0.78)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_held = true
		_press()
	elif _held:
		_held = false
		_release()


## Space / Enter: the same action from the keyboard.
func key(down: bool) -> void:
	if down:
		_press()
	else:
		_release()


func _press() -> void:
	command.emit("press", {"type": "press"})


func _release() -> void:
	pass


## The rules' events of this frame, in order.
func on_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"pop":
				_squash = 1.0
				var n := int(e["data"].get("count", 1))
				fx.burst(machine_top(), mini(n, 14) if not reduced_motion else 1, machine_size() / 900.0, rng)
			"earn":
				fx.coin(machine_top(), machine_size() / 900.0)
			"upgrade":
				_squash = 1.0
				fx.burst(machine_top(), 18 if not reduced_motion else 2, machine_size() / 900.0, rng)


func _process(delta: float) -> void:
	_t += delta
	_squash = maxf(0.0, _squash - delta * 6.0)
	fx.step(delta)
	queue_redraw()


func _draw() -> void:
	if rules == null:
		return
	var base := machine_base()
	var size_px := machine_size()
	var breathe := 0.0 if reduced_motion else sin(_t * 2.4) * 0.012
	var fill := 0.15 + 0.7 * float(rules.level) / maxf(1.0, float(rules.max_level()))
	PopMachineArt.draw(self, base, size_px, rules.level, _squash, fill, Color(0, 0, 0, 0), breathe)
	_draw_hints(base, size_px)
	fx.draw(self)


func _draw_hints(base: Vector2, size_px: float) -> void:
	var idle := now_ms - maxi(last_input_ms, 0)
	if idle < HINT_RING_MS:
		return
	var c := base - Vector2(0, PopMachineArt.height_at(rules.level, size_px) * 0.5)
	var phase := fmod(_t, 1.2) / 1.2
	var r := size_px * (0.35 + 0.15 * phase)
	draw_arc(c, r, 0.0, TAU, 48, Color(PopPalette.INK, 0.45 * (1.0 - phase)), 6.0)
	if last_input_ms < 0 and now_ms >= HINT_HAND_MS:
		var tap := 0.5 + 0.5 * sin(_t * 6.0)
		var p := c + Vector2(size_px * 0.12, size_px * 0.05 + tap * 18.0)
		# A finger: a rounded stub with a nail, pointing up-left at the machine.
		draw_circle(p, 22, PopPalette.CREAM)
		draw_rect(Rect2(p.x - 22, p.y, 44, 70), PopPalette.CREAM)
		draw_circle(p + Vector2(0, -6), 10, Color(1, 0.85, 0.8))
		draw_arc(p, 22, PI, TAU, 16, PopPalette.INK, 4.0)
