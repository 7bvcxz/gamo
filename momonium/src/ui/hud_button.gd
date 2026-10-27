class_name HudButton
extends Button

## A small square corner button: an icon over a one-word label. Compact on
## purpose -- the island is the picture, the buttons are the frame.

const SIZE := Vector2(68, 68)

var action: StringName
var label_key: String
## How many things are new here (Step 64): 0 shows nothing, 1-99 the number,
## 100 or more "99+". Something with no count of its own -- a promotion ready,
## a hire that would put a Momo to work -- is 1, never a made-up number.
var count := 0:
	set(value):
		value = maxi(value, 0)
		if count == value:
			return
		count = value
		_refresh_names()
		queue_redraw()
## Whether there is news at all (what the red dot said before Step 64).
## Setting it shows 1, or nothing.
var badge: bool:
	get:
		return count > 0
	set(value):
		count = maxi(count, 1) if value else 0
## What a screen reader and the tooltip say with a count: a format with
## {name} and {n} ("{name}, {n} unread"); "" says the name alone.
var count_words := ""

var _icon_rect: TextureRect
var _label: Label
## Step 57: news has arrived (a letter): the badge swells twice and the
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


## The badge's size now: 1 at rest, swelling twice while news plays.
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
	_refresh_names()


## A mouse resting on it (desktop) gets the name in a tooltip, and a screen
## reader the same (Step 59) -- with the count when there is one (Step 64).
func _refresh_names() -> void:
	if _label == null:
		return
	var said := _label.text
	if count > 0 and count_words != "":
		said = tr(count_words).format({"name": _label.text, "n": badge_text(count)})
	tooltip_text = said
	accessibility_name = said


## What the badge shows for `n`: nothing at 0, the number to 99, then "99+".
static func badge_text(n: int) -> String:
	if n <= 0:
		return ""
	return "99+" if n >= 100 else str(n)


const BADGE_HEIGHT := 22.0
const BADGE_FONT := 14
const BADGE_PAD := 6.0
## How far the badge sits out past the top-right corner: on the corner, off
## the icon and the label.
const BADGE_OUT := Vector2(7.0, -7.0)
const BADGE_FILL := Color("#ff5a4f")


## Where the icon is actually drawn (its texture fitted, centred, in its
## box), in this button's coordinates -- what a badge must not cover.
func icon_drawn_rect() -> Rect2:
	var box := Rect2(_icon_rect.position, _icon_rect.size)
	var tex := _icon_rect.texture
	if tex == null or tex.get_width() == 0 or tex.get_height() == 0:
		return box
	var k := minf(box.size.x / tex.get_width(), box.size.y / tex.get_height())
	var size := Vector2(tex.get_width(), tex.get_height()) * k
	return Rect2(box.position + (box.size - size) * 0.5, size)


## The badge's rectangle in this button's coordinates (Rect2() with none):
## a capsule, wide enough for its digits, centred on the top-right corner.
func badge_rect() -> Rect2:
	var text := badge_text(count)
	if text == "":
		return Rect2()
	var font := get_theme_default_font()
	var w := maxf(BADGE_HEIGHT, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT).x + BADGE_PAD * 2.0)
	return Rect2(Vector2(size.x + BADGE_OUT.x - w, BADGE_OUT.y), Vector2(w, BADGE_HEIGHT))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label != null:
		refresh_text()


var _capsule: StyleBoxFlat


func _draw() -> void:
	var r := badge_rect()
	if r.size == Vector2.ZERO:
		return
	if _capsule == null:
		_capsule = StyleBoxFlat.new()
		_capsule.bg_color = BADGE_FILL
		_capsule.border_color = Color.WHITE
		_capsule.set_border_width_all(2)
		_capsule.set_corner_radius_all(int(BADGE_HEIGHT * 0.5))
		_capsule.anti_aliasing = true
	var c := r.get_center()
	var s := dot_scale()
	# Swelling with news, round its own centre.
	draw_set_transform(c, 0.0, Vector2(s, s))
	var local := Rect2(-r.size * 0.5, r.size)
	if _pulse >= 0.0:
		var glow := _capsule.duplicate() as StyleBoxFlat
		glow.bg_color = Color(1.0, 0.35, 0.3, 0.25 * (s - 1.0) / 0.55)
		glow.border_color = Color(0, 0, 0, 0)
		draw_style_box(glow, local.grow(4.0))
	draw_style_box(_capsule, local)
	var font := get_theme_default_font()
	var text := badge_text(count)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT)
	draw_string(font, Vector2(-ts.x * 0.5, font.get_ascent(BADGE_FONT) * 0.5 - font.get_descent(BADGE_FONT) * 0.5 + 1.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
