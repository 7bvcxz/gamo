class_name HudButton
extends Button

## A small square corner button: an icon over a one-word label. Compact on
## purpose -- the island is the picture, the buttons are the frame.

const SIZE := Vector2(68, 68)

var action: StringName
var label_key: String
var badge := false:
	set(value):
		badge = value
		queue_redraw()

var _icon_rect: TextureRect
var _label: Label
## Step 57: news has arrived (a letter): the red dot swells twice and the
## icon gives one small wiggle, then everything is still again. Seconds into
## it, or -1. Reduced motion or effects off: no movement at all (the dot just
## shows).
const PULSE_SECONDS := 1.2
const WIGGLE_SECONDS := 0.45
var _pulse := -1.0
## How many times it has played (tests: news comes once, not in a storm).
var pulse_count := 0


func _init(p_action: StringName, p_label_key: String, icon_texture: Texture2D) -> void:
	action = p_action
	label_key = p_label_key
	name = "Button_" + String(p_action)
	custom_minimum_size = SIZE
	size = SIZE
	focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_icon_rect = TextureRect.new()
	_icon_rect.texture = icon_texture
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.custom_minimum_size = Vector2(30, 30)
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	box.add_child(_icon_rect)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	refresh_text()


func _ready() -> void:
	set_process(false)


## Plays the news once (a play already under way is not restarted).
func pulse() -> void:
	if not FxPrefs.enabled or FxPrefs.reduced_motion or _pulse >= 0.0:
		return
	_pulse = 0.0
	pulse_count += 1
	set_process(true)


func pulsing() -> bool:
	return _pulse >= 0.0


## The dot's size now: 1 at rest, swelling twice while news plays.
func dot_scale() -> float:
	if _pulse < 0.0:
		return 1.0
	return 1.0 + 0.55 * absf(sin(PI * 2.0 * clampf(_pulse / PULSE_SECONDS, 0.0, 1.0)))


func _process(delta: float) -> void:
	if _pulse < 0.0:
		set_process(false)
		return
	_pulse += delta
	var w := clampf(_pulse / WIGGLE_SECONDS, 0.0, 1.0)
	_icon_rect.pivot_offset = _icon_rect.size * 0.5
	_icon_rect.rotation = sin(w * TAU * 2.0) * 0.2 * (1.0 - w)
	if _pulse >= PULSE_SECONDS:
		_pulse = -1.0
		_icon_rect.rotation = 0.0
		set_process(false)
	queue_redraw()


func refresh_text() -> void:
	_label.text = tr(label_key)
	# A mouse resting on it (desktop) gets the name in a tooltip too, and a
	# screen reader the same name (Step 59).
	tooltip_text = _label.text
	accessibility_name = _label.text


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label != null:
		refresh_text()


func _draw() -> void:
	if badge:
		var r := 6.5 * dot_scale()
		if _pulse >= 0.0:
			# A soft glow round the swelling dot.
			draw_circle(Vector2(size.x - 8, 8), r + 4.0, Color(1.0, 0.35, 0.3, 0.25 * (dot_scale() - 1.0) / 0.55))
		draw_circle(Vector2(size.x - 8, 8), r, Color("#ff5a4f"))
		draw_arc(Vector2(size.x - 8, 8), r, 0, TAU, 16, Color.WHITE, 1.6, true)
