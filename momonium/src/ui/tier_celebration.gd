class_name TierCelebration
extends Control

## A short celebration when the settlement is promoted: a banner with its new
## name and a burst of confetti, 2.5 s, over everything, taking no taps.

const DURATION := 2.5

var text := ""
var _t := -1.0
var _bits: Array[Dictionary] = []


func setup() -> void:
	name = "TierCelebration"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func play(banner: String) -> void:
	text = banner
	_t = 0.0
	visible = true
	_bits.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var colours: Array[Color] = [Color("#ffd45a"), Color("#ff8aa8"), Color("#7ff0e6"), Color("#b7f08a"), Color.WHITE]
	for i in 60:
		_bits.append({"x": rng.randf(), "v": rng.randf_range(0.5, 1.1), "phase": rng.randf() * TAU, "c": colours[i % colours.size()], "s": rng.randf_range(4.0, 8.0)})


func playing() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t >= DURATION:
		_t = -1.0
		visible = false
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var k := _t / DURATION
	var fade := clampf((1.0 - k) * 3.0, 0.0, 1.0)
	for b: Dictionary in _bits:
		var p := Vector2(float(b["x"]) * size.x + sin(_t * 3.0 + float(b["phase"])) * 18.0, -20.0 + _t * float(b["v"]) * size.y * 0.55)
		draw_rect(Rect2(p, Vector2.ONE * float(b["s"])), Color(b["c"], fade))
	var font := get_theme_default_font()
	var fs := 34
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pop := minf(_t / 0.25, 1.0)
	var box := Rect2(Vector2((size.x - ts.x) * 0.5 - 24.0, size.y * 0.3 - 40.0), Vector2(ts.x + 48.0, 72.0))
	draw_rect(box.grow(4.0 * (1.0 - pop)), Color(0.06, 0.18, 0.36, 0.9 * fade))
	draw_rect(box, Color("#ffd45a", fade), false, 3.0)
	draw_string(font, Vector2(box.position.x + 24.0, box.position.y + 48.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, fade))
